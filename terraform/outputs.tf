# ============================================================
# ObservaTI - Terraform Outputs
# ============================================================

output "instance_id" {
  description = "ID de la instancia EC2"
  value       = aws_instance.observati.id
}

output "instance_private_ip" {
  description = "IP privada de la instancia"
  value       = aws_instance.observati.private_ip
}

output "instance_public_ip" {
  description = "IP pública de la instancia (si se asignó)"
  value       = var.associate_public_ip ? aws_instance.observati.public_ip : "N/A (sin IP pública)"
}

output "grafana_url" {
  description = "URL para acceder a Grafana"
  value       = var.associate_public_ip ? "http://${aws_instance.observati.public_ip}:3000" : "http://${aws_instance.observati.private_ip}:3000"
}

output "uptime_kuma_url" {
  description = "URL para acceder a Uptime Kuma"
  value       = var.associate_public_ip ? "http://${aws_instance.observati.public_ip}:3001" : "http://${aws_instance.observati.private_ip}:3001"
}

output "iam_role_arn" {
  description = "ARN del IAM Role asignado a la instancia"
  value       = aws_iam_role.observati.arn
}

output "iam_instance_profile_name" {
  description = "Nombre del Instance Profile"
  value       = aws_iam_instance_profile.observati.name
}

output "security_group_id" {
  description = "ID del Security Group"
  value       = aws_security_group.observati.id
}

output "ssm_connect_command" {
  description = "Comando para conectarse vía SSM (sin necesidad de SSH/key pair)"
  value       = "aws ssm start-session --target ${aws_instance.observati.id} --region ${var.aws_region}"
}

output "ami_id" {
  description = "AMI utilizada"
  value       = data.aws_ami.ubuntu.id
}
