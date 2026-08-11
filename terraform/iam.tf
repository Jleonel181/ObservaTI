# ============================================================
# ObservaTI - IAM Resources
# ============================================================
# Rol para la instancia EC2 de observabilidad.
# Permisos: solo lectura de CloudWatch Metrics y Logs.
# Principio de mínimo privilegio.
# ============================================================

# --- IAM Role (asumible por EC2) ---
resource "aws_iam_role" "observati" {
  name = "${var.project_name}-grafana-role"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-grafana-role"
  }
}

# --- Política: CloudWatch Read-Only ---
resource "aws_iam_policy" "cloudwatch_readonly" {
  name        = "${var.project_name}-cloudwatch-readonly"
  description = "Permite a Grafana leer métricas y logs de CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchMetricsReadOnly"
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetInsightRuleReport",
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsReadOnly"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:GetLogGroupFields",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2DescribeRegions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      },
      {
        Sid    = "ResourceTagsReadOnly"
        Effect = "Allow"
        Action = [
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-cloudwatch-readonly"
  }
}

# --- Adjuntar política al rol ---
resource "aws_iam_role_policy_attachment" "cloudwatch_readonly" {
  role       = aws_iam_role.observati.name
  policy_arn = aws_iam_policy.cloudwatch_readonly.arn
}

# --- Política: SSM Session Manager (acceso sin SSH) ---
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.observati.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# --- Instance Profile ---
resource "aws_iam_instance_profile" "observati" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.observati.name

  tags = {
    Name = "${var.project_name}-instance-profile"
  }
}

# ============================================================
# Cross-Account Role (opcional, solo si se monitorean otras cuentas)
# ============================================================
# Este recurso solo se crea si se proporcionan account IDs adicionales.
# En la cuenta remota se debe crear un rol que permita AssumeRole
# desde esta cuenta.

resource "aws_iam_policy" "cross_account_assume" {
  count = length(var.monitored_account_ids) > 0 ? 1 : 0

  name        = "${var.project_name}-cross-account-assume"
  description = "Permite asumir roles en cuentas AWS adicionales para monitoreo"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AssumeRoleCrossAccount"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          for account_id in var.monitored_account_ids :
          "arn:aws:iam::${account_id}:role/${var.project_name}-cross-account-readonly"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cross_account_assume" {
  count = length(var.monitored_account_ids) > 0 ? 1 : 0

  role       = aws_iam_role.observati.name
  policy_arn = aws_iam_policy.cross_account_assume[0].arn
}
