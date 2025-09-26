# Variables para el módulo Security Groups

variable "cluster_name" {
  description = "Nombre del clúster"
  type        = string
}

variable "environment" {
  description = "Entorno del clúster"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks permitidos para SSH"
  type        = list(string)
}

variable "allowed_web_cidr_blocks" {
  description = "CIDR blocks permitidos para acceso web"
  type        = list(string)
}

variable "allowed_monitoring_cidrs" {
  description = "CIDR blocks permitidos para monitoreo"
  type        = list(string)
}

variable "tags" {
  description = "Tags para los recursos"
  type        = map(string)
  default     = {}
}