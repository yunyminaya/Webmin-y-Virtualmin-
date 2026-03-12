# Variables para el módulo VPC

variable "cluster_name" {
  description = "Nombre del clúster"
  type        = string
}

variable "environment" {
  description = "Entorno del clúster"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  type        = string
}

variable "az_count" {
  description = "Número de Availability Zones"
  type        = number
}

variable "public_subnets" {
  description = "Subnets públicas"
  type        = list(string)
}

variable "private_subnets" {
  description = "Subnets privadas"
  type        = list(string)
}

variable "database_subnets" {
  description = "Subnets de base de datos"
  type        = list(string)
}

variable "storage_subnets" {
  description = "Subnets de almacenamiento"
  type        = list(string)
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks permitidos para SSH"
  type        = list(string)
}

variable "tags" {
  description = "Tags para los recursos"
  type        = map(string)
  default     = {}
}