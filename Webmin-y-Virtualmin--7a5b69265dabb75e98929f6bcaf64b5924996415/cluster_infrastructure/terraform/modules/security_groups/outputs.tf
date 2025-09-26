# Outputs del módulo Security Groups

output "web_sg_id" {
  description = "ID del Security Group para nodos web"
  value       = aws_security_group.web.id
}

output "api_sg_id" {
  description = "ID del Security Group para nodos API"
  value       = aws_security_group.api.id
}

output "database_sg_id" {
  description = "ID del Security Group para nodos de base de datos"
  value       = aws_security_group.database.id
}

output "storage_sg_id" {
  description = "ID del Security Group para nodos de almacenamiento"
  value       = aws_security_group.storage.id
}

output "monitoring_sg_id" {
  description = "ID del Security Group para nodos de monitoreo"
  value       = aws_security_group.monitoring.id
}

output "load_balancer_sg_id" {
  description = "ID del Security Group para Load Balancers"
  value       = aws_security_group.load_balancer.id
}

output "web_sg_arn" {
  description = "ARN del Security Group para nodos web"
  value       = aws_security_group.web.arn
}

output "api_sg_arn" {
  description = "ARN del Security Group para nodos API"
  value       = aws_security_group.api.arn
}

output "database_sg_arn" {
  description = "ARN del Security Group para nodos de base de datos"
  value       = aws_security_group.database.arn
}

output "storage_sg_arn" {
  description = "ARN del Security Group para nodos de almacenamiento"
  value       = aws_security_group.storage.arn
}

output "monitoring_sg_arn" {
  description = "ARN del Security Group para nodos de monitoreo"
  value       = aws_security_group.monitoring.arn
}

output "load_balancer_sg_arn" {
  description = "ARN del Security Group para Load Balancers"
  value       = aws_security_group.load_balancer.arn
}