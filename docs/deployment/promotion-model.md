# Application Environment Promotion Model

The application repository owns release promotion because it owns the workload and its operability.
The platform repository supplies the same secure capabilities to each approved environment.

| Environment | Release decision | Deployment behavior |
| --- | --- | --- |
| `aws-dev` | Review and merge the app-owned lock PR | Automatically deploy the merged lock when the app gate is enabled |

No image is rebuilt between environments. Optional profile changes are a separate app PR, while image
promotion preserves the profiles already merged into app `main`. The MVP has only `aws-dev`; do not
create unused environment workflows in advance. A future environment requires exercised EC2
recovery/rollback evidence plus its own acceptance, ownership, and approval contract.

The platform side must expose the matching OIDC role, SSM target, Parameter Store path, and MVP
platform contract before application delivery is enabled.
