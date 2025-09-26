# Módulo Security Groups para Clúster Enterprise

# Security Group para nodos web
resource "aws_security_group" "web" {
  name_prefix = "${var.cluster_name}-web-"
  vpc_id      = var.vpc_id

  # HTTP desde cualquier lugar (atrás del load balancer)
  ingress {
    description = "HTTP from load balancer"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS desde cualquier lugar
  ingress {
    description = "HTTPS from load balancer"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH solo desde IPs permitidas
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # Puerto de Webmin/Virtualmin
  ingress {
    description = "Webmin from allowed IPs"
    from_port   = 10000
    to_port     = 10000
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # Puerto de Usermin
  ingress {
    description = "Usermin from allowed IPs"
    from_port   = 20000
    to_port     = 20000
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # Tráfico interno del clúster
  ingress {
    description = "Internal cluster traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Salida ilimitada
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-web-sg"
    Role = "web"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group para nodos API
resource "aws_security_group" "api" {
  name_prefix = "${var.cluster_name}-api-"
  vpc_id      = var.vpc_id

  # API HTTPS desde load balancer
  ingress {
    description = "API HTTPS from load balancer"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_cidr_blocks
  }

  # SSH solo desde IPs permitidas
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # Puerto de Webmin API
  ingress {
    description = "Webmin API from allowed IPs"
    from_port   = 10000
    to_port     = 10000
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # Tráfico interno del clúster
  ingress {
    description = "Internal cluster traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Salida ilimitada
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-api-sg"
    Role = "api"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group para nodos de base de datos
resource "aws_security_group" "database" {
  name_prefix = "${var.cluster_name}-database-"
  vpc_id      = var.vpc_id

  # MySQL/MariaDB desde nodos internos
  ingress {
    description = "MySQL from web nodes"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [
      aws_security_group.web.id,
      aws_security_group.api.id,
      aws_security_group.monitoring.id
    ]
  }

  # Galera cluster communication
  ingress {
    description = "Galera cluster communication"
    from_port   = 4567
    to_port     = 4568
    protocol    = "tcp"
    self        = true
  }

  # SST (State Snapshot Transfer)
  ingress {
    description = "SST for Galera"
    from_port   = 4444
    to_port     = 4444
    protocol    = "tcp"
    self        = true
  }

  # IST (Incremental State Transfer)
  ingress {
    description = "IST for Galera"
    from_port   = 4568
    to_port     = 4568
    protocol    = "tcp"
    self        = true
  }

  # SSH solo desde IPs permitidas
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # Tráfico interno del clúster
  ingress {
    description = "Internal cluster traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Salida limitada (solo a repositorios y actualizaciones)
  egress {
    description = "HTTP to package repositories"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS to package repositories"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-database-sg"
    Role = "database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group para nodos de almacenamiento
resource "aws_security_group" "storage" {
  name_prefix = "${var.cluster_name}-storage-"
  vpc_id      = var.vpc_id

  # GlusterFS ports
  ingress {
    description = "GlusterFS brick"
    from_port   = 24007
    to_port     = 24008
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "GlusterFS management"
    from_port   = 24009
    to_port     = 24009
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "GlusterFS NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    self        = true
  }

  # Ceph ports (si se usa Ceph en lugar de GlusterFS)
  ingress {
    description = "Ceph OSD"
    from_port   = 6800
    to_port     = 7300
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Ceph MON"
    from_port   = 6789
    to_port     = 6789
    protocol    = "tcp"
    self        = true
  }

  # SSH solo desde IPs permitidas
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # Tráfico interno del clúster
  ingress {
    description = "Internal cluster traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Salida limitada
  egress {
    description = "HTTP to package repositories"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS to package repositories"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-storage-sg"
    Role = "storage"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group para nodos de monitoreo
resource "aws_security_group" "monitoring" {
  name_prefix = "${var.cluster_name}-monitoring-"
  vpc_id      = var.vpc_id

  # Prometheus
  ingress {
    description = "Prometheus from allowed IPs"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.allowed_monitoring_cidrs
  }

  # Grafana
  ingress {
    description = "Grafana from allowed IPs"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_monitoring_cidrs
  }

  # Alertmanager
  ingress {
    description = "Alertmanager from allowed IPs"
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = var.allowed_monitoring_cidrs
  }

  # Node Exporter
  ingress {
    description = "Node Exporter from monitoring nodes"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    self        = true
  }

  # SSH solo desde IPs permitidas
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # Tráfico interno del clúster
  ingress {
    description = "Internal cluster traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Salida ilimitada (necesaria para alertas y notificaciones)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-monitoring-sg"
    Role = "monitoring"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group para Load Balancers
resource "aws_security_group" "load_balancer" {
  name_prefix = "${var.cluster_name}-lb-"
  vpc_id      = var.vpc_id

  # HTTP desde cualquier lugar
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS desde cualquier lugar
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Salida solo a instancias backend
  egress {
    description = "Traffic to backend instances"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = [
      aws_security_group.web.id,
      aws_security_group.api.id,
      aws_security_group.monitoring.id
    ]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-lb-sg"
    Role = "load_balancer"
  })

  lifecycle {
    create_before_destroy = true
  }
}