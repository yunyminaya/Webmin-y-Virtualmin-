# Infraestructura de Clúster Enterprise Webmin/Virtualmin
# Soporte para 1000+ nodos Ubuntu con alta disponibilidad
# Versión: Enterprise Cluster 2025

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "webmin-cluster-terraform-state"
    key            = "cluster/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "webmin-cluster-terraform-lock"
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Generar clave SSH para el clúster
resource "tls_private_key" "cluster_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "cluster_key" {
  key_name   = "${var.cluster_name}-key-${var.environment}"
  public_key = tls_private_key.cluster_ssh_key.public_key_openssh

  tags = {
    Name        = "${var.cluster_name}-ssh-key"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# VPC para el clúster
module "vpc" {
  source = "./modules/vpc"

  cluster_name    = var.cluster_name
  environment     = var.environment
  vpc_cidr        = var.vpc_cidr
  az_count        = var.az_count
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  tags = local.common_tags
}

# Security Groups
module "security_groups" {
  source = "./modules/security_groups"

  cluster_name = var.cluster_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id

  allowed_ssh_cidr_blocks     = var.allowed_ssh_cidr_blocks
  allowed_web_cidr_blocks     = var.allowed_web_cidr_blocks
  allowed_monitoring_cidrs    = var.allowed_monitoring_cidrs

  tags = local.common_tags
}

# Load Balancers
module "load_balancers" {
  source = "./modules/load_balancers"

  cluster_name     = var.cluster_name
  environment      = var.environment
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnet_ids
  private_subnets = module.vpc.private_subnet_ids

  web_instance_ids         = module.web_nodes.instance_ids
  api_instance_ids         = module.api_nodes.instance_ids
  monitoring_instance_ids  = module.monitoring_nodes.instance_ids

  web_certificate_arn      = aws_acm_certificate.web_cert.arn
  api_certificate_arn      = aws_acm_certificate.api_cert.arn

  tags = local.common_tags
}

# Nodos Web (HAProxy/Nginx + Webmin/Virtualmin)
module "web_nodes" {
  source = "./modules/web_nodes"

  cluster_name    = var.cluster_name
  environment     = var.environment
  instance_count  = var.web_node_count
  instance_type   = var.web_instance_type

  vpc_id              = module.vpc.vpc_id
  private_subnets     = module.vpc.private_subnet_ids
  security_group_ids  = [module.security_groups.web_sg_id]

  key_name            = aws_key_pair.cluster_key.key_name
  ami_id              = data.aws_ami.ubuntu.id

  target_group_arns   = [module.load_balancers.web_target_group_arn]

  user_data = templatefile("${path.module}/templates/web_user_data.sh.tpl", {
    cluster_name = var.cluster_name
    environment  = var.environment
  })

  tags = merge(local.common_tags, {
    Role = "web"
  })
}

# Nodos API (Webmin/Virtualmin API)
module "api_nodes" {
  source = "./modules/api_nodes"

  cluster_name    = var.cluster_name
  environment     = var.environment
  instance_count  = var.api_node_count
  instance_type   = var.api_instance_type

  vpc_id              = module.vpc.vpc_id
  private_subnets     = module.vpc.private_subnet_ids
  security_group_ids  = [module.security_groups.api_sg_id]

  key_name            = aws_key_pair.cluster_key.key_name
  ami_id              = data.aws_ami.ubuntu.id

  target_group_arns   = [module.load_balancers.api_target_group_arn]

  user_data = templatefile("${path.module}/templates/api_user_data.sh.tpl", {
    cluster_name = var.cluster_name
    environment  = var.environment
  })

  tags = merge(local.common_tags, {
    Role = "api"
  })
}

# Nodos de Base de Datos (MariaDB Galera Cluster)
module "database_nodes" {
  source = "./modules/database_nodes"

  cluster_name    = var.cluster_name
  environment     = var.environment
  instance_count  = var.db_node_count
  instance_type   = var.db_instance_type

  vpc_id              = module.vpc.vpc_id
  private_subnets     = module.vpc.database_subnet_ids
  security_group_ids  = [module.security_groups.database_sg_id]

  key_name            = aws_key_pair.cluster_key.key_name
  ami_id              = data.aws_ami.ubuntu.id

  user_data = templatefile("${path.module}/templates/database_user_data.sh.tpl", {
    cluster_name = var.cluster_name
    environment  = var.environment
    db_nodes     = var.db_node_count
  })

  tags = merge(local.common_tags, {
    Role = "database"
  })
}

# Nodos de Almacenamiento (GlusterFS/Ceph)
module "storage_nodes" {
  source = "./modules/storage_nodes"

  cluster_name    = var.cluster_name
  environment     = var.environment
  instance_count  = var.storage_node_count
  instance_type   = var.storage_instance_type

  vpc_id              = module.vpc.vpc_id
  private_subnets     = module.vpc.storage_subnet_ids
  security_group_ids  = [module.security_groups.storage_sg_id]

  key_name            = aws_key_pair.cluster_key.key_name
  ami_id              = data.aws_ami.ubuntu.id
  ebs_volume_size     = var.storage_volume_size

  user_data = templatefile("${path.module}/templates/storage_user_data.sh.tpl", {
    cluster_name = var.cluster_name
    environment  = var.environment
  })

  tags = merge(local.common_tags, {
    Role = "storage"
  })
}

# Nodos de Monitoreo (Prometheus + Grafana)
module "monitoring_nodes" {
  source = "./modules/monitoring_nodes"

  cluster_name    = var.cluster_name
  environment     = var.environment
  instance_count  = var.monitoring_node_count
  instance_type   = var.monitoring_instance_type

  vpc_id              = module.vpc.vpc_id
  private_subnets     = module.vpc.private_subnet_ids
  security_group_ids  = [module.security_groups.monitoring_sg_id]

  key_name            = aws_key_pair.cluster_key.key_name
  ami_id              = data.aws_ami.ubuntu.id

  target_group_arns   = [module.load_balancers.monitoring_target_group_arn]

  user_data = templatefile("${path.module}/templates/monitoring_user_data.sh.tpl", {
    cluster_name = var.cluster_name
    environment  = var.environment
  })

  tags = merge(local.common_tags, {
    Role = "monitoring"
  })
}

# Auto Scaling Groups
module "auto_scaling" {
  source = "./modules/auto_scaling"

  cluster_name = var.cluster_name
  environment  = var.environment

  web_launch_template_id         = module.web_nodes.launch_template_id
  api_launch_template_id         = module.api_nodes.launch_template_id
  storage_launch_template_id     = module.storage_nodes.launch_template_id

  web_target_group_arn          = module.load_balancers.web_target_group_arn
  api_target_group_arn          = module.load_balancers.api_target_group_arn

  vpc_zone_identifiers          = module.vpc.private_subnet_ids

  web_min_size                  = var.web_min_size
  web_max_size                  = var.web_max_size
  web_desired_capacity          = var.web_desired_capacity

  api_min_size                  = var.api_min_size
  api_max_size                  = var.api_max_size
  api_desired_capacity          = var.api_desired_capacity

  cpu_threshold                 = var.cpu_threshold
  memory_threshold              = var.memory_threshold
  network_threshold             = var.network_threshold

  tags = local.common_tags
}

# Certificados SSL
resource "aws_acm_certificate" "web_cert" {
  domain_name       = var.web_domain
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.web_domain}"
  ]

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "api_cert" {
  domain_name       = var.api_domain
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.api_domain}"
  ]

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# Route 53 Records
resource "aws_route53_record" "web_validation" {
  for_each = {
    for dvo in aws_acm_certificate.web_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.cluster.zone_id
}

resource "aws_route53_record" "api_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.cluster.zone_id
}

# AMI de Ubuntu más reciente
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Zone Route 53
data "aws_route53_zone" "cluster" {
  name         = var.route53_zone
  private_zone = false
}

# Tags comunes
locals {
  common_tags = {
    Project     = var.cluster_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}