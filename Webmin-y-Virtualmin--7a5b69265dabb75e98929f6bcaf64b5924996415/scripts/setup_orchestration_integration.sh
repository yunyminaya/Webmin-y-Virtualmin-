
#!/bin/bash

# Script de configuración de integración con herramientas de orquestación
# Soporte para Terraform y Ansible en despliegue multi-región

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗ $1${NC}"
}

# Verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    
    # Verificar Terraform
    if ! command -v terraform &> /dev/null; then
        error "Terraform no está instalado. Por favor, instale Terraform primero."
        exit 1
    fi
    
    # Verificar Ansible
    if ! command -v ansible &> /dev/null; then
        error "Ansible no está instalado. Por favor, instale Ansible primero."
        exit 1
    fi
    
    # Verificar AWS CLI (para proveedores AWS)
    if ! command -v aws &> /dev/null; then
        warning "AWS CLI no está instalado. Algunas funcionalidades podrían no estar disponibles."
    fi
    
    # Verificar Azure CLI (para proveedores Azure)
    if ! command -v az &> /dev/null; then
        warning "Azure CLI no está instalado. Algunas funcionalidades podrían no estar disponibles."
    fi
    
    # Verificar gcloud CLI (para proveedores GCP)
    if ! command -v gcloud &> /dev/null; then
        warning "Google Cloud CLI no está instalado. Algunas funcionalidades podrían no estar disponibles."
    fi
    
    success "Dependencias verificadas"
}

# Crear estructura de directorios
create_directory_structure() {
    log "Creando estructura de directorios..."
    
    # Directorios principales
    mkdir -p /opt/virtualmin/orchestration/{terraform,ansible,scripts,configs,templates}
    mkdir -p /opt/virtualmin/orchestration/terraform/{modules,environments,providers}
    mkdir -p /opt/virtualmin/orchestration/ansible/{roles,playbooks,inventories,group_vars,host_vars}
    mkdir -p /opt/virtualmin/orchestration/scripts/{integration,deployment,validation}
    mkdir -p /opt/virtualmin/orchestration/configs/{aws,azure,gcp,multi-cloud}
    mkdir -p /opt/virtualmin/orchestration/templates/{terraform,ansible}
    
    # Directorios específicos para multi-región
    mkdir -p /opt/virtualmin/orchestration/terraform/environments/{us-east-1,us-west-2,eu-west-1,ap-southeast-1}
    mkdir -p /opt/virtualmin/orchestration/ansible/inventories/{us-east-1,us-west-2,eu-west-1,ap-southeast-1}
    
    # Directorios para pruebas de estrés
    mkdir -p /opt/virtualmin/orchestration/scripts/stress-testing/{jmeter,locust}
    
    # Directorios para configuraciones de seguridad
    mkdir -p /opt/virtualmin/orchestration/configs/security/{waf,ids-ips,mfa}
    
    # Directorios para documentación
    mkdir -p /opt/virtualmin/orchestration/docs/{multi-region,auto-scaling,security,testing}
    
    success "Estructura de directorios creada"
}

# Instalar módulos de Terraform
install_terraform_modules() {
    log "Instalando módulos de Terraform..."
    
    # Módulo de VPC multi-región
    cat > /opt/virtualmin/orchestration/terraform/modules/vpc/main.tf << 'EOF'
# Módulo de VPC multi-región para Virtualmin
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    {
      Name = "${var.cluster_name}-vpc-${var.region}"
    },
    var.tags
  )
}

# Subredes públicas
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name = "${var.cluster_name}-public-subnet-${count.index}-${var.region}"
      Type = "Public"
    },
    var.tags
  )
}

# Subredes privadas
resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    {
      Name = "${var.cluster_name}-private-subnet-${count.index}-${var.region}"
      Type = "Private"
    },
    var.tags
  )
}

# Subredes de base de datos
resource "aws_subnet" "database" {
  count = length(var.database_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    {
      Name = "${var.cluster_name}-database-subnet-${count.index}-${var.region}"
      Type = "Database"
    },
    var.tags
  )
}

# Gateway de Internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name = "${var.cluster_name}-igw-${var.region}"
    },
    var.tags
  )
}

# Tablas de rutas para subredes públicas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    {
      Name = "${var.cluster_name}-public-rt-${var.region}"
    },
    var.tags
  )
}

# Asociación de tablas de rutas para subredes públicas
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway
resource "aws_eip" "nat" {
  count = var.nat_gateway_count
  vpc = true

  tags = merge(
    {
      Name = "${var.cluster_name}-nat-eip-${count.index}-${var.region}"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = var.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    {
      Name = "${var.cluster_name}-nat-gw-${count.index}-${var.region}"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.main]
}

# Tablas de rutas para subredes privadas
resource "aws_route_table" "private" {
  count = var.nat_gateway_count

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    {
      Name = "${var.cluster_name}-private-rt-${count.index}-${var.region}"
    },
    var.tags
  )
}

# Asociación de tablas de rutas para subredes privadas
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index % var.nat_gateway_count].id
}

# Data source para zonas de disponibilidad
data "aws_availability_zones" "available" {
  state = "available"
}
EOF

    # Variables del módulo VPC
    cat > /opt/virtualmin/orchestration/terraform/modules/vpc/variables.tf << 'EOF'
variable "cluster_name" {
  description = "Nombre del clúster"
  type        = string
}

variable "region" {
  description = "Región de AWS"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Lista de CIDR blocks para subredes públicas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "Lista de CIDR blocks para subredes privadas"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "database_subnets" {
  description = "Lista de CIDR blocks para subredes de base de datos"
  type        = list(string)
  default     = ["10.0.100.0/24", "10.0.200.0/24"]
}

variable "nat_gateway_count" {
  description = "Número de NAT Gateways"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags para los recursos"
  type        = map(string)
  default     = {}
}
EOF

    # Salidas del módulo VPC
    cat > /opt/virtualmin/orchestration/terraform/modules/vpc/outputs.tf << 'EOF'
output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block de la VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs de las subredes de base de datos"
  value       = aws_subnet.database[*].id
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs de los NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}
EOF

    # Módulo de Security Groups
    cat > /opt/virtualmin/orchestration/terraform/modules/security_groups/main.tf << 'EOF'
# Security Group para nodos web
resource "aws_security_group" "web" {
  name        = "${var.cluster_name}-web-sg-${var.region}"
  description = "Security group para nodos web"
  vpc_id      = var.vpc_id

  # Acceso HTTP desde cualquier lugar
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_cidr_blocks
  }

  # Acceso HTTPS desde cualquier lugar
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_cidr_blocks
  }

  # Acceso SSH desde CIDRs permitidos
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # Salida a cualquier lugar
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "${var.cluster_name}-web-sg-${var.region}"
    },
    var.tags
  )
}

# Security Group para nodos de base de datos
resource "aws_security_group" "database" {
  name        = "${var.cluster_name}-database-sg-${var.region}"
  description = "Security group para nodos de base de datos"
  vpc_id      = var.vpc_id

  # Acceso MySQL desde nodos web
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # Acceso PostgreSQL desde nodos web
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # Acceso SSH desde CIDRs permitidos
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # Salida a cualquier lugar
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "${var.cluster_name}-database-sg-${var.region}"
    },
    var.tags
  )
}

# Security Group para nodos de monitoreo
resource "aws_security_group" "monitoring" {
  name        = "${var.cluster_name}-monitoring-sg-${var.region}"
  description = "Security group para nodos de monitoreo"
  vpc_id      = var.vpc_id

  # Acceso Prometheus desde CIDRs permitidos
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.allowed_monitoring_cidrs
  }

  # Acceso Grafana desde CIDRs permitidos
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_monitoring_cidrs
  }

  # Acceso SSH desde CIDRs permitidos
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # Salida a cualquier lugar
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "${var.cluster_name}-monitoring-sg-${var.region}"
    },
    var.tags
  )
}
EOF

    # Variables del módulo Security Groups
    cat > /opt/virtualmin/orchestration/terraform/modules/security_groups/variables.tf << 'EOF'
variable "cluster_name" {
  description = "Nombre del clúster"
  type        = string
}

variable "region" {
  description = "Región de AWS"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks permitidos para acceso SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_web_cidr_blocks" {
  description = "CIDR blocks permitidos para acceso web"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_monitoring_cidrs" {
  description = "CIDR blocks permitidos para acceso a monitoreo"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags para los recursos"
  type        = map(string)
  default     = {}
}
EOF

    # Salidas del módulo Security Groups
    cat > /opt/virtualmin/orchestration/terraform/modules/security_groups/outputs.tf << 'EOF'
output "web_sg_id" {
  description = "ID del security group para nodos web"
  value       = aws_security_group.web.id
}

output "database_sg_id" {
  description = "ID del security group para nodos de base de datos"
  value       = aws_security_group.database.id
}

output "monitoring_sg_id" {
  description = "ID del security group para nodos de monitoreo"
  value       = aws_security_group.monitoring.id
}
EOF

    success "Módulos de Terraform instalados"
}

# Crear roles de Ansible
create_ansible_roles() {
    log "Creando roles de Ansible..."
    
    # Rol para configuración de Webmin/Virtualmin
    cat > /opt/virtualmin/orchestration/ansible/roles/webmin/tasks/main.yml << 'EOF'
---
- name: Actualizar paquetes del sistema
  apt:
    update_cache: yes
    upgrade: dist
  when: ansible_os_family == "Debian"

- name: Instalar dependencias necesarias
  package:
    name:
      - wget
      - curl
      - gnupg
      - lsb-release
      - ca-certificates
      - apt-transport-https
      - software-properties-common
      - python3-pip
      - python3-dev
      - build-essential
    state: present

- name: Agregar repositorio de Webmin
  apt_repository