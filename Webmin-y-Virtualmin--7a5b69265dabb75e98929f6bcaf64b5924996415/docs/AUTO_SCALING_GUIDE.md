# Guía de Autoescalado para Virtualmin Pro

## 📈 Introducción

Esta guía proporciona instrucciones detalladas para implementar autoescalado en un entorno Virtualmin Pro, permitiendo que la infraestructura se adapte dinámicamente a las cargas de trabajo y optimice el uso de recursos.

## 📋 Requisitos Previos

### Infraestructura
- Despliegue de Virtualmin Pro existente
- Balanceadores de carga configurados (ALB, NLB o HAProxy)
- Sistema de monitoreo implementado (Prometheus, CloudWatch, etc.)
- Imágenes AMI o plantillas de máquinas virtuales preconfiguradas

### Software
- Terraform >= 1.0
- Ansible >= 2.9
- Python >= 3.6
- AWS CLI, Azure CLI, o gcloud CLI
- Herramientas de monitoreo (Prometheus, Grafana)

### Permisos
- Acceso administrativo a la cuenta de nube
- Permisos para crear y gestionar Auto Scaling Groups
- Permisos para configurar políticas de escalado
- Permisos para configurar métricas y alarmas

## 🏗️ Arquitectura de Autoescalado

### Componentes Principales

```
┌─────────────────────────────────────────────────────────┐
│                   Sistema de Autoescalado                │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │   Métricas   │  │   Alarmas   │  │   Políticas  │      │
│  │  (CPU, RAM,  │  │ (Umbral de  │  │  (Escalar y  │      │
│  │  Red, etc.)  │  │  escalado)  │  │  reducir)    │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐ │
│  │               Auto Scaling Group                   │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐ │ │
│  │  │ Nodo 1  │  │ Nodo 2  │  │ Nodo 3  │  │   ...   │ │ │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘ │ │
│  └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐ │
│  │               Balanceador de Carga                   │ │
│  │  ┌─────────────────────────────────────────────────┐ │ │
│  │  │  Distribución de tráfico basada en salud        │ │ │
│  │  └─────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Flujo de Autoescalado

1. **Recopilación de Métricas**: El sistema recopila métricas de rendimiento de los nodos (CPU, RAM, red).
2. **Evaluación de Alarmas**: Las alarmas se activan cuando las métricas superan los umbrales configurados.
3. **Ejecución de Políticas**: Las políticas de escalado se ejecutan en respuesta a las alarmas.
4. **Ajuste de Capacidad**: El Auto Scaling Group añade o elimina nodos según las políticas.
5. **Actualización del Balanceador**: El balanceador de carga actualiza su configuración para incluir los nuevos nodos.

## 🚀 Implementación Paso a Paso

### 1. Preparar Entorno

#### 1.1 Instalar Herramientas

```bash
# Instalar Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Instalar Ansible
sudo apt-get update
sudo apt-get install software-properties-common
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt-get install ansible

# Instalar Python y pip
sudo apt-get update
sudo apt-get install python3 python3-pip

# Instalar AWS CLI (para AWS)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

#### 1.2 Configurar Credenciales

```bash
# Configurar credenciales de AWS
aws configure

# Configurar credenciales de Azure (si aplica)
az login

# Configurar credenciales de GCP (si aplica)
gcloud auth login
gcloud config set project your-project-id
```

### 2. Configurar Infraestructura con Terraform

#### 2.1 Estructura de Directorios

```
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── provider.tf
├── modules/
│   ├── auto_scaling/
│   ├── load_balancer/
│   ├── monitoring/
│   └── security/
└── scripts/
    ├── setup.sh
    └── cleanup.sh
```

#### 2.2 Configurar Proveedores

```hcl
# provider.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

#### 2.3 Definir Variables

```hcl
# variables.tf
variable "cluster_name" {
  description = "Nombre del clúster"
  type        = string
  default     = "virtualmin-pro-cluster"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "instance_types" {
  description = "Tipos de instancias por componente"
  type        = map(string)
  default = {
    web       = "t3.medium"
    api       = "t3.medium"
    database  = "db.t3.medium"
    storage   = "t3.large"
    monitoring = "t3.small"
  }
}

variable "ssh_public_key" {
  description = "Clave SSH pública para acceso a las instancias"
  type        = string
}

variable "domain_name" {
  description = "Nombre de dominio principal"
  type        = string
  default     = "virtualmin-pro.com"
}

variable "auto_scaling_config" {
  description = "Configuración de autoescalado"
  type        = map(any)
  default = {
    web = {
      min_size         = 2
      max_size         = 10
      desired_capacity = 2
      cpu_threshold    = 70
      memory_threshold = 80
    }
    api = {
      min_size         = 2
      max_size         = 10
      desired_capacity = 2
      cpu_threshold    = 70
      memory_threshold = 80
    }
  }
}
```

#### 2.4 Crear Módulo de Auto Scaling

```hcl
# modules/auto_scaling/main.tf
resource "aws_launch_template" "main" {
  name_prefix   = "${var.cluster_name}-${var.component}-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    cluster_name = var.cluster_name
    component    = var.component
    environment  = var.environment
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.cluster_name}-${var.component}"
      Environment = var.environment
      Component   = var.component
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "main" {
  name                = "${var.cluster_name}-${var.component}"
  vpc_zone_identifier  = var.subnet_ids
  desired_capacity    = var.desired_capacity
  max_size            = var.max_size
  min_size            = var.min_size
  target_group_arns   = var.target_group_arns
  health_check_type   = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-${var.component}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Component"
    value               = var.component
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.cluster_name}-${var.component}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.main.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.cluster_name}-${var.component}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.main.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "scale_up_cpu" {
  alarm_name          = "${var.cluster_name}-${var.component}-scale-up-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace          = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_down_cpu" {
  alarm_name          = "${var.cluster_name}-${var.component}-scale-down-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace          = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_up_memory" {
  alarm_name          = "${var.cluster_name}-${var.component}-scale-up-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace          = "System/Linux"
  period              = "120"
  statistic           = "Average"
  threshold           = var.memory_threshold
  alarm_description   = "This metric monitors ec2 memory utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_down_memory" {
  alarm_name          = "${var.cluster_name}-${var.component}-scale-down-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace          = "System/Linux"
  period              = "120"
  statistic           = "Average"
  threshold           = 40
  alarm_description   = "This metric monitors ec2 memory utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }
}
```

#### 2.5 Configurar Variables del Módulo

```hcl
# modules/auto_scaling/variables.tf
variable "cluster_name" {
  description = "Nombre del clúster"
  type        = string
}

variable "component" {
  description = "Componente del clúster"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "ami_id" {
  description = "ID de la AMI"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia"
  type        = string
}

variable "key_name" {
  description = "Nombre de la clave SSH"
  type        = string
}

variable "subnet_ids" {
  description = "IDs de las subredes"
  type        = list(string)
}

variable "target_group_arns" {
  description = "ARNs de los grupos de destino"
  type        = list(string)
}

variable "min_size" {
  description = "Tamaño mínimo del Auto Scaling Group"
  type        = number
}

variable "max_size" {
  description = "Tamaño máximo del Auto Scaling Group"
  type        = number
}

variable "desired_capacity" {
  description = "Capacidad deseada del Auto Scaling Group"
  type        = number
}

variable "cpu_threshold" {
  description = "Umbral de CPU para escalado"
  type        = number
}

variable "memory_threshold" {
  description = "Umbral de memoria para escalado"
  type        = number
}
```

#### 2.6 Configurar Recursos de Auto Scaling

```hcl
# main.tf
# Obtener AMI más reciente de Ubuntu
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

# Obtener VPC y subredes existentes
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-vpc"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Type"
    values = ["Private"]
  }
}

# Crear Auto Scaling Group para nodos web
module "auto_scaling_web" {
  source = "./modules/auto_scaling"

  cluster_name       = var.cluster_name
  component          = "web"
  environment        = var.environment
  ami_id             = data.aws_ami.ubuntu.id
  instance_type      = var.instance_types.web
  key_name           = aws_key_pair.main.key_name
  subnet_ids         = data.aws_subnets.private.ids
  target_group_arns  = [aws_lb_target_group.web.arn]
  min_size           = var.auto_scaling_config.web.min_size
  max_size           = var.auto_scaling_config.web.max_size
  desired_capacity   = var.auto_scaling_config.web.desired_capacity
  cpu_threshold      = var.auto_scaling_config.web.cpu_threshold
  memory_threshold   = var.auto_scaling_config.web.memory_threshold
}

# Crear Auto Scaling Group para nodos API
module "auto_scaling_api" {
  source = "./modules/auto_scaling"

  cluster_name       = var.cluster_name
  component          = "api"
  environment        = var.environment
  ami_id             = data.aws_ami.ubuntu.id
  instance_type      = var.instance_types.api
  key_name           = aws_key_pair.main.key_name
  subnet_ids         = data.aws_subnets.private.ids
  target_group_arns  = [aws_lb_target_group.api.arn]
  min_size           = var.auto_scaling_config.api.min_size
  max_size           = var.auto_scaling_config.api.max_size
  desired_capacity   = var.auto_scaling_config.api.desired_capacity
  cpu_threshold      = var.auto_scaling_config.api.cpu_threshold
  memory_threshold   = var.auto_scaling_config.api.memory_threshold
}
```

### 3. Configurar Ansible para Despliegue

#### 3.1 Estructura de Directorios

```
ansible/
├── inventory/
│   └── hosts
├── group_vars/
│   └── all.yml
├── roles/
│   ├── webmin/
│   ├── virtualmin/
│   ├── monitoring/
│   └── auto_scaling/
├── playbooks/
│   ├── deploy.yml
│   ├── configure.yml
│   └── update.yml
└── ansible.cfg
```

#### 3.2 Configurar Inventario Dinámico

```ini
# inventory/hosts
[web_nodes]
${web_nodes}

[api_nodes]
${api_nodes}

[cluster_children]
web_nodes
api_nodes

[all:vars]
cluster_name=virtualmin-pro-cluster
environment=production
```

#### 3.3 Crear Playbooks de Despliegue

```yaml
# playbooks/deploy.yml
---
- name: Desplegar Virtualmin Pro con autoescalado
  hosts: all
  become: yes
  vars_files:
    - group_vars/all.yml
  
  tasks:
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

- name: Configurar nodos web
  hosts: web_nodes
  become: yes
  roles:
    - webmin
    - virtualmin
    - apache
    - monitoring

- name: Configurar nodos API
  hosts: api_nodes
  become: yes
  roles:
    - webmin
    - virtualmin
    - monitoring
```

#### 3.4 Crear Rol de Monitoreo para Autoescalado

```yaml
# roles/auto_scaling/tasks/main.yml
---
- name: Instalar agente de CloudWatch
  pip:
    name: cloudwatch-agent
    state: present

- name: Configurar agente de CloudWatch
  template:
    src: cloudwatch-agent.json.j2
    dest: /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
    owner: root
    group: root
    mode: '0644'
  notify: restart cloudwatch-agent

- name: Iniciar servicio de CloudWatch Agent
  systemd:
    name: amazon-cloudwatch-agent
    state: started
    enabled: yes

- name: Instalar scripts de personalización
  template:
    src: customize_instance.sh.j2
    dest: /usr/local/bin/customize_instance.sh
    owner: root
    group: root
    mode: '0755'

- name: Configurar script de personalización para ejecutar en arranque
  copy:
    content: |
      #!/bin/bash
      /usr/local/bin/customize_instance.sh
    dest: /etc/rc.local
    owner: root
    group: root
    mode: '0755'

# roles/auto_scaling/handlers/main.yml
---
- name: restart cloudwatch-agent
  systemd:
    name: amazon-cloudwatch-agent
    state: restarted
```

### 4. Configurar Métricas y Alarmas

#### 4.1 Configurar Métricas Personalizadas

```yaml
# roles/monitoring/tasks/metrics.yml
---
- name: Instalar herramientas de monitoreo
  apt:
    name:
      - prometheus-node-exporter
      - collectd
      - collectd-utils
    state: present

- name: Configurar Prometheus Node Exporter
  template:
    src: prometheus-node-exporter.j2
    dest: /etc/default/prometheus-node-exporter
    owner: root
    group: root
    mode: '0644'
  notify: restart prometheus-node-exporter

- name: Iniciar servicio de Prometheus Node Exporter
  systemd:
    name: prometheus-node-exporter
    state: started
    enabled: yes

- name: Configurar Collectd para métricas personalizadas
  template:
    src: collectd.conf.j2
    dest: /etc/collectd/collectd.conf
    owner: root
    group: root
    mode: '0644'
  notify: restart collectd

- name: Iniciar servicio de Collectd
  systemd:
    name: collectd
    state: started
    enabled: yes
```

#### 4.2 Configurar Alarmas Personalizadas

```hcl
# monitoring.tf
resource "aws_cloudwatch_metric_alarm" "high_request_rate" {
  alarm_name          = "${var.cluster_name}-high-request-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RequestCount"
  namespace          = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = 1000
  alarm_description   = "This metric monitors the request rate"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.cluster_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace          = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors the error rate"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "low_request_rate" {
  alarm_name          = "${var.cluster_name}-low-request-rate"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "5"
  metric_name         = "RequestCount"
  namespace          = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "This metric monitors the request rate"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}
```

### 5. Configurar Políticas de Escalado Avanzadas

#### 5.1 Escalado Basado en Predicción

```hcl
# predictive_scaling.tf
resource "aws_autoscaling_policy" "predictive_scaling" {
  name                   = "${var.cluster_name}-predictive-scaling"
  autoscaling_group_name = aws_autoscaling_group.main.name
  policy_type            = "PredictiveScaling"
  predictive_scaling_configuration {
    mode                            = "ForecastAndScale"
    scheduling_buffer_time           = 10
    max_capacity_breach_behavior     = "IncreaseMaxCapacity"
    target_capacity                 = var.desired_capacity
  }
}
```

#### 5.2 Escalado Basado en Programación

```hcl
# scheduled_scaling.tf
resource "aws_autoscaling_schedule" "scale_up_business_hours" {
  scheduled_action_name  = "${var.cluster_name}-scale-up-business-hours"
  autoscaling_group_name = aws_autoscaling_group.main.name
  min_size               = var.business_hours_min
  max_size               = var.business_hours_max
  desired_capacity       = var.business_hours_desired
  recurrence             = "0 8 * * 1-5"
}

resource "aws_autoscaling_schedule" "scale_down_non_business_hours" {
  scheduled_action_name  = "${var.cluster_name}-scale-down-non-business-hours"
  autoscaling_group_name = aws_autoscaling_group.main.name
  min_size               = var.non_business_hours_min
  max_size               = var.non_business_hours_max
  desired_capacity       = var.non_business_hours_desired
  recurrence             = "0 18 * * 1-5"
}
```

#### 5.3 Escalado Basado en Métricas Personalizadas

```hcl
# custom_metrics.tf
resource "aws_iam_policy" "cloudwatch_custom_metrics" {
  name        = "${var.cluster_name}-cloudwatch-custom-metrics"
  description = "Policy for publishing custom metrics to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_custom_metrics" {
  role       = aws_iam_role.autoscaling.name
  policy_arn = aws_iam_policy.cloudwatch_custom_metrics.arn
}

resource "aws_cloudwatch_metric_alarm" "custom_metric_scale_up" {
  alarm_name          = "${var.cluster_name}-custom-metric-scale-up"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = var.custom_metric_name
  namespace          = var.custom_metric_namespace
  period              = "60"
  statistic           = "Average"
  threshold           = var.custom_metric_threshold_up
  alarm_description   = "This metric monitors custom metric for scaling up"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }
}

resource "aws_cloudwatch_metric_alarm" "custom_metric_scale_down" {
  alarm_name          = "${var.cluster_name}-custom-metric-scale-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = var.custom_metric_name
  namespace          = var.custom_metric_namespace
  period              = "60"
  statistic           = "Average"
  threshold           = var.custom_metric_threshold_down
  alarm_description   = "This metric monitors custom metric for scaling down"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }
}
```

### 6. Configurar Optimización de Costos

#### 6.1 Instancias Spot

```hcl
# spot_instances.tf
resource "aws_launch_template" "spot" {
  name_prefix   = "${var.cluster_name}-${var.component}-spot-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    cluster_name = var.cluster_name
    component    = var.component
    environment  = var.environment
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.cluster_name}-${var.component}-spot"
      Environment = var.environment
      Component   = var.component
      InstanceType = "Spot"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "spot" {
  name                = "${var.cluster_name}-${var.component}-spot"
  vpc_zone_identifier  = var.subnet_ids
  desired_capacity    = var.spot_desired_capacity
  max_size            = var.spot_max_size
  min_size            = var.spot_min_size
  target_group_arns   = var.target_group_arns
  health_check_type   = "EC2"
  health_check_grace_period = 300

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = var.on_demand_base_capacity
      on_demand_percentage_above_base_capacity   = var.on_demand_percentage
      spot_allocation_strategy                  = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.spot.id
        version           = "$Latest"
      }
      override {
        instance_type = var.instance_type
      }
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-${var.component}-spot"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Component"
    value               = var.component
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

#### 6.2 Reservas de Instancias

```hcl
# reserved_instances.tf
resource "aws_ec2_reserved_instances_offering" "web" {
  instance_type   = var.instance_types.web
  offering_type   = "No Upfront"
  instance_tenancy = "default"
  product_description = "Linux/UNIX"
}

resource "aws_ec2_reserved_instances" "web" {
  instance_count = var.web_reserved_instances
  offering_id    = aws_ec2_reserved_instances_offering.web.offering_id
}

resource "aws_ec2_reserved_instances_offering" "api" {
  instance_type   = var.instance_types.api
  offering_type   = "No Upfront"
  instance_tenancy = "default"
  product_description = "Linux/UNIX"
}

resource "aws_ec2_reserved_instances" "api" {
  instance_count = var.api_reserved_instances
  offering_id    = aws_ec2_reserved_instances_offering.api.offering_id
}
```

### 7. Probar y Validar el Autoescalado

#### 7.1 Ejecutar Pruebas de Carga

```bash
#!/bin/bash
# scripts/load_test.sh

# Configuración
TARGET_URL="${TARGET_URL:-http://virtualmin-pro.com}"
DURATION="${DURATION:-300}"
CONCURRENT_USERS="${CONCURRENT_USERS:-50}"

# Ejecutar prueba de carga con Apache Bench
ab -n $((CONCURRENT_USERS * DURATION)) -c $CONCURRENT_USERS $TARGET_URL

# Ejecutar prueba de carga con JMeter
/opt/virtualmin/stress-testing/scripts/run_jmeter_test.sh api $CONCURRENT_USERS 10 $DURATION $TARGET_URL

# Ejecutar prueba de carga con Locust
/opt/virtualmin/stress-testing/scripts/run_locust_test.sh api $CONCURRENT_USERS 5 $DURATION localhost 10000 false
```

#### 7.2 Monitorear Actividad de Autoescalado

```bash
#!/bin/bash
# scripts/monitor_auto_scaling.sh

# Configuración
REGION="${REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-virtualmin-pro-cluster}"

# Monitorear actividad de Auto Scaling Groups
autoscaling_groups=$(aws autoscaling describe-auto-scaling-groups --region $REGION --query "AutoScalingGroups[?contains(Tags[?Key=='Name'].Value, '$CLUSTER_NAME')].AutoScalingGroupName" --output text)

for asg in $autoscaling_groups; do
  echo "Auto Scaling Group: $asg"
  echo "Desired Capacity: $(aws autoscaling describe-auto-scaling-groups --region $REGION --auto-scaling-group-names $asg --query 'AutoScalingGroups[0].DesiredCapacity' --output text)"
  echo "Min Size: $(aws autoscaling describe-auto-scaling-groups --region $REGION --auto-scaling-group-names $asg --query 'AutoScalingGroups[0].MinSize' --output text)"
  echo "Max Size: $(aws autoscaling describe-auto-scaling-groups --region $REGION --auto-scaling-group-names $asg --query 'AutoScalingGroups[0].MaxSize' --output text)"
  echo "Instances:"
  aws autoscaling describe-auto-scaling-groups --region $REGION --auto-scaling-group-names $asg --query 'AutoScalingGroups[0].Instances[*].InstanceId' --output text | while read -r instance; do
    echo "  - $instance ($(aws ec2 describe-instances --region $REGION --instance-ids $instance --query 'Reservations[0].Instances[0].State.Name' --output text))"
  done
  echo ""
done

# Monitorear actividad de alarmas
echo "Alarmas de CloudWatch:"
alarm_names=$(aws cloudwatch describe-alarms --region $REGION --query "MetricAlarms[?contains(AlarmName, '$CLUSTER_NAME')].AlarmName" --output text)

for alarm in $alarm_names; do
  echo "Alarma: $alarm"
  echo "Estado: $(aws cloudwatch describe-alarms --region $REGION --alarm-names $alarm --query 'MetricAlarms[0].StateValue' --output text)"
  echo ""
done
```

## 🔧 Mantenimiento y Operaciones

### Monitoreo Continuo

1. **Métricas de Autoescalado**: Monitorear actividad de escalado y eventos.
2. **Métricas de Rendimiento**: Monitorear latencia, tiempo de respuesta y tasa de errores.
3. **Métricas de Costos**: Monitorear costos de instancias y optimización.
4. **Alertas**: Configurar alertas para fallos de autoescalado y umbrales anormales.

### Optimización de Políticas

1. **Análisis de Patrones**: Analizar patrones de carga para ajustar políticas.
2. **Pruebas A/B**: Probar diferentes políticas para encontrar la óptima.
3. **Métricas Personalizadas**: Añadir métricas personalizadas para escalado más preciso.
4. **Feedback Loop**: Implementar un ciclo de retroalimentación para mejorar políticas.

### Actualizaciones y Despliegues

1. **Despliegues Blue/Green**: Utilizar despliegues blue/green para minimizar impacto.
2. **Actualizaciones Graduales**: Implementar actualizaciones gradualmente en los nodos.
3. **Pruebas de Validación**: Probar nuevas configuraciones en entorno de pruebas.
4. **Rollback Automático**: Configurar rollback automático en caso de fallos.

## 📊 Métricas y KPIs

### Rendimiento

- **Tiempo de escalado**: < 5 minutos
- **Disponibilidad durante escalado**: > 99.9%
- **Precisión de escalado**: > 95%
- **Eficiencia de recursos**: > 80%

### Costos

- **Optimización de costos**: 20-30% de ahorro
- **Costo por solicitud**: < $0.001
- **ROI de autoescalado**: > 200%
- **Amortización de infraestructura**: < 12 meses

### Experiencia del Usuario

- **Latencia objetivo**: < 100ms para el 95% de las solicitudes
- **Tiempo de respuesta objetivo**: < 200ms para el 95% de las solicitudes
- **Tasa de error objetivo**: < 0.1%
- **Satisfacción del cliente**: > 90%

## 🚨 Solución de Problemas

### Problemas Comunes

1. **Escalado Insuficiente**: Ajustar umbrales y políticas de escalado.
2. **Escalado Excesivo**: Implementar políticas de escalado más conservadoras.
3. **Inestabilidad durante Escalado**: Configurar health checks y grace periods.
4. **Costos Elevados**: Optimizar tipos de instancias y reservas.

### Herramientas de Diagnóstico

1. **Logs de Auto Scaling**: Analizar logs para identificar problemas.
2. **Métricas de CloudWatch**: Revisar métricas para entender el comportamiento.
3. **Eventos de Auto Scaling**: Examinar eventos de escalado para validar políticas.
4. **Gráficos de Monitoreo**: Visualizar datos para identificar tendencias.

## 📚 Referencias y Recursos Adicionales

### Documentación Oficial

- [AWS Auto Scaling Documentation](https://docs.aws.amazon.com/autoscaling/)
- [AWS CloudWatch Documentation](https://docs.aws.amazon.com/cloudwatch/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Ansible Documentation](https://docs.ansible.com/)

### Guías y Tutoriales

- [AWS Auto Scaling User Guide](https://docs.aws.amazon.com/autoscaling/ec2/userguide/)
- [AWS CloudWatch Alarms User Guide](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [Terraform Best Practices for AWS](https://www.terraform.io/docs/providers/aws/guides/best-practices.html)

### Herramientas y Utilidades

- [AWS CLI Auto Scaling Commands](https://docs.aws.amazon.com/cli/latest/reference/autoscaling/)
- [CloudWatch CLI Commands](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/)
- [Terraform AWS Auto Scaling Resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group.html)