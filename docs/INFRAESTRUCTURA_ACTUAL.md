# Infraestructura Actual en AWS (Estado: Operativo)

## Fecha de creación
2026-11-08

## Recursos creados con Terraform

| Recurso | Nombre | Estado |
| :--- | :--- | :--- |
| VPC | `unsa-matricula-dev-vpc` | ✅ Activa |
| Subredes públicas | `unsa-matricula-dev-public-1`, `-2` | ✅ Activas |
| Subredes privadas | `unsa-matricula-dev-private-1`, `-2` | ✅ Activas |
| NAT Gateway | `unsa-matricula-dev-nat` | ✅ Activo |
| Internet Gateway | `unsa-matricula-dev-igw` | ✅ Activo |
| Repositorio ECR Backend | `unsa-matricula-backend` | ✅ Vacío |
| Repositorio ECR Frontend | `unsa-matricula-frontend` | ✅ Vacío |
| Clúster EKS | `unsa-matricula-dev-cluster` | ✅ Activo (2 nodos `Ready`) |

## Cómo conectarse al clúster

```bash
aws eks update-kubeconfig --region us-east-1 --name unsa-matricula-dev-cluster
kubectl get nodes
```

## Cómo verificar el estado de Terraform

```bash
cd infrastructure
terraform plan -var-file="environments/dev.tfvars"
# Debe decir: "No changes. Your infrastructure matches the configuration."
```

## Cómo destruir (solo cuando termine el proyecto)

```bash
cd infrastructure
terraform destroy -var-file="environments/dev.tfvars" -auto-approve
```

## Nota sobre credenciales

Las credenciales de AWS Academy se obtienen desde el panel de Learner Lab
y NO deben guardarse en el repositorio. Cada miembro del equipo debe
configurarlas localmente antes de ejecutar Terraform.
