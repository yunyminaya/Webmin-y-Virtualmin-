#!/bin/bash

# 🌍 **Script de Configuración de Despliegue Multi-Región para Virtualmin Pro**
#
# Este script configura enrutamiento geográfico inteligente, implementa
# replicación global de datos, configura disaster recovery con failover
# regional, implementa cumplimiento normativo localizado y configura
# monitoreo de latencia entre regiones.

set -euo pipefail

# 📋 **Variables de configuración**
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"
CONFIG_DIR="${PROJECT_ROOT}/config/multi-region-deployment"
LOG_FILE="${PROJECT_ROOT}/logs/multi_region_deployment_setup.log"

# Crear directorios necesarios
mkdir -p "${CONFIG_DIR}" "$(dirname "${LOG_FILE}")"

# Variables de configuración
PRIMARY_REGION="us-east-1"
SECONDARY_REGION="us-west-2"
TERTIARY_REGION="eu-west-1"
PRIMARY_DOMAIN="virtualmin.local"
PRIMARY_IP="192.168.1.10"
SECONDARY_IP="192.168.2.10"
TERTIARY_IP="192.168.3.10"
DNS_PROVIDER="cloudflare"  # cloudflare, route53, bind
CDN_PROVIDER="cloudflare"  # cloudflare, cloudfront
DATABASE_TYPE="mysql"  # mysql, postgresql, mongodb
REPLICATION_TYPE="async"  # async, sync
HEALTH_CHECK_INTERVAL="30"
HEALTH_CHECK_TIMEOUT="10"
HEALTH_CHECK_PATH="/health"

# 🎨 **Colores para salida en consola**
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 📝 **Funciones de logging**
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "${LOG_FILE}"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "${LOG_FILE}"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "${LOG_FILE}"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "${LOG_FILE}"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${LOG_FILE}"
}

# 🔍 **Función para verificar dependencias**
check_dependencies() {
    log "🔍 Verificando dependencias"
    
    local missing_deps=()
    
    # Verificar comandos necesarios
    for cmd in curl jq python3 pip3 dig nslookup traceroute; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Instalar dependencias faltantes
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "📦 Instalando dependencias faltantes: ${missing_deps[*]}"
        
        # Detectar el gestor de paquetes
        if command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y curl jq python3 python3-pip dnsutils traceroute cloudflared awscli
            
        elif command -v yum &> /dev/null; then
            yum install -y curl jq python3 python3-pip bind-utils traceroute cloudflared awscli
            
        elif command -v dnf &> /dev/null; then
            dnf install -y curl jq python3 python3-pip bind-utils traceroute cloudflared awscli
        else
            error "❌ Gestor de paquetes no compatible. Por favor, instala manualmente: ${missing_deps[*]}"
            exit 1
        fi
    fi
    
    # Instalar dependencias de Python
    pip3 install requests boto3 pyyaml dnspython cloudflare
    
    success "✅ Dependencias verificadas"
}

# 🌐 **Función para configurar enrutamiento geográfico inteligente**
setup_geo_routing() {
    log "🌐 Configurando enrutamiento geográfico inteligente"
    
    # Crear directorio de configuración si no existe
    mkdir -p "${CONFIG_DIR}/geo-routing"
    
    # Crear script de gestión de enrutamiento geográfico
    local geo_routing_script="${CONFIG_DIR}/geo-routing/geo_routing_manager.py"
    
    cat > "${geo_routing_script}" << 'EOF'
#!/usr/bin/env python3
"""
Script de Gestión de Enrutamiento Geográfico para Virtualmin Pro
"""

import os
import sys
import json
import time
import logging
import argparse
import subprocess
import requests
import socket
import geoip2.database
import geoip2.errors
from datetime import datetime, timedelta
import threading
import queue

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileWriter('/var/log/geo_routing_manager.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

class GeoRoutingManager:
    def __init__(self, config_file=None):
        """
        Inicializa el gestor de enrutamiento geográfico
        
        Args:
            config_file: Ruta al archivo de configuración
        """
        self.config = self.load_config(config_file)
        self.dns_provider = self.config.get('dns_provider', 'cloudflare')
        self.cdn_provider = self.config.get('cdn_provider', 'cloudflare')
        self.primary_region = self.config.get('primary_region')
        self.secondary_region = self.config.get('secondary_region')
        self.tertiary_region = self.config.get('tertiary_region')
        self.primary_domain = self.config.get('primary_domain')
        self.regions = self.config.get('regions', {})
        
        # Inicializar clientes DNS y CDN
        self.init_dns_client()
        self.init_cdn_client()
        
        # Inicializar base de datos GeoIP
        self.init_geoip_db()
        
        # Iniciar monitoreo de salud regional
        self.init_health_monitoring()
    
    def load_config(self, config_file):
        """
        Carga configuración desde archivo
        
        Args:
            config_file: Ruta al archivo de configuración
            
        Returns:
            Diccionario con configuración
        """
        default_config = {
            'dns_provider': 'cloudflare',
            'cdn_provider': 'cloudflare',
            'primary_region': 'us-east-1',
            'secondary_region': 'us-west-2',
            'tertiary_region': 'eu-west-1',
            'primary_domain': 'virtualmin.local',
            'health_check_interval': 30,
            'health_check_timeout': 10,
            'health_check_path': '/health',
            'failover_threshold': 2,
            'regions': {
                'us-east-1': {
                    'name': 'US East',
                    'ip': '192.168.1.10',
                    'enabled': True,
                    'priority': 1,
                    'weight': 100,
                    'health_check_url': 'http://192.168.1.10/health'
                },
                'us-west-2': {
                    'name': 'US West',
                    'ip': '192.168.2.10',
                    'enabled': True,
                    'priority': 2,
                    'weight': 80,
                    'health_check_url': 'http://192.168.2.10/health'
                },
                'eu-west-1': {
                    'name': 'Europe West',
                    'ip': '192.168.3.10',
                    'enabled': True,
                    'priority': 3,
                    'weight': 60,
                    'health_check_url': 'http://192.168.3.10/health'
                }
            }
        }
        
        if config_file and os.path.exists(config_file):
            with open(config_file, 'r') as f:
                config = json.load(f)
                default_config.update(config)
        
        return default_config
    
    def init_dns_client(self):
        """Inicializa cliente DNS"""
        if self.dns_provider == 'cloudflare':
            self.init_cloudflare_dns()
        elif self.dns_provider == 'route53':
            self.init_route53_dns()
        elif self.dns_provider == 'bind':
            self.init_bind_dns()
    
    def init_cloudflare_dns(self):
        """Inicializa cliente de CloudFlare DNS"""
        self.cloudflare_api_token = self.config.get('cloudflare', {}).get('api_token')
        self.cloudflare_zone_id = self.config.get('cloudflare', {}).get('zone_id')
        
        if not self.cloudflare_api_token:
            logger.error("Token de API de CloudFlare no configurado")
            return
        
        self.cloudflare_headers = {
            'Authorization': f'Bearer {self.cloudflare_api_token}',
            'Content-Type': 'application/json'
        }
        
        self.cloudflare_base_url = 'https://api.cloudflare.com/client/v4'
    
    def init_route53_dns(self):
        """Inicializa cliente de Route53 DNS"""
        self.route53_hosted_zone_id = self.config.get('route53', {}).get('hosted_zone_id')
        self.route53_access_key = self.config.get('route53', {}).get('access_key')
        self.route53_secret_key = self.config.get('route53', {}).get('secret_key')
        self.route53_region = self.config.get('route53', {}).get('region', 'us-east-1')
        
        if not all([self.route53_hosted_zone_id, self.route53_access_key, self.route53_secret_key]):
            logger.error("Credenciales de Route53 no configuradas")
            return
        
        # Inicializar cliente de AWS
        try:
            import boto3
            self.route53_client = boto3.client(
                'route53',
                aws_access_key_id=self.route53_access_key,
                aws_secret_access_key=self.route53_secret_key,
                region_name=self.route53_region
            )
        except ImportError:
            logger.error("boto3 no instalado. Instale con: pip install boto3")
            return
    
    def init_bind_dns(self):
        """Inicializa cliente de BIND DNS"""
        self.bind_config_file = self.config.get('bind', {}).get('config_file', '/etc/bind/named.conf.local')
        self.bind_zone_file = self.config.get('bind', {}).get('zone_file', '/etc/bind/db.virtualmin.local')
        
        if not os.path.exists(self.bind_config_file):
            logger.warning(f"Archivo de configuración BIND no encontrado: {self.bind_config_file}")
    
    def init_cdn_client(self):
        """Inicializa cliente CDN"""
        if self.cdn_provider == 'cloudflare':
            self.init_cloudflare_cdn()
        elif self.cdn_provider == 'cloudfront':
            self.init_cloudfront_cdn()
    
    def init_cloudflare_cdn(self):
        """Inicializa cliente de CloudFlare CDN"""
        if self.dns_provider == 'cloudflare':
            # Reutilizar cliente de CloudFlare DNS
            return
        
        self.cdn_cloudflare_api_token = self.config.get('cdn_cloudflare', {}).get('api_token')
        self.cdn_cloudflare_zone_id = self.config.get('cdn_cloudflare', {}).get('zone_id')
        
        if not self.cdn_cloudflare_api_token:
            logger.error("Token de API de CloudFlare CDN no configurado")
            return
        
        self.cdn_cloudflare_headers = {
            'Authorization': f'Bearer {self.cdn_cloudflare_api_token}',
            'Content-Type': 'application/json'
        }
        
        self.cdn_cloudflare_base_url = 'https://api.cloudflare.com/client/v4'
    
    def init_cloudfront_cdn(self):
        """Inicializa cliente de CloudFront CDN"""
        self.cloudfront_distribution_id = self.config.get('cloudfront', {}).get('distribution_id')
        self.cloudfront_access_key = self.config.get('cloudfront', {}).get('access_key')
        self.cloudfront_secret_key = self.config.get('cloudfront', {}).get('secret_key')
        self.cloudfront_region = self.config.get('cloudfront', {}).get('region', 'us-east-1')
        
        if not all([self.cloudfront_distribution_id, self.cloudfront_access_key, self.cloudfront_secret_key]):
            logger.error("Credenciales de CloudFront no configuradas")
            return
        
        # Inicializar cliente de AWS
        try:
            import boto3
            self.cloudfront_client = boto3.client(
                'cloudfront',
                aws_access_key_id=self.cloudfront_access_key,
                aws_secret_access_key=self.cloudfront_secret_key,
                region_name=self.cloudfront_region
            )
        except ImportError:
            logger.error("boto3 no instalado. Instale con: pip install boto3")
            return
    
    def init_geoip_db(self):
        """Inicializa base de datos GeoIP"""
        self.geoip_db_path = self.config.get('geoip_db_path', '/usr/share/GeoIP/GeoLite2-City.mmdb')
        
        if not os.path.exists(self.geoip_db_path):
            logger.warning(f"Base de datos GeoIP no encontrada: {self.geoip_db_path}")
            self.geoip_reader = None
            return
        
        try:
            self.geoip_reader = geoip2.database.Reader(self.geoip_db_path)
            logger.info("Base de datos GeoIP inicializada")
        except Exception as e:
            logger.error(f"Error al inicializar base de datos GeoIP: {e}")
            self.geoip_reader = None
    
    def init_health_monitoring(self):
        """Inicializa monitoreo de salud regional"""
        self.health_status = {}
        
        # Inicializar estado de salud para cada región
        for region_name, region_config in self.regions.items():
            self.health_status[region_name] = {
                'healthy': True,
                'failures': 0,
                'last_check': None,
                'response_time': 0
            }
        
        # Iniciar hilo de monitoreo de salud
        import threading
        
        def health_monitor_worker():
            while True:
                try:
                    self.check_all_regions_health()
                    time.sleep(self.config.get('health_check_interval', 30))
                except Exception as e:
                    logger.error(f"Error en el monitoreo de salud: {e}")
                    time.sleep(60)
        
        self.health_monitor_thread = threading.Thread(target=health_monitor_worker, daemon=True)
        self.health_monitor_thread.start()
        
        logger.info("Monitoreo de salud regional iniciado")
    
    def check_all_regions_health(self):
        """
        Verifica el estado de salud de todas las regiones
        
        Returns:
            Diccionario con estado de salud de las regiones
        """
        results = {}
        
        for region_name, region_config in self.regions.items():
            if not region_config.get('enabled', True):
                continue
            
            health_check_url = region_config.get('health_check_url')
            
            if not health_check_url:
                continue
            
            try:
                # Realizar verificación de salud
                start_time = time.time()
                response = requests.get(
                    health_check_url,
                    timeout=self.config.get('health_check_timeout', 10)
                )
                response_time = (time.time() - start_time) * 1000  # Convertir a ms
                
                # Actualizar estado de salud
                if response.status_code == 200:
                    self.health_status[region_name]['healthy'] = True
                    self.health_status[region_name]['failures'] = 0
                    self.health_status[region_name]['last_check'] = datetime.now().isoformat()
                    self.health_status[region_name]['response_time'] = response_time
                    
                    results[region_name] = {
                        'healthy': True,
                        'response_time': response_time
                    }
                else:
                    self.health_status[region_name]['healthy'] = False
                    self.health_status[region_name]['failures'] += 1
                    self.health_status[region_name]['last_check'] = datetime.now().isoformat()
                    self.health_status[region_name]['response_time'] = response_time
                    
                    results[region_name] = {
                        'healthy': False,
                        'response_time': response_time,
                        'status_code': response.status_code
                    }
            except Exception as e:
                self.health_status[region_name]['healthy'] = False
                self.health_status[region_name]['failures'] += 1
                self.health_status[region_name]['last_check'] = datetime.now().isoformat()
                self.health_status[region_name]['response_time'] = 0
                
                results[region_name] = {
                    'healthy': False,
                    'error': str(e)
                }
                
                logger.error(f"Error al verificar salud de {region_name}: {e}")
        
        return results
    
    def get_optimal_region(self, client_ip=None, country_code=None):
        """
        Obtiene la región óptima para un cliente
        
        Args:
            client_ip: IP del cliente (opcional)
            country_code: Código de país del cliente (opcional)
            
        Returns:
            Nombre de la región óptima
        """
        # Si se proporciona una IP, determinar país
        if client_ip and not country_code:
            country_code = self.get_country_from_ip(client_ip)
        
        # Si se proporciona un país, determinar región óptima
        if country_code:
            optimal_region = self.get_optimal_region_for_country(country_code)
            
            if optimal_region and self.health_status.get(optimal_region, {}).get('healthy', False):
                return optimal_region
        
        # Si no se puede determinar una región óptima, usar la región primaria saludable
        if self.health_status.get(self.primary_region, {}).get('healthy', False):
            return self.primary_region
        
        # Si la región primaria no está saludable, usar la secundaria
        if self.health_status.get(self.secondary_region, {}).get('healthy', False):
            return self.secondary_region
        
        # Si la región secundaria no está saludable, usar la terciaria
        if self.health_status.get(self.tertiary_region, {}).get('healthy', False):
            return self.tertiary_region
        
        # Si ninguna región está saludable, usar la primaria
        return self.primary_region
    
    def get_country_from_ip(self, ip):
        """
        Obtiene el país a partir de una IP
        
        Args:
            ip: IP del cliente
            
        Returns:
            Código de país
        """
        if not self.geoip_reader:
            return None
        
        try:
            response = self.geoip_reader.city(ip)
            return response.country.iso_code
        except (geoip2.errors.AddressNotFoundError, ValueError, socket.error):
            return None
    
    def get_optimal_region_for_country(self, country_code):
        """
        Obtiene la región óptima para un país
        
        Args:
            country_code: Código de país
            
        Returns:
            Nombre de la región óptima
        """
        # Mapeo de países a regiones
        country_to_region = {
            # América del Norte
            'US': self.primary_region,      # Estados Unidos
            'CA': self.primary_region,      # Canadá
            'MX': self.primary_region,      # México
            
            # América del Sur
            'BR': self.primary_region,      # Brasil
            'AR': self.primary_region,      # Argentina
            'CL': self.primary_region,      # Chile
            'CO': self.primary_region,      # Colombia
            'PE': self.primary_region,      # Perú
            'VE': self.primary_region,      # Venezuela
            
            # Europa
            'GB': self.tertiary_region,    # Reino Unido
            'DE': self.tertiary_region,    # Alemania
            'FR': self.tertiary_region,    # Francia
            'IT': self.tertiary_region,    # Italia
            'ES': self.tertiary_region,    # España
            'NL': self.tertiary_region,    # Países Bajos
            'BE': self.tertiary_region,    # Bélgica
            'AT': self.tertiary_region,    # Austria
            'CH': self.tertiary_region,    # Suiza
            'SE': self.tertiary_region,    # Suecia
            'NO': self.tertiary_region,    # Noruega
            'DK': self.tertiary_region,    # Dinamarca
            'FI': self.tertiary_region,    # Finlandia
            'PL': self.tertiary_region,    # Polonia
            'CZ': self.tertiary_region,    # República Checa
            'IE': self.tertiary_region,    # Irlanda
            'PT': self.tertiary_region,    # Portugal
            'GR': self.tertiary_region,    # Grecia
            'RU': self.tertiary_region,    # Rusia
            
            # Asia
            'CN': self.secondary_region,    # China
            'JP': self.secondary_region,    # Japón
            'KR': self.secondary_region,    # Corea del Sur
            'IN': self.secondary_region,    # India
            'SG': self.secondary_region,    # Singapur
            'TH': self.secondary_region,    # Tailandia
            'MY': self.secondary_region,    # Malasia
            'ID': self.secondary_region,    # Indonesia
            'PH': self.secondary_region,    # Filipinas
            'VN': self.secondary_region,    # Vietnam
            'HK': self.secondary_region,    # Hong Kong
            'TW': self.secondary_region,    # Taiwán
            
            # Oceanía
            'AU': self.secondary_region,    # Australia
            'NZ': self.secondary_region,    # Nueva Zelanda
            
            # África
            'ZA': self.tertiary_region,    # Sudáfrica
            'EG': self.tertiary_region,    # Egipto
            'NG': self.tertiary_region,    # Nigeria
            'KE': self.tertiary_region,    # Kenia
            'MA': self.tertiary_region,    # Marruecos
            
            # Medio Oriente
            'IL': self.tertiary_region,    # Israel
            'SA': self.tertiary_region,    # Arabia Saudita
            'AE': self.tertiary_region,    # Emiratos Árabes Unidos
            'TR': self.tertiary_region,    # Turquía
            'IR': self.tertiary_region,    # Irán
        }
        
        return country_to_region.get(country_code)
    
    def update_dns_records(self):
        """
        Actualiza registros DNS para enrutamiento geográfico
        
        Returns:
            Diccionario con resultado de la actualización
        """
        if self.dns_provider == 'cloudflare':
            return self.update_cloudflare_dns_records()
        elif self.dns_provider == 'route53':
            return self.update_route53_dns_records()
        elif self.dns_provider == 'bind':
            return self.update_bind_dns_records()
        
        return {
            'status': 'error',
            'message': f'Proveedor DNS {self.dns_provider} no soportado'
        }
    
    def update_cloudflare_dns_records(self):
        """
        Actualiza registros DNS de CloudFlare para enrutamiento geográfico
        
        Returns:
            Diccionario con resultado de la actualización
        """
        try:
            # Obtener registros DNS existentes
            url = f'{self.cloudflare_base_url}/zones/{self.cloudflare_zone_id}/dns_records'
            
            response = requests.get(
                url,
                headers=self.cloudflare_headers
            )
            
            if response.status_code != 200:
                return {
                    'status': 'error',
                    'message': f'Error al obtener registros DNS: {response.status_code}'
                }
            
            records = response.json().get('result', [])
            
            # Buscar registros A existentes
            a_records = [record for record in records if record['type'] == 'A' and record['name'] == self.primary_domain]
            
            # Crear registros DNS para cada región saludable
            results = {}
            
            for region_name, region_config in self.regions.items():
                if not region_config.get('enabled', True):
                    continue
                
                if not self.health_status.get(region_name, {}).get('healthy', False):
                    continue
                
                ip = region_config.get('ip')
                if not ip:
                    continue
                
                # Crear nombre de subdominio para la región
                subdomain = f"{region_name}.{self.primary_domain}"
                
                # Buscar registro A existente para la región
                existing_record = None
                for record in a_records:
                    if record['name'] == subdomain:
                        existing_record = record
                        break
                
                if existing_record:
                    # Actualizar registro existente
                    url = f'{self.cloudflare_base_url}/zones/{self.cloudflare_zone_id}/dns_records/{existing_record["id"]}'
                    
                    data = {
                        'type': 'A',
                        'name': subdomain,
                        'content': ip,
                        'ttl': 300
                    }
                    
                    response = requests.put(
                        url,
                        headers=self.cloudflare_headers,
                        json=data
                    )
                    
                    results[region_name] = {
                        'status': response.status_code == 200,
                        'action': 'updated',
                        'subdomain': subdomain,
                        'ip': ip
                    }
                else:
                    # Crear nuevo registro
                    url = f'{self.cloudflare_base_url}/zones/{self.cloudflare_zone_id}/dns_records'
                    
                    data = {
                        'type': 'A',
                        'name': subdomain,
                        'content': ip,
                        'ttl': 300
                    }
                    
                    response = requests.post(
                        url,
                        headers=self.cloudflare_headers,
                        json=data
                    )
                    
                    results[region_name] = {
                        'status': response.status_code == 201,
                        'action': 'created',
                        'subdomain': subdomain,
                        'ip': ip
                    }
            
            return {
                'status': 'success',
                'message': 'Registros DNS de CloudFlare actualizados',
                'results': results
            }
        except Exception as e:
            logger.error(f"Error al actualizar registros DNS de CloudFlare: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al actualizar registros DNS de CloudFlare: {e}'
            }
    
    def update_route53_dns_records(self):
        """
        Actualiza registros DNS de Route53 para enrutamiento geográfico
        
        Returns:
            Diccionario con resultado de la actualización
        """
        try:
            # Crear registros DNS para cada región saludable
            results = {}
            
            for region_name, region_config in self.regions.items():
                if not region_config.get('enabled', True):
                    continue
                
                if not self.health_status.get(region_name, {}).get('healthy', False):
                    continue
                
                ip = region_config.get('ip')
                if not ip:
                    continue
                
                # Crear nombre de subdominio para la región
                subdomain = f"{region_name}.{self.primary_domain}"
                
                # Crear conjunto de cambios
                change_batch = {
                    'Comment': f'Update {subdomain} for {region_name}',
                    'Changes': [
                        {
                            'Action': 'UPSERT',
                            'ResourceRecordSet': {
                                'Name': subdomain,
                                'Type': 'A',
                                'TTL': 300,
                                'ResourceRecords': [
                                    {
                                        'Value': ip
                                    }
                                ]
                            }
                        }
                    ]
                }
                
                # Aplicar cambios
                response = self.route53_client.change_resource_record_sets(
                    HostedZoneId=self.route53_hosted_zone_id,
                    ChangeBatch=change_batch
                )
                
                results[region_name] = {
                    'status': response['ChangeInfo']['Status'] == 'PENDING',
                    'action': 'upserted',
                    'subdomain': subdomain,
                    'ip': ip,
                    'change_id': response['ChangeInfo']['Id']
                }
            
            return {
                'status': 'success',
                'message': 'Registros DNS de Route53 actualizados',
                'results': results
            }
        except Exception as e:
            logger.error(f"Error al actualizar registros DNS de Route53: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al actualizar registros DNS de Route53: {e}'
            }
    
    def update_bind_dns_records(self):
        """
        Actualiza registros DNS de BIND para enrutamiento geográfico
        
        Returns:
            Diccionario con resultado de la actualización
        """
        try:
            # Leer archivo de zona existente
            with open(self.bind_zone_file, 'r') as f:
                zone_content = f.read()
            
            # Crear registros DNS para cada región saludable
            new_records = []
            
            for region_name, region_config in self.regions.items():
                if not region_config.get('enabled', True):
                    continue
                
                if not self.health_status.get(region_name, {}).get('healthy', False):
                    continue
                
                ip = region_config.get('ip')
                if not ip:
                    continue
                
                # Crear nombre de subdominio para la región
                subdomain = f"{region_name}.{self.primary_domain}"
                
                # Crear registro A
                record = f"{subdomain}. IN A {ip}"
                new_records.append(record)
            
            # Actualizar archivo de zona
            # Buscar sección de registros A
            pattern = r'^; A Records for Geo-routing.*$(.*?); End of A Records for Geo-routing'
            replacement = f'; A Records for Geo-routing\n' + '\n'.join(new_records) + '\n; End of A Records for Geo-routing'
            
            # Reemplazar sección de registros A
            import re
            updated_zone_content = re.sub(pattern, replacement, zone_content, flags=re.MULTILINE | re.DOTALL)
            
            # Si no se encontró la sección, agregarla al final
            if updated_zone_content == zone_content:
                updated_zone_content += f'\n; A Records for Geo-routing\n' + '\n'.join(new_records) + '\n; End of A Records for Geo-routing\n'
            
            # Escribir archivo de zona actualizado
            with open(self.bind_zone_file, 'w') as f:
                f.write(updated_zone_content)
            
            # Recargar BIND
            subprocess.run(['systemctl', 'reload', 'named'], check=True)
            
            return {
                'status': 'success',
                'message': 'Registros DNS de BIND actualizados',
                'records': new_records
            }
        except Exception as e:
            logger.error(f"Error al actualizar registros DNS de BIND: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al actualizar registros DNS de BIND: {e}'
            }
    
    def update_cdn_configuration(self):
        """
        Actualiza configuración CDN para enrutamiento geográfico
        
        Returns:
            Diccionario con resultado de la actualización
        """
        if self.cdn_provider == 'cloudflare':
            return self.update_cloudflare_cdn_configuration()
        elif self.cdn_provider == 'cloudfront':
            return self.update_cloudfront_cdn_configuration()
        
        return {
            'status': 'error',
            'message': f'Proveedor CDN {self.cdn_provider} no soportado'
        }
    
    def update_cloudflare_cdn_configuration(self):
        """
        Actualiza configuración de CloudFlare CDN para enrutamiento geográfico
        
        Returns:
            Diccionario con resultado de la actualización
        """
        try:
            # Obtener configuración de CDN existente
            url = f'{self.cloudflare_base_url}/zones/{self.cloudflare_zone_id}/settings/geoip'
            
            response = requests.get(
                url,
                headers=self.cloudflare_headers
            )
            
            if response.status_code != 200:
                return {
                    'status': 'error',
                    'message': f'Error al obtener configuración de CDN: {response.status_code}'
                }
            
            # Habilitar GeoIP
            url = f'{self.cloudflare_base_url}/zones/{self.cloudflare_zone_id}/settings/geoip'
            
            data = {
                'value': 'on'
            }
            
            response = requests.patch(
                url,
                headers=self.cloudflare_headers,
                json=data
            )
            
            if response.status_code != 200:
                return {
                    'status': 'error',
                    'message': f'Error al habilitar GeoIP: {response.status_code}'
                }
            
            # Obtener reglas de Page Rules existentes
            url = f'{self.cloudflare_base_url}/zones/{self.cloudflare_zone_id}/pagerules'
            
            response = requests.get(
                url,
                headers=self.cloudflare_headers
            )
            
            if response.status_code != 200:
                return {
                    'status': 'error',
                    'message': f'Error al obtener Page Rules: {response.status_code}'
                }
            
            page_rules = response.json().get('result', [])
            
            # Buscar regla de Page Rule para enrutamiento geográfico
            geo_rule = None
            for rule in page_rules:
                if 'geo-routing' in rule.get('targets', [{}])[0].get('constraint', {}).get('value', ''):
                    geo_rule = rule
                    break
            
            # Crear o actualizar regla de Page Rule para enrutamiento geográfico
            if geo_rule:
                # Actualizar regla existente
                url = f'{self.cloudflare_base_url}/zones/{self.cloudflare_zone_id}/pagerules/{geo_rule["id"]}'
                
                data = {
                    'targets': [
                        {
                            'target': 'url',
                            'constraint': {
                                'operator': 'matches',
                                'value': f'*.{self.primary_domain}/*'
                            }
                        }
                    ],
                    'actions': [
                        {
                            'id': 'forwarding_url',
                            'value': {
                                'url': 'https://$country_code.$host$request_uri',
                                'status_code': 302
                            }
                        }
                    ],
                    'status': 'active',
                    'priority': 1
                }
                
                response = requests.put(
                    url,
                    headers=self.cloudflare_headers,
                    json=data
                )
                
                action = 'updated'
            else:
                # Crear nueva regla
                url = f'{self.cloudflare_base_url}/zones/{self.cloudflare_zone_id}/pagerules'
                
                data = {
                    'targets': [
                        {
                            'target': 'url',
                            'constraint': {
                                'operator': 'matches',
                                'value': f'*.{self.primary_domain}/*'
                            }
                        }
                    ],
                    'actions': [
                        {
                            'id': 'forwarding_url',
                            'value': {
                                'url': 'https://$country_code.$host$request_uri',
                                'status_code': 302
                            }
                        }
                    ],
                    'status': 'active',
                    'priority': 1
                }
                
                response = requests.post(
                    url,
                    headers=self.cloudflare_headers,
                    json=data
                )
                
                action = 'created'
            
            return {
                'status': response.status_code in [200, 201],
                'message': f'Configuración de CloudFlare CDN {action}',
                'action': action
            }
        except Exception as e:
            logger.error(f"Error al actualizar configuración de CloudFlare CDN: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al actualizar configuración de CloudFlare CDN: {e}'
            }
    
    def update_cloudfront_cdn_configuration(self):
        """
        Actualiza configuración de CloudFront CDN para enrutamiento geográfico
        
        Returns:
            Diccionario con resultado de la actualización
        """
        try:
            # Obtener configuración de distribución existente
            response = self.cloudfront_client.get_distribution(
                Id=self.cloudfront_distribution_id
            )
            
            distribution = response['Distribution']
            etag = response['ETag']
            
            # Actualizar configuración de distribución
            config = distribution['DistributionConfig']
            
            # Habilitar GeoIP
            config['GeoRestriction'] = {
                'RestrictionType': 'none',
                'Quantity': 0,
                'Items': []
            }
            
            # Configurar cache behavior para enrutamiento geográfico
            for cache_behavior in config['CacheBehaviors']['Items']:
                if 'geo-routing' in cache_behavior['PathPattern']:
                    # Actualizar cache behavior existente
                    cache_behavior['ForwardedValues'] = {
                        'QueryString': True,
                        'Cookies': {
                            'Forward': 'none'
                        },
                        'Headers': [
                            'CloudFront-Viewer-Country',
                            'CloudFront-Is-Mobile-Viewer',
                            'CloudFront-Is-Tablet-Viewer'
                        ],
                        'QueryStringBlacklist': [],
                        'QueryStringWhitelist': []
                    }
                    
                    cache_behavior['TrustedSigners'] = {
                        'Enabled': False,
                        'Quantity': 0,
                        'Items': []
                    }
                    
                    cache_behavior['ViewerProtocolPolicy'] = 'redirect-to-https'
            
            # Actualizar distribución
            response = self.cloudfront_client.update_distribution(
                Id=self.cloudfront_distribution_id,
                DistributionConfig=config,
                IfMatch=etag
            )
            
            return {
                'status': True,
                'message': 'Configuración de CloudFront CDN actualizada',
                'distribution_id': self.cloudfront_distribution_id
            }
        except Exception as e:
            logger.error(f"Error al actualizar configuración de CloudFront CDN: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al actualizar configuración de CloudFront CDN: {e}'
            }
    
    def get_health_status(self):
        """
        Obtiene el estado de salud de todas las regiones
        
        Returns:
            Diccionario con estado de salud de las regiones
        """
        return self.health_status

def main():
    """Función principal"""
    parser = argparse.ArgumentParser(description='Gestión de Enrutamiento Geográfico')
    parser.add_argument('--config', help='Ruta al archivo de configuración')
    parser.add_argument('--action', choices=['health', 'routing', 'dns', 'cdn'],
                       default='health', help='Acción a realizar')
    parser.add_argument('--ip', help='IP del cliente')
    parser.add_argument('--country', help='Código de país del cliente')
    
    args = parser.parse_args()
    
    # Inicializar gestor de enrutamiento geográfico
    geo_routing = GeoRoutingManager(args.config)
    
    if args.action == 'health':
        result = geo_routing.check_all_regions_health()
        print(json.dumps(result, indent=2))
        
    elif args.action == 'routing':
        optimal_region = geo_routing.get_optimal_region(args.ip, args.country)
        print(json.dumps({
            'optimal_region': optimal_region,
            'client_ip': args.ip,
            'country_code': args.country
        }, indent=2))
        
    elif args.action == 'dns':
        result = geo_routing.update_dns_records()
        print(json.dumps(result, indent=2))
        
    elif args.action == 'cdn':
        result = geo_routing.update_cdn_configuration()
        print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
EOF
    
    # Hacer el script ejecutable
    chmod +x "${geo_routing_script}"
    
    # Crear configuración de enrutamiento geográfico
    local geo_routing_config="${CONFIG_DIR}/geo-routing/geo_routing_config.json"
    
    cat > "${geo_routing_config}" << 'EOF'
{
    "dns_provider": "cloudflare",
    "cdn_provider": "cloudflare",
    "primary_region": "us-east-1",
    "secondary_region": "us-west-2",
    "tertiary_region": "eu-west-1",
    "primary_domain": "virtualmin.local",
    "health_check_interval": 30,
    "health_check_timeout": 10,
    "health_check_path": "/health",
    "failover_threshold": 2,
    "regions": {
        "us-east-1": {
            "name": "US East",
            "ip": "192.168.1.10",
            "enabled": true,
            "priority": 1,
            "weight": 100,
            "health_check_url": "http://192.168.1.10/health"
        },
        "us-west-2": {
            "name": "US West",
            "ip": "192.168.2.10",
            "enabled": true,
            "priority": 2,
            "weight": 80,
            "health_check_url": "http://192.168.2.10/health"
        },
        "eu-west-1": {
            "name": "Europe West",
            "ip": "192.168.3.10",
            "enabled": true,
            "priority": 3,
            "weight": 60,
            "health_check_url": "http://192.168.3.10/health"
        }
    },
    "cloudflare": {
        "api_token": "your_cloudflare_api_token",
        "zone_id": "your_cloudflare_zone_id"
    },
    "route53": {
        "hosted_zone_id": "your_route53_hosted_zone_id",
        "access_key": "your_aws_access_key",
        "secret_key": "your_aws_secret_key",
        "region": "us-east-1"
    },
    "bind": {
        "config_file": "/etc/bind/named.conf.local",
        "zone_file": "/etc/bind/db.virtualmin.local"
    },
    "cloudfront": {
        "distribution_id": "your_cloudfront_distribution_id",
        "access_key": "your_aws_access_key",
        "secret_key": "your_aws_secret_key",
        "region": "us-east-1"
    },
    "geoip_db_path": "/usr/share/GeoIP/GeoLite2-City.mmdb"
}
EOF
    
    # Copiar archivos al sistema
    mkdir -p "/etc/multi-region-deployment/geo-routing"
    cp "${geo_routing_script}" "/usr/local/bin/geo_routing_manager.py"
    cp "${geo_routing_config}" "/etc/multi-region-deployment/geo-routing/geo_routing_config.json"
    
    # Crear servicio systemd para enrutamiento geográfico
    local geo_routing_service="${CONFIG_DIR}/geo-routing/geo-routing.service"
    
    cat > "${geo_routing_service}" << 'EOF'
[Unit]
Description=Geo Routing Manager Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/geo_routing_manager.py --config /etc/multi-region-deployment/geo-routing/geo_routing_config.json --action health
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF
    
    # Copiar servicio al sistema
    cp "${geo_routing_service}" "/etc/systemd/system/geo-routing.service"
    
    # Habilitar y arrancar servicio
    systemctl daemon-reload
    systemctl enable geo-routing.service
    systemctl start geo-routing.service
    
    success "✅ Enrutamiento geográfico inteligente configurado"
}

# 🔄 **Función para implementar replicación global de datos**
setup_global_data_replication() {
    log "🔄 Implementando replicación global de datos"
    
    # Crear directorio de configuración si no existe
    mkdir -p "${CONFIG_DIR}/global-replication"
    
    # Crear script de gestión de replicación global
    local replication_script="${CONFIG_DIR}/global-replication/global_replication_manager.py"
    
    cat > "${replication_script}" << 'EOF'
#!/usr/bin/env python3
"""
Script de Gestión de Replicación Global de Datos para Virtualmin Pro
"""

import os
import sys
import json
import time
import logging
import argparse
import subprocess
import threading
import queue
from datetime import datetime, timedelta
import sqlite3
import requests
import paramiko

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileWriter('/var/log/global_replication_manager.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

class GlobalReplicationManager:
    def __init__(self, config_file=None):
        """
        Inicializa el gestor de replicación global
        
        Args:
            config_file: Ruta al archivo de configuración
        """
        self.config = self.load_config(config_file)
        self.database_type = self.config.get('database_type', 'mysql')
        self.replication_type = self.config.get('replication_type', 'async')
        self.primary_region = self.config.get('primary_region')
        self.regions = self.config.get('regions', {})
        
        # Inicializar base de datos
        self.init_database()
        
        # Iniciar cola de replicación
        self.replication_queue = queue.Queue()
        
        # Iniciar hilos de replicación
        self.start_replication_workers()
    
    def load_config(self, config_file):
        """
        Carga configuración desde archivo
        
        Args:
            config_file: Ruta al archivo de configuración
            
        Returns:
            Diccionario con configuración
        """
        default_config = {
            'database_type': 'mysql',
            'replication_type': 'async',
            'primary_region': 'us-east-1',
            'regions': {
                'us-east-1': {
                    'name': 'US East',
                    'host': '192.168.1.10',
                    'port': 3306,
                    'username': 'replication_user',
                    'password': 'replication_password',
                    'database': 'virtualmin',
                    'role': 'primary',
                    'enabled': True
                },
                'us-west-2': {
                    'name': 'US West',
                    'host': '192.168.2.10',
                    'port': 3306,
                    'username': 'replication_user',
                    'password': 'replication_password',
                    'database': 'virtualmin',
                    'role': 'replica',
                    'enabled': True
                },
                'eu-west-1': {
                    'name': 'Europe West',
                    'host': '192.168.3.10',
                    'port': 3306,
                    'username': 'replication_user',
                    'password': 'replication_password',
                    'database': 'virtualmin',
                    'role': 'replica',
                    'enabled': True
                }
            },
            'replication_interval': 60,
            'replication_timeout': 30,
            'max_replication_lag': 300,
            'retry_count': 3,
            'retry_delay': 10
        }
        
        if config_file and os.path.exists(config_file):
            with open(config_file, 'r') as f:
                config = json.load(f)
                default_config.update(config)
        
        return default_config
    
    def init_database(self):
        """Inicializa base de datos de replicación"""
        self.db_path = self.config.get('database_path', '/var/lib/global_replication/replication.db')
        
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Crear tabla de eventos de replicación
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS replication_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_region TEXT NOT NULL,
                target_region TEXT NOT NULL,
                event_type TEXT NOT NULL,
                event_data TEXT NOT NULL,
                status TEXT NOT NULL,
                created_at TEXT NOT NULL,
                processed_at TEXT,
                error_message TEXT
            )
        ''')
        
        # Crear tabla de estado de replicación
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS replication_status (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_region TEXT NOT NULL,
                target_region TEXT NOT NULL,
                last_event_id INTEGER DEFAULT 0,
                last_event_time TEXT,
                replication_lag INTEGER DEFAULT 0,
                status TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        ''')
        
        # Crear tabla de configuración de replicación
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS replication_config (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_region TEXT NOT NULL,
                target_region TEXT NOT NULL,
                enabled BOOLEAN DEFAULT TRUE,
                config_data TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        ''')
        
        conn.commit()
        conn.close()
        
        logger.info("Base de datos de replicación inicializada")
    
    def start_replication_workers(self):
        """Inicia hilos de replicación"""
        import threading
        
        def replication_worker():
            while True:
                try:
                    # Obtener tarea de replicación
                    try:
                        task = self.replication_queue.get(timeout=10)
                        
                        # Procesar tarea
                        self.process_replication_task(task)
                        
                        # Marcar tarea como completada
                        self.replication_queue.task_done()
                    except queue.Empty:
                        continue
                    
                except Exception as e:
                    logger.error(f"Error en el trabajador de replicación: {e}")
                    time.sleep(60)
        
        # Iniciar hilo de replicación
        self.replication_thread = threading.Thread(target=replication_worker, daemon=True)
        self.replication_thread.start()
        
        logger.info("Hilo de replicación iniciado")
    
    def process_replication_task(self, task):
        """
        Procesa una tarea de replicación
        
        Args:
            task: Tarea de replicación
        """
        try:
            operation = task.get('operation')
            source_region = task.get('source_region')
            target_region = task.get('target_region')
            event_data = task.get('event_data')
            
            if operation == 'replicate':
                # Replicar evento
                result = self.replicate_event(source_region, target_region, event_data)
                
                # Actualizar estado de la tarea
                task['status'] = result.get('status')
                task['message'] = result.get('message')
                task['processed_at'] = datetime.now().isoformat()
                
                logger.info(f"Tarea de replicación procesada: {result.get('message')}")
        except Exception as e:
            logger.error(f"Error al procesar tarea de replicación: {e}")
            
            # Actualizar estado de la tarea con error
            task['status'] = 'error'
            task['message'] = f'Error al procesar tarea: {e}'
            task['processed_at'] = datetime.now().isoformat()
    
    def replicate_event(self, source_region, target_region, event_data):
        """
        Replica un evento entre regiones
        
        Args:
            source_region: Región de origen
            target_region: Región de destino
            event_data: Datos del evento
            
        Returns:
            Diccionario con resultado de la replicación
        """
        if source_region not in self.regions:
            return {
                'status': 'error',
                'message': f'Región de origen {source_region} no configurada'
            }
        
        if target_region not in self.regions:
            return {
                'status': 'error',
                'message': f'Región de destino {target_region} no configurada'
            }
        
        source_config = self.regions[source_region]
        target_config = self.regions[target_region]
        
        if source_config.get('role') != 'primary':
            return {
                'status': 'error',
                'message': f'Región de origen {source_region} no es primaria'
            }
        
        if target_config.get('role') != 'replica':
            return {
                'status': 'error',
                'message': f'Región de destino {target_region} no es réplica'
            }
        
        try:
            # Replicar evento según tipo de base de datos
            if self.database_type == 'mysql':
                result = self.replicate_mysql_event(source_config, target_config, event_data)
            elif self.database_type == 'postgresql':
                result = self.replicate_postgresql_event(source_config, target_config, event_data)
            elif self.database_type == 'mongodb':
                result = self.replicate_mongodb_event(source_config, target_config, event_data)
            else:
                result = {
                    'status': 'error',
                    'message': f'Tipo de base de datos {self.database_type} no soportado'
                }
            
            # Guardar evento en la base de datos
            self.save_replication_event(source_region, target_region, 'replicate', event_data, result.get('status'), result.get('message'))
            
            return result
        except Exception as e:
            logger.error(f"Error al replicar evento de {source_region} a {target_region}: {e}")
            
            # Guardar evento en la base de datos
            self.save_replication_event(source_region, target_region, 'replicate', event_data, 'error', str(e))
            
            return {
                'status': 'error',
                'message': f'Error al replicar evento de {source_region} a {target_region}: {e}'
            }
    
    def replicate_mysql_event(self, source_config, target_config, event_data):
        """
        Replica un evento de MySQL
        
        Args:
            source_config: Configuración de origen
            target_config: Configuración de destino
            event_data: Datos del evento
            
        Returns:
            Diccionario con resultado de la replicación
        """
        try:
            # Extraer información del evento
            query = event_data.get('query')
            if not query:
                return {
                    'status': 'error',
                    'message': 'Query no especificado en el evento'
                }
            
            # Ejecutar query en destino
            return self.execute_mysql_query(target_config, query)
        except Exception as e:
            logger.error(f"Error al replicar evento de MySQL: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al replicar evento de MySQL: {e}'
            }
    
    def replicate_postgresql_event(self, source_config, target_config, event_data):
        """
        Replica un evento de PostgreSQL
        
        Args:
            source_config: Configuración de origen
            target_config: Configuración de destino
            event_data: Datos del evento
            
        Returns:
            Diccionario con resultado de la replicación
        """
        try:
            # Extraer información del evento
            query = event_data.get('query')
            if not query:
                return {
                    'status': 'error',
                    'message': 'Query no especificado en el evento'
                }
            
            # Ejecutar query en destino
            return self.execute_postgresql_query(target_config, query)
        except Exception as e:
            logger.error(f"Error al replicar evento de PostgreSQL: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al replicar evento de PostgreSQL: {e}'
            }
    
    def replicate_mongodb_event(self, source_config, target_config, event_data):
        """
        Replica un evento de MongoDB
        
        Args:
            source_config: Configuración de origen
            target_config: Configuración de destino
            event_data: Datos del evento
            
        Returns:
            Diccionario con resultado de la replicación
        """
        try:
            # Extraer información del evento
            operation = event_data.get('operation')
            collection = event_data.get('collection')
            document = event_data.get('document')
            
            if not operation or not collection:
                return {
                    'status': 'error',
                    'message': 'Operación o colección no especificados en el evento'
                }
            
            # Ejecutar operación en destino
            if operation == 'insert':
                return self.execute_mongodb_insert(target_config, collection, document)
            elif operation == 'update':
                return self.execute_mongodb_update(target_config, collection, document)
            elif operation == 'delete':
                return self.execute_mongodb_delete(target_config, collection, document)
            else:
                return {
                    'status': 'error',
                    'message': f'Operación {operation} no soportada'
                }
        except Exception as e:
            logger.error(f"Error al replicar evento de MongoDB: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al replicar evento de MongoDB: {e}'
            }
    
    def execute_mysql_query(self, config, query):
        """
        Ejecuta una consulta MySQL
        
        Args:
            config: Configuración de la base de datos
            query: Consulta a ejecutar
            
        Returns:
            Diccionario con resultado de la consulta
        """
        try:
            import pymysql
            
            # Conectar a la base de datos
            connection = pymysql.connect(
                host=config.get('host'),
                port=config.get('port', 3306),
                user=config.get('username'),
                password=config.get('password'),
                database=config.get('database'),
                charset='utf8mb4',
                cursorclass=pymysql.cursors.DictCursor
            )
            
            # Ejecutar consulta
            with connection.cursor() as cursor:
                cursor.execute(query)
                
                # Confirmar cambios
                connection.commit()
                
                return {
                    'status': 'success',
                    'message': f'Consulta MySQL ejecutada exitosamente',
                    'affected_rows': cursor.rowcount
                }
        except Exception as e:
            logger.error(f"Error al ejecutar consulta MySQL: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al ejecutar consulta MySQL: {e}'
            }
    
    def execute_postgresql_query(self, config, query):
        """
        Ejecuta una consulta PostgreSQL
        
        Args:
            config: Configuración de la base de datos
            query: Consulta a ejecutar
            
        Returns:
            Diccionario con resultado de la consulta
        """
        try:
            import psycopg2
            
            # Conectar a la base de datos
            connection = psycopg2.connect(
                host=config.get('host'),
                port=config.get('port', 5432),
                user=config.get('username'),
                password=config.get('password'),
                database=config.get('database')
            )
            
            # Ejecutar consulta
            with connection.cursor() as cursor:
                cursor.execute(query)
                
                # Confirmar cambios
                connection.commit()
                
                return {
                    'status': 'success',
                    'message': f'Consulta PostgreSQL ejecutada exitosamente',
                    'affected_rows': cursor.rowcount
                }
        except Exception as e:
            logger.error(f"Error al ejecutar consulta PostgreSQL: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al ejecutar consulta PostgreSQL: {e}'
            }
    
    def execute_mongodb_insert(self, config, collection, document):
        """
        Ejecuta una inserción MongoDB
        
        Args:
            config: Configuración de la base de datos
            collection: Colección
            document: Documento a insertar
            
        Returns:
            Diccionario con resultado de la inserción
        """
        try:
            from pymongo import MongoClient
            
            # Conectar a la base de datos
            client = MongoClient(
                f"mongodb://{config.get('host')}:{config.get('port', 27017)}/",
                username=config.get('username'),
                password=config.get('password')
            )
            
            db = client[config.get('database')]
            coll = db[collection]
            
            # Insertar documento
            result = coll.insert_one(document)
            
            return {
                'status': 'success',
                'message': f'Documento MongoDB insertado exitosamente',
                'inserted_id': str(result.inserted_id)
            }
        except Exception as e:
            logger.error(f"Error al insertar documento MongoDB: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al insertar documento MongoDB: {e}'
            }
    
    def execute_mongodb_update(self, config, collection, document):
        """
        Ejecuta una actualización MongoDB
        
        Args:
            config: Configuración de la base de datos
            collection: Colección
            document: Documento a actualizar
            
        Returns:
            Diccionario con resultado de la actualización
        """
        try:
            from pymongo import MongoClient
            
            # Conectar a la base de datos
            client = MongoClient(
                f"mongodb://{config.get('host')}:{config.get('port', 27017)}/",
                username=config.get('username'),
                password=config.get('password')
            )
            
            db = client[config.get('database')]
            coll = db[collection]
            
            # Extraer filtros y actualización
            filters = document.get('filters', {})
            update = document.get('update', {})
            
            # Actualizar documento
            result = coll.update_many(filters, {'$set': update})
            
            return {
                'status': 'success',
                'message': f'Documento MongoDB actualizado exitosamente',
                'matched_count': result.matched_count,
                'modified_count': result.modified_count
            }
        except Exception as e:
            logger.error(f"Error al actualizar documento MongoDB: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al actualizar documento MongoDB: {e}'
            }
    
    def execute_mongodb_delete(self, config, collection, document):
        """
        Ejecuta una eliminación MongoDB
        
        Args:
            config: Configuración de la base de datos
            collection: Colección
            document: Documento a eliminar
            
        Returns:
            Diccionario con resultado de la eliminación
        """
        try:
            from pymongo import MongoClient
            
            # Conectar a la base de datos
            client = MongoClient(
                f"mongodb://{config.get('host')}:{config.get('port', 27017)}/",
                username=config.get('username'),
                password=config.get('password')
            )
            
            db = client[config.get('database')]
            coll = db[collection]
            
            # Extraer filtros
            filters = document.get('filters', {})
            
            # Eliminar documento
            result = coll.delete_many(filters)
            
            return {
                'status': 'success',
                'message': f'Documento MongoDB eliminado exitosamente',
                'deleted_count': result.deleted_count
            }
        except Exception as e:
            logger.error(f"Error al eliminar documento MongoDB: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al eliminar documento MongoDB: {e}'
            }
    
    def save_replication_event(self, source_region, target_region, event_type, event_data, status, message=None):
        """
        Guarda un evento de replicación en la base de datos
        
        Args:
            source_region: Región de origen
            target_region: Región de destino
            event_type: Tipo de evento
            event_data: Datos del evento
            status: Estado del evento
            message: Mensaje de error (opcional)
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO replication_events (
                source_region, target_region, event_type, event_data,
                status, created_at, error_message
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            source_region, target_region, event_type,
            json.dumps(event_data), status,
            datetime.now().isoformat(), message
        ))
        
        conn.commit()
        conn.close()
    
    def schedule_replication(self, source_region, target_region, event_data):
        """
        Programa una replicación
        
        Args:
            source_region: Región de origen
            target_region: Región de destino
            event_data: Datos del evento
            
        Returns:
            Diccionario con resultado de la programación
        """
        # Crear tarea de replicación
        task = {
            'operation': 'replicate',
            'source_region': source_region,
            'target_region': target_region,
            'event_data': event_data,
            'created_at': datetime.now().isoformat()
        }
        
        # Agregar a la cola
        self.replication_queue.put(task)
        
        return {
            'status': 'success',
            'message': f'Replicación programada de {source_region} a {target_region}',
            'source_region': source_region,
            'target_region': target_region
        }
    
    def check_replication_lag(self, source_region, target_region):
        """
        Verifica el lag de replicación entre regiones
        
        Args:
            source_region: Región de origen
            target_region: Región de destino
            
        Returns:
            Diccionario con lag de replicación
        """
        try:
            if self.database_type == 'mysql':
                return self.check_mysql_replication_lag(source_region, target_region)
            elif self.database_type == 'postgresql':
                return self.check_postgresql_replication_lag(source_region, target_region)
            elif self.database_type == 'mongodb':
                return self.check_mongodb_replication_lag(source_region, target_region)
            else:
                return {
                    'status': 'error',
                    'message': f'Tipo de base de datos {self.database_type} no soportado'
                }
        except Exception as e:
            logger.error(f"Error al verificar lag de replicación: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al verificar lag de replicación: {e}'
            }
    
    def check_mysql_replication_lag(self, source_region, target_region):
        """
        Verifica el lag de replicación de MySQL
        
        Args:
            source_region: Región de origen
            target_region: Región de destino
            
        Returns:
            Diccionario con lag de replicación
        """
        try:
            source_config = self.regions[source_region]
            target_config = self.regions[target_region]
            
            # Obtener posición del binlog en origen
            source_result = self.execute_mysql_query(source_config, "SHOW MASTER STATUS")
            
            if source_result.get('status') != 'success':
                return source_result
            
            master_status = source_result.get('result', [])
            if not master_status:
                return {
                    'status': 'error',
                    'message': 'No se pudo obtener estado del master'
                }
            
            master_file = master_status[0].get('File')
            master_position = master_status[0].get('Position')
            
            # Obtener posición del relay log en réplica
            target_result = self.execute_mysql_query(target_config, "SHOW SLAVE STATUS")
            
            if target_result.get('status') != 'success':
                return target_result
            
            slave_status = target_result.get('result', [])
            if not slave_status:
                return {
                    'status': 'error',
                    'message': 'No se pudo obtener estado del slave'
                }
            
            relay_master_log_file = slave_status[0].get('Relay_Master_Log_File')
            exec_master_log_pos = slave_status[0].get('Exec_Master_Log_Pos')
            seconds_behind_master = slave_status[0].get('Seconds_Behind_Master')
            
            # Calcular lag
            if seconds_behind_master is not None and seconds_behind_master >= 0:
                replication_lag = seconds_behind_master
            else:
                replication_lag = 0
            
            return {
                'status': 'success',
                'message': 'Lag de replicación verificado',
                'source_region': source_region,
                'target_region': target_region,
                'master_file': master_file,
                'master_position': master_position,
                'relay_master_log_file': relay_master_log_file,
                'exec_master_log_pos': exec_master_log_pos,
                'replication_lag': replication_lag
            }
        except Exception as e:
            logger.error(f"Error al verificar lag de replicación de MySQL: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al verificar lag de replicación de MySQL: {e}'
            }
    
    def check_postgresql_replication_lag(self, source_region, target_region):
        """
        Verifica el lag de replicación de PostgreSQL
        
        Args:
            source_region: Región de origen
            target_region: Región de destino
            
        Returns:
            Diccionario con lag de replicación
        """
        try:
            source_config = self.regions[source_region]
            target_config = self.regions[target_region]
            
            # Obtener posición del WAL en origen
            source_result = self.execute_postgresql_query(source_config, "SELECT pg_last_wal_receive_lsn()")
            
            if source_result.get('status') != 'success':
                return source_result
            
            source_lsn = source_result.get('result', [{}])[0].get('pg_last_wal_receive_lsn')
            
            # Obtener posición del WAL en réplica
            target_result = self.execute_postgresql_query(target_config, "SELECT pg_last_wal_replay_lsn()")
            
            if target_result.get('status') != 'success':
                return target_result
            
            target_lsn = target_result.get('result', [{}])[0].get('pg_last_wal_replay_lsn')
            
            # Calcular lag
            replication_lag = 0  # PostgreSQL no proporciona lag en segundos directamente
            
            return {
                'status': 'success',
                'message': 'Lag de replicación verificado',
                'source_region': source_region,
                'target_region': target_region,
                'source_lsn': source_lsn,
                'target_lsn': target_lsn,
                'replication_lag': replication_lag
            }
        except Exception as e:
            logger.error(f"Error al verificar lag de replicación de PostgreSQL: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al verificar lag de replicación de PostgreSQL: {e}'
            }
    
    def check_mongodb_replication_lag(self, source_region, target_region):
        """
        Verifica el lag de replicación de MongoDB
        
        Args:
            source_region: Región de origen
            target_region: Región de destino
            
        Returns:
            Diccionario con lag de replicación
        """
        try:
            source_config = self.regions[source_region]
            target_config = self.regions[target_region]
            
            # Obtener estado de réplica en origen
            from pymongo import MongoClient
            
            source_client = MongoClient(
                f"mongodb://{source_config.get('host')}:{source_config.get('port', 27017)}/",
                username=source_config.get('username'),
                password=source_config.get('password')
            )
            
            source_db = source_client['admin']
            source_rs_status = source_db.command('replSetGetStatus')
            
            # Obtener optime del primario
            primary_optime = None
            for member in source_rs_status.get('members', []):
                if member.get('stateStr') == 'PRIMARY':
                    primary_optime = member.get('optimeDate')
                    break
            
            # Obtener estado de réplica en destino
            target_client = MongoClient(
                f"mongodb://{target_config.get('host')}:{target_config.get('port', 27017)}/",
                username=target_config.get('username'),
                password=target_config.get('password')
            )
            
            target_db = target_client['admin']
            target_rs_status = target_db.command('replSetGetStatus')
            
            # Obtener optime del secundario
            secondary_optime = None
            for member in target_rs_status.get('members', []):
                if member.get('stateStr') == 'SECONDARY':
                    secondary_optime = member.get('optimeDate')
                    break
            
            # Calcular lag
            replication_lag = 0
            if primary_optime and secondary_optime:
                replication_lag = (primary_optime - secondary_optime).total_seconds()
            
            return {
                'status': 'success',
                'message': 'Lag de replicación verificado',
                'source_region': source_region,
                'target_region': target_region,
                'primary_optime': primary_optime,
                'secondary_optime': secondary_optime,
                'replication_lag': replication_lag
            }
        except Exception as e:
            logger.error(f"Error al verificar lag de replicación de MongoDB: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al verificar lag de replicación de MongoDB: {e}'
            }
    
    def get_replication_status(self):
        """
        Obtiene el estado de replicación
        
        Returns:
            Diccionario con estado de replicación
        """
        results = {}
        
        for source_region, source_config in self.regions.items():
            if source_config.get('role') != 'primary':
                continue
            
            for target_region, target_config in self.regions.items():
                if target_config.get('role') != 'replica':
                    continue
                
                # Verificar lag de replicación
                lag_result = self.check_replication_lag(source_region, target_region)
                
                results[f"{source_region}->{target_region}"] = lag_result
        
        return results

def main():
    """Función principal"""
    parser = argparse.ArgumentParser(description='Gestión de Replicación Global')
    parser.add_argument('--config', help='Ruta al archivo de configuración')
    parser.add_argument('--action', choices=['replicate', 'lag', 'status'],
                       default='status', help='Acción a realizar')
    parser.add_argument('--source', help='Región de origen')
    parser.add_argument('--target', help='Región de destino')
    parser.add_argument('--query', help='Query a replicar (MySQL/PostgreSQL)')
    parser.add_argument('--operation', help='Operación a replicar (MongoDB)')
    parser.add_argument('--collection', help='Colección (MongoDB)')
    parser.add_argument('--document', help='Documento (MongoDB)')
    
    args = parser.parse_args()
    
    # Inicializar gestor de replicación global
    global_replication = GlobalReplicationManager(args.config)
    
    if args.action == 'replicate':
        if not args.source or not args.target:
            print("Error: Se requieren --source y --target para replicar")
            sys.exit(1)
        
        if global_replication.database_type == 'mongodb':
            if not args.operation or not args.collection or not args.document:
                print("Error: Se requieren --operation, --collection y --document para replicar MongoDB")
                sys.exit(1)
            
            event_data = {
                'operation': args.operation,
                'collection': args.collection,
                'document': json.loads(args.document)
            }
        else:
            if not args.query:
                print("Error: Se requiere --query para replicar MySQL/PostgreSQL")
                sys.exit(1)
            
            event_data = {
                'query': args.query
            }
        
        result = global_replication.schedule_replication(args.source, args.target, event_data)
        print(json.dumps(result, indent=2))
        
    elif args.action == 'lag':
        if not args.source or not args.target:
            print("Error: Se requieren --source y --target para verificar lag")
            sys.exit(1)
        
        result = global_replication.check_replication_lag(args.source, args.target)
        print(json.dumps(result, indent=2))
        
    elif args.action == 'status':
        results = global_replication.get_replication_status()
        print(json.dumps(results, indent=2))

if __name__ == '__main__':
    main()
EOF
    
    # Hacer el script ejecutable
    chmod +x "${replication_script}"
    
    # Crear configuración de replicación global
    local replication_config="${CONFIG_DIR}/global-replication/global_replication_config.json"
    
    cat > "${replication_config}" << 'EOF'
{
    "database_type": "mysql",
    "replication_type": "async",
    "primary_region": "us-east-1",
    "regions": {
        "us-east-1": {
            "name": "US East",
            "host": "192.168.1.10",
            "port": 3306,
            "username": "replication_user",
            "password": "replication_password",
            "database": "virtualmin",
            "role": "primary",
            "enabled": true
        },
        "us-west-2": {
            "name": "US West",
            "host": "192.168.2.10",
            "port": 3306,
            "username": "replication_user",
            "password": "replication_password",
            "database": "virtualmin",
            "role": "replica",
            "enabled": true
        },
        "eu-west-1": {
            "name": "Europe West",
            "host": "192.168.3.10",
            "port": 3306,
            "username": "replication_user",
            "password": "replication_password",
            "database": "virtualmin",
            "role": "replica",
            "enabled": true
        }
    },
    "replication_interval": 60,
    "replication_timeout": 30,
    "max_replication_lag": 300,
    "retry_count": 3,
    "retry_delay": 10
}
EOF
    
    # Copiar archivos al sistema
    mkdir -p "/etc/multi-region-deployment/global-replication"
    mkdir -p "/var/lib/global_replication"
    cp "${replication_script}" "/usr/local/bin/global_replication_manager.py"
    cp "${replication_config}" "/etc/multi-region-deployment/global-replication/global_replication_config.json"
    
    # Crear servicio systemd para replicación global
    local replication_service="${CONFIG_DIR}/global-replication/global-replication.service"
    
    cat > "${replication_service}" << 'EOF'
[Unit]
Description=Global Replication Manager Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/global_replication_manager.py --config /etc/multi-region-deployment/global-replication/global_replication_config.json --action status
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF
    
    # Copiar servicio al sistema
    cp "${replication_service}" "/etc/systemd/system/global-replication.service"
    
    # Habilitar y arrancar servicio
    systemctl daemon-reload
    systemctl enable global-replication.service
    systemctl start global-replication.service
    
    success "✅ Replicación global de datos implementada"
}

# 🚨 **Función para configurar disaster recovery con failover regional**
setup_disaster_recovery() {
    log "🚨 Configurando disaster recovery con failover regional"
    
    # Crear directorio de configuración si no existe
    mkdir -p "${CONFIG_DIR}/disaster-recovery"
    
    # Crear script de gestión de disaster recovery
    local dr_script="${CONFIG_DIR}/disaster-recovery/disaster_recovery_manager.py"
    
    cat > "${dr_script}" << 'EOF'
#!/usr/bin/env python3
"""
Script de Gestión de Disaster Recovery con Failover Regional para Virtualmin Pro
"""

import os
import sys
import json
import time
import logging
import argparse
import subprocess
import threading
import queue
from datetime import datetime, timedelta
import sqlite3
import requests
import paramiko

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileWriter('/var/log/disaster_recovery_manager.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

class DisasterRecoveryManager:
    def __init__(self, config_file=None):
        """
        Inicializa el gestor de disaster recovery
        
        Args:
            config_file: Ruta al archivo de configuración
        """
        self.config = self.load_config(config_file)
        self.primary_region = self.config.get('primary_region')
        self.secondary_region = self.config.get('secondary_region')
        self.tertiary_region = self.config.get('tertiary_region')
        self.regions = self.config.get('regions', {})
        
        # Inicializar base de datos
        self.init_database()
        
        # Iniciar cola de failover
        self.failover_queue = queue.Queue()
        
        # Iniciar hilos de failover
        self.start_failover_workers()
        
        # Estado de failover
        self.current_primary = self.primary_region
        self.failover_in_progress = False
    
    def load_config(self, config_file):
        """
        Carga configuración desde archivo
        
        Args:
            config_file: Ruta al archivo de configuración
            
        Returns:
            Diccionario con configuración
        """
        default_config = {
            'primary_region': 'us-east-1',
            'secondary_region': 'us-west-2',
            'tertiary_region': 'eu-west-1',
            'regions': {
                'us-east-1': {
                    'name': 'US East',
                    'ip': '192.168.1.10',
                    'port': 22,
                    'username': 'admin',
                    'password': 'password',
                    'role': 'primary',
                    'enabled': True,
                    'health_check_url': 'http://192.168.1.10/health'
                },
                'us-west-2': {
                    'name': 'US West',
                    'ip': '192.168.2.10',
                    'port': 22,
                    'username': 'admin',
                    'password': 'password',
                    'role': 'secondary',
                    'enabled': True,
                    'health_check_url': 'http://192.168.2.10/health'
                },
                'eu-west-1': {
                    'name': 'Europe West',
                    'ip': '192.168.3.10',
                    'port': 22,
                    'username': 'admin',
                    'password': 'password',
                    'role': 'tertiary',
                    'enabled': True,
                    'health_check_url': 'http://192.168.3.10/health'
                }
            },
            'health_check_interval': 30,
            'health_check_timeout': 10,
            'failover_threshold': 3,
            'failover_timeout': 300,
            'auto_failover_enabled': True,
            'dns_provider': 'cloudflare',
            'dns_records': [
                'virtualmin.local',
                'api.virtualmin.local',
                'mail.virtualmin.local'
            ]
        }
        
        if config_file and os.path.exists(config_file):
            with open(config_file, 'r') as f:
                config = json.load(f)
                default_config.update(config)
        
        return default_config
    
    def init_database(self):
        """Inicializa base de datos de disaster recovery"""
        self.db_path = self.config.get('database_path', '/var/lib/disaster_recovery/dr.db')
        
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Crear tabla de eventos de failover
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS failover_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                from_region TEXT NOT NULL,
                to_region TEXT NOT NULL,
                reason TEXT NOT NULL,
                status TEXT NOT NULL,
                created_at TEXT NOT NULL,
                completed_at TEXT,
                error_message TEXT
            )
        ''')
        
        # Crear tabla de estado de regiones
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS region_status (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                region_name TEXT NOT NULL,
                is_primary BOOLEAN DEFAULT FALSE,
                is_healthy BOOLEAN DEFAULT TRUE,
                last_check TEXT NOT NULL,
                consecutive_failures INTEGER DEFAULT 0,
                updated_at TEXT NOT NULL
            )
        ''')
        
        # Crear tabla de configuración de DNS
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS dns_config (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                record_name TEXT NOT NULL,
                current_region TEXT NOT NULL,
                backup_region TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        ''')
        
        conn.commit()
        conn.close()
        
        logger.info("Base de datos de disaster recovery inicializada")
    
    def start_failover_workers(self):
        """Inicia hilos de failover"""
        import threading
        
        def failover_worker():
            while True:
                try:
                    # Obtener tarea de failover
                    try:
                        task = self.failover_queue.get(timeout=10)
                        
                        # Procesar tarea
                        self.process_failover_task(task)
                        
                        # Marcar tarea como completada
                        self.failover_queue.task_done()
                    except queue.Empty:
                        continue
                    
                except Exception as e:
                    logger.error(f"Error en el trabajador de failover: {e}")
                    time.sleep(60)
        
        # Iniciar hilo de failover
        self.failover_thread = threading.Thread(target=failover_worker, daemon=True)
        self.failover_thread.start()
        
        logger.info("Hilo de failover iniciado")
    
    def process_failover_task(self, task):
        """
        Procesa una tarea de failover
        
        Args:
            task: Tarea de failover
        """
        try:
            operation = task.get('operation')
            from_region = task.get('from_region')
            to_region = task.get('to_region')
            reason = task.get('reason')
            
            if operation == 'failover':
                # Realizar failover
                result = self.perform_failover(from_region, to_region, reason)
                
                # Actualizar estado de la tarea
                task['status'] = result.get('status')
                task['message'] = result.get('message')
                task['completed_at'] = datetime.now().isoformat()
                
                logger.info(f"Tarea de failover procesada: {result.get('message')}")
        except Exception as e:
            logger.error(f"Error al procesar tarea de failover: {e}")
            
            # Actualizar estado de la tarea con error
            task['status'] = 'error'
            task['message'] = f'Error al procesar tarea: {e}'
            task['completed_at'] = datetime.now().isoformat()
    
    def perform_failover(self, from_region, to_region, reason):
        """
        Realiza un failover entre regiones
        
        Args:
            from_region: Región de origen
            to_region: Región de destino
            reason: Razón del failover
            
        Returns:
            Diccionario con resultado del failover
        """
        if from_region not in self.regions:
            return {
                'status': 'error',
                'message': f'Región de origen {from_region} no configurada'
            }
        
        if to_region not in self.regions:
            return {
                'status': 'error',
                'message': f'Región de destino {to_region} no configurada'
            }
        
        from_config = self.regions[from_region]
        to_config = self.regions[to_region]
        
        if from_config.get('role') != 'primary':
            return {
                'status': 'error',
                'message': f'Región de origen {from_region} no es primaria'
            }
        
        if to_config.get('role') not in ['secondary', 'tertiary']:
            return {
                'status': 'error',
                'message': f'Región de destino {to_region} no es secundaria o terciaria'
            }
        
        try:
            # Marcar failover en progreso
            self.failover_in_progress = True
            
            # Actualizar DNS
            dns_result = self.update_dns_records(from_region, to_region)
            
            if dns_result.get('status') != 'success':
                self.failover_in_progress = False
                
                return {
                    'status': 'error',
                    'message': f'Error al actualizar registros DNS: {dns_result.get("message")}'
                }
            
            # Actualizar roles
            self.update_region_roles(from_region, to_region)
            
            # Actualizar estado actual
            self.current_primary = to_region
            
            # Guardar evento de failover
            self.save_failover_event(from_region, to_region, reason, 'success')
            
            # Marcar failover como completado
            self.failover_in_progress = False
            
            return {
                'status': 'success',
                'message': f'Failover de {from_region} a {to_region} completado',
                'from_region': from_region,
                'to_region': to_region,
                'reason': reason
            }
        except Exception as e:
            logger.error(f"Error al realizar failover de {from_region} a {to_region}: {e}")
            
            # Marcar failover como completado
            self.failover_in_progress = False
            
            # Guardar evento de failover
            self.save_failover_event(from_region, to_region, reason, 'error', str(e))
            
            return {
                'status': 'error',
                'message': f'Error al realizar failover de {from_region} a {to_region}: {e}',
                'from_region': from_region,
                'to_region': to_region,
                'reason': reason
            }
    
    def update_dns_records(self, from_region, to_region):
        """
        Actualiza registros DNS para failover
        
        Args:
            from_region: Región de origen
            to_region: Región de destino
            
        Returns:
            Diccionario con resultado de la actualización
        """
        dns_provider = self.config.get('dns_provider', 'cloudflare')
        dns_records = self.config.get('dns_records', [])
        
        if dns_provider == 'cloudflare':
            return self.update_cloudflare_dns_records(from_region, to_region, dns_records)
        elif dns_provider == 'route53':
            return self.update_route53_dns_records(from_region, to_region, dns_records)
        elif dns_provider == 'bind':
            return self.update_bind_dns_records(from_region, to_region, dns_records)
        
        return {
            'status': 'error',
            'message': f'Proveedor DNS {dns_provider} no soportado'
        }
    
    def update_cloudflare_dns_records(self, from_region, to_region, dns_records):
        """
        Actualiza registros DNS de CloudFlare para failover
        
        Args:
            from_region: Región de origen
            to_region: Región de destino
            dns_records: Registros DNS a actualizar
            
        Returns:
            Diccionario con resultado de la actualización
        """
        try:
            # Obtener credenciales de CloudFlare
            api_token = self.config.get('cloudflare', {}).get('api_token')
            zone_id = self.config.get('cloudflare', {}).get('zone_id')
            
            if not api_token or not zone_id:
                return {
                    'status': 'error',
                    'message': 'Credenciales de CloudFlare no configuradas'
                }
            
            # Obtener IPs de las regiones
            from_ip = self.regions[from_region].get('ip')
            to_ip = self.regions[to_region].get('ip')
            
            if not from_ip or not to_ip:
                return {
                    'status': 'error',
                    'message': 'IPs de las regiones no configuradas'
                }
            
            # Actualizar cada registro DNS
            results = {}
            
            headers = {
                'Authorization': f'Bearer {api_token}',
                'Content-Type': 'application/json'
            }
            
            for record_name in dns_records:
                # Obtener registros DNS existentes
                url = f'https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records'
                
                params = {
                    'name': record_name,
                    'type': 'A'
                }
                
                response = requests.get(
                    url,
                    headers=headers,
                    params=params
                )
                
                if response.status_code != 200:
                    results[record_name] = {
                        'status': 'error',
                        'message': f'Error al obtener registro {record_name}: {response.status_code}'
                    }
                    continue
                
                records = response.json().get('result', [])
                
                if not records:
                    results[record_name] = {
                        'status': 'error',
                        'message': f'Registro {record_name} no encontrado'
                    }
                    continue
                
                # Actualizar registros que apuntan a la región de origen
                for record in records:
                    if record['content'] == from_ip:
                        # Actualizar registro
                        url = f'https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record["id"]}'
                        
                        data = {
                            'type': 'A',
                            'name': record_name,
                            'content': to_ip,
                            'ttl': 300
                        }
                        
                        response = requests.put(
                            url,
                            headers=headers,
                            json=data
                        )
                        
                        results[record_name] = {
                            'status': response.status_code == 200,
                            'message': f'Registro {record_name} actualizado' if response.status_code == 200 else f'Error al actualizar registro {record_name}: {response.status_code}',
                            'from_ip': from_ip,
                            'to_ip': to_ip
                        }
            
            return {
                'status': 'success',
                'message': 'Registros DNS de CloudFlare actualizados',
                'results': results
            }
        except Exception as e:
            logger.error(f"Error al actualizar registros DNS de CloudFlare: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al actualizar registros DNS de CloudFlare: {e}'
            }
    
    def update_route53_dns_records(self, from_region, to_region, dns_records):
        """
        Actualiza registros DNS de Route53 para failover
        
        Args:
            from_region: Región de origen
            to_region: Región de destino
            dns_records: Registros DNS a actualizar
            
        Returns:
            Diccionario con resultado de la actualización
        """
        try:
            # Obtener credenciales de Route53
            hosted_zone_id = self.config.get('route53', {}).get('hosted_zone_id')
            access_key = self.config.get('route53', {}).get('access_key')
            secret_key = self.config.get('route53', {}).get('secret_key')
            region = self.config.get('route53', {}).get('region', 'us-east-1')
            
            if not all([hosted_zone_id, access_key, secret_key]):
                return {
                    'status': 'error',
                    'message': 'Credenciales de Route53 no configuradas'
                }
            
            # Inicializar cliente de AWS
            import boto3
            
            route53_client = boto3.client(
                'route53',
                aws_access_key_id=access_key,
                aws_secret_access_key=secret_key,
                region_name=region
            )
            
            # Obtener IPs de las regiones
            from_ip = self.regions[from_region].get('ip')
            to_ip = self.regions[to_region].get('ip')
            
            if not from_ip or not to_ip:
                return {
                    'status': 'error',
                    'message': 'IPs de las regiones no configuradas'
                }
            
            # Actualizar cada registro DNS
            results = {}
            
            for record_name in dns_records:
                # Crear conjunto de cambios
                change_batch = {
                    'Comment': f'Failover update for {record_name}',
                    'Changes': [
                        {
                            'Action': 'UPSERT',
                            'ResourceRecordSet': {
                                'Name': record_name,
                                'Type': 'A',
                                'TTL': 300,
                                'ResourceRecords': [
                                    {
                                        'Value': to_ip
                                    }
                                ]
                            }
                        }
                    ]
                }
                
                # Aplicar cambios
                response = route53_client.change_resource_record_sets(
                    HostedZoneId=hosted_zone_id,
                    ChangeBatch=change_batch
                )
                
                results[record_name] = {
                    'status': response['ChangeInfo']['Status'] == 'PENDING',
                    'message': f'Registro {record_name} actualizado',
                    'from_ip': from_ip,
                    'to_ip': to_ip,
                    'change_id': response['ChangeInfo']['Id']
                }
            
            return {
                'status': 'success',
                'message': 'Registros DNS de Route53 actualizados',
                'results': results
            }
        except Exception as e:
            logger.error(f"Error al actualizar registros DNS de Route53: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al actualizar registros DNS de Route53: {e}'
            }
    
    def update_bind_dns_records(self, from_region, to_region, dns_records):
        """
        Actualiza registros DNS de BIND para failover
        
        Args:
            from_region: Región de origen
            to_region: Región de destino
            dns_records: Registros DNS a actualizar
            
        Returns:
            Diccionario con resultado de la actualización
        """
        try:
            # Obtener archivo de zona
            zone_file = self.config.get('bind', {}).get('zone_file', '/etc/bind/db.virtualmin.local')
            
            if not os.path.exists(zone_file):
                return {
                    'status': 'error',
                    'message': f'Archivo de zona BIND no encontrado: {zone_file}'
                }
            
            # Obtener IPs de las regiones
            from_ip = self.regions[from_region].get('ip')
            to_ip = self.regions[to_region].get('ip')
            
            if not from_ip or not to_ip:
                return {
                    'status': 'error',
                    'message': 'IPs de las regiones no configuradas'
                }
            
            # Leer archivo de zona
            with open(zone_file, 'r') as f:
                zone_content = f.read()
            
            # Actualizar cada registro DNS
            results = {}
            
            for record_name in dns_records:
                # Reemplazar IP en el archivo de zona
                pattern = f'^{record_name}[. ]*IN[ ]*A[ ]*{from_ip}$'
                replacement = f'{record_name}. IN A {to_ip}'
                
                import re
                updated_zone_content = re.sub(pattern, replacement, zone_content, flags=re.MULTILINE)
                
                if updated_zone_content != zone_content:
                    zone_content = updated_zone_content
                    results[record_name] = {
                        'status': True,
                        'message': f'Registro {record_name} actualizado',
                        'from_ip': from_ip,
                        'to_ip': to_ip
                    }
                else:
                    results[record_name] = {
                        'status': False,
                        'message': f'Registro {record_name} no encontrado o no actualizado',
                        'from_ip': from_ip,
                        'to_ip': to_ip
                    }
            
            # Escribir archivo de zona actualizado
            with open(zone_file, 'w') as f:
                f.write(zone_content)
            
            # Recargar BIND
            subprocess.run(['systemctl', 'reload', 'named'], check=True)
            
            return {
                'status': 'success',
                'message': 'Registros DNS de BIND actualizados',
                'results': results
            }
        except Exception as e:
            logger.error(f"Error al actualizar registros DNS de BIND: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al actualizar registros DNS de BIND: {e}'
            }
    
    def update_region_roles(self, from_region, to_region):
        """
        Actualiza roles de las regiones
        
        Args:
            from_region: Región de origen
            to_region: Región de destino
        """
        # Actualizar roles en la configuración
        self.regions[from_region]['role'] = 'secondary'
        self.regions[to_region]['role'] = 'primary'
        
        # Guardar en la base de datos
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Actualizar estado de regiones
        cursor.execute('''
            UPDATE region_status
            SET is_primary = 0, updated_at = ?
            WHERE region_name = ?
        ''', (datetime.now().isoformat(), from_region))
        
        cursor.execute('''
            UPDATE region_status
            SET is_primary = 1, updated_at = ?
            WHERE region_name = ?
        ''', (datetime.now().isoformat(), to_region))
        
        conn.commit()
        conn.close()
    
    def save_failover_event(self, from_region, to_region, reason, status, error_message=None):
        """
        Guarda un evento de failover en la base de datos
        
        Args:
            from_region: Región de origen
            to_region: Región de destino
            reason: Razón del failover
            status: Estado del failover
            error_message: Mensaje de error (opcional)
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO failover_events (
                from_region, to_region, reason, status, created_at, error_message
            )
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (
            from_region, to_region, reason, status,
            datetime.now().isoformat(), error_message
        ))
        
        conn.commit()
        conn.close()
    
    def check_region_health(self, region_name):
        """
        Verifica el estado de salud de una región
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con estado de salud de la región
        """
        if region_name not in self.regions:
            return {
                'status': 'error',
                'message': f'Región {region_name} no configurada'
            }
        
        region_config = self.regions[region_name]
        health_check_url = region_config.get('health_check_url')
        
        if not health_check_url:
            return {
                'status': 'warning',
                'message': f'URL de verificación de salud no configurada para {region_name}'
            }
        
        try:
            # Realizar verificación de salud
            response = requests.get(
                health_check_url,
                timeout=self.config.get('health_check_timeout', 10)
            )
            
            if response.status_code == 200:
                return {
                    'status': 'healthy',
                    'message': f'Región {region_name} saludable',
                    'response_time': response.elapsed.total_seconds()
                }
            else:
                return {
                    'status': 'unhealthy',
                    'message': f'Región {region_name} no saludable: HTTP {response.status_code}',
                    'response_time': response.elapsed.total_seconds()
                }
        except Exception as e:
            return {
                'status': 'unhealthy',
                'message': f'Error al verificar salud de {region_name}: {e}',
                'response_time': 0
            }
    
    def check_all_regions_health(self):
        """
        Verifica el estado de salud de todas las regiones
        
        Returns:
            Diccionario con estado de salud de las regiones
        """
        results = {}
        
        for region_name, region_config in self.regions.items():
            if not region_config.get('enabled', True):
                continue
            
            # Verificar salud
            health_result = self.check_region_health(region_name)
            results[region_name] = health_result
            
            # Actualizar estado en la base de datos
            self.update_region_status(region_name, health_result.get('status') == 'healthy')
        
        return results
    
    def update_region_status(self, region_name, is_healthy):
        """
        Actualiza el estado de una región en la base de datos
        
        Args:
            region_name: Nombre de la región
            is_healthy: Si la región está saludable
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Obtener estado actual
        cursor.execute('''
            SELECT consecutive_failures FROM region_status
            WHERE region_name = ?
        ''', (region_name,))
        
        result = cursor.fetchone()
        
        if result:
            consecutive_failures = result[0]
            
            if is_healthy:
                # Restablecer contador de fallos
                cursor.execute('''
                    UPDATE region_status
                    SET is_healthy = 1, consecutive_failures = 0, last_check = ?, updated_at = ?
                    WHERE region_name = ?
                ''', (datetime.now().isoformat(), datetime.now().isoformat(), region_name))
            else:
                # Incrementar contador de fallos
                cursor.execute('''
                    UPDATE region_status
                    SET is_healthy = 0, consecutive_failures = consecutive_failures + 1, last_check = ?, updated_at = ?
                    WHERE region_name = ?
                ''', (datetime.now().isoformat(), datetime.now().isoformat(), region_name))
        else:
            # Insertar nuevo estado
            consecutive_failures = 0 if is_healthy else 1
            
            cursor.execute('''
                INSERT INTO region_status (
                    region_name, is_primary, is_healthy, last_check,
                    consecutive_failures, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (
                region_name, region_name == self.current_primary,
                is_healthy, datetime.now().isoformat(),
                consecutive_failures, datetime.now().isoformat()
            ))
        
        conn.commit()
        conn.close()
    
    def check_failover_conditions(self):
        """
        Verifica si se deben cumplir las condiciones de failover
        
        Returns:
            Diccionario con resultado de la verificación
        """
        if self.failover_in_progress:
            return {
                'status': 'skip',
                'message': 'Failover ya en progreso'
            }
        
        if not self.config.get('auto_failover_enabled', True):
            return {
                'status': 'skip',
                'message': 'Failover automático deshabilitado'
            }
        
        # Verificar salud de la región primaria
        primary_health = self.check_region_health(self.current_primary)
        
        if primary_health.get('status') == 'healthy':
            return {
                'status': 'skip',
                'message': f'Región primaria {self.current_primary} saludable'
            }
        
        # Obtener contador de fallos consecutivos
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT consecutive_failures FROM region_status
            WHERE region_name = ?
        ''', (self.current_primary,))
        
        result = cursor.fetchone()
        conn.close()
        
        if not result:
            return {
                'status': 'skip',
                'message': f'No se encontró estado para la región {self.current_primary}'
            }
        
        consecutive_failures = result[0]
        failover_threshold = self.config.get('failover_threshold', 3)
        
        if consecutive_failures < failover_threshold:
            return {
                'status': 'skip',
                'message': f'Contador de fallos ({consecutive_failures}) inferior al umbral ({failover_threshold})'
            }
        
        # Determinar región de destino para failover
        target_region = None
        
        if self.secondary_region in self.regions and self.regions[self.secondary_region].get('enabled', True):
            secondary_health = self.check_region_health(self.secondary_region)
            
            if secondary_health.get('status') == 'healthy':
                target_region = self.secondary_region
        
        if not target_region and self.tertiary_region in self.regions and self.regions[self.tertiary_region].get('enabled', True):
            tertiary_health = self.check_region_health(self.tertiary_region)
            
            if tertiary_health.get('status') == 'healthy':
                target_region = self.tertiary_region
        
        if not target_region:
            return {
                'status': 'error',
                'message': 'No hay regiones saludables para failover'
            }
        
        # Programar failover
        reason = f'Failover automático: {consecutive_failures} fallos consecutivos en {self.current_primary}'
        
        failover_result = self.schedule_failover(self.current_primary, target_region, reason)
        
        return {
            'status': 'success',
            'message': f'Failover automático programado de {self.current_primary} a {target_region}',
            'reason': reason,
            'failover_result': failover_result
        }
    
    def schedule_failover(self, from_region, to_region, reason):
        """
        Programa un failover
        
        Args:
            from_region: Región de origen
            to_region: Región de destino
            reason: Razón del failover
            
        Returns:
            Diccionario con resultado de la programación
        """
        # Crear tarea de failover
        task = {
            'operation': 'failover',
            'from_region': from_region,
            'to_region': to_region,
            'reason': reason,
            'created_at': datetime.now().isoformat()
        }
        
        # Agregar a la cola
        self.failover_queue.put(task)
        
        return {
            'status': 'success',
            'message': f'Failover programado de {from_region} a {to_region}',
            'from_region': from_region,
            'to_region': to_region,
            'reason': reason
        }
    
    def get_failover_history(self, hours=24):
        """
        Obtiene el historial de failover
        
        Args:
            hours: Horas de historial a obtener
            
        Returns:
            Lista con historial de failover
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT from_region, to_region, reason, status, created_at, completed_at, error_message
            FROM failover_events
            WHERE created_at > datetime('now', '-{} hours')
            ORDER BY created_at DESC
        '''.format(hours))
        
        results = []
        for row in cursor.fetchall():
            results.append({
                'from_region': row[0],
                'to_region': row[1],
                'reason': row[2],
                'status': row[3],
                'created_at': row[4],
                'completed_at': row[5],
                'error_message': row[6]
            })
        
        conn.close()
        
        return results
    
    def get_current_primary(self):
        """
        Obtiene la región primaria actual
        
        Returns:
            Nombre de la región primaria actual
        """
        return self.current_primary
    
    def get_failover_status(self):
        """
        Obtiene el estado de failover
        
        Returns:
            Diccionario con estado de failover
        """
        return {
            'current_primary': self.current_primary,
            'failover_in_progress': self.failover_in_progress,
            'auto_failover_enabled': self.config.get('auto_failover_enabled', True)
        }

def main():
    """Función principal"""
    parser = argparse.ArgumentParser(description='Gestión de Disaster Recovery')
    parser.add_argument('--config', help='Ruta al archivo de configuración')
    parser.add_argument('--action', choices=['health', 'check', 'failover', 'history', 'status'],
                       default='status', help='Acción a realizar')
    parser.add_argument('--from', help='Región de origen')
    parser.add_argument('--to', help='Región de destino')
    parser.add_argument('--reason', help='Razón del failover')
    parser.add_argument('--hours', type=int, default=24, help='Horas de historial')
    
    args = parser.parse_args()
    
    # Inicializar gestor de disaster recovery
    disaster_recovery = DisasterRecoveryManager(args.config)
    
    if args.action == 'health':
        if not args.from:
            results = disaster_recovery.check_all_regions_health()
        else:
            results = disaster_recovery.check_region_health(args.from)
        
        print(json.dumps(results, indent=2))
        
    elif args.action == 'check':
        result = disaster_recovery.check_failover_conditions()
        print(json.dumps(result, indent=2))
        
    elif args.action == 'failover':
        if not args.from or not args.to:
            print("Error: Se requieren --from y --to para realizar failover")
            sys.exit(1)
        
        reason = args.reason or 'Manual failover'
        
        result = disaster_recovery.schedule_failover(args.from, args.to, reason)
        print(json.dumps(result, indent=2))
        
    elif args.action == 'history':
        results = disaster_recovery.get_failover_history(args.hours)
        print(json.dumps(results, indent=2))
        
    elif args.action == 'status':
        result = disaster_recovery.get_failover_status()
        print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
EOF
    
    # Hacer el script ejecutable
    chmod +x "${dr_script}"
    
    # Crear configuración de disaster recovery
    local dr_config="${CONFIG_DIR}/disaster-recovery/disaster_recovery_config.json"
    
    cat > "${dr_config}" << 'EOF'
{
    "primary_region": "us-east-1",
    "secondary_region": "us-west-2",
    "tertiary_region": "eu-west-1",
    "regions": {
        "us-east-1": {
            "name": "US East",
            "ip": "192.168.1.10",
            "port": 22,
            "username": "admin",
            "password": "password",
            "role": "primary",
            "enabled": true,
            "health_check_url": "http://192.168.1.10/health"
        },
        "us-west-2": {
            "name": "US West",
            "ip": "192.168.2.10",
            "port": 22,
            "username": "admin",
            "password": "password",
            "role": "secondary",
            "enabled": true,
            "health_check_url": "http://192.168.2.10/health"
        },
        "eu-west-1": {
            "name": "Europe West",
            "ip": "192.168.3.10",
            "port": 22,
            "username": "admin",
            "password": "password",
            "role": "tertiary",
            "enabled": true,
            "health_check_url": "http://192.168.3.10/health"
        }
    },
    "health_check_interval": 30,
    "health_check_timeout": 10,
    "failover_threshold": 3,
    "failover_timeout": 300,
    "auto_failover_enabled": true,
    "dns_provider": "cloudflare",
    "dns_records": [
        "virtualmin.local",
        "api.virtualmin.local",
        "mail.virtualmin.local"
    ],
    "cloudflare": {
        "api_token": "your_cloudflare_api_token",
        "zone_id": "your_cloudflare_zone_id"
    },
    "route53": {
        "hosted_zone_id": "your_route53_hosted_zone_id",
        "access_key": "your_aws_access_key",
        "secret_key": "your_aws_secret_key",
        "region": "us-east-1"
    },
    "bind": {
        "zone_file": "/etc/bind/db.virtualmin.local"
    }
}
EOF
    
    # Copiar archivos al sistema
    mkdir -p "/etc/multi-region-deployment/disaster-recovery"
    mkdir -p "/var/lib/disaster_recovery"
    cp "${dr_script}" "/usr/local/bin/disaster_recovery_manager.py"
    cp "${dr_config}" "/etc/multi-region-deployment/disaster-recovery/disaster_recovery_config.json"
    
    # Crear servicio systemd para disaster recovery
    local dr_service="${CONFIG_DIR}/disaster-recovery/disaster-recovery.service"
    
    cat > "${dr_service}" << 'EOF'
[Unit]
Description=Disaster Recovery Manager Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/disaster_recovery_manager.py --config /etc/multi-region-deployment/disaster-recovery/disaster_recovery_config.json --action health
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF
    
    # Crear servicio systemd para verificación de failover
    local dr_check_service="${CONFIG_DIR}/disaster-recovery/disaster-recovery-check.service"
    
    cat > "${dr_check_service}" << 'EOF'
[Unit]
Description=Disaster Recovery Check Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 /usr/local/bin/disaster_recovery_manager.py --config /etc/multi-region-deployment/disaster-recovery/disaster_recovery_config.json --action check

[Install]
WantedBy=multi-user.target
EOF
    
    # Crear temporizador systemd para verificación de failover
    local dr_check_timer="${CONFIG_DIR}/disaster-recovery/disaster-recovery-check.timer"
    
    cat > "${dr_check_timer}" << 'EOF'
[Unit]
Description=Run Disaster Recovery Check

[Timer]
OnCalendar=*:*:0/5

[Install]
WantedBy=timers.target
EOF
    
    # Copiar servicio y temporizador al sistema
    cp "${dr_service}" "/etc/systemd/system/disaster-recovery.service"
    cp "${dr_check_service}" "/etc/systemd/system/disaster-recovery-check.service"
    cp "${dr_check_timer}" "/etc/systemd/system/disaster-recovery-check.timer"
    
    # Habilitar y arrancar servicios
    systemctl daemon-reload
    systemctl enable disaster-recovery.service
    systemctl start disaster-recovery.service
    
    systemctl enable disaster-recovery-check.timer
    systemctl start disaster-recovery-check.timer
    
    success "✅ Disaster recovery con failover regional configurado"
}

# 📋 **Función para implementar cumplimiento normativo localizado**
setup_localized_compliance() {
    log "📋 Implementando cumplimiento normativo localizado"
    
    # Crear directorio de configuración si no existe
    mkdir -p "${CONFIG_DIR}/localized-compliance"
    
    # Crear script de gestión de cumplimiento normativo
    local compliance_script="${CONFIG_DIR}/localized-compliance/localized_compliance_manager.py"
    
    cat > "${compliance_script}" << 'EOF'
#!/usr/bin/env python3
"""
Script de Gestión de Cumplimiento Normativo Localizado para Virtualmin Pro
"""

import os
import sys
import json
import time
import logging
import argparse
import subprocess
import threading
import queue
from datetime import datetime, timedelta
import sqlite3
import requests

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileWriter('/var/log/localized_compliance_manager.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

class LocalizedComplianceManager:
    def __init__(self, config_file=None):
        """
        Inicializa el gestor de cumplimiento normativo localizado
        
        Args:
            config_file: Ruta al archivo de configuración
        """
        self.config = self.load_config(config_file)
        self.regions = self.config.get('regions', {})
        
        # Inicializar base de datos
        self.init_database()
        
        # Iniciar cola de verificación de cumplimiento
        self.compliance_queue = queue.Queue()
        
        # Iniciar hilos de verificación de cumplimiento
        self.start_compliance_workers()
    
    def load_config(self, config_file):
        """
        Carga configuración desde archivo
        
        Args:
            config_file: Ruta al archivo de configuración
            
        Returns:
            Diccionario con configuración
        """
        default_config = {
            'regions': {
                'us-east-1': {
                    'name': 'US East',
                    'country': 'US',
                    'state': 'VA',
                    'compliance_frameworks': ['CIS', 'NIST', 'HIPAA', 'PCI DSS'],
                    'data_residency': 'US',
                    'enabled': True
                },
                'us-west-2': {
                    'name': 'US West',
                    'country': 'US',
                    'state': 'CA',
                    'compliance_frameworks': ['CIS', 'NIST', 'CCPA', 'PCI DSS'],
                    'data_residency': 'US',
                    'enabled': True
                },
                'eu-west-1': {
                    'name': 'Europe West',
                    'country': 'IE',
                    'state': 'Dublin',
                    'compliance_frameworks': ['CIS', 'NIST', 'GDPR'],
                    'data_residency': 'EU',
                    'enabled': True
                }
            },
            'compliance_frameworks': {
                'CIS': {
                    'name': 'Center for Internet Security',
                    'version': 'CIS Controls v8',
                    'checks': [
                        'inventory_and_control_of_hardware_assets',
                        'inventory_and_control_of_software_assets',
                        'continuous_vulnerability_management',
                        'controlled_use_of_administrative_privileges',
                        'configuration_baseline_database',
                        'configuration_baseline_operating_system',
                        'email_and_web_browser_protections',
                        'malware_defenses',
                        'data_recovery',
                        'secure_configuration_for_network_infrastructure',
                        'network_monitoring_and_defense',
                        'secure_configuration_for_network_devices',
                        'boundary_defense',
                        'data_protection',
                        'access_control_management',
                        'audit_log_management',
                        'information_protection_processes_and_procedures',
                        'incident_response_management',
                        'penetration_testing',
                        'security_awareness_and_training'
                    ]
                },
                'NIST': {
                    'name': 'National Institute of Standards and Technology',
                    'version': 'NIST SP 800-53 Rev. 5',
                    'checks': [
                        'access_control',
                        'audit_and_accountability',
                        'awareness_and_training',
                        'configuration_management',
                        'contingency_planning',
                        'identification_and_authentication',
                        'incident_response',
                        'maintenance',
                        'media_protection',
                        'physical_and_environmental_protection',
                        'planning',
                        'risk_assessment',
                        'system_and_communications_protection',
                        'system_and_information_integrity'
                    ]
                },
                'GDPR': {
                    'name': 'General Data Protection Regulation',
                    'version': 'GDPR 2016/679',
                    'checks': [
                        'lawfulness_fairness_and_transparency',
                        'purpose_limitation',
                        'data_minimisation',
                        'accuracy',
                        'storage_limitation',
                        'integrity_and_confidentiality',
                        'accountability'
                    ]
                },
                'HIPAA': {
                    'name': 'Health Insurance Portability and Accountability Act',
                    'version': 'HIPAA 2003',
                    'checks': [
                        'administrative_safeguards',
                        'physical_safeguards',
                        'technical_safeguards'
                    ]
                },
                'PCI DSS': {
                    'name': 'Payment Card Industry Data Security Standard',
                    'version': 'PCI DSS v4.0',
                    'checks': [
                        'network_security',
                        'access_control_measures',
                        'vulnerability_management_program',
                        'secure_software_development',
                        'secure_cardholder_data_environment',
                        'secure_authentication',
                        'monitoring_and_testing',
                        'information_security_policy'
                    ]
                },
                'CCPA': {
                    'name': 'California Consumer Privacy Act',
                    'version': 'CCPA 2018',
                    'checks': [
                        'right_to_know',
                        'right_to_delete',
                        'right_to_opt_out',
                        'right_to_non_discrimination'
                    ]
                }
            },
            'check_interval': 86400,  # 24 horas
            'report_retention_days': 90,
            'notification_email': 'admin@virtualmin.local'
        }
        
        if config_file and os.path.exists(config_file):
            with open(config_file, 'r') as f:
                config = json.load(f)
                default_config.update(config)
        
        return default_config
    
    def init_database(self):
        """Inicializa base de datos de cumplimiento normativo"""
        self.db_path = self.config.get('database_path', '/var/lib/localized_compliance/compliance.db')
        
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Crear tabla de verificaciones de cumplimiento
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS compliance_checks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                region_name TEXT NOT NULL,
                framework_name TEXT NOT NULL,
                check_name TEXT NOT NULL,
                status TEXT NOT NULL,
                result TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT
            )
        ''')
        
        # Crear tabla de informes de cumplimiento
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS compliance_reports (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                region_name TEXT NOT NULL,
                framework_name TEXT NOT NULL,
                report_data TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
        ''')
        
        # Crear tabla de configuración de cumplimiento
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS compliance_config (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                region_name TEXT NOT NULL,
                framework_name TEXT NOT NULL,
                check_name TEXT NOT NULL,
                enabled BOOLEAN DEFAULT TRUE,
                config_data TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        ''')
        
        conn.commit()
        conn.close()
        
        logger.info("Base de datos de cumplimiento normativo inicializada")
    
    def start_compliance_workers(self):
        """Inicia hilos de verificación de cumplimiento"""
        import threading
        
        def compliance_worker():
            while True:
                try:
                    # Obtener tarea de verificación de cumplimiento
                    try:
                        task = self.compliance_queue.get(timeout=10)
                        
                        # Procesar tarea
                        self.process_compliance_task(task)
                        
                        # Marcar tarea como completada
                        self.compliance_queue.task_done()
                    except queue.Empty:
                        continue
                    
                except Exception as e:
                    logger.error(f"Error en el trabajador de cumplimiento: {e}")
                    time.sleep(60)
        
        # Iniciar hilo de verificación de cumplimiento
        self.compliance_thread = threading.Thread(target=compliance_worker, daemon=True)
        self.compliance_thread.start()
        
        logger.info("Hilo de verificación de cumplimiento iniciado")
    
    def process_compliance_task(self, task):
        """
        Procesa una tarea de verificación de cumplimiento
        
        Args:
            task: Tarea de verificación de cumplimiento
        """
        try:
            operation = task.get('operation')
            region_name = task.get('region_name')
            framework_name = task.get('framework_name')
            check_name = task.get('check_name')
            
            if operation == 'check':
                # Realizar verificación
                result = self.perform_compliance_check(region_name, framework_name, check_name)
                
                # Actualizar estado de la tarea
                task['status'] = result.get('status')
                task['result'] = result.get('result')
                task['updated_at'] = datetime.now().isoformat()
                
                logger.info(f"Tarea de verificación de cumplimiento procesada: {result.get('message')}")
        except Exception as e:
            logger.error(f"Error al procesar tarea de verificación de cumplimiento: {e}")
            
            # Actualizar estado de la tarea con error
            task['status'] = 'error'
            task['result'] = f'Error al procesar tarea: {e}'
            task['updated_at'] = datetime.now().isoformat()
    
    def perform_compliance_check(self, region_name, framework_name, check_name):
        """
        Realiza una verificación de cumplimiento
        
        Args:
            region_name: Nombre de la región
            framework_name: Nombre del marco de cumplimiento
            check_name: Nombre de la verificación
            
        Returns:
            Diccionario con resultado de la verificación
        """
        if region_name not in self.regions:
            return {
                'status': 'error',
                'message': f'Región {region_name} no configurada'
            }
        
        if framework_name not in self.config.get('compliance_frameworks', {}):
            return {
                'status': 'error',
                'message': f'Marco de cumplimiento {framework_name} no configurado'
            }
        
        region_config = self.regions[region_name]
        framework_config = self.config['compliance_frameworks'][framework_name]
        
        if framework_name not in region_config.get('compliance_frameworks', []):
            return {
                'status': 'skip',
                'message': f'Marco de cumplimiento {framework_name} no aplicable a la región {region_name}'
            }
        
        try:
            # Realizar verificación según marco de cumplimiento
            if framework_name == 'CIS':
                result = self.check_cis_compliance(region_name, check_name)
            elif framework_name == 'NIST':
                result = self.check_nist_compliance(region_name, check_name)
            elif framework_name == 'GDPR':
                result = self.check_gdpr_compliance(region_name, check_name)
            elif framework_name == 'HIPAA':
                result = self.check_hipaa_compliance(region_name, check_name)
            elif framework_name == 'PCI DSS':
                result = self.check_pci_dss_compliance(region_name, check_name)
            elif framework_name == 'CCPA':
                result = self.check_ccpa_compliance(region_name, check_name)
            else:
                result = {
                    'status': 'error',
                    'message': f'Marco de cumplimiento {framework_name} no soportado'
                }
            
            # Guardar resultado en la base de datos
            self.save_compliance_check(region_name, framework_name, check_name, result.get('status'), result.get('result'))
            
            return result
        except Exception as e:
            logger.error(f"Error al realizar verificación de cumplimiento: {e}")
            
            # Guardar resultado en la base de datos
            self.save_compliance_check(region_name, framework_name, check_name, 'error', str(e))
            
            return {
                'status': 'error',
                'message': f'Error al realizar verificación de cumplimiento: {e}'
            }
    
    def check_cis_compliance(self, region_name, check_name):
        """
        Realiza una verificación de cumplimiento CIS
        
        Args:
            region_name: Nombre de la región
            check_name: Nombre de la verificación
            
        Returns:
            Diccionario con resultado de la verificación
        """
        # Implementar verificaciones específicas de CIS
        if check_name == 'inventory_and_control_of_hardware_assets':
            return self.check_cis_hardware_inventory(region_name)
        elif check_name == 'inventory_and_control_of_software_assets':
            return self.check_cis_software_inventory(region_name)
        elif check_name == 'continuous_vulnerability_management':
            return self.check_cis_vulnerability_management(region_name)
        elif check_name == 'controlled_use_of_administrative_privileges':
            return self.check_cis_admin_privileges(region_name)
        elif check_name == 'configuration_baseline_database':
            return self.check_cis_database_baseline(region_name)
        elif check_name == 'configuration_baseline_operating_system':
            return self.check_cis_os_baseline(region_name)
        elif check_name == 'email_and_web_browser_protections':
            return self.check_cis_email_browser_protections(region_name)
        elif check_name == 'malware_defenses':
            return self.check_cis_malware_defenses(region_name)
        elif check_name == 'data_recovery':
            return self.check_cis_data_recovery(region_name)
        elif check_name == 'secure_configuration_for_network_infrastructure':
            return self.check_cis_network_infrastructure(region_name)
        elif check_name == 'network_monitoring_and_defense':
            return self.check_cis_network_monitoring(region_name)
        elif check_name == 'secure_configuration_for_network_devices':
            return self.check_cis_network_devices(region_name)
        elif check_name == 'boundary_defense':
            return self.check_cis_boundary_defense(region_name)
        elif check_name == 'data_protection':
            return self.check_cis_data_protection(region_name)
        elif check_name == 'access_control_management':
            return self.check_cis_access_control(region_name)
        elif check_name == 'audit_log_management':
            return self.check_cis_audit_log_management(region_name)
        elif check_name == 'information_protection_processes_and_procedures':
            return self.check_cis_info_protection(region_name)
        elif check_name == 'incident_response_management':
            return self.check_cis_incident_response(region_name)
        elif check_name == 'penetration_testing':
            return self.check_cis_penetration_testing(region_name)
        elif check_name == 'security_awareness_and_training':
            return self.check_cis_security_training(region_name)
        else:
            return {
                'status': 'warning',
                'message': f'Verificación CIS {check_name} no implementada',
                'result': 'not_implemented'
            }
    
    def check_cis_hardware_inventory(self, region_name):
        """
        Verifica el inventario y control de activos de hardware CIS
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con resultado de la verificación
        """
        try:
            # Obtener lista de hardware
            hardware_list = self.get_hardware_list(region_name)
            
            # Verificar si todos los dispositivos están en el inventario
            inventory_complete = True
            missing_devices = []
            
            for device in hardware_list:
                if not device.get('inventoried', False):
                    inventory_complete = False
                    missing_devices.append(device.get('name', 'unknown'))
            
            if inventory_complete:
                return {
                    'status': 'pass',
                    'message': 'Inventario de hardware completo y actualizado',
                    'result': {
                        'total_devices': len(hardware_list),
                        'inventory_complete': True
                    }
                }
            else:
                return {
                    'status': 'fail',
                    'message': f'Dispositivos faltantes en el inventario: {", ".join(missing_devices)}',
                    'result': {
                        'total_devices': len(hardware_list),
                        'inventory_complete': False,
                        'missing_devices': missing_devices
                    }
                }
        except Exception as e:
            logger.error(f"Error al verificar inventario de hardware CIS: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al verificar inventario de hardware CIS: {e}'
            }
    
    def get_hardware_list(self, region_name):
        """
        Obtiene la lista de hardware de una región
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Lista con dispositivos de hardware
        """
        # Implementar lógica para obtener lista de hardware
        # Por ahora, devolver una lista vacía
        return []
    
    def check_cis_software_inventory(self, region_name):
        """
        Verifica el inventario y control de activos de software CIS
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con resultado de la verificación
        """
        try:
            # Obtener lista de software
            software_list = self.get_software_list(region_name)
            
            # Verificar si todo el software está en el inventario
            inventory_complete = True
            missing_software = []
            
            for software in software_list:
                if not software.get('inventoried', False):
                    inventory_complete = False
                    missing_software.append(software.get('name', 'unknown'))
            
            # Verificar si hay software no autorizado
            unauthorized_software = []
            
            for software in software_list:
                if not software.get('authorized', True):
                    unauthorized_software.append(software.get('name', 'unknown'))
            
            if inventory_complete and not unauthorized_software:
                return {
                    'status': 'pass',
                    'message': 'Inventario de software completo y autorizado',
                    'result': {
                        'total_software': len(software_list),
                        'inventory_complete': True,
                        'unauthorized_software': []
                    }
                }
            else:
                return {
                    'status': 'fail',
                    'message': f'Problemas en el inventario de software',
                    'result': {
                        'total_software': len(software_list),
                        'inventory_complete': inventory_complete,
                        'missing_software': missing_software,
                        'unauthorized_software': unauthorized_software
                    }
                }
        except Exception as e:
            logger.error(f"Error al verificar inventario de software CIS: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al verificar inventario de software CIS: {e}'
            }
    
    def get_software_list(self, region_name):
        """
        Obtiene la lista de software de una región
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Lista con software
        """
        # Implementar lógica para obtener lista de software
        # Por ahora, devolver una lista vacía
        return []
    
    def check_cis_vulnerability_management(self, region_name):
        """
        Verifica la gestión continua de vulnerabilidades CIS
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con resultado de la verificación
        """
        try:
            # Obtener resultados de escaneo de vulnerabilidades
            vulnerability_results = self.get_vulnerability_scan_results(region_name)
            
            # Verificar si hay vulnerabilidades críticas o altas
            critical_vulnerabilities = []
            high_vulnerabilities = []
            
            for vuln in vulnerability_results:
                severity = vuln.get('severity', '').lower()
                
                if severity == 'critical':
                    critical_vulnerabilities.append(vuln)
                elif severity == 'high':
                    high_vulnerabilities.append(vuln)
            
            if not critical_vulnerabilities and not high_vulnerabilities:
                return {
                    'status': 'pass',
                    'message': 'No hay vulnerabilidades críticas o altas',
                    'result': {
                        'total_vulnerabilities': len(vulnerability_results),
                        'critical_vulnerabilities': len(critical_vulnerabilities),
                        'high_vulnerabilities': len(high_vulnerabilities)
                    }
                }
            else:
                return {
                    'status': 'fail',
                    'message': f'Se encontraron {len(critical_vulnerabilities)} vulnerabilidades críticas y {len(high_vulnerabilities)} vulnerabilidades altas',
                    'result': {
                        'total_vulnerabilities': len(vulnerability_results),
                        'critical_vulnerabilities': len(critical_vulnerabilities),
                        'high_vulnerabilities': len(high_vulnerabilities)
                    }
                }
        except Exception as e:
            logger.error(f"Error al verificar gestión de vulnerabilidades CIS: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al verificar gestión de vulnerabilidades CIS: {e}'
            }
    
    def get_vulnerability_scan_results(self, region_name):
        """
        Obtiene los resultados de escaneo de vulnerabilidades
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Lista con resultados de escaneo
        """
        # Implementar lógica para obtener resultados de escaneo de vulnerabilidades
        # Por ahora, devolver una lista vacía
        return []
    
    def check_cis_admin_privileges(self, region_name):
        """
        Verifica el uso controlado de privilegios administrativos CIS
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con resultado de la verificación
        """
        try:
            # Obtener lista de usuarios con privilegios administrativos
            admin_users = self.get_admin_users(region_name)
            
            # Verificar si los usuarios administrativos tienen MFA
            mfa_enabled_users = []
            mfa_disabled_users = []
            
            for user in admin_users:
                if user.get('mfa_enabled', False):
                    mfa_enabled_users.append(user.get('username', 'unknown'))
                else:
                    mfa_disabled_users.append(user.get('username', 'unknown'))
            
            # Verificar si se utilizan cuentas de servicio
            service_accounts = self.get_service_accounts(region_name)
            
            if not mfa_disabled_users and len(service_accounts) <= 5:
                return {
                    'status': 'pass',
                    'message': 'Privilegios administrativos controlados correctamente',
                    'result': {
                        'total_admin_users': len(admin_users),
                        'mfa_enabled_users': len(mfa_enabled_users),
                        'mfa_disabled_users': len(mfa_disabled_users),
                        'total_service_accounts': len(service_accounts)
                    }
                }
            else:
                return {
                    'status': 'fail',
                    'message': f'Problemas con privilegios administrativos: {len(mfa_disabled_users)} usuarios sin MFA, {len(service_accounts)} cuentas de servicio',
                    'result': {
                        'total_admin_users': len(admin_users),
                        'mfa_enabled_users': len(mfa_enabled_users),
                        'mfa_disabled_users': mfa_disabled_users,
                        'total_service_accounts': len(service_accounts)
                    }
                }
        except Exception as e:
            logger.error(f"Error al verificar privilegios administrativos CIS: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al verificar privilegios administrativos CIS: {e}'
            }
    
    def get_admin_users(self, region_name):
        """
        Obtiene la lista de usuarios administrativos
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Lista con usuarios administrativos
        """
        # Implementar lógica para obtener usuarios administrativos
        # Por ahora, devolver una lista vacía
        return []
    
    def get_service_accounts(self, region_name):
        """
        Obtiene la lista de cuentas de servicio
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Lista con cuentas de servicio
        """
        # Implementar lógica para obtener cuentas de servicio
        # Por ahora, devolver una lista vacía
        return []
    
    def check_cis_database_baseline(self, region_name):
        """
        Verifica la línea base de configuración de base de datos CIS
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con resultado de la verificación
        """
        try:
            # Obtener configuración de base de datos
            db_config = self.get_database_config(region_name)
            
            # Verificar configuración recomendada
            config_issues = []
            
            # Verificar si las credenciales no son por defecto
            if db_config.get('default_credentials', True):
                config_issues.append('Credenciales por defecto')
            
            # Verificar si el puerto no es el predeterminado
            if db_config.get('default_port', True):
                config_issues.append('Puerto predeterminado')
            
            # Verificar si el acceso remoto está restringido
            if not db_config.get('remote_access_restricted', True):
                config_issues.append('Acceso remoto no restringido')
            
            # Verificar si el cifrado está habilitado
            if not db_config.get('encryption_enabled', True):
                config_issues.append('Cifrado no habilitado')
            
            if not config_issues:
                return {
                    'status': 'pass',
                    'message': 'Configuración de base de datos cumple con línea base CIS',
                    'result': {
                        'config_issues': [],
                        'compliant': True
                    }
                }
            else:
                return {
                    'status': 'fail',
                    'message': f'Configuración de base de datos no cumple con línea base CIS: {", ".join(config_issues)}',
                    'result': {
                        'config_issues': config_issues,
                        'compliant': False
                    }
                }
        except Exception as e:
            logger.error(f"Error al verificar línea base de base de datos CIS: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al verificar línea base de base de datos CIS: {e}'
            }
    
    def get_database_config(self, region_name):
        """
        Obtiene la configuración de base de datos
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con configuración de base de datos
        """
        # Implementar lógica para obtener configuración de base de datos
        # Por ahora, devolver una configuración por defecto
        return {
            'default_credentials': True,
            'default_port': True,
            'remote_access_restricted': False,
            'encryption_enabled': False
        }
    
    def check_nist_compliance(self, region_name, check_name):
        """
        Realiza una verificación de cumplimiento NIST
        
        Args:
            region_name: Nombre de la región
            check_name: Nombre de la verificación
            
        Returns:
            Diccionario con resultado de la verificación
        """
        # Implementar verificaciones específicas de NIST
        if check_name == 'access_control':
            return self.check_nist_access_control(region_name)
        elif check_name == 'audit_and_accountability':
            return self.check_nist_audit_accountability(region_name)
        elif check_name == 'awareness_and_training':
            return self.check_nist_awareness_training(region_name)
        elif check_name == 'configuration_management':
            return self.check_nist_configuration_management(region_name)
        elif check_name == 'contingency_planning':
            return self.check_nist_contingency_planning(region_name)
        elif check_name == 'identification_and_authentication':
            return self.check_nist_identification_authentication(region_name)
        elif check_name == 'incident_response':
            return self.check_nist_incident_response(region_name)
        elif check_name == 'maintenance':
            return self.check_nist_maintenance(region_name)
        elif check_name == 'media_protection':
            return self.check_nist_media_protection(region_name)
        elif check_name == 'physical_and_environmental_protection':
            return self.check_nist_physical_environmental_protection(region_name)
        elif check_name == 'planning':
            return self.check_nist_planning(region_name)
        elif check_name == 'risk_assessment':
            return self.check_nist_risk_assessment(region_name)
        elif check_name == 'system_and_communications_protection':
            return self.check_nist_system_communications_protection(region_name)
        elif check_name == 'system_and_information_integrity':
            return self.check_nist_system_information_integrity(region_name)
        else:
            return {
                'status': 'warning',
                'message': f'Verificación NIST {check_name} no implementada',
                'result': 'not_implemented'
            }
    
    def check_nist_access_control(self, region_name):
        """
        Verifica el control de acceso NIST
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con resultado de la verificación
        """
        try:
            # Verificar políticas de acceso
            access_policies = self.get_access_policies(region_name)
            
            # Verificar si se implementa principio de menor privilegio
            least_privilege = access_policies.get('least_privilege', False)
            
            # Verificar si se revisan regularmente los permisos
            permissions_review = access_policies.get('permissions_review', False)
            
            # Verificar si se implementan controles de acceso
            access_controls = access_policies.get('access_controls', False)
            
            if least_privilege and permissions_review and access_controls:
                return {
                    'status': 'pass',
                    'message': 'Control de acceso NIST implementado correctamente',
                    'result': {
                        'least_privilege': least_privilege,
                        'permissions_review': permissions_review,
                        'access_controls': access_controls
                    }
                }
            else:
                return {
                    'status': 'fail',
                    'message': 'Control de acceso NIST no implementado correctamente',
                    'result': {
                        'least_privilege': least_privilege,
                        'permissions_review': permissions_review,
                        'access_controls': access_controls
                    }
                }
        except Exception as e:
            logger.error(f"Error al verificar control de acceso NIST: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al verificar control de acceso NIST: {e}'
            }
    
    def get_access_policies(self, region_name):
        """
        Obtiene las políticas de acceso
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con políticas de acceso
        """
        # Implementar lógica para obtener políticas de acceso
        # Por ahora, devolver políticas por defecto
        return {
            'least_privilege': False,
            'permissions_review': False,
            'access_controls': False
        }
    
    def check_gdpr_compliance(self, region_name, check_name):
        """
        Realiza una verificación de cumplimiento GDPR
        
        Args:
            region_name: Nombre de la región
            check_name: Nombre de la verificación
            
        Returns:
            Diccionario con resultado de la verificación
        """
        # Implementar verificaciones específicas de GDPR
        if check_name == 'lawfulness_fairness_and_transparency':
            return self.check_gdpr_lawfulness_fairness_transparency(region_name)
        elif check_name == 'purpose_limitation':
            return self.check_gdpr_purpose_limitation(region_name)
        elif check_name == 'data_minimisation':
            return self.check_gdpr_data_minimisation(region_name)
        elif check_name == 'accuracy':
            return self.check_gdpr_accuracy(region_name)
        elif check_name == 'storage_limitation':
            return self.check_gdpr_storage_limitation(region_name)
        elif check_name == 'integrity_and_confidentiality':
            return self.check_gdpr_integrity_confidentiality(region_name)
        elif check_name == 'accountability':
            return self.check_gdpr_accountability(region_name)
        else:
            return {
                'status': 'warning',
                'message': f'Verificación GDPR {check_name} no implementada',
                'result': 'not_implemented'
            }
    
    def check_gdpr_lawfulness_fairness_and_transparency(self, region_name):
        """
        Verifica la licitud, equidad y transparencia GDPR
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con resultado de la verificación
        """
        try:
            # Verificar si hay políticas de privacidad
            privacy_policies = self.get_privacy_policies(region_name)
            
            # Verificar si se proporciona información transparente
            transparency = privacy_policies.get('transparency', False)
            
            # Verificar si se obtiene consentimiento explícito
            explicit_consent = privacy_policies.get('explicit_consent', False)
            
            # Verificar si se informa sobre propósito del procesamiento
            purpose_informed = privacy_policies.get('purpose_informed', False)
            
            if transparency and explicit_consent and purpose_informed:
                return {
                    'status': 'pass',
                    'message': 'Licitud, equidad y transparencia GDPR implementadas correctamente',
                    'result': {
                        'transparency': transparency,
                        'explicit_consent': explicit_consent,
                        'purpose_informed': purpose_informed
                    }
                }
            else:
                return {
                    'status': 'fail',
                    'message': 'Licitud, equidad y transparencia GDPR no implementadas correctamente',
                    'result': {
                        'transparency': transparency,
                        'explicit_consent': explicit_consent,
                        'purpose_informed': purpose_informed
                    }
                }
        except Exception as e:
            logger.error(f"Error al verificar licitud, equidad y transparencia GDPR: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al verificar licitud, equidad y transparencia GDPR: {e}'
            }
    
    def get_privacy_policies(self, region_name):
        """
        Obtiene las políticas de privacidad
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con políticas de privacidad
        """
        # Implementar lógica para obtener políticas de privacidad
        # Por ahora, devolver políticas por defecto
        return {
            'transparency': False,
            'explicit_consent': False,
            'purpose_informed': False
        }
    
    def check_hipaa_compliance(self, region_name, check_name):
        """
        Realiza una verificación de cumplimiento HIPAA
        
        Args:
            region_name: Nombre de la región
            check_name: Nombre de la verificación
            
        Returns:
            Diccionario con resultado de la verificación
        """
        # Implementar verificaciones específicas de HIPAA
        if check_name == 'administrative_safeguards':
            return self.check_hipaa_administrative_safeguards(region_name)
        elif check_name == 'physical_safeguards':
            return self.check_hipaa_physical_safeguards(region_name)
        elif check_name == 'technical_safeguards':
            return self.check_hipaa_technical_safeguards(region_name)
        else:
            return {
                'status': 'warning',
                'message': f'Verificación HIPAA {check_name} no implementada',
                'result': 'not_implemented'
            }
    
    def check_hipaa_administrative_safeguards(self, region_name):
        """
        Verifica las salvaguardias administrativas HIPAA
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con resultado de la verificación
        """
        try:
            # Verificar políticas de seguridad
            security_policies = self.get_security_policies(region_name)
            
            # Verificar si hay oficial de privacidad
            privacy_officer = security_policies.get('privacy_officer', False)
            
            # Verificar si hay formación en seguridad
            security_training = security_policies.get('security_training', False)
            
            # Verificar si hay procedimientos de respuesta a incidentes
            incident_procedures = security_policies.get('incident_procedures', False)
            
            if privacy_officer and security_training and incident_procedures:
                return {
                    'status': 'pass',
                    'message': 'Salvaguardias administrativas HIPAA implementadas correctamente',
                    'result': {
                        'privacy_officer': privacy_officer,
                        'security_training': security_training,
                        'incident_procedures': incident_procedures
                    }
                }
            else:
                return {
                    'status': 'fail',
                    'message': 'Salvaguardias administrativas HIPAA no implementadas correctamente',
                    'result': {
                        'privacy_officer': privacy_officer,
                        'security_training': security_training,
                        'incident_procedures': incident_procedures
                    }
                }
        except Exception as e:
            logger.error(f"Error al verificar salvaguardias administrativas HIPAA: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al verificar salvaguardias administrativas HIPAA: {e}'
            }
    
    def get_security_policies(self, region_name):
        """
        Obtiene las políticas de seguridad
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con políticas de seguridad
        """
        # Implementar lógica para obtener políticas de seguridad
        # Por ahora, devolver políticas por defecto
        return {
            'privacy_officer': False,
            'security_training': False,
            'incident_procedures': False
        }
    
    def check_pci_dss_compliance(self, region_name, check_name):
        """
        Realiza una verificación de cumplimiento PCI DSS
        
        Args:
            region_name: Nombre de la región
            check_name: Nombre de la verificación
            
        Returns:
            Diccionario con resultado de la verificación
        """
        # Implementar verificaciones específicas de PCI DSS
        if check_name == 'network_security':
            return self.check_pci_dss_network_security(region_name)
        elif check_name == 'access_control_measures':
            return self.check_pci_dss_access_control_measures(region_name)
        elif check_name == 'vulnerability_management_program':
            return self.check_pci_dss_vulnerability_management(region_name)
        elif check_name == 'secure_software_development':
            return self.check_pci_dss_secure_software_development(region_name)
        elif check_name == 'secure_cardholder_data_environment':
            return self.check_pci_dss_secure_cardholder_data_environment(region_name)
        elif check_name == 'secure_authentication':
            return self.check_pci_dss_secure_authentication(region_name)
        elif check_name == 'monitoring_and_testing':
            return self.check_pci_dss_monitoring_testing(region_name)
        elif check_name == 'information_security_policy':
            return self.check_pci_dss_information_security_policy(region_name)
        else:
            return {
                'status': 'warning',
                'message': f'Verificación PCI DSS {check_name} no implementada',
                'result': 'not_implemented'
            }
    
    def check_pci_dss_network_security(self, region_name):
        """
        Verifica la seguridad de red PCI DSS
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con resultado de la verificación
        """
        try:
            # Verificar configuración de firewall
            firewall_config = self.get_firewall_config(region_name)
            
            # Verificar si hay segmentación de red
            network_segmentation = firewall_config.get('network_segmentation', False)
            
            # Verificar si el tráfico está monitoreado
            traffic_monitoring = firewall_config.get('traffic_monitoring', False)
            
            # Verificar si hay control de acceso a la red
            access_control = firewall_config.get('access_control', False)
            
            if network_segmentation and traffic_monitoring and access_control:
                return {
                    'status': 'pass',
                    'message': 'Seguridad de red PCI DSS implementada correctamente',
                    'result': {
                        'network_segmentation': network_segmentation,
                        'traffic_monitoring': traffic_monitoring,
                        'access_control': access_control
                    }
                }
            else:
                return {
                    'status': 'fail',
                    'message': 'Seguridad de red PCI DSS no implementada correctamente',
                    'result': {
                        'network_segmentation': network_segmentation,
                        'traffic_monitoring': traffic_monitoring,
                        'access_control': access_control
                    }
                }
        except Exception as e:
            logger.error(f"Error al verificar seguridad de red PCI DSS: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al verificar seguridad de red PCI DSS: {e}'
            }
    
    def get_firewall_config(self, region_name):
        """
        Obtiene la configuración del firewall
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con configuración del firewall
        """
        # Implementar lógica para obtener configuración del firewall
        # Por ahora, devolver configuración por defecto
        return {
            'network_segmentation': False,
            'traffic_monitoring': False,
            'access_control': False
        }
    
    def check_ccpa_compliance(self, region_name, check_name):
        """
        Realiza una verificación de cumplimiento CCPA
        
        Args:
            region_name: Nombre de la región
            check_name: Nombre de la verificación
            
        Returns:
            Diccionario con resultado de la verificación
        """
        # Implementar verificaciones específicas de CCPA
        if check_name == 'right_to_know':
            return self.check_ccpa_right_to_know(region_name)
        elif check_name == 'right_to_delete':
            return self.check_ccpa_right_to_delete(region_name)
        elif check_name == 'right_to_opt_out':
            return self.check_ccpa_right_to_opt_out(region_name)
        elif check_name == 'right_to_non_discrimination':
            return self.check_ccpa_right_to_non_discrimination(region_name)
        else:
            return {
                'status': 'warning',
                'message': f'Verificación CCPA {check_name} no implementada',
                'result': 'not_implemented'
            }
    
    def check_ccpa_right_to_know(self, region_name):
        """
        Verifica el derecho a saber CCPA
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con resultado de la verificación
        """
        try:
            # Verificar si se proporciona acceso a datos personales
            data_access = self.get_data_access_policies(region_name)
            
            # Verificar si se informa sobre categorías de datos
            data_categories = data_access.get('data_categories_informed', False)
            
            # Verificar si se informa sobre fines de recolección
            collection_purposes = data_access.get('collection_purposes_informed', False)
            
            if data_categories and collection_purposes:
                return {
                    'status': 'pass',
                    'message': 'Derecho a saber CCPA implementado correctamente',
                    'result': {
                        'data_categories_informed': data_categories,
                        'collection_purposes_informed': collection_purposes
                    }
                }
            else:
                return {
                    'status': 'fail',
                    'message': 'Derecho a saber CCPA no implementado correctamente',
                    'result': {
                        'data_categories_informed': data_categories,
                        'collection_purposes_informed': collection_purposes
                    }
                }
        except Exception as e:
            logger.error(f"Error al verificar derecho a saber CCPA: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al verificar derecho a saber CCPA: {e}'
            }
    
    def get_data_access_policies(self, region_name):
        """
        Obtiene las políticas de acceso a datos
        
        Args:
            region_name: Nombre de la región
            
        Returns:
            Diccionario con políticas de acceso a datos
        """
        # Implementar lógica para obtener políticas de acceso a datos
        # Por ahora, devolver políticas por defecto
        return {
            'data_categories_informed': False,
            'collection_purposes_informed': False
        }
    
    def save_compliance_check(self, region_name, framework_name, check_name, status, result):
        """
        Guarda una verificación de cumplimiento en la base de datos
        
        Args:
            region_name: Nombre de la región
            framework_name: Nombre del marco de cumplimiento
            check_name: Nombre de la verificación
            status: Estado de la verificación
            result: Resultado de la verificación
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Buscar verificación existente
        cursor.execute('''
            SELECT id FROM compliance_checks
            WHERE region_name = ? AND framework_name = ? AND check_name = ?
        ''', (region_name, framework_name, check_name))
        
        existing = cursor.fetchone()
        
        if existing:
            # Actualizar verificación existente
            cursor.execute('''
                UPDATE compliance_checks
                SET status = ?, result = ?, updated_at = ?
                WHERE region_name = ? AND framework_name = ? AND check_name = ?
            ''', (
                status, json.dumps(result), datetime.now().isoformat(),
                region_name, framework_name, check_name
            ))
        else:
            # Insertar nueva verificación
            cursor.execute('''
                INSERT INTO compliance_checks (
                    region_name, framework_name, check_name, status, result, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (
                region_name, framework_name, check_name,
                status, json.dumps(result),
                datetime.now().isoformat(), datetime.now().isoformat()
            ))
        
        conn.commit()
        conn.close()
    
    def schedule_compliance_check(self, region_name, framework_name, check_name):
        """
        Programa una verificación de cumplimiento
        
        Args:
            region_name: Nombre de la región
            framework_name: Nombre del marco de cumplimiento
            check_name: Nombre de la verificación
            
        Returns:
            Diccionario con resultado de la programación
        """
        # Crear tarea de verificación de cumplimiento
        task = {
            'operation': 'check',
            'region_name': region_name,
            'framework_name': framework_name,
            'check_name': check_name,
            'created_at': datetime.now().isoformat()
        }
        
        # Agregar a la cola
        self.compliance_queue.put(task)
        
        return {
            'status': 'success',
            'message': f'Verificación de cumplimiento programada',
            'region_name': region_name,
            'framework_name': framework_name,
            'check_name': check_name
        }
    
    def schedule_all_compliance_checks(self, region_name=None):
        """
        Programa todas las verificaciones de cumplimiento
        
        Args:
            region_name: Nombre de la región (opcional)
            
        Returns:
            Diccionario con resultado de la programación
        """
        results = {}
        
        regions = [region_name] if region_name else list(self.regions.keys())
        
        for region in regions:
            if region not in self.regions:
                results[region] = {
                    'status': 'error',
                    'message': f'Región {region} no configurada'
                }
                continue
            
            region_config = self.regions[region]
            
            if not region_config.get('enabled', True):
                results[region] = {
                    'status': 'skip',
                    'message': f'Región {region} deshabilitada'
                }
                continue
            
            compliance_frameworks = region_config.get('compliance_frameworks', [])
            
            region_results = {}
            
            for framework in compliance_frameworks:
                if framework not in self.config.get('compliance_frameworks', {}):
                    region_results[framework] = {
                        'status': 'error',
                        'message': f'Marco de cumplimiento {framework} no configurado'
                    }
                    continue
                
                framework_config = self.config['compliance_frameworks'][framework]
                checks = framework_config.get('checks', [])
                
                framework_results = {}
                
                for check in checks:
                    check_result = self.schedule_compliance_check(region, framework, check)
                    framework_results[check] = check_result
                
                region_results[framework] = {
                    'status': 'success',
                    'message': f'Verificaciones de {framework} programadas',
                    'checks': framework_results
                }
            
            results[region] = {
                'status': 'success',
                'message': f'Verificaciones de cumplimiento programadas para {region}',
                'frameworks': region_results
            }
        
        return {
            'status': 'success',
            'message': 'Verificaciones de cumplimiento programadas',
            'results': results
        }
    
    def generate_compliance_report(self, region_name, framework_name=None):
        """
        Genera un informe de cumplimiento
        
        Args:
            region_name: Nombre de la región
            framework_name: Nombre del marco de cumplimiento (opcional)
            
        Returns:
            Diccionario con resultado de la generación
        """
        try:
            # Obtener verificaciones de cumplimiento
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            if framework_name:
                cursor.execute('''
                    SELECT check_name, status, result, updated_at
                    FROM compliance_checks
                    WHERE region_name = ? AND framework_name = ?
                    ORDER BY updated_at DESC
                ''', (region_name, framework_name))
            else:
                cursor.execute('''
                    SELECT framework_name, check_name, status, result, updated_at
                    FROM compliance_checks
                    WHERE region_name = ?
                    ORDER BY framework_name, updated_at DESC
                ''', (region_name,))
            
            checks = []
            for row in cursor.fetchall():
                if framework_name:
                    checks.append({
                        'check_name': row[0],
                        'status': row[1],
                        'result': json.loads(row[2]) if row[2] else None,
                        'updated_at': row[3]
                    })
                else:
                    checks.append({
                        'framework_name': row[0],
                        'check_name': row[1],
                        'status': row[2],
                        'result': json.loads(row[3]) if row[3] else None,
                        'updated_at': row[4]
                    })
            
            conn.close()
            
            # Generar informe
            report = {
                'region_name': region_name,
                'framework_name': framework_name,
                'generated_at': datetime.now().isoformat(),
                'checks': checks
            }
            
            # Guardar informe en la base de datos
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO compliance_reports (
                    region_name, framework_name, report_data, created_at
                )
                VALUES (?, ?, ?, ?)
            ''', (
                region_name, framework_name, json.dumps(report),
                datetime.now().isoformat()
            ))
            
            conn.commit()
            conn.close()
            
            return {
                'status': 'success',
                'message': f'Informe de cumplimiento generado para {region_name}' + (f' ({framework_name})' if framework_name else ''),
                'report': report
            }
        except Exception as e:
            logger.error(f"Error al generar informe de cumplimiento: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al generar informe de cumplimiento: {e}'
            }
    
    def get_compliance_status(self, region_name=None, framework_name=None):
        """
        Obtiene el estado de cumplimiento
        
        Args:
            region_name: Nombre de la región (opcional)
            framework_name: Nombre del marco de cumplimiento (opcional)
            
        Returns:
            Diccionario con estado de cumplimiento
        """
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            if region_name and framework_name:
                # Obtener estado de una región y marco específicos
                cursor.execute('''
                    SELECT status, COUNT(*) as count
                    FROM compliance_checks
                    WHERE region_name = ? AND framework_name = ?
                    GROUP BY status
                ''', (region_name, framework_name))
                
                results = {f"{region_name}->{framework_name}": {}}
                
                for row in cursor.fetchall():
                    results[f"{region_name}->{framework_name}"][row[0]] = row[1]
                
            elif region_name:
                # Obtener estado de una región específica
                cursor.execute('''
                    SELECT framework_name, status, COUNT(*) as count
                    FROM compliance_checks
                    WHERE region_name = ?
                    GROUP BY framework_name, status
                ''', (region_name,))
                
                results = {region_name: {}}
                
                current_framework = None
                framework_results = {}
                
                for row in cursor.fetchall():
                    if current_framework != row[0]:
                        if current_framework:
                            results[region_name][current_framework] = framework_results
                        
                        current_framework = row[0]
                        framework_results = {}
                    
                    framework_results[row[1]] = row[2]
                
                if current_framework:
                    results[region_name][current_framework] = framework_results
                
            elif framework_name:
                # Obtener estado de un marco específico
                cursor.execute('''
                    SELECT region_name, status, COUNT(*) as count
                    FROM compliance_checks
                    WHERE framework_name = ?
                    GROUP BY region_name, status
                ''', (framework_name,))
                
                results = {framework_name: {}}
                
                current_region = None
                region_results = {}
                
                for row in cursor.fetchall():
                    if current_region != row[0]:
                        if current_region:
                            results[framework_name][current_region] = region_results
                        
                        current_region = row[0]
                        region_results = {}
                    
                    region_results[row[1]] = row[2]
                
                if current_region:
                    results[framework_name][current_region] = region_results
                
            else:
                # Obtener estado general
                cursor.execute('''
                    SELECT region_name, framework_name, status, COUNT(*) as count
                    FROM compliance_checks
                    GROUP BY region_name, framework_name, status
                ''')
                
                results = {}
                
                for row in cursor.fetchall():
                    region_key = row[0]
                    framework_key = row[1]
                    status_key = row[2]
                    count = row[3]
                    
                    if region_key not in results:
                        results[region_key] = {}
                    
                    if framework_key not in results[region_key]:
                        results[region_key][framework_key] = {}
                    
                    results[region_key][framework_key][status_key] = count
            
            conn.close()
            
            return {
                'status': 'success',
                'message': 'Estado de cumplimiento obtenido',
                'results': results
            }
        except Exception as e:
            logger.error(f"Error al obtener estado de cumplimiento: {e}")
            
            return {
                'status': 'error',
                'message': f'Error al obtener estado de cumplimiento: {e}'
            }

def main():
    """Función principal"""
    parser = argparse.ArgumentParser(description='Gestión de Cumplimiento Normativo Localizado')
    parser.add_argument('--config', help='Ruta al archivo de configuración')
    parser.add_argument('--action', choices=['check', 'check-all', 'report', 'status'],
                       default='status', help='Acción a realizar')
    parser.add_argument('--region', help='Nombre de la región')
    parser.add_argument('--framework', help='Nombre del marco de cumplimiento')
    parser.add_argument('--check', help='Nombre de la verificación')
    
    args = parser.parse_args()
    
    # Inicializar gestor de cumplimiento normativo localizado
    localized_compliance = LocalizedComplianceManager(args.config)
    
    if args.action == 'check':
        if not args.region or not args.framework or not args.check:
            print("Error: Se requieren --region, --framework y --check para verificar cumplimiento")
            sys.exit(1)
        
        result = localized_compliance.schedule_compliance_check(args.region, args.framework, args.check)
        print(json.dumps(result, indent=2))
        
    elif args.action == 'check-all':
        if args.region:
            results = localized_compliance.schedule_all_compliance_checks(args.region)
        else:
            results = localized_compliance.schedule_all_compliance_checks()
        
        print(json.dumps(results, indent=2))
        
    elif args.action == 'report':
        if not args.region:
            print("Error: Se requiere --region para generar informe")
            sys.exit(1)
        
        result = localized_compliance.generate_compliance_report(args.region, args.framework)
        print(json.dumps(result, indent=2))
        
    elif args.action == 'status':
        results = localized_compliance.get_compliance_status(args.region, args.framework)
        print(json.dumps(results, indent=2))

if __name__ == '__main__':
    main()
EOF
    
    # Hacer el script ejecutable
    chmod +x "${compliance_script}"
    
    # Crear configuración de cumplimiento normativo localizado
    local compliance_config="${CONFIG_DIR}/localized-compliance/localized_compliance_config.json"
    
    cat > "${compliance_config}" << 'EOF'
{
    "regions": {
        "us-east-1": {
            "name": "US East",
            "country": "US",
            "state": "VA",
            "compliance_frameworks": ["CIS", "NIST", "HIPAA", "PCI DSS"],
            "data_residency": "US",
            "enabled": true
        },
        "us-west-2": {
            "name": "US West",
            "country": "US",
            "state": "CA",
            "compliance_frameworks": ["CIS", "NIST", "CCPA", "PCI DSS"],
            "data_residency": "US",
            "enabled": true
        },
        "eu-west-1": {
            "name": "Europe West",
            "country": "IE",
            "state": "Dublin",
            "compliance_frameworks": ["CIS", "NIST", "GDPR"],
            "data_residency": "EU",
            "enabled": true
        }
    },
    "compliance_frameworks": {
        "CIS": {
            "name": "Center for Internet Security",
            "version": "CIS Controls v8",
            "checks": [
                "inventory_and_control_of_hardware_assets",
                "inventory_and_control_of_software_assets",
                "continuous_vulnerability_management",
                "controlled_use_of_administrative_privileges",
                "configuration_baseline_database",
                "configuration_baseline_operating_system",
                "email_and_web_browser_protections",
                "malware_defenses",
                "data_recovery",
                "secure_configuration_for_network_infrastructure",
                "network_monitoring_and_defense",
                "secure_configuration_for_network_devices",
                "boundary_defense",
                "data_protection",
                "access_control_management",
                "audit_log_management",
                "information_protection_processes_and_procedures",
                "incident_response_management",
                "penetration_testing",
                "security_awareness_and_training"
            ]
        },
        "NIST": {
            "name": "National Institute of Standards and Technology",
            "version": "NIST SP 800-53 Rev. 5",
            "checks": [
                "access_control",
                "audit_and_accountability",
                "awareness_and_training",
                "configuration_management",
                "contingency_planning",
                "identification_and_authentication",
                "incident_response",
                "maintenance",
                "media_protection",
                "physical_and_environmental_protection",
                "planning",
                "risk_assessment",
                "system_and_communications_protection",
                "system_and_information_integrity"
            ]
        },
        "GDPR": {
            "name": "General Data Protection Regulation",
            "version": "GDPR 2016/679",
            "checks": [
                "lawfulness_fairness_and_transparency",
                "purpose_limitation",
                "data_minimisation",
                "accuracy",
                "storage_limitation",
                "integrity_and_confidentiality",
                "accountability"
            ]
        },
        "HIPAA": {
            "name": "Health Insurance Portability and Accountability Act",
            "version": "HIPAA 2003",
            "checks": [
                "administrative_safeguards",
                "physical_safeguards",
                "technical_safeguards"
            ]
        },
        "PCI DSS": {
            "name": "Payment Card Industry Data Security Standard",
            "version": "PCI DSS v4.0",
            "checks": [
                "network_security",
                "access_control_measures",
                "vulnerability_management_program",
                "secure_software_development",
                "secure_cardholder_data_environment",
                "secure_authentication",
                "monitoring_and_testing",
                "information_security_policy"
            ]
        },
        "CCPA": {
            "name": "California Consumer Privacy Act",
            "version": "CCPA 2018",
            "checks": [
                "right_to_know",
                "right_to_delete",
                "right_to_opt_out",
                "right_to_non_discrimination"
            ]
        }
    },
    "check_interval": 86400,
    "report_retention_days": 90,
    "notification_email": "admin@virtualmin.local"
}
EOF
    
    # Copiar archivos al sistema
    mkdir -p "/etc/multi-region-deployment/localized-compliance"
    mkdir -p "/var/lib/localized_compliance"
    cp "${compliance_script}" "/usr/local/bin/localized_compliance_manager.py"
    cp "${compliance_config}" "/etc/multi-region-deployment/localized-compliance/localized_compliance_config.json"
    
    # Crear servicio systemd para cumplimiento normativo
    local compliance_service="${CONFIG_DIR}/localized-compliance/localized-compliance.service"
    
    cat > "${compliance_service}" << 'EOF'
[Unit]
Description=Localized Compliance Manager Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/localized_compliance_manager.py --config /etc/multi-region-deployment/localized-compliance/localized_compliance_config.json --action status
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF
    
    # Crear servicio systemd para verificación de cumplimiento
    local compliance_check_service="${CONFIG_DIR}/localized-compliance/localized-compliance-check.service"
    
    cat > "${compliance_check_service}" << 'EOF'
[Unit]
Description=Localized Compliance Check Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 /usr/local/bin/localized_compliance_manager.py --config /etc/multi-region-deployment/localized-compliance/localized_compliance_config.json --action check-all

[Install]
WantedBy=multi-user.target
EOF
    
    # Crear temporizador systemd para verificación de cumplimiento
    local compliance_check_timer="${CONFIG_DIR}/localized-compliance/localized-compliance-check.timer"
    
    cat > "${compliance_check_timer}" << 'EOF'
[Unit]
Description=Run Localized Compliance Check

[Timer]
OnCalendar=daily

[Install]
WantedBy=timers.target
EOF
    
    # Copiar servicio y temporizador al sistema
    cp "${compliance_service}" "/etc/systemd/system/localized-compliance.service"
    cp "${compliance_check_service}" "/etc/systemd/system/localized-compliance-check.service"
    cp "${compliance_check_timer}" "/etc/systemd/system/localized-compliance-check.timer"
    
    # Habilitar y arrancar servicios
    systemctl daemon-reload
    systemctl enable localized-compliance.service
    systemctl start localized-compliance.service
    
    systemctl enable localized-compliance-check.timer
    systemctl start localized-compliance-check.timer
    
    success "✅ Cumplimiento normativo localizado implementado"
}

# 📊 **Función para configurar monitoreo de latencia entre regiones**
setup_latency_monitoring() {
    log "📊 Configurando monitoreo de latencia entre regiones"
    
    # Crear directorio de configuración si no existe
    mkdir -p "${CONFIG_DIR}/latency-monitoring"
    
    # Crear script de monitoreo de latencia
    local latency_script="${CONFIG_DIR}/latency-monitoring/latency_monitor.py"
    
    cat > "${latency_script}" << 'EOF'
#!/usr/bin/env python3
"""
Script de Monitoreo de Latencia entre Regiones para Virtualmin Pro
"""

import os
import sys
import json
import time
import logging
import argparse
import subprocess
import threading
import queue
from datetime import datetime, timedelta
import sqlite3
import requests
import ping3

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileWriter('/var/log/latency_monitor.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

class LatencyMonitor:
    def __init__(self, config_file=None):
        """
        Inicializa el monitor de latencia
        
        Args:
            config_file: Ruta al archivo de configuración
        """
        self.config = self.load_config(config_file)
        self.regions = self.config.get('regions', {})
        
        # Inicializar base de datos
        self.init_database()
        
        # Iniciar cola de monitoreo de latencia
        self.latency_queue = queue.Queue()
        
        # Iniciar hilos de monitoreo de latencia
        self.start_latency_workers()
        
        # Iniciar monitoreo automático
        self.start_auto_monitoring()
    
    def load_config(self, config_file):
        """
        Carga configuración desde archivo
        
        Args:
            config_file: Ruta al archivo de configuración
            
        Returns:
            Diccionario con configuración
        """
        default_config = {
            'regions': {
                'us-east-1': {
                    'name': 'US East',
                    'ip': '192.168.1.10',
                    'port': 22,
                    'enabled': True
                },
                'us-west-2': {
                    'name': 'US West',
                    'ip': '192.168.2.10',
                    'port': 22,
                    'enabled': True
                },
                'eu-west-1': {
                    'name': 'Europe West',
                    'ip': '192.168.3.10',
                    'port': 22,
                    'enabled': True
                }
            },
            'monitoring_interval': 60,
            'monitoring_timeout': 5,
            'latency_threshold_warning': 100,
            'latency_threshold_critical': 500,
            'packet_count': 10,
            'packet_size': 64,
            'alert_email': 'admin@virtualmin.local'
        }
        
        if config_file and os.path.exists(config_file):
            with open(config_file, 'r') as f:
                config = json.load(f)
                default_config.update(config)
        
        return default_config
    
    def init_database(self):
        """Inicializa base de datos de monitoreo de latencia"""
        self.db_path = self.config.get('database_path', '/var/lib/latency_monitor/latency.db')
        
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Crear tabla de mediciones de latencia
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS latency_measurements (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_region TEXT NOT NULL,
                target_region TEXT NOT NULL,
                latency_ms REAL NOT NULL,
                packet_loss REAL NOT NULL,
                jitter_ms REAL NOT NULL,
                created_at TEXT NOT NULL
            )
        ''')
        
        # Crear tabla de alertas de latencia
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS latency_alerts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_region TEXT NOT NULL,
                target_region TEXT NOT NULL,
                alert_type TEXT NOT NULL,
                message TEXT NOT NULL,
                created_at TEXT NOT NULL,
                resolved_at TEXT
            )
        ''')
        
        # Crear tabla de estado de latencia
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS latency_status (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_region TEXT NOT NULL,
                target_region TEXT NOT NULL,
                current_latency_ms REAL DEFAULT 0,
                avg_latency_ms REAL DEFAULT 0,
                min_latency_ms REAL DEFAULT 0,
                max_latency_ms REAL DEFAULT 0,
                status TEXT NOT NULL,
                last_check TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        ''')
        
        conn.commit()
        conn.close()
        
        logger.info("Base de datos de monitoreo de latencia inicializada")
    
    def start_latency_workers(self):
        """Inicia hilos de monitoreo de latencia"""
        import threading
        
        def latency_worker():
            while True:
                try:
                    # Obtener tarea de monitoreo de latencia
                    try:
                        task = self.latency_queue.get(timeout=10)
                        
                        # Procesar tarea
                        self.process_latency_task(task)
                        
                        # Marcar tarea como completada
                        self.latency_queue.task_done()
                    except queue.Empty:
                        continue
                    
                except Exception as e:
                    logger.error(f"Error en el trabajador de monitoreo de latencia: {e}")
                    time.sleep(60)
        
        # Iniciar hilo de monitoreo de latencia
        self.latency_thread = threading.Thread(target=latency_worker, daemon=True)
        self.latency_thread.start()
        
        logger.info("Hilo de monitoreo de latencia iniciado")
    
    def start_auto_monitoring(self):
        """Inicia monitoreo automático"""
        import threading
        
        def auto_monitoring_worker():
            while True:
                try:
                    # Monitorear latencia entre todas las regiones
                    self.monitor_all_regions_latency()
                    
                    # Esperar hasta el siguiente ciclo
                    time.sleep(self.config.get('monitoring_interval', 60))
                except Exception as e:
                    logger.error(f"Error en el monitoreo automático de latencia: {e}")
                    time.sleep(60)
        
        # Iniciar hilo de monitoreo automático
        self.auto_monitoring_thread = threading.Thread(target=auto_monitoring_worker, daemon=True)
        self.auto_monitoring_thread.start()
        
        logger.info("Monitoreo automático de latencia iniciado")
    
    def process_latency_task(self, task):
        """
        Procesa una tarea de monitoreo de latencia
        
        Args:
            task: Tarea de monitoreo de latencia
        """
        try:
            operation = task.get('operation')
            source_region = task.get('source_region')
            target_region = task.get('target_region')
            
            if operation == 'measure':
                # Realizar medición de latencia
                result = self.measure_latency(source_region, target_region)
                
                # Actualizar estado de la tarea
                task['status'] = result.get('status')
                task['result'] = result.get('result')
                task['created_at'] = datetime.now().isoformat()
                
                logger.info(f"Tarea de monitoreo de latencia procesada: {result.get('message')}")
        except Exception as e:
            logger.error(f"Error al procesar tarea de monitoreo de latencia: {e}")
            
            # Actualizar estado de la tarea con error
            task['status'] = 'error'
            task['result'] = f'Error al procesar tarea: {e}'
            task['created_at'] = datetime.now().isoformat()
    
    def measure_latency(self, source_region, target_region):
        """
        Mide la latencia entre dos regiones
        
        Args:
            source_region: Región de origen
            target_region: Región de destino
            
        Returns:
            Diccionario con resultado de la medición
        """
        if source_region not in self.regions:
            return {
                'status': 'error',
                'message': f'Región de origen {source_region} no configurada'
            }
        
        if target_region not in self.regions:
            return {
                'status': 'error',
                'message': f'Región de destino {target_region} no configurada'
            }
        
        source_config = self.regions[source_region]
        target_config = self.regions[target_region]
        
        if not source_config.get('enabled', True):
            return {
                'status': 'skip',
                'message': f'Región de origen {source_region} deshabilitada'
            }
        
        if not target_config.get('enabled', True):
            return {
                'status': 'skip',
                'message': f'Región de destino {target_region} deshabilitada'
            }
        
        try:
            # Medir latencia usando ping
            target_ip = target_config.get('ip')
            
            if not target_ip:
                return {
                    'status': 'error',
                    'message': f'IP de la región de destino {target_region} no configurada'
                }
            
            # Realizar ping
            ping_result = subprocess.run(
                ['ping', '-c', str(self.config.get('packet_count', 10)), '-s', str(self.config.get('packet_size', 64)), '-W', str(self.config.get('monitoring_timeout', 5)), target_ip],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            if ping_result.returncode != 0:
                return {
                    'status': 'error',
                    'message': f'Error al hacer ping a {target_ip}: {ping_result.stderr}',
                    'result': {
                        'latency_ms': 0,
                        'packet_loss': 100,
                        'jitter_ms': 0
                    }
                }
            
            # Parsear resultado de ping
            ping_stats = ping3.ping.ping(target_ip, count=self.config.get('packet_count', 10), size=self.config.get('packet_size', 64), timeout=self.config.get('monitoring_timeout', 5))
            
            # Calcular estadísticas
            latency_ms = ping_stats.rtt_avg
            min_latency_ms = ping_stats.rtt_min
            max_latency_ms = ping_stats.rtt_max
            packet_loss = ping_stats.packet_loss
            
            # Calcular jitter (desviación estándar)
            if ping_stats.rtt_max and ping_stats.rtt_min:
                jitter_ms = ping_stats.rtt_max - ping_stats.rtt_min
            else:
                jitter_ms = 0
            
            # Guardar medición en la base de datos
            self.save_latency_measurement(source_region, target_region, latency_ms, packet_loss, jitter_ms)
            
            # Actualizar estado de latencia
            self.update_latency_status(source_region, target_region, latency_ms)
            
            # Verificar umbrales y generar alertas
            self.check_latency_thresholds(source_region, target_region, latency_ms)
            
            return {
                'status': 'success',
                'message': f'Latencia medida entre {source_region} y {target_region}',
                'result': {
                    'latency_ms': latency_ms,
                    'packet_loss': packet_loss,
                    'jitter_ms': jitter_ms,
                    'min_latency_ms': min_latency_ms,
                    'max_latency_ms': max_latency_ms
                }
            }
        except Exception as e:
            logger.error(f"Error al medir latencia de {source_region} a {target_region}: {e}")
            
            # Guardar medición en la base de datos
            self.save_latency_measurement(source_region, target_region, 0, 100, 0)
            
            # Actualizar estado de latencia
            self.update_latency_status(source_region, target_region, 0)
            
            return {
                'status': 'error',
                'message': f'Error al medir latencia de {source_region} a {target_region}: {e}',
                'result': {
                    'latency_ms': 0,
                    'packet_loss': 100,
                    'jitter_ms': 0
                }
            }
    
    def save_latency_measurement(self, source_region, target_region, latency_ms, packet_loss, jitter_ms):
        """
        Guarda una medición de latencia en la base de datos
        
        Args:
            source_region: Región de origen
            target_region: Región de destino
            latency_ms: Latencia en milisegundos
            packet_loss: Pérdida de paquetes en porcentaje
            jitter_ms: Jitter en milisegundos
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO latency_measurements (
                source_region, target_region, latency_ms, packet_loss, jitter_ms, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            source_region, target_region, latency_ms, packet_loss, jitter_ms,
            datetime.now().isoformat()
        ))
        
        conn.commit()
        conn.close()
    
    def update_latency_status(self, source_region, target_region, latency_ms):
        """
        Actualiza el estado de latencia entre dos regiones
        
        Args:
            source_region: Región de origen
            target_region: Región de destino
            latency_ms: Latencia en milisegundos
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Obtener estado actual
        cursor.execute('''
            SELECT current_latency_ms, avg_latency_ms, min_latency_ms, max_latency_ms FROM latency_status
            WHERE source_region = ? AND target_region = ?
        ''', (source_region, target_region))
        
        result = cursor.fetchone()
        
        if result:
            current_latency, avg_latency, min_latency, max_latency = result
            
            # Calcular nuevas estadísticas
            total_count = self.get_latency_count(source_region, target_region)
            
            if total_count > 0:
                # Calcular nuevo promedio
                new_avg = ((avg_latency * (total_count - 1)) + latency_ms) / total_count
                
                # Actualizar mínimo y máximo
                new_min = min(min_latency, latency_ms)
                new_max = max(max_latency, latency_ms)
            else:
                new_avg = latency_ms
                new_min = latency_ms
                new_max = latency_ms
            
            # Determinar estado
            status = 'normal'
            latency_threshold_warning = self.config.get('latency_threshold_warning', 100)
            latency_threshold_critical = self.config.get('latency_threshold_critical', 500)
            
            if latency_ms > latency_threshold_critical:
                status = 'critical'
            elif latency_ms > latency_threshold_warning:
                status = 'warning'
            
            # Actualizar estado
            cursor.execute('''
                UPDATE latency_status
                SET current_latency_ms = ?, avg_latency_ms = ?, min_latency_ms = ?, max_latency_ms = ?, status = ?, last_check = ?, updated_at = ?
                WHERE source_region = ? AND target_region = ?
            ''', (
                latency_ms, new_avg, new_min, new_max, status,
                datetime.now().isoformat(), datetime.now().isoformat(),
                source_region, target_region
            ))
        else:
            # Insertar nuevo estado
            status = 'normal'
            latency_threshold_warning = self.config.get('latency_threshold_warning', 100)
            latency_threshold_critical = self.config.get('latency_threshold_critical', 500)
            
            if latency_ms > latency_threshold_critical:
                status = 'critical'
            elif latency_ms > latency_threshold_warning:
                status = 'warning'
            
            cursor.execute('''
                INSERT INTO latency_status (
                    source_region, target_region, current_latency_ms, avg_latency_ms,
                    min_latency_ms, max_latency_ms, status, last_check, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                source_region, target_region, latency_ms, latency_ms,
                latency_ms, latency_ms, status,
                datetime.now().isoformat(), datetime.now().isoformat()
            ))
        
        conn.commit()
        conn.close()
    
    def get_latency_count(self, source_region, target_region):
        """
        Obtiene el número de mediciones de latencia entre dos regiones
        
        Args:
            source_region: Región de origen
            target_region: Región de destino
            
        Returns:
            Número de mediciones
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT COUNT(*) FROM latency_measurements
            WHERE source_region = ? AND target_region = ?
        ''', (source_region, target_region))
        
        result = cursor.fetchone()
        conn.close()
        
        return result[0] if result else 0
    
    def check_latency_thresholds(self, source_region, target_region, latency_ms):
        """
        Verifica los umbrales de latencia y genera alertas
        
        Args:
            source_region: Región de origen
            target_region: Región de destino
            latency_ms: Latencia en milisegundos
        """
        latency_threshold_warning = self.config.get('latency_threshold_warning', 100)
        latency_threshold_critical = self.config.get('latency_threshold_critical', 500)
        
        if latency_ms > latency_threshold_critical:
            # Generar alerta crítica
            self.generate_latency_alert(source_region, target_region, 'critical', latency_ms)
        elif latency_ms > latency_threshold_warning:
            # Generar alerta de advertencia
            self.generate_latency_alert(source_region, target_region, 'warning', latency_ms)
    
    def generate_latency_alert(self, source_region, target_region, alert_type, latency_ms):
        """
        Genera una alerta de latencia
        
        Args:
            source_region: Región de origen
            target_region: Región de destino
            alert_type: Tipo de alerta (warning, critical)
            latency_ms: Latencia en milisegundos
        """
        message = f'Alerta de latencia {alert_type}: {source_region} -> {target_region}: {latency_ms}ms'
        
        logger.warning(message)
        
        # Guardar alerta en la base de datos
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO latency_alerts (
                source_region, target_region, alert_type, message, created_at
            )
            VALUES (?, ?, ?, ?, ?)
        ''', (
            source_region, target_region, alert_type, message,
            datetime.now().isoformat()
        ))
        
        conn.commit()
        conn.close()
        
        # Enviar notificación por email
        notification_email = self.config.get('notification_email')
        
        if notification_email:
            try:
                # Aquí se implementaría el envío de email
                # Por ahora, solo registrar en los logs
                logger.info(f"Alerta de latencia enviada a {notification_email}")
            except Exception as e:
                logger.error(f"Error al enviar alerta de latencia por email: {e}")
    
    def monitor_all_regions_latency(self):
        """
        Monitorea la latencia entre todas las regiones
        
        Returns:
            Diccionario con resultados del monitoreo
        """
        results = {}
        
        for source_region, source_config in self.regions.items():
            if not source_config.get('enabled', True):
                continue
            
            for target_region, target_config in self.regions.items():
                if not target_config.get('enabled', True):
                    continue
                
                if source_region == target_region:
                    continue
                
                # Programar medición de latencia
                latency_result = self.measure_latency(source_region, target_region)
                
                results[f"{source_region}->{target_region}"] = latency_result
        
        return results
    
    def get_latency_history(self, source_region=None, target_region=None, hours=24):
        """
        Obtiene el historial de latencia
        
        Args:
            source_region: Región de origen (opcional)
            target_region: Región de destino (opcional)
            hours: Horas de historial a obtener
            
        Returns:
            Lista con historial de latencia
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        if source_region and target_region:
            # Obtener historial entre dos regiones específicas
            cursor.execute('''
                SELECT latency_ms, packet_loss, jitter_ms, created_at
                FROM latency_measurements
                WHERE source_region = ? AND target_region = ? AND created_at > datetime('now', '-{} hours')
                ORDER BY created_at DESC
            '''.format(hours), (source_region, target_region))
            
            results = []
            for row in cursor.fetchall():
                results.append({
                    'latency_ms': row[0],
                    'packet_loss': row[1],
                    'jitter_ms': row[2],
                    'created_at': row[3]
                })
        else:
            # Obtener historial general
            cursor.execute('''
                SELECT source_region, target_region, latency_ms, packet_loss, jitter_ms, created_at
                FROM latency_measurements
                WHERE created_at > datetime('now', '-{} hours')
                ORDER BY created_at DESC
            '''.format(hours))
            
            results = []
            for row in cursor.fetchall():
                results.append({
                    'source_region': row[0],
                    'target_region': row[1],
                    'latency_ms': row[2],
                    'packet_loss': row[3],
                    'jitter_ms': row[4],
                    'created_at': row[5]
                })
        
        conn.close()
        
        return results
    
    def get_latency_status(self):
        """
        Obtiene el estado de latencia
        
        Returns:
            Diccionario con estado de latencia
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT source_region, target_region, current_latency_ms, avg_latency_ms,
                   min_latency_ms, max_latency_ms, status, last_check, updated_at
            FROM latency_status
            ORDER BY source_region, target_region
        ''')
        
        results = []
        for row in cursor.fetchall():
            results.append({
                'source_region': row[0],
                'target_region': row[1],
                'current_latency_ms': row[2],
                'avg_latency_ms': row[3],
                'min_latency_ms': row[4],
                'max_latency_ms': row[5],
                'status': row[6],
                'last_check': row[7],
                'updated_at': row[8]
            })
        
        conn.close()
        
        return results
    
    def schedule_latency_measurement(self, source_region, target_region):
        """
        Programa una medición de latencia
        
        Args:
            source_region: Región de origen
            target_region: Región de destino
            
        Returns:
            Diccionario con resultado de la programación
        """
        # Crear tarea de medición de latencia
        task = {
            'operation': 'measure',
            'source_region': source_region,
            'target_region': target_region,
            'created_at': datetime.now().isoformat()
        }
        
        # Agregar a la cola
        self.latency_queue.put(task)
        
        return {
            'status': 'success',
            'message': f'Medición de latencia programada de {source_region} a {target_region}',
            'source_region': source_region,
            'target_region': target_region
        }

def main():
    """Función principal"""
    parser = argparse.ArgumentParser(description='Monitoreo de Latencia entre Regiones')
    parser.add_argument('--config', help='Ruta al archivo de configuración')
    parser.add_argument('--action', choices=['measure', 'measure-all', 'history', 'status'],
                       default='status', help='Acción a realizar')
    parser.add_argument('--from', help='Región de origen')
    parser.add_argument('--to', help='Región de destino')
    parser.add_argument('--hours', type=int, default=24, help='Horas de historial')
    
    args = parser.parse_args()
    
    # Inicializar monitor de latencia
    latency_monitor = LatencyMonitor(args.config)
    
    if args.action == 'measure':
        if not args.from or not args.to:
            print("Error: Se requieren --from y --to para medir latencia")
            sys.exit(1)
        
        result = latency_monitor.schedule_latency_measurement(args.from, args.to)
        print(json.dumps(result, indent=2))
        
    elif args.action == 'measure-all':
        results = latency_monitor.monitor_all_regions_latency()
        print(json.dumps(results, indent=2))
        
    elif args.action == 'history':
        if args.from and args.to:
            results = latency_monitor.get_latency_history(args.from, args.to, args.hours)
        else:
            results = latency_monitor.get_latency_history(hours=args.hours)
        
        print(json.dumps(results, indent=2))
        
    elif args.action == 'status':
        results = latency_monitor.get_latency_status()
        print(json.dumps(results, indent=2))

if __name__ == '__main__':
    main()
EOF
    
    # Hacer el script ejecutable
    chmod +x "${latency_script}"
    
    # Crear configuración de monitoreo de latencia
    local latency_config="${CONFIG_DIR}/latency-monitoring/latency_config.json"
    
    cat > "${latency_config}" << 'EOF'
{
    "regions": {
        "us-east-1": {
            "name": "US East",
            "ip": "192.168.1.10",
            "port": 22,
            "enabled": true
        },
        "us-west-2": {
            "name": "US West",
            "ip": "192.168.2.10",
            "port": 22,
            "enabled": true
        },
        "eu-west-1": {
            "name": "Europe West",
            "ip": "192.168.3.10",
            "port": 22,
            "enabled": true
        }
    },
    "monitoring_interval": 60,
    "monitoring_timeout": 5,
    "latency_threshold_warning": 100,
    "latency_threshold_critical": 500,
    "packet_count": 10,
    "packet_size": 64,
    "notification_email": "admin@virtualmin.local"
}
EOF
    
    # Copiar archivos al sistema
    mkdir -p "/etc/multi-region-deployment/latency-monitoring"
    mkdir -p "/var/lib/latency_monitor"
    cp "${latency_script}" "/usr/local/bin/latency_monitor.py"
    cp "${latency_config}" "/etc/multi-region-deployment/latency-monitoring/latency_config.json"
    
    # Crear servicio systemd para monitoreo de latencia
    local latency_service="${CONFIG_DIR}/latency-monitoring/latency-monitor.service"
    
    cat > "${latency_service}" << 'EOF'
[Unit]
Description=Latency Monitor Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/latency_monitor.py --config /etc/multi-region-deployment/latency-monitoring/latency_config.json --action status
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF
    
    # Copiar servicio al sistema
    cp "${latency_service}" "/etc/systemd/system/latency-monitor.service"
    
    # Habilitar y arrancar servicio
    systemctl daemon-reload
    systemctl enable latency-monitor.service
    systemctl start latency-monitor.service
    
    success "✅ Monitoreo de latencia entre regiones configurado"
}

# 🚀 **Función principal**
main() {
    log "🚀 Iniciando configuración de Despliegue Multi-Región"
    
    # Verificar dependencias
    check_dependencies
    
    # Configurar enrutamiento geográfico inteligente
    setup_geo_routing
    
    # Implementar replicación global de datos
    setup_global_data_replication
    
    # Configurar disaster recovery con failover regional
    setup_disaster_recovery
    
    # Implementar cumplimiento normativo localizado
    setup_localized_compliance
    
    # Configurar monitoreo de latencia entre regiones
    setup_latency_monitoring
    
    success "✅ Configuración de Despliegue Multi-Región completada"
    
    # Mostrar resumen
    echo
    echo -e "${CYAN}📋 Resumen de la configuración:${NC}"
    echo -e "${BLUE}• Geo Routing Manager:${NC} /usr/local/bin/geo_routing_manager.py"
    echo -e "${BLUE}• Global Replication Manager:${NC} /usr/local/bin/global_replication_manager.py"
    echo -e "${BLUE}• Disaster Recovery Manager:${NC} /usr/local/bin/disaster_recovery_manager.py"
    echo -e "${BLUE}• Localized Compliance Manager:${NC} /usr/local/bin/localized_compliance_manager.py"
    echo -e "${BLUE}• Latency Monitor:${NC} /usr/local/bin/latency_monitor.py"
    echo
    echo -e "${CYAN}🔄 Para verificar el estado:${NC}"
    echo -e "${BLUE}geo_routing_manager.py --config /etc/multi-region-deployment/geo-routing/geo_routing_config.json --action health${NC}"
    echo -e "${BLUE}global_replication_manager.py --config /etc/multi-region-deployment/global-replication/global_replication_config.json --action status${NC}"
    echo -e "${BLUE}disaster_recovery_manager.py --config /etc/multi-region-deployment/disaster-recovery/disaster_recovery_config.json --action status${NC}"
    echo -e "${BLUE}localized_compliance_manager.py --config /etc/multi-region-deployment/localized-compliance/localized_compliance_config.json --action status${NC}"
    echo -e "${BLUE}latency_monitor.py --config /etc/multi-region-deployment/latency-monitoring/latency_config.json --action status${NC}"
    echo
    echo -e "${CYAN}📊 Para ver métricas:${NC}"
    echo -e "${BLUE}geo_routing_manager.py --config /etc/multi-region-deployment/geo-routing/geo_routing_config.json --action routing --ip 8.8.8.8${NC}"
    echo -e "${BLUE}global_replication_manager.py --config /etc/multi-region-deployment/global-replication/global_replication_config.json --action lag --from us-east-1 --to us-west-2${NC}"
    echo -e "${BLUE}disaster_recovery_manager.py --config /etc/multi-region-deployment/disaster-recovery/disaster_recovery_config.json --action history${NC}"
    echo -e "${BLUE}localized_compliance_manager.py --config /etc/multi-region-deployment/localized-compliance/localized_compliance_config.json --action check-all${NC}"
    echo -e "${BLUE}latency_monitor.py --config /etc/multi-region-deployment/latency-monitoring/latency_config.json --action history --from us-east-1 --to us-west-2${NC}"
    echo
}

# 🚀 **Ejecutar función principal**
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi