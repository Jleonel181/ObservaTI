# ObservaTI - Terraform Infrastructure

Infraestructura como código para la plataforma de observabilidad ObservaTI.

## ¿Qué se crea?

| Recurso | Descripción |
|---------|-------------|
| EC2 Instance | Ubuntu 24.04 con Docker preinstalado |
| IAM Role | Permisos read-only para CloudWatch Metrics y Logs |
| IAM Instance Profile | Adjunta el rol a la instancia (sin Access Keys) |
| Security Group | Acceso restringido a Grafana, Uptime Kuma, SSH |
| SSM Access | Acceso por Session Manager (sin necesidad de SSH) |

## Permisos que necesitas para ejecutar Terraform

El usuario o rol que ejecute `terraform apply` necesita estos permisos en IAM:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformEC2",
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeImages",
        "ec2:DescribeSecurityGroups",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DescribeKeyPairs",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeInstanceAttribute",
        "ec2:ModifyInstanceAttribute",
        "ec2:DescribeInstanceCreditSpecifications"
      ],
      "Resource": "*"
    },
    {
      "Sid": "TerraformIAM",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicyVersions",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:PassRole",
        "iam:TagRole",
        "iam:TagPolicy",
        "iam:TagInstanceProfile",
        "iam:ListInstanceProfilesForRole"
      ],
      "Resource": "*"
    },
    {
      "Sid": "TerraformSTSDescribe",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

> **Alternativa rápida:** Si estás probando y tienes un usuario con `AdministratorAccess`, eso cubre todo. Pero para producción se recomienda la política de arriba.

## Requisitos previos

| Requisito | Instalación |
|-----------|-------------|
| Terraform >= 1.5 | [terraform.io/downloads](https://developer.hashicorp.com/terraform/downloads) |
| AWS CLI v2 | [docs.aws.amazon.com/cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Credenciales AWS configuradas | `aws configure` o variables de entorno |

### Verificar credenciales

```bash
aws sts get-caller-identity
```

Debe retornar tu Account ID y ARN. Si falla, configura tus credenciales.

## Uso

### 1. Configurar variables

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
```

Editar `terraform.tfvars` con tus valores reales:

```hcl
vpc_id    = "vpc-abc123"         # Tu VPC existente
subnet_id = "subnet-def456"     # Subnet donde colocar la instancia

allowed_cidr_blocks = [
  "203.0.113.50/32",            # Tu IP pública (curl ifconfig.me)
]
```

### 2. Obtener tu VPC y Subnet

Si no los conoces:

```bash
# Listar VPCs
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],CidrBlock]' --output table

# Listar subnets de una VPC
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-XXXXXXX" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,MapPublicIpOnLaunch]' --output table
```

### 3. Inicializar y aplicar

```bash
# Descargar providers
terraform init

# Ver qué se va a crear (sin ejecutar)
terraform plan

# Crear la infraestructura
terraform apply
```

### 4. Conectarse al servidor

**Opción A - SSM (recomendado, sin key pair):**

```bash
# El comando exacto lo muestra terraform output
aws ssm start-session --target i-XXXXXXXXXXXXXXXXX --region us-east-1
```

**Opción B - SSH (si configuraste key_pair_name):**

```bash
ssh -i tu-key.pem ubuntu@<IP_PUBLICA>
```

### 5. Desplegar ObservaTI en el servidor

Una vez conectado:

```bash
# Clonar el repositorio
cd /opt/observati
sudo -u observati git clone <URL_REPO> .

# Configurar
sudo -u observati cp .env.example .env
sudo -u observati nano .env

# Iniciar
sudo -u observati make up
```

## Destruir infraestructura

```bash
terraform destroy
```

> El volumen EBS tiene `delete_on_termination = false`. Si destruyes la instancia, el volumen persiste (con tus datos). Elimínalo manualmente si quieres limpieza total.

## Estructura de archivos

```
terraform/
├── versions.tf             # Provider y versión de Terraform
├── variables.tf            # Variables de entrada
├── terraform.tfvars.example # Template de valores
├── iam.tf                  # Rol, política CloudWatch, Instance Profile
├── security_group.tf       # Reglas de acceso de red
├── ec2.tf                  # Instancia EC2 + AMI Ubuntu
├── user_data.sh            # Script de bootstrap (Docker install)
├── outputs.tf              # Valores de salida útiles
└── README.md               # Este archivo
```

## Decisiones de diseño

| Decisión | Razón |
|----------|-------|
| IAM Role en vez de Access Keys | Rotación automática, sin credenciales estáticas |
| IMDSv2 obligatorio | Previene SSRF y exfiltración de credenciales |
| SSM Session Manager | Acceso sin exponer SSH al mundo |
| EBS encriptado | Protege datos en reposo |
| Security Group restrictivo | Solo CIDRs autorizados pueden acceder |
| `delete_on_termination = false` | Protege datos si se destruye la instancia por error |
| Egress limitado | Solo HTTPS, HTTP, SMTP y DNS (no all traffic) |

## Costos estimados

| Recurso | Costo mensual (us-east-1) |
|---------|:-------------------------:|
| t3.small (on-demand) | ~$15 |
| t3.medium (on-demand) | ~$30 |
| EBS 30GB gp3 | ~$2.40 |
| EBS 80GB gp3 | ~$6.40 |
| Transferencia datos (estimado) | ~$1-3 |
| **Total (lab)** | **~$18-20** |
| **Total (producción)** | **~$35-40** |

## Próximos pasos tras terraform apply

1. Conectarse al servidor (SSM o SSH).
2. Verificar Docker: `docker --version && docker compose version`.
3. Clonar el repo ObservaTI en `/opt/observati/`.
4. Configurar `.env` y ejecutar `make up`.
5. Acceder a Grafana en `http://<IP>:3000`.
6. Verificar que CloudWatch datasource funciona (el IAM Role ya tiene permisos).
