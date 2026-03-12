#!/usr/bin/env python3

# Sistema de Pruebas de Estrés y Failover con JMeter, Locust y Chaos Monkey
# para Virtualmin Enterprise

import json
import os
import sys
import time
import subprocess
import threading
import logging
import sqlite3
import requests
import yaml
import random
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
import xml.etree.ElementTree as ET

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/virtualmin-enterprise/stresstesting.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class StressTestingSystem:
    def __init__(self, config_file=None):
        """Inicializar el sistema de pruebas de estrés"""
        self.config = self.load_config(config_file)
        self.db_path = self.config.get('database', {}).get('path', '/opt/virtualmin-enterprise/testing/stresstesting.db')
        self.reports_dir = self.config.get('reports', {}).get('path', '/opt/virtualmin-enterprise/testing/reports')
        self.test_scenarios_dir = self.config.get('scenarios', {}).get('path', '/opt/virtualmin-enterprise/testing/scenarios')
        self.jmeter_dir = self.config.get('tools', {}).get('jmeter', {}).get('path', '/opt/jmeter')
        self.locust_dir = self.config.get('tools', {}).get('locust', {}).get('path', '/opt/locust')
        self.chaos_dir = self.config.get('tools', {}).get('chaos', {}).get('path', '/opt/chaos')
        
        # Crear directorios necesarios
        self.create_directories()
        
        # Inicializar base de datos
        self.init_database()
        
        # Estado de las pruebas
        self.active_tests = {}
        self.test_threads = {}
    
    def load_config(self, config_file):
        """Cargar configuración desde archivo"""
        default_config = {
            "database": {
                "path": "/opt/virtualmin-enterprise/testing/stresstesting.db"
            },
            "reports": {
                "path": "/opt/virtualmin-enterprise/testing/reports",
                "format": ["html", "json", "jtl"],
                "retention_days": 30
            },
            "scenarios": {
                "path": "/opt/virtualmin-enterprise/testing/scenarios",
                "default": "basic_load_test"
            },
            "tools": {
                "jmeter": {
                    "path": "/opt/jmeter",
                    "version": "5.5",
                    "download_url": "https://downloads.apache.org//jmeter/binaries/apache-jmeter-5.5.tgz"
                },
                "locust": {
                    "path": "/opt/locust",
                    "version": "2.15.1",
                    "download_url": "https://github.com/locustio/locust/archive/refs/tags/2.15.1.tar.gz"
                },
                "chaos": {
                    "path": "/opt/chaos",
                    "version": "0.9.0",
                    "download_url": "https://github.com/chaosmonkeyio/chaos-monkey/releases/download/v0.9.0/chaos-monkey-0.9.0.tar.gz"
                }
            },
            "targets": {
                "web": {
                    "protocol": "https",
                    "host": "localhost",
                    "port": 443,
                    "path": "/"
                },
                "api": {
                    "protocol": "https",
                    "host": "localhost",
                    "port": 443,
                    "path": "/api"
                },
                "virtualmin": {
                    "protocol": "https",
                    "host": "localhost",
                    "port": 10000,
                    "path": "/"
                }
            },
            "limits": {
                "max_users": 1000,
                "ramp_up_time": 60,
                "test_duration": 300,
                "think_time": 1000
            },
            "failover": {
                "enabled": True,
                "scenarios": ["server_shutdown", "network_partition", "disk_full", "memory_exhaustion"],
                "auto_recovery": True,
                "recovery_timeout": 300
            },
            "notification": {
                "email_enabled": False,
                "smtp_server": "",
                "smtp_port": 587,
                "smtp_username": "",
                "smtp_password": "",
                "slack_webhook": "",
                "alert_on_failure": True,
                "alert_on_recovery": True
            }
        }
        
        if config_file and os.path.exists(config_file):
            try:
                with open(config_file, 'r') as f:
                    user_config = json.load(f)
                
                # Fusionar configuración por defecto con configuración de usuario
                for section in default_config:
                    if section in user_config:
                        if isinstance(default_config[section], dict):
                            default_config[section].update(user_config[section])
                        else:
                            default_config[section] = user_config[section]
                
                return default_config
            except (json.JSONDecodeError, IOError) as e:
                logger.error(f"Error al cargar configuración: {e}")
                return default_config
        else:
            return default_config
    
    def create_directories(self):
        """Crear directorios necesarios"""
        directories = [
            '/opt/virtualmin-enterprise/testing',
            os.path.dirname(self.db_path),
            self.reports_dir,
            self.test_scenarios_dir,
            self.jmeter_dir,
            self.locust_dir,
            self.chaos_dir,
            '/var/log/virtualmin-enterprise'
        ]
        
        for directory in directories:
            try:
                os.makedirs(directory, exist_ok=True)
                logger.info(f"Directorio creado: {directory}")
            except OSError as e:
                logger.error(f"Error al crear directorio {directory}: {e}")
    
    def init_database(self):
        """Inicializar base de datos SQLite"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Crear tabla de pruebas
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS tests (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    test_id TEXT UNIQUE NOT NULL,
                    name TEXT NOT NULL,
                    type TEXT NOT NULL,
                    tool TEXT NOT NULL,
                    target TEXT NOT NULL,
                    status TEXT DEFAULT 'pending',
                    start_time TIMESTAMP,
                    end_time TIMESTAMP,
                    duration INTEGER,
                    parameters TEXT,
                    results TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Crear tabla de métricas
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    test_id TEXT NOT NULL,
                    metric_name TEXT NOT NULL,
                    metric_value REAL,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (test_id) REFERENCES tests (test_id)
                )
            ''')
            
            # Crear tabla de eventos de failover
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS failover_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    test_id TEXT NOT NULL,
                    event_type TEXT NOT NULL,
                    description TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    recovery_time TIMESTAMP,
                    status TEXT DEFAULT 'active',
                    FOREIGN KEY (test_id) REFERENCES tests (test_id)
                )
            ''')
            
            # Crear tabla de escenarios de prueba
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS test_scenarios (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT UNIQUE NOT NULL,
                    type TEXT NOT NULL,
                    tool TEXT NOT NULL,
                    description TEXT,
                    parameters TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Insertar escenarios de prueba por defecto
            default_scenarios = [
                {
                    'name': 'basic_load_test',
                    'type': 'load',
                    'tool': 'jmeter',
                    'description': 'Prueba de carga básica con usuarios incrementales',
                    'parameters': json.dumps({
                        'users': 50,
                        'ramp_up': 30,
                        'duration': 120,
                        'target': 'web'
                    })
                },
                {
                    'name': 'stress_test',
                    'type': 'stress',
                    'tool': 'jmeter',
                    'description': 'Prueba de estrés para encontrar el límite del sistema',
                    'parameters': json.dumps({
                        'users': 500,
                        'ramp_up': 60,
                        'duration': 300,
                        'target': 'web'
                    })
                },
                {
                    'name': 'endurance_test',
                    'type': 'endurance',
                    'tool': 'locust',
                    'description': 'Prueba de resistencia de larga duración',
                    'parameters': json.dumps({
                        'users': 100,
                        'hatch_rate': 5,
                        'duration': 3600,
                        'target': 'api'
                    })
                },
                {
                    'name': 'spike_test',
                    'type': 'spike',
                    'tool': 'locust',
                    'description': 'Prueba de picos de tráfico',
                    'parameters': json.dumps({
                        'users_min': 10,
                        'users_max': 500,
                        'spawn_rate': 50,
                        'duration': 600,
                        'target': 'web'
                    })
                },
                {
                    'name': 'server_shutdown_failover',
                    'type': 'failover',
                    'tool': 'chaos',
                    'description': 'Simulación de apagado de servidor',
                    'parameters': json.dumps({
                        'experiment': 'server.shutdown',
                        'target': 'web_server',
                        'auto_recovery': True
                    })
                }
            ]
            
            for scenario in default_scenarios:
                cursor.execute('''
                    INSERT OR IGNORE INTO test_scenarios (name, type, tool, description, parameters)
                    VALUES (?, ?, ?, ?, ?)
                ''', (
                    scenario['name'],
                    scenario['type'],
                    scenario['tool'],
                    scenario['description'],
                    scenario['parameters']
                ))
            
            conn.commit()
            conn.close()
            
            logger.info("Base de datos inicializada")
            return True
        except Exception as e:
            logger.error(f"Error al inicializar base de datos: {e}")
            return False
    
    def get_db_connection(self):
        """Obtener conexión a la base de datos"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn
    
    def install_jmeter(self):
        """Instalar JMeter"""
        try:
            # Verificar si JMeter ya está instalado
            if os.path.exists(os.path.join(self.jmeter_dir, 'bin', 'jmeter')):
                logger.info("JMeter ya está instalado")
                return True
            
            # Descargar JMeter
            download_url = self.config['tools']['jmeter']['download_url']
            tar_file = os.path.join('/tmp', os.path.basename(download_url))
            
            logger.info(f"Descargando JMeter desde {download_url}")
            subprocess.run(['wget', '-O', tar_file, download_url], check=True)
            
            # Extraer JMeter
            logger.info("Extrayendo JMeter")
            subprocess.run(['tar', '-xzf', tar_file, '-C', '/tmp'], check=True)
            
            # Mover a directorio de instalación
            jmeter_extracted = os.path.join('/tmp', f"apache-jmeter-{self.config['tools']['jmeter']['version']}")
            subprocess.run(['mv', jmeter_extracted, self.jmeter_dir], check=True)
            
            # Establecer permisos de ejecución
            jmeter_bin = os.path.join(self.jmeter_dir, 'bin')
            subprocess.run(['chmod', '+x', os.path.join(jmeter_bin, 'jmeter')], check=True)
            subprocess.run(['chmod', '+x', os.path.join(jmeter_bin, 'jmeter-server')], check=True)
            
            # Limpiar
            os.remove(tar_file)
            
            logger.info("JMeter instalado exitosamente")
            return True
        except Exception as e:
            logger.error(f"Error al instalar JMeter: {e}")
            return False
    
    def install_locust(self):
        """Instalar Locust"""
        try:
            # Verificar si Locust ya está instalado
            if os.path.exists(os.path.join(self.locust_dir, 'locust')):
                logger.info("Locust ya está instalado")
                return True
            
            # Instalar Locust usando pip
            logger.info("Instalando Locust con pip")
            subprocess.run(['pip', 'install', 'locustio'], check=True)
            
            # Crear enlace simbólico
            locust_bin = subprocess.run(['which', 'locust'], capture_output=True, text=True).stdout.strip()
            os.symlink(locust_bin, os.path.join(self.locust_dir, 'locust'))
            
            logger.info("Locust instalado exitosamente")
            return True
        except Exception as e:
            logger.error(f"Error al instalar Locust: {e}")
            return False
    
    def install_chaos_monkey(self):
        """Instalar Chaos Monkey"""
        try:
            # Verificar si Chaos Monkey ya está instalado
            if os.path.exists(os.path.join(self.chaos_dir, 'chaos-monkey')):
                logger.info("Chaos Monkey ya está instalado")
                return True
            
            # Instalar Chaos Monkey usando pip
            logger.info("Instalando Chaos Monkey con pip")
            subprocess.run(['pip', 'install', 'chaosmonkey'], check=True)
            
            # Crear script wrapper
            wrapper_script = os.path.join(self.chaos_dir, 'chaos-monkey')
            with open(wrapper_script, 'w') as f:
                f.write("""#!/bin/bash
# Wrapper para Chaos Monkey
python3 -m chaosmonkey "$@"
""")
            
            # Establecer permisos de ejecución
            os.chmod(wrapper_script, 0o755)
            
            logger.info("Chaos Monkey instalado exitosamente")
            return True
        except Exception as e:
            logger.error(f"Error al instalar Chaos Monkey: {e}")
            return False
    
    def install_tools(self):
        """Instalar todas las herramientas de prueba"""
        tools_installed = []
        
        if self.install_jmeter():
            tools_installed.append('jmeter')
        
        if self.install_locust():
            tools_installed.append('locust')
        
        if self.install_chaos_monkey():
            tools_installed.append('chaos')
        
        return tools_installed
    
    def create_jmeter_test_plan(self, test_name, target, parameters):
        """Crear plan de prueba JMeter"""
        try:
            # Obtener configuración del objetivo
            target_config = self.config['targets'].get(target, {})
            protocol = target_config.get('protocol', 'https')
            host = target_config.get('host', 'localhost')
            port = target_config.get('port', 443)
            path = target_config.get('path', '/')
            
            # Obtener parámetros de la prueba
            users = parameters.get('users', 50)
            ramp_up = parameters.get('ramp_up', 30)
            duration = parameters.get('duration', 120)
            think_time = parameters.get('think_time', 1000)
            
            # Crear directorio para la prueba
            test_dir = os.path.join(self.test_scenarios_dir, 'jmeter', test_name)
            os.makedirs(test_dir, exist_ok=True)
            
            # Crear plan de prueba JMeter
            test_plan_file = os.path.join(test_dir, f"{test_name}.jmx")
            
            # XML del plan de prueba
            jmx_xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2" properties="5.0" jmeter="5.5">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="{test_name}" enabled="true">
      <stringProp name="TestPlan.comments">Prueba de carga para Virtualmin Enterprise</stringProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
      <boolProp name="TestPlan.teardown_on_shutdown">true</boolProp>
      <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
      <elementProp name="TestPlan.user_defined_variables" elementType="Arguments" guiclass="ArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
        <collectionProp name="Arguments.arguments">
          <elementProp name="TARGET_HOST" elementType="Argument">
            <stringProp name="Argument.name">TARGET_HOST</stringProp>
            <stringProp name="Argument.value">{host}</stringProp>
          </elementProp>
          <elementProp name="TARGET_PORT" elementType="Argument">
            <stringProp name="Argument.name">TARGET_PORT</stringProp>
            <stringProp name="Argument.value">{port}</stringProp>
          </elementProp>
          <elementProp name="TARGET_PATH" elementType="Argument">
            <stringProp name="Argument.name">TARGET_PATH</stringProp>
            <stringProp name="Argument.value">{path}</stringProp>
          </elementProp>
          <elementProp name="TARGET_PROTOCOL" elementType="Argument">
            <stringProp name="Argument.name">TARGET_PROTOCOL</stringProp>
            <stringProp name="Argument.value">{protocol}</stringProp>
          </elementProp>
        </collectionProp>
      </elementProp>
    </TestPlan>
    <hashTree>
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Usuarios" enabled="true">
        <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController" guiclass="LoopControlPanel" testclass="LoopController" testname="Loop Controller" enabled="true">
          <boolProp name="LoopController.continue_forever">false</boolProp>
          <stringProp name="LoopController.loops">-1</stringProp>
        </elementProp>
        <stringProp name="ThreadGroup.num_threads">{users}</stringProp>
        <stringProp name="ThreadGroup.ramp_time">{ramp_up}</stringProp>
        <boolProp name="ThreadGroup.scheduler">true</boolProp>
        <stringProp name="ThreadGroup.duration">{duration}</stringProp>
        <stringProp name="ThreadGroup.delay"></stringProp>
      </ThreadGroup>
      <hashTree>
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="Request to {target}" enabled="true">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments" guiclass="HTTPArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
            <collectionProp name="Arguments.arguments"/>
          </elementProp>
          <stringProp name="HTTPSampler.domain">${{TARGET_HOST}}</stringProp>
          <stringProp name="HTTPSampler.port">${{TARGET_PORT}}</stringProp>
          <stringProp name="HTTPSampler.protocol">${{TARGET_PROTOCOL}}</stringProp>
          <stringProp name="HTTPSampler.contentEncoding"></stringProp>
          <stringProp name="HTTPSampler.path">${{TARGET_PATH}}</stringProp>
          <stringProp name="HTTPSampler.method">GET</stringProp>
          <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
          <boolProp name="HTTPSampler.auto_redirects">false</boolProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
          <boolProp name="HTTPSampler.DO_MULTIPART_POST">false</boolProp>
          <stringProp name="HTTPSampler.embedded_url_re"></stringProp>
        </HTTPSamplerProxy>
        <hashTree>
          <ConstantTimer guiclass="ConstantTimerGui" testclass="ConstantTimer" testname="Think Time" enabled="true">
            <stringProp name="ConstantTimer.delay">{think_time}</stringProp>
          </ConstantTimer>
          <hashTree/>
        </hashTree>
        <ResultCollector guiclass="ViewResultsFullVisualizer" testclass="ResultCollector" testname="View Results Tree" enabled="true">
          <boolProp name="ResultCollector.error_logging">false</boolProp>
          <objProp>
            <name>saveConfig</name>
            <value class="SampleSaveConfiguration">
              <time>true</time>
              <latency>true</latency>
              <timestamp>true</timestamp>
              <success>true</success>
              <label>true</label>
              <code>true</code>
              <message>true</message>
              <threadName>true</threadName>
              <dataType>true</dataType>
              <encoding>false</encoding>
              <assertions>true</assertions>
              <subresults>true</subresults>
              <responseData>false</responseData>
              <samplerData>false</samplerData>
              <xml>false</xml>
              <fieldNames>true</fieldNames>
              <responseHeaders>false</responseHeaders>
              <requestHeaders>false</requestHeaders>
              <responseDataOnError>false</responseDataOnError>
              <saveAssertionResultsFailureMessage>true</saveAssertionResultsFailureMessage>
              <assertionsResultsToSave>0</assertionsResultsToSave>
              <bytes>true</bytes>
              <sentBytes>true</sentBytes>
              <url>true</url>
              <threadCounts>true</threadCounts>
              <idleTime>true</idleTime>
              <connectTime>true</connectTime>
            </value>
          </objProp>
          <stringProp name="filename"></stringProp>
        </ResultCollector>
        <hashTree/>
        <ResultCollector guiclass="SummaryReport" testclass="ResultCollector" testname="Summary Report" enabled="true">
          <boolProp name="ResultCollector.error_logging">false</boolProp>
          <objProp>
            <name>saveConfig</name>
            <value class="SampleSaveConfiguration">
              <time>true</time>
              <latency>true</latency>
              <timestamp>true</timestamp>
              <success>true</success>
              <label>true</label>
              <code>true</code>
              <message>true</message>
              <threadName>true</threadName>
              <dataType>true</dataType>
              <encoding>false</encoding>
              <assertions>true</assertions>
              <subresults>true</subresults>
              <responseData>false</responseData>
              <samplerData>false</samplerData>
              <xml>false</xml>
              <fieldNames>true</fieldNames>
              <responseHeaders>false</responseHeaders>
              <requestHeaders>false</requestHeaders>
              <responseDataOnError>false</responseDataOnError>
              <saveAssertionResultsFailureMessage>true</saveAssertionResultsFailureMessage>
              <assertionsResultsToSave>0</assertionsResultsToSave>
              <bytes>true</bytes>
              <sentBytes>true</sentBytes>
              <url>true</url>
              <threadCounts>true</threadCounts>
              <idleTime>true</idleTime>
              <connectTime>true</connectTime>
            </value>
          </objProp>
          <stringProp name="filename"></stringProp>
        </ResultCollector>
        <hashTree/>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
'''
            
            # Escribir archivo JMX
            with open(test_plan_file, 'w') as f:
                f.write(jmx_xml)
            
            logger.info(f"Plan de prueba JMeter creado: {test_plan_file}")
            return test_plan_file
        except Exception as e:
            logger.error(f"Error al crear plan de prueba JMeter: {e}")
            return None
    
    def create_locust_test_file(self, test_name, target, parameters):
        """Crear archivo de prueba Locust"""
        try:
            # Obtener configuración del objetivo
            target_config = self.config['targets'].get(target, {})
            protocol = target_config.get('protocol', 'https')
            host = target_config.get('host', 'localhost')
            port = target_config.get('port', 443)
            path = target_config.get('path', '/')
            
            # Construir URL base
            base_url = f"{protocol}://{host}:{port}"
            
            # Crear directorio para la prueba
            test_dir = os.path.join(self.test_scenarios_dir, 'locust', test_name)
            os.makedirs(test_dir, exist_ok=True)
            
            # Crear archivo de prueba Locust
            test_file = os.path.join(test_dir, f"{test_name}.py")
            
            # Contenido del archivo de prueba
            locust_code = f'''from locust import HttpUser, task, between
import random

class {test_name.title().replace('_', '')}User(HttpUser):
    wait_time = between({parameters.get('min_wait', 1000)}, {parameters.get('max_wait', 3000)})
    
    def on_start(self):
        """Se ejecuta cuando un usuario inicia"""
        response = self.client.get("{path}")
        
    @task(3)
    def view_page(self):
        """Ver página principal"""
        self.client.get("{path}")
        
    @task(2)
    def view_dashboard(self):
        """Ver dashboard"""
        self.client.get("/dashboard")
        
    @task(1)
    def view_settings(self):
        """Ver configuración"""
        self.client.get("/settings")
        
    @task(1)
    def api_status(self):
        """Verificar estado de API"""
        self.client.get("/api/status")
'''
            
            # Escribir archivo de prueba
            with open(test_file, 'w') as f:
                f.write(locust_code)
            
            logger.info(f"Archivo de prueba Locust creado: {test_file}")
            return test_file
        except Exception as e:
            logger.error(f"Error al crear archivo de prueba Locust: {e}")
            return None
    
    def run_jmeter_test(self, test_name, target, parameters):
        """Ejecutar prueba con JMeter"""
        try:
            # Crear plan de prueba
            test_plan = self.create_jmeter_test_plan(test_name, target, parameters)
            
            if not test_plan:
                return {'success': False, 'error': 'No se pudo crear el plan de prueba'}
            
            # Generar ID único para la prueba
            test_id = str(uuid.uuid4())
            
            # Crear directorio para resultados
            results_dir = os.path.join(self.reports_dir, 'jmeter', test_id)
            os.makedirs(results_dir, exist_ok=True)
            
            # Archivos de resultados
            jtl_file = os.path.join(results_dir, f"{test_id}.jtl")
            html_file = os.path.join(results_dir, f"{test_id}.html")
            
            # Construir comando JMeter
            jmeter_bin = os.path.join(self.jmeter_dir, 'bin', 'jmeter')
            cmd = [
                jmeter_bin,
                '-n',  # Modo no GUI
                '-t', test_plan,  # Plan de prueba
                '-l', jtl_file,  # Archivo de resultados JTL
                '-e', '-o', html_file  # Generar reporte HTML
            ]
            
            # Registrar prueba en la base de datos
            self.register_test(test_id, test_name, 'load', 'jmeter', target, parameters)
            
            # Actualizar estado de la prueba
            self.update_test_status(test_id, 'running')
            
            # Ejecutar prueba
            logger.info(f"Ejecutando prueba JMeter: {test_name}")
            start_time = datetime.now()
            
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # Guardar proceso para seguimiento
            self.active_tests[test_id] = {
                'process': process,
                'type': 'jmeter',
                'start_time': start_time,
                'status': 'running'
            }
            
            # Esperar a que la prueba termine
            stdout, stderr = process.communicate()
            
            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()
            
            # Actualizar estado de la prueba
            if process.returncode == 0:
                status = 'completed'
                success = True
            else:
                status = 'failed'
                success = False
            
            self.update_test_status(test_id, status, end_time, duration)
            
            # Procesar resultados
            results = self.process_jmeter_results(jtl_file)
            
            # Guardar métricas
            self.save_metrics(test_id, results)
            
            # Limpiar
            if test_id in self.active_tests:
                del self.active_tests[test_id]
            
            return {
                'success': success,
                'test_id': test_id,
                'duration': duration,
                'results': results,
                'jtl_file': jtl_file,
                'html_file': html_file,
                'stdout': stdout,
                'stderr': stderr
            }
        except Exception as e:
            logger.error(f"Error en prueba JMeter: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def process_jmeter_results(self, jtl_file):
        """Procesar resultados JTL de JMeter"""
        try:
            results = {
                'total_samples': 0,
                'successful_samples': 0,
                'failed_samples': 0,
                'avg_response_time': 0,
                'min_response_time': 0,
                'max_response_time': 0,
                'avg_bytes': 0,
                'throughput': 0,
                'errors': {}
            }
            
            if not os.path.exists(jtl_file):
                logger.error(f"Archivo JTL no encontrado: {jtl_file}")
                return results
            
            # Analizar archivo JTL
            tree = ET.parse(jtl_file)
            root = tree.getroot()
            
            response_times = []
            bytes_received = []
            
            for sample in root.findall('.//httpSample'):
                # Contar muestras
                results['total_samples'] += 1
                
                # Verificar éxito
                success = sample.get('s', 'false') == 'true'
                if success:
                    results['successful_samples'] += 1
                else:
                    results['failed_samples'] += 1
                    
                    # Contar errores
                    error_msg = sample.find('.//assertionResult').get('failureMessage', '') if sample.find('.//assertionResult') is not None else ''
                    if error_msg:
                        results['errors'][error_msg] = results['errors'].get(error_msg, 0) + 1
                
                # Tiempo de respuesta
                response_time = float(sample.get('t', 0))
                response_times.append(response_time)
                
                # Bytes recibidos
                bytes_received.append(int(sample.get('by', 0)))
            
            # Calcular estadísticas
            if response_times:
                results['avg_response_time'] = sum(response_times) / len(response_times)
                results['min_response_time'] = min(response_times)
                results['max_response_time'] = max(response_times)
            
            if bytes_received:
                results['avg_bytes'] = sum(bytes_received) / len(bytes_received)
            
            # Calcular throughput (muestras/segundo)
            if results['total_samples'] > 0:
                # Obtener duración de la prueba
                first_sample = root.find('.//httpSample')
                last_sample = list(root.findall('.//httpSample'))[-1] if results['total_samples'] > 0 else first_sample
                
                if first_sample is not None and last_sample is not None:
                    start_time = int(first_sample.get('ts', 0))
                    end_time = int(last_sample.get('ts', 0)) + int(last_sample.get('t', 0))
                    duration = (end_time - start_time) / 1000  # Convertir a segundos
                    
                    if duration > 0:
                        results['throughput'] = results['total_samples'] / duration
            
            return results
        except Exception as e:
            logger.error(f"Error al procesar resultados JMeter: {e}")
            return {}
    
    def run_locust_test(self, test_name, target, parameters):
        """Ejecutar prueba con Locust"""
        try:
            # Crear archivo de prueba
            test_file = self.create_locust_test_file(test_name, target, parameters)
            
            if not test_file:
                return {'success': False, 'error': 'No se pudo crear el archivo de prueba'}
            
            # Generar ID único para la prueba
            test_id = str(uuid.uuid4())
            
            # Crear directorio para resultados
            results_dir = os.path.join(self.reports_dir, 'locust', test_id)
            os.makedirs(results_dir, exist_ok=True)
            
            # Archivos de resultados
            html_file = os.path.join(results_dir, f"{test_id}.html")
            csv_file = os.path.join(results_dir, f"{test_id}.csv")
            
            # Obtener configuración del objetivo
            target_config = self.config['targets'].get(target, {})
            host = target_config.get('host', 'localhost')
            port = target_config.get('port', 443)
            
            # Construir URL base
            base_url = f"{host}:{port}"
            
            # Construir comando Locust
            locust_bin = os.path.join(self.locust_dir, 'locust')
            cmd = [
                locust_bin,
                '-f', test_file,  # Archivo de prueba
                '--host', f'http://{base_url}',  # URL base
                '--users', str(parameters.get('users', 50)),  # Número de usuarios
                '--spawn-rate', str(parameters.get('spawn_rate', 5)),  # Tasa de generación de usuarios
                '--run-time', f"{parameters.get('duration', 120)}s",  # Duración
                '--html', html_file,  # Reporte HTML
                '--csv', csv_file,  # Reporte CSV
                '--headless',  # Modo sin interfaz gráfica
            ]
            
            # Registrar prueba en la base de datos
            self.register_test(test_id, test_name, 'load', 'locust', target, parameters)
            
            # Actualizar estado de la prueba
            self.update_test_status(test_id, 'running')
            
            # Ejecutar prueba
            logger.info(f"Ejecutando prueba Locust: {test_name}")
            start_time = datetime.now()
            
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            #Guardar proceso para seguimiento
            self.active_tests[test_id] = {
                'process': process,
                'type': 'locust',
                'start_time': start_time,
                'status': 'running'
            }
            
            # Esperar a que la prueba termine
            stdout, stderr = process.communicate()
            
            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()
            
            # Actualizar estado de la prueba
            if process.returncode == 0:
                status = 'completed'
                success = True
            else:
                status = 'failed'
                success = False
            
            self.update_test_status(test_id, status, end_time, duration)
            
            # Procesar resultados
            results = self.process_locust_results(csv_file)
            
            # Guardar métricas
            self.save_metrics(test_id, results)
            
            # Limpiar
            if test_id in self.active_tests:
                del self.active_tests[test_id]
            
            return {
                'success': success,
                'test_id': test_id,
                'duration': duration,
                'results': results,
                'html_file': html_file,
                'csv_file': csv_file,
                'stdout': stdout,
                'stderr': stderr
            }
        except Exception as e:
            logger.error(f"Error en prueba Locust: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def process_locust_results(self, csv_file):
        """Procesar resultados CSV de Locust"""
        try:
            results = {
                'total_requests': 0,
                'successful_requests': 0,
                'failed_requests': 0,
                'avg_response_time': 0,
                'min_response_time': 0,
                'max_response_time': 0,
                'median_response_time': 0,
                'requests_per_second': 0
            }
            
            if not os.path.exists(csv_file):
                logger.error(f"Archivo CSV no encontrado: {csv_file}")
                return results
            
            # Leer archivo CSV
            with open(csv_file, 'r') as f:
                lines = f.readlines()
            
            if len(lines) < 2:
                return results
            
            # Procesar datos (omitir cabecera)
            response_times = []
            
            for line in lines[1:]:
                parts = line.strip().split(',')
                if len(parts) >= 8:
                    # Formato: Type,Name,Request#,Response Time,Exception,Status,Method,URL
                    request_type = parts[0]
                    response_time = float(parts[3]) if parts[3] else 0
                    status = parts[5]
                    
                    if request_type == 'Aggregated':
                        continue
                    
                    results['total_requests'] += 1
                    
                    if status == '200' or status == 'OK':
                        results['successful_requests'] += 1
                        response_times.append(response_time)
                    else:
                        results['failed_requests'] += 1
            
            # Calcular estadísticas
            if response_times:
                results['avg_response_time'] = sum(response_times) / len(response_times)
                results['min_response_time'] = min(response_times)
                results['max_response_time'] = max(response_times)
                
                # Calcular mediana
                sorted_times = sorted(response_times)
                n = len(sorted_times)
                if n % 2 == 0:
                    results['median_response_time'] = (sorted_times[n//2-1] + sorted_times[n//2]) / 2
                else:
                    results['median_response_time'] = sorted_times[n//2]
            
            return results
        except Exception as e:
            logger.error(f"Error al procesar resultados Locust: {e}")
            return {}
    
    def run_chaos_experiment(self, test_name, target, parameters):
        """Ejecutar experimento de Chaos Engineering"""
        try:
            # Generar ID único para la prueba
            test_id = str(uuid.uuid4())
            
            # Crear directorio para resultados
            results_dir = os.path.join(self.reports_dir, 'chaos', test_id)
            os.makedirs(results_dir, exist_ok=True)
            
            # Archivo de resultados
            results_file = os.path.join(results_dir, f"{test_id}.json")
            
            # Obtener tipo de experimento
            experiment_type = parameters.get('experiment', 'server.shutdown')
            experiment_target = parameters.get('target', 'web_server')
            auto_recovery = parameters.get('auto_recovery', True)
            
            # Registrar prueba en la base de datos
            self.register_test(test_id, test_name, 'chaos', 'chaos', target, parameters)
            
            # Actualizar estado de la prueba
            self.update_test_status(test_id, 'running')
            
            # Registrar evento de failover
            self.register_failover_event(test_id, 'chaos_experiment_start', f"Iniciando experimento de caos: {experiment_type}")
            
            # Ejecutar experimento
            logger.info(f"Ejecutando experimento de caos: {experiment_type}")
            start_time = datetime.now()
            
            # Simular diferentes tipos de experimentos
            if experiment_type == 'server.shutdown':
                # Simular apagado de servidor
                result = self.simulate_server_shutdown(experiment_target)
            elif experiment_type == 'network.partition':
                # Simular partición de red
                result = self.simulate_network_partition(experiment_target)
            elif experiment_type == 'disk.full':
                # Simular disco lleno
                result = self.simulate_disk_full(experiment_target)
            elif experiment_type == 'memory.exhaustion':
                # Simular agotamiento de memoria
                result = self.simulate_memory_exhaustion(experiment_target)
            else:
                result = {'success': False, 'error': f'Tipo de experimento no soportado: {experiment_type}'}
            
            # Esperar un tiempo para observar efectos
            observation_time = parameters.get('observation_time', 60)
            time.sleep(observation_time)
            
            # Recuperación automática si está habilitada
            if auto_recovery and result['success']:
                self.register_failover_event(test_id, 'recovery_start', "Iniciando recuperación automática")
                
                recovery_result = self.simulate_recovery(experiment_type, experiment_target)
                
                if recovery_result['success']:
                    self.register_failover_event(test_id, 'recovery_complete', "Recuperación completada exitosamente")
                else:
                    self.register_failover_event(test_id, 'recovery_failed', f"Error en recuperación: {recovery_result.get('error')}")
            
            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()
            
            # Actualizar estado de la prueba
            if result['success']:
                status = 'completed'
                success = True
            else:
                status = 'failed'
                success = False
            
            self.update_test_status(test_id, status, end_time, duration)
            
            # Preparar resultados
            results = {
                'experiment_type': experiment_type,
                'experiment_target': experiment_target,
                'success': result['success'],
                'auto_recovery': auto_recovery,
                'observation_time': observation_time,
                'details': result
            }
            
            # Guardar resultados en archivo
            with open(results_file, 'w') as f:
                json.dump(results, f, indent=2, default=str)
            
            # Guardar métricas
            self.save_metrics(test_id, {
                'experiment_success': 1 if result['success'] else 0,
                'recovery_success': 1 if auto_recovery and result.get('recovery_success', False) else 0
            })
            
            return {
                'success': success,
                'test_id': test_id,
                'duration': duration,
                'results': results,
                'results_file': results_file
            }
        except Exception as e:
            logger.error(f"Error en experimento de caos: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def simulate_server_shutdown(self, target):
        """Simular apagado de servidor"""
        try:
            # En un entorno real, esto ejecutaría comandos para detener servicios
            # Por seguridad, solo simulamos la acción
            
            # Simular detención de servicio web
            if target == 'web_server':
                logger.info("Simulando detención de servidor web...")
                # En un entorno real: systemctl stop apache2 o systemctl stop nginx
                return {'success': True, 'message': 'Servidor web detenido'}
            elif target == 'database':
                logger.info("Simulando detención de base de datos...")
                # En un entorno real: systemctl stop mysql
                return {'success': True, 'message': 'Base de datos detenida'}
            else:
                return {'success': False, 'error': f'Objetivo no soportado: {target}'}
        except Exception as e:
            logger.error(f"Error al simular apagado de servidor: {e}")
            return {'success': False, 'error': str(e)}
    
    def simulate_network_partition(self, target):
        """Simular partición de red"""
        try:
            # En un entorno real, esto usaría iptables para bloquear el tráfico
            logger.info("Simulando partición de red...")
            
            # Simular bloqueo de tráfico
            return {'success': True, 'message': 'Partición de red simulada'}
        except Exception as e:
            logger.error(f"Error al simular partición de red: {e}")
            return {'success': False, 'error': str(e)}
    
    def simulate_disk_full(self, target):
        """Simular disco lleno"""
        try:
            # En un entorno real, esto llenaría el disco con un archivo grande
            logger.info("Simulando disco lleno...")
            
            # Simular disco lleno
            return {'success': True, 'message': 'Disco lleno simulado'}
        except Exception as e:
            logger.error(f"Error al simular disco lleno: {e}")
            return {'success': False, 'error': str(e)}
    
    def simulate_memory_exhaustion(self, target):
        """Simular agotamiento de memoria"""
        try:
            # En un entorno real, esto consumiría memoria hasta agotarla
            logger.info("Simulando agotamiento de memoria...")
            
            # Simular agotamiento de memoria
            return {'success': True, 'message': 'Agotamiento de memoria simulado'}
        except Exception as e:
            logger.error(f"Error al simular agotamiento de memoria: {e}")
            return {'success': False, 'error': str(e)}
    
    def simulate_recovery(self, experiment_type, target):
        """Simular recuperación de un experimento"""
        try:
            logger.info(f"Simulando recuperación para: {experiment_type}")
            
            if experiment_type == 'server.shutdown':
                # Simular reinicio de servicio
                if target == 'web_server':
                    logger.info("Simulando reinicio de servidor web...")
                    # En un entorno real: systemctl start apache2 o systemctl start nginx
                    return {'success': True, 'message': 'Servidor web reiniciado', 'recovery_success': True}
                elif target == 'database':
                    logger.info("Simulando reinicio de base de datos...")
                    # En un entorno real: systemctl start mysql
                    return {'success': True, 'message': 'Base de datos reiniciada', 'recovery_success': True}
            elif experiment_type == 'network.partition':
                # Simular restauración de red
                logger.info("Simulando restauración de red...")
                return {'success': True, 'message': 'Red restaurada', 'recovery_success': True}
            elif experiment_type == 'disk.full':
                # Simular limpieza de disco
                logger.info("Simulando limpieza de disco...")
                return {'success': True, 'message': 'Disco limpiado', 'recovery_success': True}
            elif experiment_type == 'memory.exhaustion':
                # Simular liberación de memoria
                logger.info("Simulando liberación de memoria...")
                return {'success': True, 'message': 'Memoria liberada', 'recovery_success': True}
            else:
                return {'success': False, 'error': f'Tipo de experimento no soportado: {experiment_type}'}
        except Exception as e:
            logger.error(f"Error al simular recuperación: {e}")
            return {'success': False, 'error': str(e)}
    
    def register_test(self, test_id, name, test_type, tool, target, parameters):
        """Registrar prueba en la base de datos"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO tests (test_id, name, type, tool, target, parameters, start_time)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (
                test_id,
                name,
                test_type,
                tool,
                target,
                json.dumps(parameters),
                datetime.now()
            ))
            
            conn.commit()
            conn.close()
            
            return True
        except Exception as e:
            logger.error(f"Error al registrar prueba: {e}")
            return False
    
    def update_test_status(self, test_id, status, end_time=None, duration=None):
        """Actualizar estado de una prueba"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            if end_time and duration:
                cursor.execute('''
                    UPDATE tests SET status = ?, end_time = ?, duration = ?
                    WHERE test_id = ?
                ''', (status, end_time, duration, test_id))
            else:
                cursor.execute('''
                    UPDATE tests SET status = ?
                    WHERE test_id = ?
                ''', (status, test_id))
            
            conn.commit()
            conn.close()
            
            return True
        except Exception as e:
            logger.error(f"Error al actualizar estado de prueba: {e}")
            return False
    
    def register_failover_event(self, test_id, event_type, description):
        """Registrar evento de failover"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO failover_events (test_id, event_type, description, timestamp)
                VALUES (?, ?, ?, ?)
            ''', (test_id, event_type, description, datetime.now()))
            
            conn.commit()
            conn.close()
            
            return True
        except Exception as e:
            logger.error(f"Error al registrar evento de failover: {e}")
            return False
    
    def save_metrics(self, test_id, metrics):
        """Guardar métricas de una prueba"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            for metric_name, metric_value in metrics.items():
                if isinstance(metric_value, (int, float)):
                    cursor.execute('''
                        INSERT INTO metrics (test_id, metric_name, metric_value)
                        VALUES (?, ?, ?)
                    ''', (test_id, metric_name, metric_value))
            
            conn.commit()
            conn.close()
            
            return True
        except Exception as e:
            logger.error(f"Error al guardar métricas: {e}")
            return False
    
    def run_test_scenario(self, scenario_name):
        """Ejecutar un escenario de prueba"""
        try:
            # Obtener escenario de la base de datos
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                SELECT * FROM test_scenarios WHERE name = ?
            ''', (scenario_name,))
            
            scenario = cursor.fetchone()
            conn.close()
            
            if not scenario:
                return {'success': False, 'error': f'Escenario no encontrado: {scenario_name}'}
            
            # Obtener parámetros del escenario
            parameters = json.loads(scenario['parameters'])
            
            # Ejecutar prueba según tipo y herramienta
            if scenario['tool'] == 'jmeter':
                result = self.run_jmeter_test(
                    scenario['name'],
                    parameters.get('target', 'web'),
                    parameters
                )
            elif scenario['tool'] == 'locust':
                result = self.run_locust_test(
                    scenario['name'],
                    parameters.get('target', 'web'),
                    parameters
                )
            elif scenario['tool'] == 'chaos':
                result = self.run_chaos_experiment(
                    scenario['name'],
                    parameters.get('target', 'web'),
                    parameters
                )
            else:
                result = {'success': False, 'error': f'Herramienta no soportada: {scenario["tool"]}'}
            
            return result
        except Exception as e:
            logger.error(f"Error al ejecutar escenario de prueba: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def run_comprehensive_test_suite(self):
        """Ejecutar suite de pruebas completa"""
        try:
            test_results = {}
            
            # Obtener todos los escenarios de prueba
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('SELECT name FROM test_scenarios ORDER BY type, tool')
            scenarios = [row[0] for row in cursor.fetchall()]
            conn.close()
            
            # Ejecutar cada escenario
            for scenario in scenarios:
                logger.info(f"Ejecutando escenario: {scenario}")
                result = self.run_test_scenario(scenario)
                test_results[scenario] = result
                
                # Esperar entre pruebas para evitar sobrecarga
                time.sleep(10)
            
            # Generar reporte consolidado
            report_file = self.generate_comprehensive_report(test_results)
            
            return {
                'success': True,
                'test_results': test_results,
                'report_file': report_file
            }
        except Exception as e:
            logger.error(f"Error en suite de pruebas completa: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def generate_comprehensive_report(self, test_results):
        """Generar reporte consolidado de todas las pruebas"""
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            report_file = os.path.join(self.reports_dir, f"comprehensive_report_{timestamp}.html")
            
            # Contenido HTML
            html_content = f"""
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Pruebas de Estrés y Failover - Virtualmin Enterprise</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
        }}
        .header {{
            text-align: center;
            margin-bottom: 30px;
            padding-bottom: 20px;
            border-bottom: 1px solid #ddd;
        }}
        .summary {{
            display: flex;
            justify-content: space-around;
            margin-bottom: 30px;
        }}
        .summary-item {{
            text-align: center;
            padding: 15px;
            border-radius: 8px;
            min-width: 120px;
        }}
        .summary-item.success {{
            background-color: #e8f5e9;
            color: #2e7d32;
        }}
        .summary-item.failure {{
            background-color: #ffebee;
            color: #c62828;
        }}
        .summary-item.total {{
            background-color: #e3f2fd;
            color: #1565c0;
        }}
        .summary-number {{
            font-size: 24px;
            font-weight: bold;
            margin-bottom: 5px;
        }}
        .summary-label {{
            font-size: 14px;
        }}
        .test-section {{
            margin-bottom: 30px;
            padding: 20px;
            border-radius: 8px;
            border: 1px solid #ddd;
        }}
        .test-title {{
            font-size: 20px;
            font-weight: bold;
            margin-bottom: 15px;
            color: #333;
        }}
        .test-status {{
            margin-bottom: 15px;
            padding: 8px 12px;
            border-radius: 4px;
            font-weight: bold;
            text-align: center;
        }}
        .test-status.success {{
            background-color: #e8f5e9;
            color: #2e7d32;
        }}
        .test-status.failure {{
            background-color: #ffebee;
            color: #c62828;
        }}
        .test-details {{
            margin-top: 15px;
        }}
        .metric {{
            margin-bottom: 10px;
            padding: 10px;
            border-radius: 4px;
            background-color: #f5f5f5;
        }}
        .metric-name {{
            font-weight: bold;
            margin-bottom: 5px;
        }}
        .footer {{
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Reporte de Pruebas de Estrés y Failover</h1>
            <p>Virtualmin Enterprise - Sistema de Pruebas de Estrés y Failover</p>
        </div>
        
        <div class="summary">
            <div class="summary-item total">
                <div class="summary-number">{len(test_results)}</div>
                <div class="summary-label">Total</div>
            </div>
            <div class="summary-item success">
                <div class="summary-number">{sum(1 for r in test_results.values() if r.get('success', False))}</div>
                <div class="summary-label">Exitosas</div>
            </div>
            <div class="summary-item failure">
                <div class="summary-number">{sum(1 for r in test_results.values() if not r.get('success', False))}</div>
                <div class="summary-label">Fallidas</div>
            </div>
        </div>
"""
            
            # Añadir secciones de pruebas
            for scenario, result in test_results.items():
                html_content += f"""
        <div class="test-section">
            <div class="test-title">Escenario: {scenario}</div>
"""
                
                if result.get('success', False):
                    html_content += f"""
            <div class="test-status success">Completado exitosamente</div>
"""
                    
                    if 'results' in result and result['results']:
                        html_content += f"""
            <div class="test-details">
                <p><strong>Duración:</strong> {result.get('duration', 'N/A')} segundos</p>
"""
                        
                        # Mostrar métricas
                        for metric_name, metric_value in result['results'].items():
                            if isinstance(metric_value, (int, float)):
                                html_content += f"""
                <div class="metric">
                    <div class="metric-name">{metric_name.replace('_', ' ').title()}</div>
                    <div>{metric_value}</div>
                </div>
"""
                        
                        html_content += """
            </div>
"""
                else:
                    html_content += f"""
            <div class="test-status failure">Error: {result.get('error', 'Unknown error')}</div>
"""
                
                html_content += """
        </div>
"""
            
            # Cerrar HTML
            html_content += """
    </div>
    
    <div class="footer">
        <p>Reporte generado por Virtualmin Enterprise - Sistema de Pruebas de Estrés y Failover</p>
        <p>Fecha de generación: """ + datetime.now().strftime('%Y-%m-%d %H:%M:%S') + """</p>
    </div>
</body>
</html>
"""
            
            # Escribir archivo HTML
            with open(report_file, 'w') as f:
                f.write(html_content)
            
            logger.info(f"Reporte consolidado generado: {report_file}")
            return report_file
        except Exception as e:
            logger.error(f"Error al generar reporte consolidado: {e}")
            return None
    
    def stop_test(self, test_id):
        """Detener una prueba en ejecución"""
        try:
            if test_id not in self.active_tests:
                return {'success': False, 'message': 'Prueba no encontrada o no está en ejecución'}
            
            test_info = self.active_tests[test_id]
            process = test_info['process']
            
            # Terminar proceso
            process.terminate()
            process.wait(timeout=10)
            
            # Actualizar estado
            self.update_test_status(test_id, 'stopped')
            
            # Limpiar
            del self.active_tests[test_id]
            
            return {'success': True, 'message': 'Prueba detenida'}
        except Exception as e:
            logger.error(f"Error al detener prueba: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_active_tests(self):
        """Obtener pruebas activas"""
        return {
            test_id: {
                'type': test_info['type'],
                'start_time': test_info['start_time'].isoformat(),
                'status': test_info['status']
            }
            for test_id, test_info in self.active_tests.items()
        }

def main():
    """Función principal"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Sistema de Pruebas de Estrés y Failover para Virtualmin Enterprise')
    parser.add_argument('--config', help='Archivo de configuración', default='/opt/virtualmin-enterprise/testing/stresstesting_config.json')
    parser.add_argument('--install', action='store_true', help='Instalar herramientas de prueba')
    parser.add_argument('--scenario', help='Ejecutar escenario de prueba específico')
    parser.add_argument('--comprehensive', action='store_true', help='Ejecutar suite de pruebas completa')
    parser.add_argument('--stop', help='Detener prueba activa')
    parser.add_argument('--list', action='store_true', help='Listar pruebas activas')
    
    args = parser.parse_args()
    
    # Inicializar sistema
    stresstesting_system = StressTestingSystem(args.config)
    
    if args.install:
        # Instalar herramientas
        tools = stresstesting_system.install_tools()
        print(f"Herramientas instaladas: {', '.join(tools)}")
    elif args.scenario:
        # Ejecutar escenario específico
        result = stresstesting_system.run_test_scenario(args.scenario)
        
        if result['success']:
            print(f"Escenario ejecutado exitosamente")
            print(f"ID de prueba: {result['test_id']}")
            print(f"Duración: {result.get('duration', 'N/A')} segundos")
            if 'html_file' in result:
                print(f"Reporte HTML: {result['html_file']}")
        else:
            print(f"Error en escenario: {result.get('error')}")
            sys.exit(1)
    elif args.comprehensive:
        # Ejecutar suite completa
        result = stresstesting_system.run_comprehensive_test_suite()
        
        if result['success']:
            print(f"Suite de pruebas completada exitosamente")
            print(f"Reporte consolidado: {result['report_file']}")
        else:
            print(f"Error en suite de pruebas: {result.get('error')}")
            sys.exit(1)
    elif args.stop:
        # Detener prueba
        result = stresstesting_system.stop_test(args.stop)
        
        if result['success']:
            print(f"Prueba detenida: {args.stop}")
        else:
            print(f"Error al detener prueba: {result.get('message')}")
            sys.exit(1)
    elif args.list:
        # Listar pruebas activas
        active_tests = stresstesting_system.get_active_tests()
        
        if active_tests:
            print("Pruebas activas:")
            for test_id, test_info in active_tests.items():
                print(f"  - {test_id}: {test_info['type']} ({test_info['status']}) - {test_info['start_time']}")
        else:
            print("No hay pruebas activas")
    else:
        # Ejecutar suite completa por defecto
        result = stresstesting_system.run_comprehensive_test_suite()
        
        if result['success']:
            print(f"Suite de pruebas completada exitosamente")
            print(f"Reporte consolidado: {result['report_file']}")
        else:
            print(f"Error en suite de pruebas: {result.get('error')}")
            sys.exit(1)

if __name__ == "__main__":
    main()