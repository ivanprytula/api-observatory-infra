# API Observatory Infrastructure
#
# Just owns supported named workflows. Use the documented native Terraform and
# Ansible commands for explicit operator work, including plan review and host
# bootstrap. Kubernetes is Deferred/Post-MVP; its assets are not a supported
# local deployment workflow.

help-aws-stage0:
    @echo "1. Create and configure the private S3 state backend from README.md."
    @echo "2. cd terraform/environments/aws-dev"
    @echo "3. terraform init -reconfigure -upgrade -backend-config=backend.s3.hcl"
    @echo "4. terraform validate"
    @echo "5. terraform plan -input=false -var-file=terraform.tfvars -out=tfplan"
    @echo "6. terraform show tfplan"
    @echo "7. Obtain explicit approval before: terraform apply tfplan"
    @echo "8. Bootstrap through the explicit SSM Ansible commands in docs/deployment/deployment-guide.md."
    @echo "9. Add runtime SecureStrings outside Git and review a real images.lock.json promotion."
    @echo "10. Merge the green aws-dev promotion PR to approve automatic deployment."
    @echo "11. Manual workflow dispatch only replays the desired state already on main."

promote-images metadata-file:
    uv run python scripts/promote_stage0_images.py "{{metadata-file}}"

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
