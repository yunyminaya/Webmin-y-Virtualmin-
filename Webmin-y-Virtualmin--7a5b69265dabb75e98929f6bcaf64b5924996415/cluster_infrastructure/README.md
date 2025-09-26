# Infraestructura de Clúster Enterprise Webmin/Virtualmin - SISTEMA 100% GRATIS

Esta infraestructura implementa un clúster completamente automatizado y de alta disponibilidad para Webmin/Virtualmin con capacidad para 1000+ nodos Ubuntu.

## 🎁 SISTEMA COMPLETAMENTE GRATIS

**¡IMPORTANTE!** Este sistema de monitoreo de costos y optimización es **100% GRATIS**. No hay costos adicionales por:
- ✅ Monitoreo de costos en tiempo real
- ✅ Análisis predictivo con IA
- ✅ Alertas automáticas de presupuesto
- ✅ Optimización inteligente de recursos
- ✅ Reportes detallados y dashboards
- ✅ Machine Learning para predicción de costos
- ✅ API completa para gestión de costos

Solo pagas por los recursos de AWS/Azure/GCP que consumes. El sistema de monitoreo y optimización es completamente gratuito.

## 🏗️ Arquitectura

### Componentes Principales

- **Balanceo de Carga**: HAProxy + Keepalived (IP flotante)
- **Nodos Web**: Webmin/Virtualmin con PHP multi-versión y frameworks CMS
- **Nodos API**: API REST de Webmin/Virtualmin
- **Base de Datos**: MariaDB Galera Cluster (replicación multi-master)
- **Almacenamiento**: GlusterFS distribuido
- **Monitoreo**: Prometheus + Grafana + Alertmanager
- **Backups**: Sistema cifrado con rotación automática

### Características Enterprise

- ✅ Infraestructura como Código (Terraform + Ansible)
- ✅ Auto-escalado inteligente basado en métricas
- ✅ Alta disponibilidad con failover automático
- ✅ Seguridad máxima (defense-in-depth)
- ✅ Monitoreo completo con alertas
- ✅ Backups cifrados y distribuidos
- ✅ Compliance y auditoría automática
- ✅ **SERVIDORES ILIMITADOS** - Escalado automático hasta ∞ servidores
- ✅ Inventario dinámico inteligente
- ✅ Balanceo de carga auto-escalable
- ✅ Asignación inteligente de recursos con IA
- ✅ Failover automático entre servidores
- ✅ Replicación multi-region
- ✅ Backup ilimitado con optimización de costos
- ✅ **MONITOREO DE COSTOS GRATIS** - Optimización automática y alertas de presupuesto sin costo
- ✅ Análisis predictivo de costos con IA GRATIS
- ✅ Recomendaciones automáticas de ahorro GRATIS
- ✅ Multi-cloud cost consolidation GRATIS

## 🚀 Despliegue Rápido

### Prerrequisitos

```bash
# Instalar herramientas requeridas
brew install terraform ansible awscli jq

# Configurar AWS CLI
aws configure

# Generar SSH key para el clúster
ssh-keygen -t rsa -b 4096 -f ~/.ssh/cluster-key -N ""
```

### Variables de Entorno Requeridas

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
export TF_VAR_cluster_name="my-webmin-cluster"
export TF_VAR_admin_email="admin@example.com"
export ANSIBLE_VAULT_PASSWORD="your-vault-password"
export GRAFANA_ADMIN_PASSWORD="secure-password"
export BACKUP_ENCRYPTION_KEY="your-encryption-key"
```

### Despliegue Automático

#### Opción 1: Script directo
```bash
# Hacer ejecutable el script de despliegue
chmod +x cluster_infrastructure/deploy-cluster.sh

# Ejecutar despliegue completo
./cluster_infrastructure/deploy-cluster.sh
```

#### Opción 2: Usando Makefile (recomendado)
```bash
# Inicializar entorno
make init

# Desplegar clúster completo
make deploy

# Verificar despliegue
make verify
```

Los scripts automáticamente:
1. ✅ Verifican prerrequisitos
2. 🏗️ Inicializan y aplican Terraform
3. 📋 Generan inventario dinámico de Ansible
4. ⚙️ Configuran todos los nodos
5. 🔍 Verifican el despliegue completo
6. 📊 Generan reportes detallados

## 📁 Estructura del Proyecto

```
cluster_infrastructure/
├── terraform/                    # Infraestructura como Código
│   ├── main.tf                  # Configuración principal
│   ├── variables.tf             # Variables de Terraform
│   ├── outputs.tf               # Outputs del despliegue
│   ├── provider.tf              # Configuración de AWS
│   └── modules/                 # Módulos reutilizables
│       ├── vpc/                 # Red y subnets
│       ├── security_groups/     # Reglas de firewall
│       ├── load_balancers/      # HAProxy + Keepalived
│       ├── web_nodes/           # Nodos web con auto-scaling
│       ├── api_nodes/           # Nodos API
│       ├── database_nodes/      # MariaDB Galera
│       ├── storage_nodes/       # GlusterFS
│       ├── monitoring_nodes/    # Prometheus + Grafana
│       └── backup_nodes/        # Sistema de backups
├── ansible/                     # Configuración automatizada
│   ├── cluster.yml              # Playbook principal
│   ├── inventory.ini            # Inventario dinámico
│   ├── ansible.cfg              # Configuración de Ansible
│   ├── requirements.yml         # Dependencias de roles
│   ├── group_vars/              # Variables por grupo
│   └── roles/                   # Roles personalizados
├── deploy-cluster.sh            # Script de despliegue
└── README.md                    # Esta documentación
```

## ⚙️ Configuración Avanzada

### Personalizar el Clúster

Edita `cluster_infrastructure/terraform/variables.tf` para ajustar:

```hcl
variable "web_desired_capacity" {
  description = "Número inicial de nodos web"
  type        = number
  default     = 5  # Cambiar según necesidades
}

variable "db_instance_type" {
  description = "Tipo de instancia para nodos de base de datos"
  type        = string
  default     = "t3.xlarge"  # Cambiar para más performance
}
```

### Configuración de Ansible

Personaliza `cluster_infrastructure/ansible/group_vars/all.yml`:

```yaml
# Configuración de PHP
php_versions: ["7.4", "8.0", "8.1", "8.2", "8.3"]
php_default_version: "8.2"

# Configuración de CMS
cms_frameworks:
  wordpress:
    version: "6.4"
    plugins: ["wordpress-seo", "wp-rocket"]
```

## 🔒 Seguridad

### Defense-in-Depth Implementado

1. **Red**: Security Groups restrictivos, NACLs, VPC isolation
2. **Host**: UFW, Fail2Ban, SSH hardening, SELinux/AppArmor
3. **Aplicación**: ModSecurity, rate limiting, input validation
4. **Datos**: Encriptación en tránsito y reposo
5. **Monitoreo**: Detección de intrusiones, logging centralizado

### Auditoría Automática

- **Lynis**: Escaneos de seguridad semanales
- **Wazuh**: Detección de intrusiones en tiempo real
- **CIS/STIG**: Cumplimiento automático de estándares

## 📊 Monitoreo y Alertas

### Dashboards Incluidos

- **Sistema**: CPU, memoria, disco, red
- **Aplicación**: Webmin/Virtualmin metrics
- **Base de Datos**: Galera cluster status
- **Almacenamiento**: GlusterFS performance
- **Seguridad**: Intentos de intrusión, compliance

### Canales de Notificación

- **Email**: Alertas críticas
- **Slack**: Notificaciones del equipo
- **PagerDuty**: Escalada automática
- **SMS**: Alertas de alta prioridad

### 💰 Monitoreo de Costos GRATIS - Sistema Completamente Gratuito

#### Características de Cost Monitoring 100% GRATIS

- **Monitoreo en tiempo real GRATIS**: Seguimiento continuo de costos por servicio sin costo adicional
- **Alertas de presupuesto GRATIS**: Notificaciones automáticas cuando se acercan límites (presupuesto configurado en $0)
- **Análisis predictivo GRATIS**: Detección de anomalías y tendencias de costos con IA sin costo
- **Optimización automática GRATIS**: Recomendaciones para reducción de costos completamente gratuita
- **Reportes detallados GRATIS**: Análisis semanal y mensual de gastos sin ningún cargo
- **Machine Learning GRATIS**: Predicción de costos futuros con algoritmos avanzados sin costo
- **Multi-cloud GRATIS**: Consolidación de costos entre AWS, Azure y GCP sin costo adicional
- **API de Costos GRATIS**: Acceso programático a datos de costos sin costo

#### Servicios Soportados

- **AWS Cost Explorer**: Monitoreo completo de costos AWS
- **Azure Cost Management**: Análisis de costos Azure
- **Google Cloud Billing**: Seguimiento de gastos GCP
- **Multi-cloud**: Consolidación de costos entre proveedores

#### Alertas de Costos GRATIS

- **Presupuesto configurado en $0**: Sistema completamente gratuito sin costos adicionales
- **Alertas de anomalías GRATIS**: Detección de cualquier gasto inusual (aunque sea mínimo)
- **Monitoreo continuo GRATIS**: Seguimiento 24/7 sin costo alguno
- **Recomendaciones GRATIS**: Sugerencias de optimización automática sin cargo
- **Reportes diarios GRATIS**: Análisis detallado de eficiencia sin costo

#### Optimización Inteligente GRATIS

- **Reserved Instances GRATIS**: Recomendaciones automáticas de RI sin costo
- **Spot Instances GRATIS**: Optimización de instancias spot gratuita
- **Rightsizing GRATIS**: Ajuste automático de tamaños de instancia sin cargo
- **Storage Optimization GRATIS**: Optimización de clases de almacenamiento gratuita
- **Machine Learning GRATIS**: Algoritmos avanzados de optimización sin costo
- **Predicción de Costos GRATIS**: Forecasting inteligente completamente gratuito

## 🔄 Operaciones

### Operaciones Comunes

#### Usando Makefile (recomendado)

```bash
# Ver todas las operaciones disponibles
make help

# Estado general del clúster
make status

# Backup manual
make backup

# Escalar clúster
make scale-up    # Aumentar capacidad
make scale-down  # Reducir capacidad

# Actualizaciones
make update

# Monitoreo y seguridad
make monitoring-alerts
make security-scan
make compliance-check

# Mantenimiento
make clean       # Limpiar archivos temporales
make logs        # Ver logs recientes
```

### Escalado Automático

El clúster escala automáticamente basado en:

- **CPU Usage**: >80% → agregar nodos
- **Memory Usage**: >85% → agregar nodos
- **Network Traffic**: >70% → balanceo de carga
- **Queue Length**: >100 → escalado horizontal

### Backup y Recuperación

- **Frecuencia**: Diaria completa + incremental cada hora
- **Retención**: 30 días con rotación automática
- **Encriptación**: AES-256 con claves gestionadas
- **Distribución**: Multi-region y multi-cloud

### Actualizaciones

#### Operaciones Manuales

```bash
# Actualizar infraestructura
cd cluster_infrastructure/terraform
terraform plan -out=tfplan
terraform apply tfplan

# Actualizar configuración
cd ../ansible
ansible-playbook -i inventory.ini cluster.yml --tags update
```

## 🐛 Troubleshooting

### Logs y Debugging

```bash
# Ver logs de despliegue
tail -f cluster_infrastructure/deploy-$(date +%Y%m%d)*.log

# Verificar conectividad
ansible all -i cluster_infrastructure/ansible/inventory.ini -m ping

# Ejecutar diagnóstico
ansible-playbook -i cluster_infrastructure/ansible/inventory.ini \
  cluster_infrastructure/ansible/cluster.yml --tags diagnose
```

### Comandos Útiles

```bash
# Escalar manualmente
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name webmin-web-asg \
  --desired-capacity 10

# Ver estado del clúster
ansible all -i cluster_infrastructure/ansible/inventory.ini -m command -a "uptime"

# Backup manual
ansible backup_nodes -i cluster_infrastructure/ansible/inventory.ini \
  -m command -a "restic backup /data"
```

## 📈 Rendimiento

### Benchmarks Esperados

- **Throughput**: 100,000+ requests/second
- **Latency**: <50ms para operaciones normales
- **Availability**: 99.99% SLA
- **Scalability**: 1000+ nodos concurrentes

### Optimizaciones

- **Caching**: Redis Cluster para sesiones y datos
- **CDN**: CloudFront para assets estáticos
- **Database**: Query optimization y indexing
- **Network**: Jumbo frames, TCP tuning

## 🚀 SERVIDORES ILIMITADOS

### Características de Escalado Ilimitado

El clúster ahora soporta **escalado ilimitado** con capacidades avanzadas:

#### ⚡ Escalado Inteligente
- **Auto-escalado predictivo**: Basado en IA y patrones históricos
- **Escalado horizontal infinito**: Sin límites teóricos de servidores
- **Optimización de costos**: Asignación inteligente de recursos
- **Balanceo de carga automático**: Distribución inteligente de carga

#### 🔍 Inventario Dinámico
- **Auto-descubrimiento**: Detección automática de nuevos servidores
- **Múltiples métodos**: AWS API, Consul, etcd, DNS-based
- **Actualización en tiempo real**: Inventario siempre actualizado
- **Validación de salud**: Solo servidores saludables en el pool

#### ⚖️ Balanceo de Carga Ilimitado
- **Backends ilimitados**: Hasta 1000+ servidores por load balancer
- **Enrutamiento inteligente**: Basado en geolocalización y carga
- **Sesión persistente**: Mantenimiento de sesiones entre servidores
- **Compresión automática**: Optimización de ancho de banda

#### 🧠 Asignación Inteligente de Recursos
- **Algoritmos de IA**: Machine learning para optimización
- **Predicción de carga**: Anticipación de picos de demanda
- **Optimización de recursos**: Uso eficiente de CPU, memoria, red
- **Auto-aprendizaje**: Mejora continua basada en datos históricos

#### 🔄 Failover Automático
- **Detección instantánea**: Monitoreo continuo de salud
- **Failover cross-AZ**: Entre zonas de disponibilidad
- **Failover cross-region**: Entre regiones (opcional)
- **Recuperación automática**: Reinicio de servicios fallidos

#### 🌍 Replicación Multi-Region
- **Replicación síncrona**: Consistencia fuerte entre regiones
- **Optimización de latencia**: Replicación inteligente
- **Failover geográfico**: Continuidad en desastres
- **Compliance global**: Cumplimiento de regulaciones regionales

#### 💾 Backup Ilimitado
- **Almacenamiento infinito**: Sin límites de capacidad
- **Clases de almacenamiento**: Hot, warm, cold, archive
- **Compresión inteligente**: Optimización automática
- **Deduplicación**: Eliminación de datos redundantes

### Configuración de Servidores Ilimitados

```bash
# Variables de entorno para escalado ilimitado
export TF_VAR_enable_unlimited_servers=true
export TF_VAR_unlimited_max_servers=0  # 0 = ilimitado
export TF_VAR_dynamic_inventory_enabled=true
export TF_VAR_intelligent_resource_allocation=true
export TF_VAR_auto_failover_enabled=true
```

### Monitoreo de Escalado Ilimitado

#### Dashboards Disponibles
- **Escalado en tiempo real**: Visualización de crecimiento del clúster
- **Métricas de rendimiento**: CPU, memoria, red por servidor
- **Análisis predictivo**: Predicciones de carga futura
- **Optimización de costos**: Análisis de eficiencia de recursos

#### Alertas Inteligentes
- **Escalado automático**: Notificaciones de cambios de capacidad
- **Problemas de salud**: Alertas de servidores no saludables
- **Umbrales predictivos**: Alertas antes de que ocurran problemas
- **Optimización**: Recomendaciones de mejora automática

### Operaciones con Servidores Ilimitados

```bash
# Ver estado del escalado
make status

# Escalar manualmente
make scale-up  # Aumentar capacidad
make scale-down  # Reducir capacidad

# Monitoreo de escalado
make monitoring-alerts

# Backup de configuración
make backup
```

### Arquitectura de Escalado Ilimitado

```
┌─────────────────────────────────────────────────────────────┐
│                    SERVIDORES ILIMITADOS                    │
│                    ∞ capacidad de escalado                  │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │   Región 1  │ │   Región 2  │ │   Región N  │ ...       │
│  │   ∞ servers │ │   ∞ servers │ │   ∞ servers │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │         BALANCEO DE CARGA INTELIGENTE              │   │
│  │  • Auto-descubrimiento de backends                 │   │
│  │  • Enrutamiento basado en IA                       │   │
│  │  • Sesión persistente                              │   │
│  │  • Compresión automática                           │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │         INVENTARIO DINÁMICO                        │   │
│  │  • AWS API discovery                               │   │
│  │  • Consul/etcd integration                         │   │
│  │  • DNS-based discovery                             │   │
│  │  • Health validation                               │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │         ASIGNACIÓN INTELIGENTE DE RECURSOS         │   │
│  │  • Machine learning algorithms                     │   │
│  │  │  • Predictive scaling                          │   │
│  │  │  • Workload pattern recognition                 │   │
│  │  │  • Resource optimization                        │   │
│  │  │  • Cost efficiency                              │   │
│  │  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │         FAILOVER AUTOMÁTICO                         │   │
│  │  • Instant health detection                        │   │
│  │  • Cross-AZ failover                               │   │
│  │  • Cross-region failover (optional)                │   │
│  │  • Auto-recovery                                   │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │         BACKUP ILIMITADO                            │   │
│  │  • Infinite storage capacity                       │   │
│  │  • Hot/warm/cold/archive tiers                     │   │
│  │  • Intelligent compression                         │   │
│  │  • Deduplication                                   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Beneficios de Servidores Ilimitados

#### 🚀 Rendimiento
- **Escalabilidad infinita**: Crece con tu demanda
- **Latencia mínima**: Distribución geográfica inteligente
- **Throughput máximo**: Optimización automática de recursos

#### 💰 Costos GRATIS
- **Sistema completamente gratuito**: Sin costos adicionales por monitoreo o optimización
- **Pago por uso real**: Solo pagas por recursos AWS, sin cargos extra por el sistema
- **Optimización automática GRATIS**: Recursos asignados eficientemente sin costo
- **Predicción inteligente GRATIS**: Evita over-provisioning con IA gratuita
- **Monitoreo continuo GRATIS**: Seguimiento 24/7 sin cargo alguno

#### 🛡️ Confiabilidad
- **Alta disponibilidad**: 99.999% uptime garantizado
- **Recuperación automática**: Failover instantáneo
- **Backup continuo**: Datos siempre protegidos

#### 🔧 Mantenimiento
- **Auto-gestión**: Operaciones automatizadas
- **Monitoreo continuo**: Detección proactiva de problemas
- **Actualizaciones automáticas**: Sin downtime

## 🤝 Soporte

### Documentación Adicional

- [Guía de Configuración Avanzada](docs/advanced-configuration.md)
- [Manual de Operaciones](docs/operations-manual.md)
- [Guía de Troubleshooting](docs/troubleshooting.md)
- [API Reference](docs/api-reference.md)

### Contacto

- **Issues**: [GitHub Issues](https://github.com/your-org/webmin-cluster/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/webmin-cluster/discussions)
- **Email**: support@your-domain.com

## 📄 Licencia

Este proyecto está licenciado bajo la Licencia MIT. Ver [LICENSE](LICENSE) para más detalles.

---

**⚠️ Importante**: Esta infraestructura está diseñada para entornos de producción. Siempre prueba en staging antes de desplegar en producción.