# API Observatory Infrastructure
#
# Just owns supported named workflows. Use the documented native Terraform and
# Ansible commands for explicit operator work, including plan review and host
# bootstrap. Kubernetes is Deferred/Post-MVP; its assets are not a supported
# local deployment workflow.

doctor:
    bash scripts/doctor.sh

help-aws-mvp:
    @echo "1. Create and configure the private S3 state backend from README.md."
    @echo "2. cd terraform/environments/aws-dev"
    @echo "3. terraform init -reconfigure -upgrade -backend-config=backend.s3.hcl"
    @echo "4. terraform validate"
    @echo "5. terraform plan -input=false -var-file=terraform.tfvars -out=tfplan"
    @echo "6. terraform show tfplan"
    @echo "7. Obtain explicit approval before: terraform apply tfplan"
    @echo "8. Bootstrap MVP platform contract 1 through the explicit SSM Ansible commands in docs/deployment/deployment-guide.md."
    @echo "9. Add runtime SecureStrings outside Git and configure app environments from Terraform outputs."
    @echo "10. The app repository owns reviewed lock promotion and application deployment."

ansible-lint:
    ansible-lint --project-dir ansible

helm-lint:
    #!/usr/bin/env bash
    set -euo pipefail
    for chart in kubernetes/charts/*/; do
        echo "Linting ${chart}..."
        helm lint "$chart"
    done

help-kubernetes:
    @echo "Kubernetes/k3d assets are Deferred/Post-MVP and are not a supported deployment workflow."
    @echo "See kubernetes/README.md for scope and the evidence required before activation."
