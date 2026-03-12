# Outputs del módulo VPC

output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR de la VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs de subnets públicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs de subnets privadas"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs de subnets de base de datos"
  value       = aws_subnet.database[*].id
}

output "storage_subnet_ids" {
  description = "IDs de subnets de almacenamiento"
  value       = aws_subnet.storage[*].id
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs de los NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "public_route_table_id" {
  description = "ID de la tabla de rutas públicas"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs de las tablas de rutas privadas"
  value       = aws_route_table.private[*].id
}

output "vpc_flow_log_group" {
  description = "Nombre del grupo de logs de VPC Flow"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}

output "vpc_flow_log_role_arn" {
  description = "ARN del rol IAM para VPC Flow Logs"
  value       = aws_iam_role.vpc_flow_logs.arn
}