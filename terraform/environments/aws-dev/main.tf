terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.52"
    }
  }

  backend "s3" {}

}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# ─── Networking ────────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project}-vpc"
    Project = var.project
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project}-public-subnet"
    Project = var.project
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project}-igw"
    Project = var.project
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project}-public-rt"
    Project = var.project
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ─── Security Group ───────────────────────────────────────────────────────────

resource "aws_security_group" "app" {
  name_prefix = "${var.project}-sg-"
  description = "Security group for the application EC2 instance"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "DNS TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound HTTP for Ubuntu package bootstrap"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound HTTPS for AWS APIs and image pulls"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-sg"
    Project = var.project
  }
}

# ─── EC2 Instance ──────────────────────────────────────────────────────────────

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.stage0.name
  monitoring             = true
  ebs_optimized          = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name    = "${var.project}-vm"
    Project = var.project
  }
}

# ─── VPC Flow Logs ──────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs/${var.project}"
  retention_in_days = 400
  kms_key_id        = aws_kms_key.main.arn

  tags = {
    Project = var.project
  }
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.project}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project = var.project
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.project}-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = {
    Project = var.project
  }
}

# ─── KMS Key ──────────────────────────────────────────────────────────────────
# Used for CloudWatch Log Group encryption.

resource "aws_kms_key" "main" {
  description             = "KMS key for CloudWatch Logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs to use the key"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      },
    ]
  })

  tags = {
    Project = var.project
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project}-key"
  target_key_id = aws_kms_key.main.id
}

# ─── Stage 0 delivery identity and registry ─────────────────────────────────

locals {
  stage0_services = toset(["ingestor", "inference", "dashboard"])
  github_oidc_provider_arn = coalesce(
    var.github_oidc_provider_arn,
    try(aws_iam_openid_connect_provider.github_actions[0].arn, null),
  )
}

resource "aws_ecr_repository" "stage0" {
  for_each = local.stage0_services

  name                 = "api-observatory/${each.value}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "stage0" {
  for_each = aws_ecr_repository.stage0

  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Retain the latest 20 immutable Stage 0 candidate images."
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["tree-"]
        countType     = "imageCountMoreThan"
        countNumber   = 20
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.github_oidc_provider_arn == null ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_actions_image_publish_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.app_github_repository}:environment:aws-image-publish"]
    }
  }
}

resource "aws_iam_role" "github_actions_image_publish" {
  name               = "${var.project}-github-actions-image-publish"
  assume_role_policy = data.aws_iam_policy_document.github_actions_image_publish_assume.json
}

data "aws_iam_policy_document" "github_actions_image_publish" {
  statement {
    sid       = "PushImmutableImages"
    effect    = "Allow"
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload", "ecr:DescribeImages", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart"]
    resources = [for repository in aws_ecr_repository.stage0 : repository.arn]
  }

  statement {
    sid       = "GetEcrAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

}

resource "aws_iam_role_policy" "github_actions_image_publish" {
  name   = "${var.project}-github-actions-image-publish"
  role   = aws_iam_role.github_actions_image_publish.id
  policy = data.aws_iam_policy_document.github_actions_image_publish.json
}

data "aws_iam_policy_document" "github_actions_infra_deploy_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.infra_github_repository}:environment:aws-dev"]
    }
  }
}

resource "aws_iam_role" "github_actions_infra_deploy" {
  name               = "${var.project}-github-actions-infra-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_infra_deploy_assume.json
}

data "aws_iam_policy_document" "github_actions_infra_deploy" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:DescribeImages"]
    resources = [for repository in aws_ecr_repository.stage0 : repository.arn]
  }
  statement {
    effect  = "Allow"
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.app.id}",
    ]
  }
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetCommandInvocation"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_infra_deploy" {
  name   = "${var.project}-github-actions-infra-deploy"
  role   = aws_iam_role.github_actions_infra_deploy.id
  policy = data.aws_iam_policy_document.github_actions_infra_deploy.json
}

resource "aws_iam_role" "stage0_instance" {
  name = "${var.project}-stage0-instance"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "stage0_ssm" {
  role       = aws_iam_role.stage0_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "stage0_ecr_pull" {
  role       = aws_iam_role.stage0_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

data "aws_iam_policy_document" "stage0_runtime_parameters" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.stage0_runtime_parameter_path}/*"]
  }
}

resource "aws_iam_role_policy" "stage0_runtime_parameters" {
  name   = "${var.project}-stage0-runtime-parameters"
  role   = aws_iam_role.stage0_instance.id
  policy = data.aws_iam_policy_document.stage0_runtime_parameters.json
}

resource "aws_iam_instance_profile" "stage0" {
  name = "${var.project}-stage0"
  role = aws_iam_role.stage0_instance.name
}

resource "aws_s3_bucket" "stage0_backups" {
  bucket_prefix = "${var.project}-stage0-backups-"
}

# The Ansible SSM connection plugin transfers its module files through this
# bucket. It is separate from retained backups and intentionally unversioned so
# an interrupted controller run cannot retain module payloads indefinitely.
resource "aws_s3_bucket" "stage0_ansible_transfer" {
  bucket_prefix = "${var.project}-stage0-ansible-"
}

resource "aws_s3_bucket_public_access_block" "stage0_ansible_transfer" {
  bucket                  = aws_s3_bucket.stage0_ansible_transfer.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "stage0_ansible_transfer" {
  bucket = aws_s3_bucket.stage0_ansible_transfer.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "stage0_ansible_transfer" {
  bucket = aws_s3_bucket.stage0_ansible_transfer.id

  rule {
    id     = "expire-ansible-ssm-transfer-files"
    status = "Enabled"

    filter {}

    expiration { days = 1 }
  }
}

resource "aws_s3_bucket_public_access_block" "stage0_backups" {
  bucket                  = aws_s3_bucket.stage0_backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "stage0_backups" {
  bucket = aws_s3_bucket.stage0_backups.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_versioning" "stage0_backups" {
  bucket = aws_s3_bucket.stage0_backups.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "stage0_backups" {
  bucket = aws_s3_bucket.stage0_backups.id

  rule {
    id     = "retain-stage0-postgres-backups"
    status = "Enabled"

    filter { prefix = "postgres/" }

    expiration { days = 30 }
    noncurrent_version_expiration { noncurrent_days = 7 }
  }
}

data "aws_iam_policy_document" "stage0_backups" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${aws_s3_bucket.stage0_backups.arn}/postgres/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.stage0_backups.arn]
  }
}

resource "aws_iam_role_policy" "stage0_backups" {
  name   = "${var.project}-stage0-backups"
  role   = aws_iam_role.stage0_instance.id
  policy = data.aws_iam_policy_document.stage0_backups.json
}
