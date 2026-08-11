# Políticas IAM - ObservaTI

Este directorio contiene las políticas IAM necesarias divididas por propósito.

## ¿Quién usa cada política?

| Política | Se adjunta a | Propósito |
|----------|-------------|-----------|
| `01-terraform-operator.json` | IAM User/Role que ejecuta `terraform apply` | Crear y gestionar la infraestructura |
| `02-grafana-cloudwatch.json` | EC2 Instance Profile (se crea automáticamente por Terraform) | Grafana lee CloudWatch |
| `03-cross-account-target.json` | Rol en OTRAS cuentas AWS (si aplica) | Permitir que la cuenta de observabilidad lea CloudWatch de otra cuenta |

## Orden de creación

1. Primero crea un IAM User o Role con la política `01-terraform-operator.json`.
2. Ejecuta `terraform apply` — esto crea automáticamente el rol con `02-grafana-cloudwatch.json`.
3. Si tienes múltiples cuentas AWS, crea el rol `03-cross-account-target.json` en cada cuenta remota.
