# Guía de Sistema Empresarial para Datacenters

## Descripción General

Este sistema incluye una configuración completa **enterprise-grade** para servidores profesionales en datacenters, con todos los componentes necesarios para operaciones críticas de alto rendimiento.

## Arquitectura Empresarial Implementada

### 1. **Monitoreo y Observabilidad**
- **Prometheus**: Recolección de métricas en tiempo real
- **Grafana**: Dashboards y visualización avanzada
- **Node Exporter**: Métricas del sistema operativo
- **Zabbix**: Monitoreo empresarial completo
- **Nagios**: Monitoreo de red y servicios

### 2. **Logging Centralizado (ELK Stack)**
- **Elasticsearch**: Base de datos de búsqueda y análisis
- **Logstash**: Procesamiento y transformación de logs
- **Kibana**: Interfaz de visualización de logs
- **Filebeat**: Recolección de logs del sistema

### 3. **Backup Empresarial**
- **Bacula**: Sistema de backup profesional
- **Configuración automática**: Políticas de retención
- **Encriptación**: Backups seguros
- **Almacenamiento distribuido**: Múltiples destinos

### 4. **Virtualización y Contenedores**
- **Docker**: Contenedores de aplicaciones
- **Kubernetes**: Orquestación de contenedores
- **KVM/QEMU**: Virtualización completa
- **Libvirt**: Gestión de máquinas virtuales

### 5. **Redes Empresariales**
- **HAProxy**: Load balancer de alta disponibilidad
- **OpenVPN**: VPN empresarial
- **WireGuard**: VPN moderna de alto rendimiento
- **nftables**: Firewall de nueva generación

### 6. **Almacenamiento Distribuido**
- **GlusterFS**: Sistema de archivos distribuido
- **Configuración automática**: Replicación y alta disponibilidad
- **Escalabilidad**: Expansión dinámica

### 7. **Herramientas DevOps**
- **Ansible**: Automatización de configuración
- **Terraform**: Infraestructura como código
- **HashiCorp Vault**: Gestión de secretos
- **HashiCorp Consul**: Service discovery

### 8. **Seguridad Enterprise**
- **Snort**: Sistema de detección de intrusiones (IDS)
- **OSSEC**: Host-based IDS (HIDS)
- **ModSecurity**: Web Application Firewall (WAF)
- **Auditd**: Auditoría del sistema

## Instalación Automática

El sistema se instala automáticamente durante la instalación unificada:

```bash
sudo ./instalacion_unificada.sh
```

## Servicios y Puertos

### Monitoreo y Dashboards
| Servicio | Puerto | URL | Usuario/Contraseña |
|----------|--------|-----|-------------------|
| Prometheus | 9090 | http://localhost:9090 | - |
| Grafana | 3000 | http://localhost:3000 | admin/admin |
| Kibana | 5601 | http://localhost:5601 | - |
| Zabbix | 8080 | http://localhost:8080/zabbix | Admin/zabbix |
| Nagios | 80 | http://localhost/nagios | nagiosadmin/nagiosadmin |
| HAProxy Stats | 8404 | http://localhost:8404/stats | - |

### Gestión y Control
| Servicio | Puerto | Propósito |
|----------|--------|-----------|
| Docker | 2376 | API de Docker |
| Kubernetes API | 6443 | API del cluster |
| Consul | 8500 | Service discovery |
| Vault | 8200 | Gestión de secretos |
| Bacula Director | 9101 | Control de backups |

## Configuraciones de Producción

### Prometheus Configuration
```yaml
# /opt/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

### HAProxy Configuration
```haproxy
# /etc/haproxy/haproxy.cfg
frontend http_front
    bind *:80
    default_backend http_back

backend http_back
    balance roundrobin
    server web1 127.0.0.1:8080 check
    server web2 127.0.0.1:8081 check
```

### Zabbix Database Setup
```sql
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'zabbix_password';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
```

## Comandos de Gestión

### Docker y Kubernetes
```bash
# Ver estado de contenedores
docker ps -a

# Ver estado del cluster Kubernetes
kubectl get nodes
kubectl get pods --all-namespaces

# Ver servicios de Kubernetes
kubectl get services
```

### Monitoreo
```bash
# Ver métricas de Prometheus
curl http://localhost:9090/api/v1/query?query=up

# Ver estado de Zabbix
systemctl status zabbix-server

# Ver logs de Nagios
tail -f /usr/local/nagios/var/nagios.log
```

### Backup con Bacula
```bash
# Ver estado de Bacula
systemctl status bacula-director

# Ejecutar backup manual
bconsole
# Dentro de bconsole:
# run job=BackupCatalog
```

### Gestión de Secrets con Vault
```bash
# Ver estado de Vault
systemctl status vault

# Inicializar Vault (primera vez)
vault operator init

# Desbloquear Vault
vault operator unseal
```

## Configuración de Alta Disponibilidad

### Load Balancer con HAProxy
```bash
# Configurar múltiples servidores web
# Editar /etc/haproxy/haproxy.cfg
backend http_back
    balance roundrobin
    server web1 192.168.1.10:80 check
    server web2 192.168.1.11:80 check
    server web3 192.168.1.12:80 check
```

### Cluster de Elasticsearch
```yaml
# /etc/elasticsearch/elasticsearch.yml
cluster.name: datacenter-cluster
node.name: node-1
path.data: /var/lib/elasticsearch
network.host: 0.0.0.0
discovery.seed_hosts: ["192.168.1.10:9300", "192.168.1.11:9300"]
cluster.initial_master_nodes: ["node-1", "node-2"]
```

### GlusterFS Replicado
```bash
# Crear volumen replicado
gluster volume create gv0 replica 3 \
  server1:/data/brick1/gv0 \
  server2:/data/brick1/gv0 \
  server3:/data/brick1/gv0

gluster volume start gv0
```

## Monitoreo de Rendimiento

### Métricas Clave a Monitorear
- **CPU Usage**: < 80% sustained
- **Memory Usage**: < 90% sustained
- **Disk I/O**: < 1000 IOPS per disk
- **Network I/O**: < 1Gbps sustained
- **Response Time**: < 100ms for web requests
- **Error Rate**: < 1% for applications

### Alertas Recomendadas
```yaml
# Prometheus alerting rules
groups:
  - name: datacenter_alerts
    rules:
      - alert: HighCPUUsage
        expr: cpu_usage_percent > 85
        for: 5m
        labels:
          severity: warning
      - alert: HighMemoryUsage
        expr: memory_usage_percent > 90
        for: 3m
        labels:
          severity: critical
```

## Seguridad Enterprise

### Configuración de Firewall
```bash
# nftables rules
#!/usr/sbin/nft -f

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Allow loopback
        iif lo accept

        # Allow established connections
        ct state established,related accept

        # Allow SSH
        tcp dport 22 accept

        # Allow HTTP/HTTPS
        tcp dport {80, 443} accept

        # Allow monitoring ports
        tcp dport {9090, 3000, 5601, 8080} accept

        # Allow Kubernetes API
        tcp dport 6443 accept

        # Log dropped packets
        log prefix "nftables-dropped: " drop
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}
```

### Configuración de Auditd
```bash
# /etc/audit/audit.rules
# Monitor file changes
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/sudoers -p wa -k sudoers_changes

# Monitor system calls
-a always,exit -F arch=b64 -S execve -k execve_calls
-a always,exit -F arch=b32 -S execve -k execve_calls

# Monitor network activity
-a always,exit -F arch=b64 -S socket -k network_activity
```

## Backup Strategy

### Políticas de Backup
1. **Backups Diarios**: Configuración completa del sistema
2. **Backups Semanales**: Datos críticos con retención de 4 semanas
3. **Backups Mensuales**: Archivos históricos con retención de 12 meses
4. **Backups en Tiempo Real**: Logs y configuraciones críticas

### Estrategia de Recuperación
- **RTO (Recovery Time Objective)**: < 4 horas para servicios críticos
- **RPO (Recovery Point Objective)**: < 1 hora de pérdida de datos
- **Pruebas de Recuperación**: Mensuales para sistemas críticos

## Escalabilidad y Rendimiento

### Optimizaciones de Rendimiento
```bash
# Sysctl optimizations
net.core.somaxconn = 65536
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.ip_local_port_range = 1024 65535
vm.swappiness = 10
vm.dirty_ratio = 20
vm.dirty_background_ratio = 10
```

### Configuración de Kubernetes
```yaml
# High-performance cluster configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubelet-config
  namespace: kube-system
data:
  kubelet: |
    apiVersion: kubelet.config.k8s.io/v1beta1
    kind: KubeletConfiguration
    maxPods: 110
    maxOpenFiles: 1000000
    maxConcurrentRequests: 100
    serializeImagePulls: false
```

## Troubleshooting

### Problemas Comunes

#### Prometheus no recolecta métricas
```bash
# Verificar estado
systemctl status prometheus
journalctl -u prometheus -f

# Verificar configuración
promtool check config /opt/prometheus/prometheus.yml
```

#### Grafana no carga dashboards
```bash
# Reiniciar servicio
systemctl restart grafana-server

# Verificar logs
tail -f /var/log/grafana/grafana.log
```

#### Kubernetes nodes no se unen al cluster
```bash
# Verificar estado del cluster
kubectl get nodes
kubectl describe node <node-name>

# Verificar logs de kubelet
journalctl -u kubelet -f
```

#### Backup de Bacula falla
```bash
# Verificar estado de servicios
systemctl status bacula-director
systemctl status bacula-sd
systemctl status bacula-fd

# Verificar logs
tail -f /var/log/bacula/bacula.log
```

## Mantenimiento y Actualizaciones

### Actualizaciones de Seguridad
```bash
# Actualizar todos los componentes
apt-get update && apt-get upgrade -y

# Actualizar Docker
docker system prune -f

# Actualizar Kubernetes
kubeadm upgrade plan
kubeadm upgrade apply v1.28.x
```

### Monitoreo de Salud del Sistema
```bash
# Verificar todos los servicios
systemctl list-units --type=service --state=running

# Verificar uso de recursos
htop
df -h
free -h

# Verificar conectividad de red
ping -c 4 8.8.8.8
traceroute google.com
```

## Conclusión

Este sistema proporciona una plataforma **enterprise-grade** completa para datacenters profesionales, con:

- ✅ **Monitoreo 24/7** con múltiples herramientas
- ✅ **Alta disponibilidad** con load balancing y clustering
- ✅ **Seguridad enterprise** con IDS, IPS y WAF
- ✅ **Backup automatizado** con encriptación
- ✅ **Virtualización completa** con Docker y Kubernetes
- ✅ **Escalabilidad automática** con herramientas DevOps
- ✅ **Logging centralizado** con ELK Stack
- ✅ **Gestión de configuración** con Ansible y Terraform

El sistema está diseñado para operaciones críticas en entornos de producción empresarial, proporcionando todas las herramientas necesarias para gestión, monitoreo y mantenimiento de infraestructura de datacenter profesional.

---

*Documentación actualizada automáticamente con cada nueva versión del sistema enterprise.*