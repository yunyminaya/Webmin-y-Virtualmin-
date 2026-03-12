# Configuración del Proveedor AWS para Clúster Enterprise

terraform {
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
}

# Proveedor AWS principal
provider "aws" {
  region = var.aws_region

  # Configuración opcional para perfiles
  # profile = var.aws_profile

  # Tags por defecto para todos los recursos
  default_tags {
    tags = {
      Project     = var.cluster_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
      CreatedAt   = timestamp()
      AutoScaling = "enabled"
      Backup      = "enabled"
      Monitoring  = "enabled"
      Security    = "enterprise"
    }
  }

  # Configuración de reintentos para estabilidad
  retry_mode      = "adaptive"
  max_retries     = 3

  # Configuración de timeouts
  assume_role_with_web_identity {
    # Para uso con GitHub Actions, GitLab CI, etc.
    # web_identity_token_file = "/path/to/token"
    # role_arn               = var.assume_role_arn
  }
}

# Proveedor AWS para región secundaria (opcional para DR)
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region != "" ? var.secondary_region : var.aws_region

  default_tags {
    tags = {
      Project     = var.cluster_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
      Region      = "secondary"
      DR          = "enabled"
    }
  }
}

# Variables adicionales para el provider
variable "aws_region" {
  description = "Región principal de AWS"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Región secundaria para Disaster Recovery"
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "Perfil de AWS CLI (opcional)"
  type        = string
  default     = ""
}

variable "assume_role_arn" {
  description = "ARN del rol IAM para asumir (opcional)"
  type        = string
  default     = ""
}

# Data sources para información de la cuenta
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# Configuración de backend S3 (mover a un archivo separado en producción)
# Este backend debe configurarse antes del primer apply
terraform {
  backend "s3" {
    # bucket         = "webmin-cluster-terraform-state"
    # key            = "cluster/terraform.tfstate"
    # region         = "us-east-1"
    # encrypt        = true
    # dynamodb_table = "webmin-cluster-terraform-lock"
    # kms_key_id     = "alias/terraform-state-key"
  }
}

# Configuración de backend local para desarrollo
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }

# Recursos adicionales para el backend
resource "aws_s3_bucket" "terraform_state" {
  count  = var.create_backend_resources ? 1 : 0
  bucket = "webmin-cluster-terraform-state-${random_string.suffix[0].result}"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Name        = "Terraform State Bucket"
    Environment = var.environment
    Purpose     = "terraform-backend"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count  = var.create_backend_resources ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  count        = var.create_backend_resources ? 1 : 0
  name         = "webmin-cluster-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform Lock Table"
    Environment = var.environment
    Purpose     = "terraform-backend"
  }
}

resource "random_string" "suffix" {
  count   = var.create_backend_resources ? 1 : 0
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

# Variable para crear recursos de backend
variable "create_backend_resources" {
  description = "Crear recursos de backend S3 y DynamoDB"
  type        = bool
  default     = false
}

# Configuración de KMS para encriptación de estado (opcional)
resource "aws_kms_key" "terraform_state" {
  count                   = var.create_backend_resources ? 1 : 0
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30

  tags = {
    Name        = "Terraform State KMS Key"
    Environment = var.environment
    Purpose     = "terraform-backend"
  }
}

resource "aws_kms_alias" "terraform_state" {
  count         = var.create_backend_resources ? 1 : 0
  name          = "alias/terraform-state-key"
  target_key_id = aws_kms_key.terraform_state[0].key_id
}

# Outputs del provider
output "aws_region" {
  description = "Región de AWS actual"
  value       = data.aws_region.current.name
}

output "account_id" {
  description = "ID de la cuenta AWS"
  value       = data.aws_caller_identity.current.account_id
}

output "terraform_state_bucket" {
  description = "Bucket S3 para estado de Terraform"
  value       = var.create_backend_resources ? aws_s3_bucket.terraform_state[0].bucket : "No creado"
}

output "terraform_lock_table" {
  description = "Tabla DynamoDB para bloqueo de Terraform"
  value       = var.create_backend_resources ? aws_dynamodb_table.terraform_lock[0].name : "No creada"
}