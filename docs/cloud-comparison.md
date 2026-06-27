# Cloud Comparison: AWS vs Azure

Decision log comparing the same application deployed to AWS and Azure.
This document demonstrates architectural thinking across cloud providers.

## Resource Mapping

| Concern | Azure | AWS | Notes |
|---------|-------|-----|-------|
| **Compute** | VM (B1s) | EC2 (t2.micro) | Both free tier: 750 hrs/month |
| **Database** | PostgreSQL Flexible Server (B1ms) | RDS PostgreSQL (db.t3.micro) | Azure: 750 hrs free. AWS: 750 hrs/12mo |
| **Networking** | VNet + NSG | VPC + Security Group | Functionally identical |
| **Object Storage** | Blob Storage | S3 | Backup target |
| **Container Registry** | ACR (Basic) | ECR | CI pushes images here |
| **State Backend** | Azure Storage + Blob | S3 + DynamoDB (locking) | AWS needs separate lock table |
| **SSH Access** | NSG rule + admin_cidr | SG rule + admin_cidr | Both restrict to operator IP |
| **DNS** | Azure DNS (optional) | Route 53 (optional) | Not provisioned in dev |
| **Managed K8s** | AKS | EKS | Future production target |

## Free Tier Comparison

| Resource | Azure Free | AWS Free (12-month) | AWS Always Free |
|----------|-----------|--------------------|-----------------|
| Compute | B1s: 750 hrs/mo (ongoing) | t2.micro: 750 hrs/mo | — |
| Database | Flex Server B1ms: 750 hrs/mo | RDS db.t3.micro: 750 hrs/mo | — |
| Storage | 5 GB Blob | 5 GB S3 | — |
| Bandwidth | 15 GB/mo out | 100 GB/mo out (first 12mo) | 1 GB/mo |
| Registry | ACR Basic: included | ECR: 500 MB | — |

**Strategy**: Start on Azure (generous ongoing free tier), switch to AWS when
Azure credits expire or when targeting AWS-specific services (ECS, Lambda, etc.).

## Key Architectural Differences

### 1. State Backend

**Azure**: Single resource — Storage Account with a blob container.
```hcl
backend "azurerm" {
  storage_account_name = "..."
  container_name       = "tfstate"
  key                  = "dev/terraform.tfstate"
}
```

**AWS**: Two resources — S3 bucket + DynamoDB table for state locking.
```hcl
backend "s3" {
  bucket         = "..."
  key            = "dev/terraform.tfstate"
  dynamodb_table = "...-tflock"
  encrypt        = true
}
```

**Decision**: Azure's single-resource model is simpler. AWS's separation of
storage and locking is more explicit but requires extra bootstrap.

### 2. Security Groups vs NSGs

Both enforce the same policy (SSH restricted to admin_cidr, HTTP/HTTPS open).
Azure NSGs use priority numbers; AWS security groups use implicit allow-all-deny.

### 3. Database Networking

**Azure**: Firewall rules on the Flexible Server allow specific IPs.
**AWS**: RDS lives in a private subnet; access is via security group referencing the app SG.

AWS's approach is more secure by default (no public endpoint), but requires the
app and DB to be in the same VPC.

### 4. Backup Strategy

Both use the same PostgreSQL dump (pg_dump → gzip). The cloud-specific part is
only the upload target:
- Azure: `az storage blob upload` (backup.sh + backup-blob variant)
- AWS: `aws s3 cp` (backup-s3.sh wrapper)

The restore scripts mirror this — download from cloud, then feed to the same
pg_restore pipeline.

## What Stays Cloud-Neutral

| Layer | Why it doesn't change |
|-------|----------------------|
| **Kubernetes manifests** | K8s API is the same on EKS, AKS, k3d |
| **Helm charts** | Values change per cloud; templates stay identical |
| **Prometheus/Grafana** | Scrape targets are service names, not cloud endpoints |
| **Alertmanager** | Routing rules are app-level, not cloud-level |
| **Network policies** | K8s NetworkPolicy is provider-agnostic |
| **Docker images** | Same Dockerfile, different registry URL |

## Local Emulators (Floci)

Both clouds use [Floci](https://floci.dev) for local emulation (wire-compatible with real SDKs/CLIs).
Sandboxes live in the **app repo** — they're dev tooling, not infrastructure.

| Cloud | Emulator | Image | Port | App Repo Compose Profile |
|-------|----------|-------|------|--------------------------|
| Azure | floci-az | `floci/floci-az:latest` | 4577 | `aws` |
| AWS | floci-aws | `floci/floci-aws:latest` | 4566 | `azure` |

### Sandbox → Cloud Promotion

```bash
# 1. Test in sandbox (app repo — $0, no credentials)
just sandbox-azure-up
just sandbox-azure-validate
TF_ENV=azure-sandbox just tf plan

# 2. Promote to real cloud (infra repo — real credentials)
TF_ENV=azure-dev just tf plan
just ansible-run provision-azure-vm
```

Same workflow for AWS — swap `azure` → `aws`.

## Switching Clouds

To switch from Azure to AWS (or vice versa):

1. **Terraform**: `TF_ENV=aws-dev just tf init && just tf plan`
2. **Ansible**: Change `-l azure_dev` to `-l aws_dev`
3. **CI/CD**: Update registry vars (ACR → ECR) and deploy target IP
4. **Backup**: Switch `BACKUP_STORAGE=blob` to `BACKUP_STORAGE=s3`

Everything else (app code, K8s, monitoring) stays untouched.
