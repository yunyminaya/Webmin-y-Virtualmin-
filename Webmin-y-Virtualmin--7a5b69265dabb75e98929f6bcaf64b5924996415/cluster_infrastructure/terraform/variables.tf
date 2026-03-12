# Variables para Infraestructura de Clúster Enterprise
# Configuración completa para 1000+ nodos

# Configuración básica del clúster
variable "cluster_name" {
  description = "Nombre del clúster"
  type        = string
  default     = "webmin-cluster"
}

variable "environment" {
  description = "Entorno (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "El entorno debe ser dev, staging o prod."
  }
}

variable "owner" {
  description = "Propietario del clúster"
  type        = string
  default     = "DevOps Team"
}

variable "cost_center" {
  description = "Centro de costos"
  type        = string
  default     = "IT-Infrastructure"
}

# Configuración de red
variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Número de Availability Zones"
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 6
    error_message = "El número de AZ debe estar entre 2 y 6."
  }
}

variable "public_subnets" {
  description = "Subnets públicas por AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  description = "Subnets privadas por AZ"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "database_subnets" {
  description = "Subnets de base de datos por AZ"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
}

variable "storage_subnets" {
  description = "Subnets de almacenamiento por AZ"
  type        = list(string)
  default     = ["10.0.31.0/24", "10.0.32.0/24", "10.0.33.0/24"]
}

# Configuración de nodos
variable "web_node_count" {
  description = "Número inicial de nodos web"
  type        = number
  default     = 3

  validation {
    condition     = var.web_node_count >= 2
    error_message = "Debe haber al menos 2 nodos web para HA."
  }
}

variable "api_node_count" {
  description = "Número inicial de nodos API"
  type        = number
  default     = 2

  validation {
    condition     = var.api_node_count >= 2
    error_message = "Debe haber al menos 2 nodos API para HA."
  }
}

variable "db_node_count" {
  description = "Número de nodos de base de datos (Galera cluster)"
  type        = number
  default     = 3

  validation {
    condition     = var.db_node_count >= 3 && var.db_node_count % 2 == 1
    error_message = "El clúster Galera debe tener 3, 5, 7, etc. nodos."
  }
}

variable "storage_node_count" {
  description = "Número de nodos de almacenamiento"
  type        = number
  default     = 3

  validation {
    condition     = var.storage_node_count >= 3
    error_message = "Debe haber al menos 3 nodos de almacenamiento."
  }
}

variable "monitoring_node_count" {
  description = "Número de nodos de monitoreo"
  type        = number
  default     = 2

  validation {
    condition     = var.monitoring_node_count >= 2
    error_message = "Debe haber al menos 2 nodos de monitoreo para HA."
  }
}

# Tipos de instancia
variable "web_instance_type" {
  description = "Tipo de instancia para nodos web"
  type        = string
  default     = "t3.large"
}

variable "api_instance_type" {
  description = "Tipo de instancia para nodos API"
  type        = string
  default     = "t3.medium"
}

variable "db_instance_type" {
  description = "Tipo de instancia para nodos de base de datos"
  type        = string
  default     = "t3.xlarge"
}

variable "storage_instance_type" {
  description = "Tipo de instancia para nodos de almacenamiento"
  type        = string
  default     = "t3.large"
}

variable "monitoring_instance_type" {
  description = "Tipo de instancia para nodos de monitoreo"
  type        = string
  default     = "t3.medium"
}

# Configuración de almacenamiento
variable "storage_volume_size" {
  description = "Tamaño del volumen EBS para nodos de almacenamiento (GB)"
  type        = number
  default     = 500

  validation {
    condition     = var.storage_volume_size >= 100
    error_message = "El volumen debe ser al menos 100GB."
  }
}

# Auto Scaling
variable "web_min_size" {
  description = "Tamaño mínimo del ASG web"
  type        = number
  default     = 3
}

variable "web_max_size" {
  description = "Tamaño máximo del ASG web"
  type        = number
  default     = 100
}

variable "web_desired_capacity" {
  description = "Capacidad deseada inicial del ASG web"
  type        = number
  default     = 3
}

variable "api_min_size" {
  description = "Tamaño mínimo del ASG API"
  type        = number
  default     = 2
}

variable "api_max_size" {
  description = "Tamaño máximo del ASG API"
  type        = number
  default     = 50
}

variable "api_desired_capacity" {
  description = "Capacidad deseada inicial del ASG API"
  type        = number
  default     = 2
}

# Umbrales de auto-scaling
variable "cpu_threshold" {
  description = "Umbral de CPU para auto-scaling (%)"
  type        = number
  default     = 70

  validation {
    condition     = var.cpu_threshold >= 10 && var.cpu_threshold <= 95
    error_message = "El umbral de CPU debe estar entre 10% y 95%."
  }
}

variable "memory_threshold" {
  description = "Umbral de memoria para auto-scaling (%)"
  type        = number
  default     = 80

  validation {
    condition     = var.memory_threshold >= 10 && var.memory_threshold <= 95
    error_message = "El umbral de memoria debe estar entre 10% y 95%."
  }
}

variable "network_threshold" {
  description = "Umbral de red para auto-scaling (%)"
  type        = number
  default     = 60

  validation {
    condition     = var.network_threshold >= 10 && var.network_threshold <= 95
    error_message = "El umbral de red debe estar entre 10% y 95%."
  }
}

# Configuración de seguridad
variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks permitidos para SSH"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]

  validation {
    condition = alltrue([
      for cidr in var.allowed_ssh_cidr_blocks : can(cidrnetmask(cidr))
    ])
    error_message = "Todos los CIDR blocks deben ser válidos."
  }
}

variable "allowed_web_cidr_blocks" {
  description = "CIDR blocks permitidos para acceso web"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_monitoring_cidrs" {
  description = "CIDR blocks permitidos para monitoreo"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

# Configuración de DNS
variable "route53_zone" {
  description = "Zona Route 53 para el clúster"
  type        = string
  default     = "cluster.internal"
}

variable "web_domain" {
  description = "Dominio para servicios web"
  type        = string
  default     = "web.cluster.internal"
}

variable "api_domain" {
  description = "Dominio para servicios API"
  type        = string
  default     = "api.cluster.internal"
}

# Configuración de backup
variable "backup_retention_days" {
  description = "Días de retención de backups"
  type        = number
  default     = 30

  validation {
    condition     = var.backup_retention_days >= 7
    error_message = "La retención debe ser al menos 7 días."
  }
}

variable "backup_schedule" {
  description = "Horario de backup (cron expression)"
  type        = string
  default     = "0 2 * * *" # 2 AM daily

  validation {
    condition     = can(regex("^([0-9,*-/]+)\\s+([0-9,*-/]+)\\s+([0-9,*-/]+)\\s+([0-9,*-/]+)\\s+([0-9,*-/]+)$", var.backup_schedule))
    error_message = "Debe ser una expresión cron válida."
  }
}

# Configuración de monitoreo
variable "monitoring_retention_days" {
  description = "Días de retención de métricas"
  type        = number
  default     = 90

  validation {
    condition     = var.monitoring_retention_days >= 30
    error_message = "La retención de métricas debe ser al menos 30 días."
  }
}

variable "alert_email" {
  description = "Email para alertas"
  type        = string
  default     = "alerts@cluster.internal"
}

variable "slack_webhook_url" {
  description = "URL del webhook de Slack para alertas"
  type        = string
  default     = ""
  sensitive   = true
}

# Configuración de escalado masivo
variable "enable_massive_scaling" {
  description = "Habilitar escalado para más de 1000 nodos"
  type        = bool
  default     = false
}

variable "max_cluster_nodes" {
  description = "Máximo número de nodos en el clúster"
  type        = number
  default     = 1000

  validation {
    condition     = var.max_cluster_nodes >= 10 && var.max_cluster_nodes <= 10000
    error_message = "El máximo debe estar entre 10 y 10000 nodos."
  }
}

# Configuración de compliance
variable "enable_compliance_scanning" {
  description = "Habilitar escaneos de compliance automáticos"
  type        = bool
  default     = true
}

variable "compliance_scan_schedule" {
  description = "Horario de escaneos de compliance"
  type        = string
  default     = "0 3 * * 1" # 3 AM Mondays

  validation {
    condition     = can(regex("^([0-9,*-/]+)\\s+([0-9,*-/]+)\\s+([0-9,*-/]+)\\s+([0-9,*-/]+)\\s+([0-9,*-/]+)$", var.compliance_scan_schedule))
    error_message = "Debe ser una expresión cron válida."
  }
}

# Configuración para SERVIDORES ILIMITADOS
variable "enable_unlimited_servers" {
  description = "Habilitar capacidad para servidores ilimitados"
  type        = bool
  default     = true
}

variable "unlimited_max_servers" {
  description = "Máximo teórico de servidores (0 = ilimitado)"
  type        = number
  default     = 0

  validation {
    condition     = var.unlimited_max_servers >= 0
    error_message = "Debe ser 0 (ilimitado) o un número positivo."
  }
}

variable "dynamic_inventory_enabled" {
  description = "Habilitar inventario dinámico automático"
  type        = bool
  default     = true
}

variable "auto_discovery_interval" {
  description = "Intervalo de auto-descubrimiento de nuevos servidores (minutos)"
  type        = number
  default     = 5

  validation {
    condition     = var.auto_discovery_interval >= 1 && var.auto_discovery_interval <= 60
    error_message = "El intervalo debe estar entre 1 y 60 minutos."
  }
}

variable "load_balancer_auto_scaling" {
  description = "Auto-scaling automático de load balancers basado en carga"
  type        = bool
  default     = true
}

variable "intelligent_resource_allocation" {
  description = "Asignación inteligente de recursos basada en IA"
  type        = bool
  default     = true
}

variable "server_health_check_interval" {
  description = "Intervalo de verificación de salud de servidores (segundos)"
  type        = number
  default     = 30

  validation {
    condition     = var.server_health_check_interval >= 10 && var.server_health_check_interval <= 300
    error_message = "El intervalo debe estar entre 10 y 300 segundos."
  }
}

variable "auto_failover_enabled" {
  description = "Failover automático entre servidores"
  type        = bool
  default     = true
}

variable "cross_region_replication" {
  description = "Replicación automática entre regiones"
  type        = bool
  default     = false
}

variable "unlimited_backup_storage" {
  description = "Almacenamiento ilimitado para backups"
  type        = bool
  default     = true
}

variable "server_provisioning_speed" {
  description = "Velocidad de aprovisionamiento de nuevos servidores (segundos)"
  type        = number
  default     = 120

  validation {
    condition     = var.server_provisioning_speed >= 60
    error_message = "El aprovisionamiento debe tomar al menos 60 segundos."
  }
}

# Configuración de COSTOS Y OPTIMIZACIÓN - SISTEMA GRATIS
variable "enable_cost_monitoring" {
  description = "Habilitar monitoreo de costos GRATIS en tiempo real"
  type        = bool
  default     = true
}

variable "monthly_budget_limit" {
  description = "Límite mensual de presupuesto en USD (0 = GRATIS/ilimitado)"
  type        = number
  default     = 0  # GRATIS - Sin costo adicional

  validation {
    condition     = var.monthly_budget_limit >= 0
    error_message = "El presupuesto debe ser 0 (GRATIS) o mayor."
  }
}

variable "cost_alert_thresholds" {
  description = "Umbrales de alerta de costos GRATIS (%)"
  type        = list(number)
  default     = [50, 75, 90, 100]

  validation {
    condition = alltrue([
      for threshold in var.cost_alert_thresholds : threshold >= 0 && threshold <= 100
    ])
    error_message = "Los umbrales deben estar entre 0% y 100%."
  }
}

variable "cost_optimization_enabled" {
  description = "Habilitar optimización automática de costos GRATIS"
  type        = bool
  default     = true
}

variable "spot_instances_enabled" {
  description = "Usar instancias spot para optimizar costos GRATIS"
  type        = bool
  default     = false
}

variable "reserved_instances_optimization" {
  description = "Optimización automática de Reserved Instances GRATIS"
  type        = bool
  default     = true
}

variable "cost_anomaly_detection" {
  description = "Detección automática de anomalías en costos GRATIS"
  type        = bool
  default     = true
}

variable "budget_alert_emails" {
  description = "Emails para alertas de presupuesto GRATIS"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.budget_alert_emails : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "Todos los emails deben tener formato válido."
  }
}

variable "cost_saving_targets" {
  description = "Objetivos de ahorro de costos GRATIS (%)"
  type        = number
  default     = 20

  validation {
    condition     = var.cost_saving_targets >= 0 && var.cost_saving_targets <= 50
    error_message = "Los objetivos de ahorro deben estar entre 0% y 50%."
  }
}