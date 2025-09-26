# Módulo VPC para Clúster Enterprise Webmin/Virtualmin

# VPC principal
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-igw"
  })
}

# NAT Gateways (uno por AZ para alta disponibilidad)
resource "aws_eip" "nat" {
  count = var.az_count
  vpc   = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "main" {
  count         = var.az_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# Subnets Públicas
resource "aws_subnet" "public" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-public-${count.index + 1}"
    Type = "public"
  })
}

# Subnets Privadas
resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-private-${count.index + 1}"
    Type = "private"
  })
}

# Subnets de Base de Datos (aisladas)
resource "aws_subnet" "database" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-database-${count.index + 1}"
    Type = "database"
  })
}

# Subnets de Almacenamiento (aisladas)
resource "aws_subnet" "storage" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.storage_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-storage-${count.index + 1}"
    Type = "storage"
  })
}

# Tabla de rutas públicas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-public-rt"
  })
}

# Asociación de subnets públicas con tabla de rutas públicas
resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Tablas de rutas privadas (una por AZ)
resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-private-rt-${count.index + 1}"
  })
}

# Asociación de subnets privadas con tablas de rutas privadas
resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Asociación de subnets de base de datos con tablas de rutas privadas
resource "aws_route_table_association" "database" {
  count          = var.az_count
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Asociación de subnets de almacenamiento con tablas de rutas privadas
resource "aws_route_table_association" "storage" {
  count          = var.az_count
  subnet_id      = aws_subnet.storage[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# VPC Endpoints para servicios AWS (seguridad y rendimiento)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.dynamodb"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-dynamodb-endpoint"
  })
}

# Security Group por defecto (restrictivo)
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No permitir ningún tráfico por defecto
  ingress = []
  egress  = []

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-default-sg"
  })
}

# DHCP Options Set personalizado
resource "aws_vpc_dhcp_options" "main" {
  domain_name         = "${var.cluster_name}.internal"
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-dhcp-options"
  })
}

resource "aws_vpc_dhcp_options_association" "main" {
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.main.id
}

# Network ACLs restrictivas
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # Reglas de entrada
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = var.allowed_ssh_cidr_blocks[0]
    from_port  = 22
    to_port    = 22
  }

  # Reglas de salida
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-public-nacl"
  })
}

resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = concat(aws_subnet.private[*].id, aws_subnet.database[*].id, aws_subnet.storage[*].id)

  # Permitir todo el tráfico interno de la VPC
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Reglas de salida
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-private-nacl"
  })
}

# Flow Logs para monitoreo de red
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.cluster_name}-flow-logs"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpc-flow-logs"
  })
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-flow-log"
  })
}

# IAM Role para VPC Flow Logs
resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.cluster_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpc-flow-logs-role"
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.cluster_name}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Data sources
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}