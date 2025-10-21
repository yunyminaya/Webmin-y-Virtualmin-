# Guía de Despliegue Multi-Región para Virtualmin Pro

## 🌍 Introducción

Esta guía proporciona instrucciones detalladas para implementar un despliegue multi-región de Virtualmin Pro, garantizando alta disponibilidad, redundancia y rendimiento optimizado a nivel global.

## 📋 Requisitos Previos

### Infraestructura
- Al menos 3 regiones de nube (ej. AWS: us-east-1, us-west-2, eu-west-1)
- Cuentas de administrador en cada región
- Conectividad de red entre regiones (VPN o Direct Connect)
- Almacenamiento compartido entre regiones (S3, EFS, etc.)

### Software
- Terraform >= 1.0
- Ansible >= 2.9
- Python >= 3.6
- AWS CLI, Azure CLI, o gcloud CLI
- Docker y Docker Compose

### Permisos
- Acceso administrativo a las cuentas de nube
- Permisos para crear y gestionar recursos en todas las regiones
- Permisos para configurar DNS global y balanceadores de carga

## 🏗️ Arquitectura Multi-Región

### Componentes Principales

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Región Este    │    │   Región Oeste   │    │   Región Europa  │
│   (Primaria)     │    │   (Secundaria)   │    │   (Terciaria)    │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│  Balanceador     │    │  Balanceador     │    │  Balanceador     │
│  de Carga        │    │  de Carga        │    │  de Carga        │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│  Nodos Web (2)   │    │  Nodos Web (2)   │    │  Nodos Web (2)   │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│  Nodos API (2)   │    │  Nodos API (2)   │    │  Nodos API (2)   │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│  Nodos BD (2)    │    │  Nodos BD (2)    │    │  Nodos BD (2)    │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│  Nodos Almacen.  │    │  Nodos Almacen.  │    │  Nodos Almacen.  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        └───────────────────────┼───────────────────────┘
                                │
                    ┌─────────────────┐
                    │  DNS Global     │
                    │  (Route53,      │
                    │   CloudFlare)   │
                    └─────────────────┘
```

### Flujo de Datos

1. **Enrutamiento Geográfico**: Las solicitudes se dirigen a la región más cercana mediante DNS global.
2. **Balanceo de Carga**: Los balanceadores locales distribuyen el tráfico entre los nodos disponibles.
3. **Replicación de Datos**: Los datos se replican entre regiones para garantizar consistencia.
4. **Failover Automático**: Si una región falla, el tráfico se redirige automáticamente a las regiones restantes.

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
├── environments/
│   ├── us-east-1/
│   ├── us-west-2/
│   └── eu-west-1/
├── modules/
│   ├── vpc/
│   ├── security_groups/
│   ├── compute/
│   ├── load_balancer/
│   └── database/
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

# Configurar proveedores para múltiples regiones
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
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

variable "regions" {
  description = "Regiones de despliegue"
  type        = list(string)
  default     = ["us-east-1", "us-west-2", "eu-west-1"]
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
```

#### 2.4 Crear Módulos de Infraestructura

##### Módulo VPC

```hcl
# modules/vpc/main.tf
resource "aws_vpc" "main" {
  provider   = aws.aws_region
  cidr_block = var.vpc_cidr

  tags = {
    Name        = "${var.cluster_name}-vpc-${var.region}"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  provider   = aws.aws_region
  count      = length(var.public_subnets)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.cluster_name}-public-subnet-${count.index}-${var.region}"
    Environment = var.environment
  }
}

resource "aws_subnet" "private" {
  provider   = aws.aws_region
  count      = length(var.private_subnets)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.cluster_name}-private-subnet-${count.index}-${var.region}"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "main" {
  provider = aws.aws_region
  vpc_id   = aws_vpc.main.id

  tags = {
    Name        = "${var.cluster_name}-igw-${var.region}"
    Environment = var.environment
  }
}

resource "aws_route_table" "public" {
  provider = aws.aws_region
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.cluster_name}-public-rt-${var.region}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  provider          = aws.aws_region
  count             = length(aws_subnet.public)
  subnet_id         = aws_subnet.public[count.index].id
  route_table_id    = aws_route_table.public.id
}
```

##### Módulo de Instancias

```hcl
# modules/compute/main.tf
resource "aws_key_pair" "cluster_key" {
  provider   = aws.aws_region
  key_name   = "${var.cluster_name}-key-${var.region}"
  public_key = var.ssh_public_key

  tags = {
    Name        = "${var.cluster_name}-key-${var.region}"
    Environment = var.environment
  }
}

resource "aws_launch_template" "web_nodes" {
  provider = aws.aws_region
  name_prefix = "${var.cluster_name}-web-${var.region}-"

  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_types.web
  key_name      = aws_key_pair.cluster_key.key_name

  user_data = templatefile("${path.module}/web_user_data.sh.tpl", {
    cluster_name = var.cluster_name
    region       = var.region
  })

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.cluster_name}-web-${var.region}"
      Environment = var.environment
      Role        = "web"
    }
  }
}

resource "aws_autoscaling_group" "web_nodes" {
  provider = aws.aws_region
  name     = "${var.cluster_name}-web-${var.region}"

  vpc_zone_identifier = var.private_subnet_ids
  desired_capacity    = var.web_desired_capacity
  max_size           = var.web_max_size
  min_size           = var.web_min_size

  launch_template {
    id      = aws_launch_template.web_nodes.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-web-${var.region}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "web"
    propagate_at_launch = true
  }
}
```

#### 2.5 Configurar Recursos Multi-Región

```hcl
# main.tf
# Crear VPCs en todas las regiones
module "vpc_us_east_1" {
  source = "./modules/vpc"
  providers = {
    aws.aws_region = aws.us_east_1
  }
  
  cluster_name    = var.cluster_name
  region          = "us-east-1"
  environment     = var.environment
  vpc_cidr        = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]
}

module "vpc_us_west_2" {
  source = "./modules/vpc"
  providers = {
    aws.aws_region = aws.us_west_2
  }
  
  cluster_name    = var.cluster_name
  region          = "us-west-2"
  environment     = var.environment
  vpc_cidr        = "10.1.0.0/16"
  public_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnets = ["10.1.10.0/24", "10.1.20.0/24"]
}

module "vpc_eu_west_1" {
  source = "./modules/vpc"
  providers = {
    aws.aws_region = aws.eu_west_1
  }
  
  cluster_name    = var.cluster_name
  region          = "eu-west-1"
  environment     = var.environment
  vpc_cidr        = "10.2.0.0/16"
  public_subnets  = ["10.2.1.0/24", "10.2.2.0/24"]
  private_subnets = ["10.2.10.0/24", "10.2.20.0/24"]
}

# Crear grupos de Auto Scaling en todas las regiones
module "compute_us_east_1" {
  source = "./modules/compute"
  providers = {
    aws.aws_region = aws.us_east_1
  }
  
  cluster_name          = var.cluster_name
  region               = "us-east-1"
  environment          = var.environment
  ssh_public_key       = var.ssh_public_key
  instance_types       = var.instance_types
  private_subnet_ids   = module.vpc_us_east_1.private_subnet_ids
  
  web_desired_capacity = 2
  web_max_size         = 5
  web_min_size         = 2
  
  api_desired_capacity = 2
  api_max_size         = 5
  api_min_size         = 2
  
  db_desired_capacity  = 2
  db_max_size          = 3
  db_min_size          = 2
}

module "compute_us_west_2" {
  source = "./modules/compute"
  providers = {
    aws.aws_region = aws.us_west_2
  }
  
  cluster_name          = var.cluster_name
  region               = "us-west-2"
  environment          = var.environment
  ssh_public_key       = var.ssh_public_key
  instance_types       = var.instance_types
  private_subnet_ids   = module.vpc_us_west_2.private_subnet_ids
  
  web_desired_capacity = 2
  web_max_size         = 5
  web_min_size         = 2
  
  api_desired_capacity = 2
  api_max_size         = 5
  api_min_size         = 2
  
  db_desired_capacity  = 2
  db_max_size          = 3
  db_min_size          = 2
}

module "compute_eu_west_1" {
  source = "./modules/compute"
  providers = {
    aws.aws_region = aws.eu_west_1
  }
  
  cluster_name          = var.cluster_name
  region               = "eu-west-1"
  environment          = var.environment
  ssh_public_key       = var.ssh_public_key
  instance_types       = var.instance_types
  private_subnet_ids   = module.vpc_eu_west_1.private_subnet_ids
  
  web_desired_capacity = 2
  web_max_size         = 5
  web_min_size         = 2
  
  api_desired_capacity = 2
  api_max_size         = 5
  api_min_size         = 2
  
  db_desired_capacity  = 2
  db_max_size          = 3
  db_min_size          = 2
}
```

### 3. Configurar Ansible para Despliegue

#### 3.1 Estructura de Directorios

```
ansible/
├── inventory/
│   ├── us-east-1/
│   ├── us-west-2/
│   └── eu-west-1/
├── group_vars/
│   └── all.yml
├── roles/
│   ├── webmin/
│   ├── virtualmin/
│   ├── database/
│   ├── storage/
│   └── monitoring/
├── playbooks/
│   ├── deploy.yml
│   ├── configure.yml
│   └── update.yml
└── ansible.cfg
```

#### 3.2 Configurar Inventario Dinámico

```ini
# inventory/us-east-1/hosts
[web_nodes]
web-node-1 ansible_host=10.0.10.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/cluster-key.pem
web-node-2 ansible_host=10.0.10.11 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/cluster-key.pem

[api_nodes]
api-node-1 ansible_host=10.0.20.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/cluster-key.pem
api-node-2 ansible_host=10.0.20.11 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/cluster-key.pem

[database_nodes]
db-node-1 ansible_host=10.0.30.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/cluster-key.pem
db-node-2 ansible_host=10.0.30.11 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/cluster-key.pem

[storage_nodes]
storage-node-1 ansible_host=10.0.40.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/cluster-key.pem
storage-node-2 ansible_host=10.0.40.11 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/cluster-key.pem

[monitoring_nodes]
monitoring-node-1 ansible_host=10.0.50.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/cluster-key.pem
monitoring-node-2 ansible_host=10.0.50.11 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/cluster-key.pem

[cluster_children]
web_nodes
api_nodes
database_nodes
storage_nodes
monitoring_nodes

[all:vars]
region=us-east-1
cluster_name=virtualmin-pro-cluster
environment=production
```

#### 3.3 Crear Playbooks de Despliegue

```yaml
# playbooks/deploy.yml
---
- name: Desplegar Virtualmin Pro en todas las regiones
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

- name: Configurar nodos API
  hosts: api_nodes
  become: yes
  roles:
    - webmin
    - virtualmin

- name: Configurar nodos de base de datos
  hosts: database_nodes
  become: yes
  roles:
    - database

- name: Configurar nodos de almacenamiento
  hosts: storage_nodes
  become: yes
  roles:
    - storage

- name: Configurar nodos de monitoreo
  hosts: monitoring_nodes
  become: yes
  roles:
    - monitoring
```

#### 3.4 Crear Roles de Ansible

##### Rol de Webmin

```yaml
# roles/webmin/tasks/main.yml
---
- name: Agregar repositorio de Webmin
  apt_repository:
    repo: "deb http://download.webmin.com/download/repository sarge contrib"
    state: present
    update_cache: yes

- name: Agregar clave GPG de Webmin
  apt_key:
    url: http://www.webmin.com/jcameron-key.asc
    state: present

- name: Instalar Webmin
  apt:
    name: webmin
    state: present
    update_cache: yes

- name: Configurar Webmin para escuchar en todas las interfaces
  lineinfile:
    path: /etc/webmin/miniserv.conf
    regexp: '^listen='
    line: 'listen=10000'
    state: present
  notify: restart webmin

- name: Configurar Webmin para permitir acceso desde la red privada
  lineinfile:
    path: /etc/webmin/miniserv.conf
    regexp: '^allow='
    line: 'allow=10.0.0.0/8'
    state: present
  notify: restart webmin

- name: Crear usuario de Webmin para Ansible
  user:
    name: webminadmin
    shell: /bin/bash
    create_home: yes
    generate_ssh_key: yes
    ssh_key_bits: 2048
    ssh_key_file: .ssh/id_rsa

- name: Configurar contraseña de Webmin para Ansible
  shell: |
    echo "webminadmin:{{ webmin_admin_password }}" | chpasswd
  args:
    executable: /bin/bash

- name: Asegurar que el servicio de Webmin está en ejecución
  service:
    name: webmin
    state: started
    enabled: yes

# roles/webmin/handlers/main.yml
---
- name: restart webmin
  service:
    name: webmin
    state: restarted
```

##### Rol de Virtualmin

```yaml
# roles/virtualmin/tasks/main.yml
---
- name: Descargar instalador de Virtualmin
  get_url:
    url: http://software.virtualmin.com/gpl/scripts/install.sh
    dest: /tmp/install.sh
    mode: '0755'

- name: Ejecutar instalador de Virtualmin
  shell: |
    /tmp/install.sh --force --hostname {{ inventory_hostname }} --domain {{ domain_name }}
  args:
    executable: /bin/bash

- name: Configurar Virtualmin para modo de clúster
  lineinfile:
    path: /etc/webmin/virtual-server/config
    regexp: '^cluster_mode='
    line: 'cluster_mode=1'
    state: present
  notify: restart webmin

- name: Configurar Virtualmin para replicación de DNS
  lineinfile:
    path: /etc/webmin/virtual-server/config
    regexp: '^dns_replication='
    line: 'dns_replication=1'
    state: present
  notify: restart webmin

- name: Configurar Virtualmin para replicación de base de datos
  lineinfile:
    path: /etc/webmin/virtual-server/config
    regexp: '^db_replication='
    line: 'db_replication=1'
    state: present
  notify: restart webmin

# roles/virtualmin/handlers/main.yml
---
- name: restart webmin
  service:
    name: webmin
    state: restarted
```

### 4. Configurar Replicación Global de Datos

#### 4.1 Replicación de Base de Datos

```yaml
# roles/database/tasks/main.yml
---
- name: Instalar MariaDB
  apt:
    name:
      - mariadb-server
      - mariadb-client
      - python3-mysqldb
    state: present

- name: Configurar MariaDB para replicación
  template:
    src: my.cnf.j2
    dest: /etc/mysql/my.cnf
    owner: root
    group: root
    mode: '0644'
  notify: restart mariadb

- name: Crear usuario de replicación
  mysql_user:
    name: repl_user
    password: "{{ replication_password }}"
    priv: "*.*:REPLICATION SLAVE"
    host: "%"
    state: present

- name: Obtener posición maestra
  mysql_info:
    login_user: root
    login_password: "{{ mysql_root_password }}"
    filter: master_status
  register: master_status
  when: inventory_hostname == groups['database_nodes'][0]

- name: Configurar replicación en nodos esclavos
  mysql_replication:
    mode: changeprimaryto
    master_host: "{{ hostvars[groups['database_nodes'][0]]['ansible_host'] }}"
    master_user: repl_user
    master_password: "{{ replication_password }}"
    master_log_file: "{{ master_status.File }}"
    master_log_pos: "{{ master_status.Position }}"
  when: inventory_hostname != groups['database_nodes'][0]

# roles/database/handlers/main.yml
---
- name: restart mariadb
  service:
    name: mariadb
    state: restarted
```

#### 4.2 Replicación de Almacenamiento

```yaml
# roles/storage/tasks/main.yml
---
- name: Instalar GlusterFS
  apt:
    name:
      - glusterfs-server
      - glusterfs-client
    state: present

- name: Crear directorio para GlusterFS
  file:
    path: /data/glusterfs
    state: directory
    mode: '0755'

- name: Crear volumen de GlusterFS
  gluster_volume:
    name: gv0
    state: present
    bricks: "{{ inventory_hostname }}:/data/glusterfs/brick"
    cluster: "{{ groups['storage_nodes'] | map('extract', ['ansible_host']) | list }}"
    force: yes
  when: inventory_hostname == groups['storage_nodes'][0]

- name: Iniciar volumen de GlusterFS
  gluster_volume:
    name: gv0
    state: started
  when: inventory_hostname == groups['storage_nodes'][0]

- name: Montar volumen de GlusterFS
  mount:
    path: /mnt/glusterfs
    src: "{{ groups['storage_nodes'][0] }}:/gv0"
    fstype: glusterfs
    opts: defaults,_netdev
    state: mounted
```

### 5. Configurar DNS Global y Balanceo de Carga

#### 5.1 Configurar Route53

```hcl
# dns.tf
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "www_us_east_1" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.us-east-1.${var.domain_name}"
  type    = "A"
  ttl     = "60"
  records = module.compute_us_east_1.web_instance_ips
}

resource "aws_route53_record" "www_us_west_2" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.us-west-2.${var.domain_name}"
  type    = "A"
  ttl     = "60"
  records = module.compute_us_west_2.web_instance_ips
}

resource "aws_route53_record" "www_eu_west_1" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.eu-west-1.${var.domain_name}"
  type    = "A"
  ttl     = "60"
  records = module.compute_eu_west_1.web_instance_ips
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  ttl     = "60"
  set_identifier = "us-east-1"
  health_check_id = aws_route53_health_check.www_us_east_1.id
  records = [module.compute_us_east_1.web_instance_ips[0]]
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  ttl     = "60"
  set_identifier = "us-west-2"
  health_check_id = aws_route53_health_check.www_us_west_2.id
  records = [module.compute_us_west_2.web_instance_ips[0]]
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  ttl     = "60"
  set_identifier = "eu-west-1"
  health_check_id = aws_route53_health_check.www_eu_west_1.id
  records = [module.compute_eu_west_1.web_instance_ips[0]]
}

resource "aws_route53_health_check" "www_us_east_1" {
  fqdn                            = "www.${var.domain_name}"
  ip_address                      = module.compute_us_east_1.web_instance_ips[0]
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = "/"
  failure_threshold               = 3
  request_interval                = 30
  cloudwatch_logs_region          = "us-east-1"
  insufficient_data_health_status  = "Failure"
  ssl_certificate_method           = "DEFAULT"
}

resource "aws_route53_health_check" "www_us_west_2" {
  fqdn                            = "www.${var.domain_name}"
  ip_address                      = module.compute_us_west_2.web_instance_ips[0]
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = "/"
  failure_threshold               = 3
  request_interval                = 30
  cloudwatch_logs_region          = "us-west-2"
  insufficient_data_health_status  = "Failure"
  ssl_certificate_method           = "DEFAULT"
}

resource "aws_route53_health_check" "www_eu_west_1" {
  fqdn                            = "www.${var.domain_name}"
  ip_address                      = module.compute_eu_west_1.web_instance_ips[0]
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = "/"
  failure_threshold               = 3
  request_interval                = 30
  cloudwatch_logs_region          = "eu-west-1"
  insufficient_data_health_status  = "Failure"
  ssl_certificate_method           = "DEFAULT"
}

resource "aws_route53_record" "www_failover" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  set_identifier = "us-east-1"
  health_check_id = aws_route53_health_check.www_us_east_1.id
  records = [module.compute_us_east_1.web_instance_ips[0]]
  failover_routing_policy {
    primary = true
  }
}

resource "aws_route53_record" "www_failover" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  set_identifier = "us-west-2"
  health_check_id = aws_route53_health_check.www_us_west_2.id
  records = [module.compute_us_west_2.web_instance_ips[0]]
  failover_routing_policy {
    primary = false
  }
}

resource "aws_route53_record" "www_failover" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  set_identifier = "eu-west-1"
  health_check_id = aws_route53_health_check.www_eu_west_1.id
  records = [module.compute_eu_west_1.web_instance_ips[0]]
  failover_routing_policy {
    primary = false
  }
}
```

#### 5.2 Configurar CloudFlare (Opcional)

```bash
# Obtener ID de zona de CloudFlare
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN_NAME}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

# Crear registros DNS para cada región
for REGION in us-east-1 us-west-2 eu-west-1; do
  # Obtener IP del balanceador de carga en la región
  LB_IP=$(aws elbv2 describe-load-balancers \
    --region ${REGION} \
    --names "${CLUSTER_NAME}-web-lb-${REGION}" \
    --query 'LoadBalancers[0].CanonicalHostedZoneName' \
    --output text)
  
  # Crear registro DNS
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"${REGION}.${DOMAIN_NAME}\",\"content\":\"${LB_IP}\",\"ttl\":60,\"proxied\":false}"
done

# Configurar Load Balancing de CloudFlare
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/load_balancers" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "{
    \"name\":\"${CLUSTER_NAME}-lb\",
    \"fallback_pool\":\"${REGION}-pool\",
    \"default_pools\":[\"us-east-1-pool\",\"us-west-2-pool\",\"eu-west-1-pool\"],
    \"description\":\"Load Balancer for ${CLUSTER_NAME}\",
    \"ttl\":60,
    \"proxied\":true
  }"

# Crear pools para cada región
for REGION in us-east-1 us-west-2 eu-west-1; do
  # Obtener IPs de los balanceadores de carga en la región
  LB_IPS=$(aws elbv2 describe-load-balancers \
    --region ${REGION} \
    --names "${CLUSTER_NAME}-web-lb-${REGION}" \
    --query 'LoadBalancers[*].CanonicalHostedZoneName' \
    --output text)
  
  # Crear array de orígenes
  ORIGINS=$(echo "${LB_IPS}" | jq -R 'split("\n") | map(select(length > 0)) | map({"name": ., "address": .}) | tostring')
  
  # Crear pool
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/load_balancers/pools" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "{
      \"name\":\"${REGION}-pool\",
      \"description\":\"Pool for ${REGION}\",
      \"enabled\":true,
      \"monitor\":\"${CLUSTER_NAME}-monitor\",
      \"origins\":${ORIGINS}
    }"
done

# Crear monitor de salud
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/load_balancers/monitors" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "{
    \"name\":\"${CLUSTER_NAME}-monitor\",
    \"description\":\"Health monitor for ${CLUSTER_NAME}\",
    \"type\":\"https\",
    \"path\":\"/\",
    \"check_regions\":[\"wnam\",\"enam\",\"weur\"],
    \"port\":443,
    \"interval\":60,
    \"timeout\":5,
    \"retries\":3,
    \"success_codes\":[200,201,202,204]
  }"
```

### 6. Configurar Monitoreo y Alertas

#### 6.1 Configurar Prometheus y Grafana

```yaml
# roles/monitoring/tasks/main.yml
---
- name: Instalar Prometheus
  apt:
    name:
      - prometheus
      - prometheus-node-exporter
    state: present

- name: Configurar Prometheus
  template:
    src: prometheus.yml.j2
    dest: /etc/prometheus/prometheus.yml
    owner: root
    group: root
    mode: '0644'
  notify: restart prometheus

- name: Instalar Grafana
  apt:
    name:
      - grafana
    state: present

- name: Configurar Grafana
  template:
    src: grafana.ini.j2
    dest: /etc/grafana/grafana.ini
    owner: root
    group: root
    mode: '0644'
  notify: restart grafana

- name: Crear dashboard de Grafana para Virtualmin
  copy:
    src: virtualmin-dashboard.json
    dest: /var/lib/grafana/dashboards/virtualmin-dashboard.json
    owner: grafana
    group: grafana
    mode: '0644'
  notify: restart grafana

# roles/monitoring/handlers/main.yml
---
- name: restart prometheus
  service:
    name: prometheus
    state: restarted

- name: restart grafana
  service:
    name: grafana
    state: restarted
```

#### 6.2 Configurar Alertas

```yaml
# roles/monitoring/tasks/alerts.yml
---
- name: Instalar Alertmanager
  apt:
    name:
      - prometheus-alertmanager
    state: present

- name: Configurar Alertmanager
  template:
    src: alertmanager.yml.j2
    dest: /etc/prometheus/alertmanager.yml
    owner: root
    group: root
    mode: '0644'
  notify: restart alertmanager

- name: Crear reglas de alerta para Virtualmin
  copy:
    src: virtualmin-alerts.yml
    dest: /etc/prometheus/virtualmin-alerts.yml
    owner: root
    group: root
    mode: '0644'
  notify: restart prometheus

# roles/monitoring/handlers/alerts.yml
---
- name: restart alertmanager
  service:
    name: prometheus-alertmanager
    state: restarted
```

### 7. Implementar Disaster Recovery

#### 7.1 Configurar Backups Automáticos

```yaml
# roles/backup/tasks/main.yml
---
- name: Instalar herramientas de backup
  apt:
    name:
      - awscli
      - duplicity
    state: present

- name: Crear directorio de backups
  file:
    path: /opt/virtualmin/backups
    state: directory
    mode: '0755'

- name: Configurar script de backup
  template:
    src: backup.sh.j2
    dest: /opt/virtualmin/backups/backup.sh
    owner: root
    group: root
    mode: '0750'

- name: Crear cron job para backups diarios
  cron:
    name: "daily backup"
    minute: "0"
    hour: "2"
    job: "/opt/virtualmin/backups/backup.sh"
    user: root
```

#### 7.2 Configurar Replicación de Backups

```bash
#!/bin/bash
# /opt/virtualmin/backups/backup.sh

# Configuración
BACKUP_DIR="/opt/virtualmin/backups"
S3_BUCKET="virtualmin-backups-${REGION}"
RETENTION_DAYS=30

# Crear backup de bases de datos
mysqldump --all-databases --single-transaction --routines --triggers | gzip > "${BACKUP_DIR}/mysql-$(date +%Y%m%d%H%M%S).sql.gz"

# Crear backup de archivos de configuración
tar -czf "${BACKUP_DIR}/config-$(date +%Y%m%d%H%M%S).tar.gz" /etc/webmin /etc/virtualmin /etc/apache2 /etc/nginx

# Crear backup de archivos de usuarios
tar -czf "${BACKUP_DIR}/users-$(date +%Y%m%d%H%M%S).tar.gz" /home

# Subir backups a S3
aws s3 sync "${BACKUP_DIR}" "s3://${S3_BUCKET}/" --delete

# Limpiar backups locales antiguos
find "${BACKUP_DIR}" -name "*.gz" -mtime +${RETENTION_DAYS} -delete

# Limpiar backups en S3 antiguos
aws s3 ls "s3://${S3_BUCKET}/" | while read -r line; do
    createDate=$(echo "$line" | awk '{print $1" "$2}')
    createDate=$(date -d "$createDate" +%s)
    olderThan=$(date -d "$RETENTION_DAYS days ago" +%s)
    if [[ $createDate -lt $olderThan ]]; then
        fileName=$(echo "$line" | awk '{print $4}')
        if [[ $fileName != "" ]]; then
            aws s3 rm "s3://${S3_BUCKET}/$fileName"
        fi
    fi
done
```

### 8. Probar y Validar el Despliegue

#### 8.1 Ejecutar Pruebas de Conectividad

```bash
#!/bin/bash
# scripts/test_connectivity.sh

# Configuración
REGIONS=("us-east-1" "us-west-2" "eu-west-1")
DOMAIN_NAME="virtualmin-pro.com"

# Probar conectividad a cada región
for REGION in "${REGIONS[@]}"; do
    echo "Probando conectividad a ${REGION}..."
    
    # Probar ping a balanceador de carga
    ping -c 3 "${REGION}.${DOMAIN_NAME}"
    
    # Probar conexión HTTPS
    curl -I "https://${REGION}.${DOMAIN_NAME}"
    
    # Probar API de Webmin
    curl -I "https://${REGION}.${DOMAIN_NAME}:10000"
    
    echo "Conectividad a ${REGION} probada"
    echo ""
done
```

#### 8.2 Ejecutar Pruebas de Failover

```bash
#!/bin/bash
# scripts/test_failover.sh

# Configuración
PRIMARY_REGION="us-east-1"
SECONDARY_REGION="us-west-2"
DOMAIN_NAME="virtualmin-pro.com"

# Detener servicio en región primaria
echo "Deteniendo servicio en ${PRIMARY_REGION}..."
aws ec2 stop-instances --region ${PRIMARY_REGION} --instance-ids $(aws ec2 describe-instances --region ${PRIMARY_REGION} --filters "Name=tag:Role,Values=web" --query "Instances[*].InstanceId" --output text)

# Esperar a que el health check falle
echo "Esperando a que el health check falle..."
sleep 120

# Probar conectividad a región secundaria
echo "Probando conectividad a ${SECONDARY_REGION}..."
curl -I "https://${DOMAIN_NAME}"

# Iniciar servicio en región primaria
echo "Iniciando servicio en ${PRIMARY_REGION}..."
aws ec2 start-instances --region ${PRIMARY_REGION} --instance-ids $(aws ec2 describe-instances --region ${PRIMARY_REGION} --filters "Name=tag:Role,Values=web" --query "Instances[*].InstanceId" --output text)

# Esperar a que el servicio esté disponible
echo "Esperando a que el servicio esté disponible..."
sleep 120

# Probar conectividad a región primaria
echo "Probando conectividad a ${PRIMARY_REGION}..."
curl -I "https://${DOMAIN_NAME}"

echo "Prueba de failover completada"
```

## 🔧 Mantenimiento y Operaciones

### Monitoreo Continuo

1. **Métricas de Rendimiento**: Monitorear latencia, tiempo de respuesta y tasa de errores por región.
2. **Métricas de Recursos**: Monitorear CPU, memoria, disco y red en todos los nodos.
3. **Métricas de Replicación**: Monitorear lag de replicación de bases de datos y almacenamiento.
4. **Alertas**: Configurar alertas para fallos de región, alta latencia y agotamiento de recursos.

### Actualizaciones y Parches

1. **Actualizaciones de Sistema**: Programar actualizaciones de sistema operativo en ventanas de mantenimiento.
2. **Actualizaciones de Aplicación**: Implementar actualizaciones de Webmin/Virtualmin de forma gradual.
3. **Parches de Seguridad**: Aplicar parches de seguridad de forma inmediata.
4. **Pruebas de Actualización**: Probar actualizaciones en entorno de pruebas antes de aplicar en producción.

### Escalado Automático

1. **Métricas de Escalado**: Configurar métricas personalizadas para escalado automático.
2. **Políticas de Escalado**: Definir políticas de escalado basadas en carga y tiempo.
3. **Pruebas de Escalado**: Realizar pruebas de escalado para validar las políticas.
4. **Optimización de Costos**: Revisar y optimizar configuraciones de escalado para minimizar costos.

## 📊 Métricas y KPIs

### Disponibilidad

- **Uptime Objetivo**: 99.9%
- **Tiempo de Recuperación Objetivo (RTO)**: 5 minutos
- **Punto de Recuperación Objetivo (RPO)**: 1 hora

### Rendimiento

- **Latencia Objetiva**: < 100ms para el 95% de las solicitudes
- **Tiempo de Respuesta Objetivo**: < 200ms para el 95% de las solicitudes
- **Tasa de Error Objetiva**: < 0.1%

### Escalabilidad

- **Capacidad de Escalado**: 1000+ nodos
- **Tiempo de Escalado**: < 5 minutos
- **Eficiencia de Escalado**: > 80%

## 🚨 Solución de Problemas

### Problemas Comunes

1. **Conectividad entre Regiones**: Verificar configuración de VPN o Direct Connect.
2. **Replicación de Datos**: Verificar configuración de replicación y lag.
3. **Balanceo de Carga**: Verificar configuración de health checks y políticas de enrutamiento.
4. **DNS Global**: Verificar configuración de registros DNS y health checks.

### Herramientas de Diagnóstico

1. **Ping y Traceroute**: Para diagnosticar problemas de conectividad.
2. **Telnet y Nc**: Para diagnosticar problemas de puertos.
3. **Logs de Aplicación**: Para diagnosticar problemas de aplicación.
4. **Métricas de Monitoreo**: Para diagnosticar problemas de rendimiento.

## 📚 Referencias y Recursos Adicionales

### Documentación Oficial

- [Terraform Documentation](https://www.terraform.io/docs/index.html)
- [Ansible Documentation](https://docs.ansible.com/ansible/latest/index.html)
- [AWS Documentation](https://docs.aws.amazon.com/index.html)
- [Virtualmin Documentation](https://www.virtualmin.com/documentation/)

### Guías y Tutoriales

- [AWS Multi-Region Deployment](https://aws.amazon.com/multi-region-deployment/)
- [Terraform Best Practices](https://www.terraform.io/docs/guides/enterprise/index.html)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

### Herramientas y Utilidades

- [Terraform Provider for AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Ansible Modules for AWS](https://docs.ansible.com/ansible/latest/collections/amazon/aws/index.html)
- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/)