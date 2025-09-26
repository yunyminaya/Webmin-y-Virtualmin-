# Outputs para Infraestructura de Clúster Enterprise

# Información general del clúster
output "cluster_name" {
  description = "Nombre del clúster"
  value       = var.cluster_name
}

output "environment" {
  description = "Entorno del clúster"
  value       = var.environment
}

output "region" {
  description = "Región de AWS"
  value       = data.aws_region.current.name
}

# Información de red
output "vpc_id" {
  description = "ID de la VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR de la VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs de subnets públicas"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs de subnets privadas"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "IDs de subnets de base de datos"
  value       = module.vpc.database_subnet_ids
}

output "storage_subnet_ids" {
  description = "IDs de subnets de almacenamiento"
  value       = module.vpc.storage_subnet_ids
}

# Load Balancers
output "web_load_balancer_dns" {
  description = "DNS del Load Balancer web"
  value       = module.load_balancers.web_lb_dns_name
}

output "web_load_balancer_zone_id" {
  description = "Zone ID del Load Balancer web"
  value       = module.load_balancers.web_lb_zone_id
}

output "api_load_balancer_dns" {
  description = "DNS del Load Balancer API"
  value       = module.load_balancers.api_lb_dns_name
}

output "api_load_balancer_zone_id" {
  description = "Zone ID del Load Balancer API"
  value       = module.load_balancers.api_lb_zone_id
}

output "monitoring_load_balancer_dns" {
  description = "DNS del Load Balancer de monitoreo"
  value       = module.load_balancers.monitoring_lb_dns_name
}

# Nodos del clúster
output "web_nodes" {
  description = "Información de nodos web"
  value = {
    instance_ids   = module.web_nodes.instance_ids
    private_ips    = module.web_nodes.private_ips
    public_ips     = module.web_nodes.public_ips
    instance_count = length(module.web_nodes.instance_ids)
  }
}

output "api_nodes" {
  description = "Información de nodos API"
  value = {
    instance_ids   = module.api_nodes.instance_ids
    private_ips    = module.api_nodes.private_ips
    public_ips     = module.api_nodes.public_ips
    instance_count = length(module.api_nodes.instance_ids)
  }
}

output "database_nodes" {
  description = "Información de nodos de base de datos"
  value = {
    instance_ids   = module.database_nodes.instance_ids
    private_ips    = module.database_nodes.private_ips
    instance_count = length(module.database_nodes.instance_ids)
  }
}

output "storage_nodes" {
  description = "Información de nodos de almacenamiento"
  value = {
    instance_ids   = module.storage_nodes.instance_ids
    private_ips    = module.storage_nodes.private_ips
    instance_count = length(module.storage_nodes.instance_ids)
  }
}

output "monitoring_nodes" {
  description = "Información de nodos de monitoreo"
  value = {
    instance_ids   = module.monitoring_nodes.instance_ids
    private_ips    = module.monitoring_nodes.private_ips
    public_ips     = module.monitoring_nodes.public_ips
    instance_count = length(module.monitoring_nodes.instance_ids)
  }
}

# Auto Scaling Groups
output "web_asg_name" {
  description = "Nombre del Auto Scaling Group web"
  value       = module.auto_scaling.web_asg_name
}

output "api_asg_name" {
  description = "Nombre del Auto Scaling Group API"
  value       = module.auto_scaling.api_asg_name
}

output "storage_asg_name" {
  description = "Nombre del Auto Scaling Group de almacenamiento"
  value       = module.auto_scaling.storage_asg_name
}

# Claves SSH
output "ssh_private_key" {
  description = "Clave privada SSH para acceder al clúster"
  value       = tls_private_key.cluster_ssh_key.private_key_pem
  sensitive   = true
}

output "ssh_public_key" {
  description = "Clave pública SSH del clúster"
  value       = tls_private_key.cluster_ssh_key.public_key_openssh
}

output "ssh_key_name" {
  description = "Nombre del key pair SSH"
  value       = aws_key_pair.cluster_key.key_name
}

# Certificados SSL
output "web_certificate_arn" {
  description = "ARN del certificado SSL web"
  value       = aws_acm_certificate.web_cert.arn
}

output "api_certificate_arn" {
  description = "ARN del certificado SSL API"
  value       = aws_acm_certificate.api_cert.arn
}

# DNS Records
output "web_domain" {
  description = "Dominio web del clúster"
  value       = var.web_domain
}

output "api_domain" {
  description = "Dominio API del clúster"
  value       = var.api_domain
}

# Información de monitoreo
output "prometheus_url" {
  description = "URL de Prometheus"
  value       = "https://${module.load_balancers.monitoring_lb_dns_name}/prometheus"
}

output "grafana_url" {
  description = "URL de Grafana"
  value       = "https://${module.load_balancers.monitoring_lb_dns_name}/grafana"
}

output "alertmanager_url" {
  description = "URL de Alertmanager"
  value       = "https://${module.load_balancers.monitoring_lb_dns_name}/alertmanager"
}

# Información de backup
output "backup_bucket" {
  description = "Bucket S3 para backups"
  value       = aws_s3_bucket.backup_bucket.bucket
}

output "backup_bucket_arn" {
  description = "ARN del bucket S3 para backups"
  value       = aws_s3_bucket.backup_bucket.arn
}

# Información de seguridad
output "security_groups" {
  description = "Security Groups del clúster"
  value = {
    web_sg_id        = module.security_groups.web_sg_id
    api_sg_id        = module.security_groups.api_sg_id
    database_sg_id   = module.security_groups.database_sg_id
    storage_sg_id    = module.security_groups.storage_sg_id
    monitoring_sg_id = module.security_groups.monitoring_sg_id
  }
}

# Información de escalado
output "current_cluster_size" {
  description = "Tamaño actual del clúster"
  value = {
    web_nodes       = length(module.web_nodes.instance_ids)
    api_nodes       = length(module.api_nodes.instance_ids)
    database_nodes  = length(module.database_nodes.instance_ids)
    storage_nodes   = length(module.storage_nodes.instance_ids)
    monitoring_nodes = length(module.monitoring_nodes.instance_ids)
    total_nodes     = (
      length(module.web_nodes.instance_ids) +
      length(module.api_nodes.instance_ids) +
      length(module.database_nodes.instance_ids) +
      length(module.storage_nodes.instance_ids) +
      length(module.monitoring_nodes.instance_ids)
    )
  }
}

output "auto_scaling_limits" {
  description = "Límites de auto-scaling"
  value = {
    web_min     = var.web_min_size
    web_max     = var.web_max_size
    api_min     = var.api_min_size
    api_max     = var.api_max_size
    max_total   = var.max_cluster_nodes
  }
}

# Información de compliance y auditoría
output "compliance_enabled" {
  description = "Compliance scanning habilitado"
  value       = var.enable_compliance_scanning
}

output "massive_scaling_enabled" {
  description = "Escalado masivo habilitado"
  value       = var.enable_massive_scaling
}

# Información de costos
output "estimated_monthly_cost" {
  description = "Costo mensual estimado (USD)"
  value       = (
    # Web nodes
    length(module.web_nodes.instance_ids) * 100 +
    # API nodes
    length(module.api_nodes.instance_ids) * 50 +
    # Database nodes
    length(module.database_nodes.instance_ids) * 150 +
    # Storage nodes
    length(module.storage_nodes.instance_ids) * 120 +
    # Monitoring nodes
    length(module.monitoring_nodes.instance_ids) * 60 +
    # EBS storage
    (length(module.storage_nodes.instance_ids) * var.storage_volume_size * 0.1) +
    # Load balancers
    30 +
    # Data transfer estimate
    100
  )
}

# Información de despliegue
output "deployment_commands" {
  description = "Comandos para completar el despliegue"
  value = {
    ansible_inventory = "ansible-playbook -i inventory.ini cluster.yml"
    monitoring_setup  = "ansible-playbook -i inventory.ini monitoring.yml"
    security_hardening = "ansible-playbook -i inventory.ini security.yml"
    backup_setup      = "ansible-playbook -i inventory.ini backup.yml"
  }
}

# Información de recuperación de desastres
output "disaster_recovery_info" {
  description = "Información para recuperación de desastres"
  value = {
    backup_location     = aws_s3_bucket.backup_bucket.bucket
    terraform_state     = "s3://webmin-cluster-terraform-state/cluster/terraform.tfstate"
    ansible_config      = "Configurado en nodos de monitoreo"
    emergency_contacts  = "Definidos en variables de Terraform"
  }
}