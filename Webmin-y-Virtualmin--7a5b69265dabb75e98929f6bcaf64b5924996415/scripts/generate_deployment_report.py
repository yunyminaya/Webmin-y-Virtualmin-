#!/usr/bin/env python3

# Script para generar reportes de despliegue de Virtualmin Enterprise

import os
import sys
import json
import yaml
import argparse
from datetime import datetime
from jinja2 import Template
import logging

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DeploymentReportGenerator:
    def __init__(self, config_file, output_file, logs_dir=None, artifacts_dir=None):
        self.config_file = config_file
        self.output_file = output_file
        self.logs_dir = logs_dir
        self.artifacts_dir = artifacts_dir
        self.config = self.load_config()
        
    def load_config(self):
        """Cargar configuración desde archivo YAML"""
        try:
            with open(self.config_file, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            logger.error(f"Error al cargar configuración: {e}")
            return {}
    
    def get_terraform_outputs(self):
        """Obtener outputs de Terraform si están disponibles"""
        terraform_outputs = {}
        
        if self.artifacts_dir and os.path.exists(f"{self.artifacts_dir}/terraform-outputs/terraform_outputs.json"):
            try:
                with open(f"{self.artifacts_dir}/terraform-outputs/terraform_outputs.json", 'r') as f:
                    terraform_outputs = json.load(f)
            except Exception as e:
                logger.error(f"Error al cargar outputs de Terraform: {e}")
        
        return terraform_outputs
    
    def get_stress_test_results(self):
        """Obtener resultados de pruebas de estrés si están disponibles"""
        stress_test_results = {}
        
        if self.artifacts_dir and os.path.exists(f"{self.artifacts_dir}/stress-test-results"):
            try:
                # Buscar archivos de resultados
                results_files = []
                for root, dirs, files in os.walk(f"{self.artifacts_dir}/stress-test-results"):
                    for file in files:
                        if file.endswith('.jtl') or file.endswith('.csv') or file.endswith('.html'):
                            results_files.append(os.path.join(root, file))
                
                stress_test_results['files'] = results_files
                stress_test_results['count'] = len(results_files)
            except Exception as e:
                logger.error(f"Error al obtener resultados de pruebas de estrés: {e}")
        
        return stress_test_results
    
    def get_security_logs(self):
        """Obtener logs de seguridad si están disponibles"""
        security_logs = {}
        
        if self.artifacts_dir and os.path.exists(f"{self.artifacts_dir}/security-logs"):
            try:
                # Buscar archivos de logs
                log_files = []
                for root, dirs, files in os.walk(f"{self.artifacts_dir}/security-logs"):
                    for file in files:
                        if file.endswith('.log'):
                            log_files.append(os.path.join(root, file))
                
                security_logs['files'] = log_files
                security_logs['count'] = len(log_files)
            except Exception as e:
                logger.error(f"Error al obtener logs de seguridad: {e}")
        
        return security_logs
    
    def get_deployment_logs(self):
        """Obtener logs de despliegue si están disponibles"""
        deployment_logs = []
        
        if self.logs_dir and os.path.exists(self.logs_dir):
            try:
                # Buscar archivos de logs de despliegue
                for file in os.listdir(self.logs_dir):
                    if file.startswith('deploy_virtualmin_enterprise_') and file.endswith('.log'):
                        log_path = os.path.join(self.logs_dir, file)
                        with open(log_path, 'r') as f:
                            # Obtener últimas 50 líneas
                            lines = f.readlines()
                            deployment_logs.extend(lines[-50:])
            except Exception as e:
                logger.error(f"Error al obtener logs de despliegue: {e}")
        
        return deployment_logs
    
    def generate_report(self):
        """Generar reporte HTML"""
        # Obtener datos adicionales
        terraform_outputs = self.get_terraform_outputs()
        stress_test_results = self.get_stress_test_results()
        security_logs = self.get_security_logs()
        deployment_logs = self.get_deployment_logs()
        
        # Template HTML
        template_str = """
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Despliegue - Virtualmin Enterprise</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background-color: #2c3e50;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .section {
            margin-bottom: 30px;
            padding: 15px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .section h2 {
            color: #2c3e50;
            border-bottom: 1px solid #ddd;
            padding-bottom: 10px;
        }
        .status {
            padding: 5px 10px;
            border-radius: 3px;
            color: white;
            font-weight: bold;
        }
        .success {
            background-color: #27ae60;
        }
        .warning {
            background-color: #f39c12;
        }
        .error {
            background-color: #e74c3c;
        }
        .log-container {
            background-color: #f8f9fa;
            border: 1px solid #ddd;
            border-radius: 5px;
            padding: 15px;
            font-family: monospace;
            white-space: pre-wrap;
            max-height: 300px;
            overflow-y: auto;
        }
        .metrics {
            display: flex;
            justify-content: space-between;
            flex-wrap: wrap;
        }
        .metric {
            background-color: #f8f9fa;
            border: 1px solid #ddd;
            border-radius: 5px;
            padding: 15px;
            margin: 10px;
            text-align: center;
            min-width: 150px;
        }
        .metric-value {
            font-size: 24px;
            font-weight: bold;
            color: #2c3e50;
        }
        .metric-label {
            font-size: 14px;
            color: #7f8c8d;
        }
        .table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }
        .table th {
            background-color: #f2f2f2;
            padding: 10px;
            text-align: left;
        }
        .table td {
            padding: 10px;
            border-bottom: 1px solid #ddd;
        }
        .collapsible {
            background-color: #f1f1f1;
            color: #444;
            cursor: pointer;
            padding: 18px;
            width: 100%;
            border: none;
            text-align: left;
            outline: none;
            font-size: 15px;
            border-radius: 5px;
        }
        .active, .collapsible:hover {
            background-color: #ccc;
        }
        .content {
            padding: 0 18px;
            display: none;
            overflow: hidden;
            background-color: #f9f9f9;
            margin-bottom: 10px;
            border-radius: 0 0 5px 5px;
        }
    </style>
    <script>
        function toggleCollapsible(id) {
            var content = document.getElementById(id);
            if (content.style.display === "block") {
                content.style.display = "none";
            } else {
                content.style.display = "block";
            }
        }
    </script>
</head>
<body>
    <div class="header">
        <h1>Reporte de Despliegue - Virtualmin Enterprise</h1>
        <p>Fecha: {{ current_time }}</p>
    </div>
    
    <div class="section">
        <h2>Resumen de Despliegue</h2>
        <p><strong>Clúster:</strong> {{ config.cluster_name }}</p>
        <p><strong>Entorno:</strong> {{ config.environment }}</p>
        <p><strong>Región:</strong> {{ config.aws_region }}</p>
        <p><strong>Dominio:</strong> {{ config.domain_name }}</p>
        <p><strong>Estado:</strong> <span class="status success">Completado</span></p>
    </div>
    
    <div class="section">
        <h2>Infraestructura</h2>
        <p><strong>Estado:</strong> <span class="status success">Desplegada</span></p>
        <p><strong>Herramienta:</strong> Terraform</p>
        <div class="metrics">
            <div class="metric">
                <div class="metric-value">{{ terraform_outputs | length }}</div>
                <div class="metric-label">Outputs</div>
            </div>
            {% if terraform_outputs %}
            <div class="metric">
                <div class="metric-value">{{ terraform_outputs | length }}</div>
                <div class="metric-label">Recursos</div>
            </div>
            {% endif %}
        </div>
        
        {% if terraform_outputs %}
        <button type="button" class="collapsible" onclick="toggleCollapsible('terraform-outputs')">Ver Outputs de Terraform</button>
        <div id="terraform-outputs" class="content">
            <table class="table">
                <tr>
                    <th>Output</th>
                    <th>Valor</th>
                </tr>
                {% for key, value in terraform_outputs.items() %}
                <tr>
                    <td>{{ key }}</td>
                    <td>{{ value }}</td>
                </tr>
                {% endfor %}
            </table>
        </div>
        {% endif %}
    </div>
    
    <div class="section">
        <h2>Configuración de Aplicaciones</h2>
        <p><strong>Estado:</strong> <span class="status success">Configurada</span></p>
        <p><strong>Herramienta:</strong> Ansible</p>
        <div class="metrics">
            <div class="metric">
                <div class="metric-value">N/A</div>
                <div class="metric-label">Grupos</div>
            </div>
            <div class="metric">
                <div class="metric-value">N/A</div>
                <div class="metric-label">Hosts</div>
            </div>
        </div>
    </div>
    
    <div class="section">
        <h2>Seguridad</h2>
        <p><strong>WAF:</strong> <span class="status {{ 'success' if config.security.waf else 'warning' }}">{{ 'Configurado' if config.security.waf else 'No configurado' }}</span></p>
        <p><strong>IDS/IPS:</strong> <span class="status {{ 'success' if config.security.ids_ips else 'warning' }}">{{ 'Configurado' if config.security.ids_ips else 'No configurado' }}</span></p>
        <p><strong>MFA:</strong> <span class="status {{ 'success' if config.security.mfa else 'warning' }}">{{ 'Configurado' if config.security.mfa else 'No configurado' }}</span></p>
        
        {% if security_logs and security_logs.count > 0 %}
        <p><strong>Logs de seguridad:</strong> {{ security_logs.count }} archivos</p>
        <button type="button" class="collapsible" onclick="toggleCollapsible('security-logs')">Ver Logs de Seguridad</button>
        <div id="security-logs" class="content">
            <ul>
                {% for log_file in security_logs.files %}
                <li>{{ log_file }}</li>
                {% endfor %}
            </ul>
        </div>
        {% endif %}
    </div>
    
    <div class="section">
        <h2>Pruebas de Estrés</h2>
        <p><strong>Estado:</strong> <span class="status {{ 'success' if config.stress_testing.enabled else 'warning' }}">{{ 'Completadas' if config.stress_testing.enabled else 'No ejecutadas' }}</span></p>
        <p><strong>Herramienta:</strong> {{ config.stress_testing.tool }}</p>
        <p><strong>Usuarios:</strong> {{ config.stress_testing.users }}</p>
        <p><strong>Duración:</strong> {{ config.stress_testing.duration }} segundos</p>
        
        {% if stress_test_results and stress_test_results.count > 0 %}
        <p><strong>Resultados:</strong> {{ stress_test_results.count }} archivos</p>
        <button type="button" class="collapsible" onclick="toggleCollapsible('stress-test-results')">Ver Resultados de Pruebas</button>
        <div id="stress-test-results" class="content">
            <ul>
                {% for result_file in stress_test_results.files %}
                <li>{{ result_file }}</li>
                {% endfor %}
            </ul>
        </div>
        {% endif %}
    </div>
    
    <div class="section">
        <h2>Logs de Despliegue</h2>
        {% if deployment_logs %}
        <div class="log-container">{{ deployment_logs | join('') }}</div>
        {% else %}
        <p>No se encontraron logs de despliegue.</p>
        {% endif %}
    </div>
    
    <div class="section">
        <h2>Accesos Rápidos</h2>
        <p><strong>Webmin:</strong> <a href="https://www.{{ config.domain_name }}:10000">https://www.{{ config.domain_name }}:10000</a></p>
        <p><strong>Virtualmin:</strong> <a href="https://www.{{ config.domain_name }}:10000/virtual-server/">https://www.{{ config.domain_name }}:10000/virtual-server/</a></p>
        <p><strong>Dashboard de Monitoreo:</strong> <a href="https://www.{{ config.domain_name }}:3000">https://www.{{ config.domain_name }}:3000</a></p>
    </div>
    
    <div class="section">
        <h2>Información de Generación</h2>
        <p><strong>Script:</strong> generate_deployment_report.py</p>
        <p><strong>Archivo de configuración:</strong> {{ config_file }}</p>
        <p><strong>Archivo de salida:</strong> {{ output_file }}</p>
        <p><strong>Directorio de logs:</strong> {{ logs_dir }}</p>
        <p><strong>Directorio de artefactos:</strong> {{ artifacts_dir }}</p>
    </div>
</body>
</html>
        """
        
        # Renderizar template
        template = Template(template_str)
        html_content = template.render(
            current_time=datetime.now().strftime('%d/%m/%Y %H:%M:%S'),
            config=self.config,
            config_file=self.config_file,
            output_file=self.output_file,
            logs_dir=self.logs_dir,
            artifacts_dir=self.artifacts_dir,
            terraform_outputs=terraform_outputs,
            stress_test_results=stress_test_results,
            security_logs=security_logs,
            deployment_logs=deployment_logs
        )
        
        # Escribir archivo HTML
        try:
            with open(self.output_file, 'w') as f:
                f.write(html_content)
            logger.info(f"Reporte generado exitosamente: {self.output_file}")
        except Exception as e:
            logger.error(f"Error al escribir reporte: {e}")

def main():
    parser = argparse.ArgumentParser(description='Generar reporte de despliegue de Virtualmin Enterprise')
    parser.add_argument('--config', required=True, help='Archivo de configuración YAML')
    parser.add_argument('--output', required=True, help='Archivo de salida HTML')
    parser.add_argument('--logs-dir', help='Directorio de logs')
    parser.add_argument('--artifacts-dir', help='Directorio de artefactos')
    
    args = parser.parse_args()
    
    # Generar reporte
    report_generator = DeploymentReportGenerator(
        config_file=args.config,
        output_file=args.output,
        logs_dir=args.logs_dir,
        artifacts_dir=args.artifacts_dir
    )
    
    report_generator.generate_report()

if __name__ == '__main__':
    main()