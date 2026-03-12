#!/usr/bin/env python3
"""
Sistema Completo de Clustering Ilimitado con FossFlow
Permite crear, gestionar y visualizar clusters de servidores ilimitados
con conexión gráfica interactiva usando FossFlow
"""

import json
import sys
import os
import time
import socket
import subprocess
import threading
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import requests
import logging

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('cluster_manager.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class UnlimitedClusterManager:
    """Gestor de clustering ilimitado con FossFlow"""
    
    def __init__(self):
        self.servers = {}
        self.connections = []
        self.clusters = {}
        self.fossflow_data = None
        self.real_time_updates = True
        self.update_interval = 5  # segundos
        
        # Tipos de servidores soportados
        self.server_types = {
            'web': {'color': '#4CAF50', 'icon': '🌐', 'ports': [80, 443, 8080]},
            'database': {'color': '#2196F3', 'icon': '🗄️', 'ports': [3306, 5432, 27017]},
            'dns': {'color': '#FF9800', 'icon': '🌍', 'ports': [53]},
            'cache': {'color': '#9C27B0', 'icon': '⚡', 'ports': [6379, 11211]},
            'load_balancer': {'color': '#F44336', 'icon': '⚖️', 'ports': [80, 443, 1936]},
            'file_system': {'color': '#795548', 'icon': '📁', 'ports': [22, 445]},
            'monitoring': {'color': '#607D8B', 'icon': '📊', 'ports': [9090, 3000]},
            'backup': {'color': '#FF5722', 'icon': '💾', 'ports': [22, 873]},
            'security': {'color': '#E91E63', 'icon': '🛡️', 'ports': [22, 443, 8080]}
        }
        
    def add_server(self, server_id: str, name: str, server_type: str,
                   ip: str, region: str = "default", simulate: bool = False, **kwargs) -> bool:
        """Agrega un nuevo servidor al cluster"""
        logger.info(f"🔍 DIAGNÓSTICO: Intentando agregar servidor {server_id} (simulate={simulate})")
        try:
            if server_id in self.servers:
                logger.warning(f"Servidor {server_id} ya existe")
                logger.info(f"🔍 DIAGNÓSTICO: Servidor duplicado detectado")
                return False
                
            if server_type not in self.server_types:
                logger.error(f"Tipo de servidor {server_type} no soportado")
                logger.info(f"🔍 DIAGNÓSTICO: Tipo de servidor inválido: {server_type}")
                return False
            
            # Validar IP y conectividad (solo si no es simulación)
            if not simulate and not self._validate_server(ip, self.server_types[server_type]['ports']):
                logger.error(f"No se puede conectar al servidor {ip}")
                logger.info(f"🔍 DIAGNÓSTICO: Fallo de conexión detectado para {ip}:{self.server_types[server_type]['ports']}")
                return False
            elif simulate:
                logger.info(f"🔍 DIAGNÓSTICO: Modo simulación activado, omitiendo verificación de conexión")
            
            server = {
                'id': server_id,
                'name': name,
                'type': server_type,
                'ip': ip,
                'region': region,
                'status': 'active',
                'created_at': datetime.now().isoformat(),
                'last_check': datetime.now().isoformat(),
                'metrics': {
                    'cpu': 0,
                    'memory': 0,
                    'disk': 0,
                    'network': 0
                },
                **kwargs
            }
            
            self.servers[server_id] = server
            logger.info(f"Servidor {server_id} agregado exitosamente")
            logger.info(f"🔍 DIAGNÓSTICO: Total de servidores en el sistema: {len(self.servers)}")
            return True
            
        except Exception as e:
            logger.error(f"Error agregando servidor {server_id}: {e}")
            logger.error(f"🔍 DIAGNÓSTICO: Excepción capturada en add_server: {type(e).__name__}")
            return False
    
    def remove_server(self, server_id: str) -> bool:
        """Elimina un servidor del cluster"""
        try:
            if server_id not in self.servers:
                logger.warning(f"Servidor {server_id} no encontrado")
                return False
            
            # Eliminar conexiones asociadas
            self.connections = [
                conn for conn in self.connections 
                if conn['from'] != server_id and conn['to'] != server_id
            ]
            
            del self.servers[server_id]
            logger.info(f"Servidor {server_id} eliminado exitosamente")
            return True
            
        except Exception as e:
            logger.error(f"Error eliminando servidor {server_id}: {e}")
            return False
    
    def connect_servers(self, from_server: str, to_server: str, 
                       connection_type: str = "standard", **kwargs) -> bool:
        """Conecta dos servidores visualmente"""
        try:
            if from_server not in self.servers or to_server not in self.servers:
                logger.error("Uno o ambos servidores no existen")
                return False
            
            # Verificar si la conexión ya existe
            existing = any(
                conn for conn in self.connections 
                if (conn['from'] == from_server and conn['to'] == to_server) or
                   (conn['from'] == to_server and conn['to'] == from_server)
            )
            
            if existing:
                logger.warning("La conexión ya existe")
                return False
            
            connection = {
                'id': f"{from_server}_{to_server}_{int(time.time())}",
                'from': from_server,
                'to': to_server,
                'type': connection_type,
                'status': 'active',
                'created_at': datetime.now().isoformat(),
                'latency': self._measure_latency(
                    self.servers[from_server]['ip'],
                    self.servers[to_server]['ip']
                ),
                **kwargs
            }
            
            self.connections.append(connection)
            logger.info(f"Conexión creada: {from_server} -> {to_server}")
            return True
            
        except Exception as e:
            logger.error(f"Error creando conexión: {e}")
            return False
    
    def disconnect_servers(self, from_server: str, to_server: str) -> bool:
        """Desconecta dos servidores"""
        try:
            original_count = len(self.connections)
            self.connections = [
                conn for conn in self.connections 
                if not ((conn['from'] == from_server and conn['to'] == to_server) or
                       (conn['from'] == to_server and conn['to'] == from_server))
            ]
            
            if len(self.connections) < original_count:
                logger.info(f"Conexión eliminada: {from_server} <-> {to_server}")
                return True
            else:
                logger.warning("No se encontró la conexión especificada")
                return False
                
        except Exception as e:
            logger.error(f"Error eliminando conexión: {e}")
            return False
    
    def create_cluster(self, cluster_name: str, server_ids: List[str]) -> bool:
        """Crea un cluster con los servidores especificados"""
        try:
            # Verificar que todos los servidores existan
            missing_servers = [sid for sid in server_ids if sid not in self.servers]
            if missing_servers:
                logger.error(f"Servidores no encontrados: {missing_servers}")
                return False
            
            # Crear el cluster
            cluster = {
                'id': cluster_name,
                'name': cluster_name,
                'servers': server_ids,
                'created_at': datetime.now().isoformat(),
                'status': 'active',
                'load_balancer': None,
                'health_status': 'healthy'
            }
            
            # Asignar load balancer si hay servidores web
            web_servers = [
                sid for sid in server_ids 
                if self.servers[sid]['type'] == 'web'
            ]
            if web_servers:
                cluster['load_balancer'] = web_servers[0]
            
            self.clusters[cluster_name] = cluster
            
            # Conectar automáticamente los servidores del cluster
            for i, server1 in enumerate(server_ids):
                for server2 in server_ids[i+1:]:
                    self.connect_servers(server1, server2, "cluster_internal")
            
            logger.info(f"Cluster {cluster_name} creado con {len(server_ids)} servidores")
            return True
            
        except Exception as e:
            logger.error(f"Error creando cluster {cluster_name}: {e}")
            return False
    
    def generate_fossflow_data(self) -> Dict:
        """Genera datos en formato FossFlow para visualización"""
        try:
            nodes = []
            links = []
            
            # Generar nodos
            for server_id, server in self.servers.items():
                node_config = self.server_types[server['type']]
                node = {
                    'id': server_id,
                    'label': f"{server['name']}\n({server['ip']})",
                    'type': server['type'],
                    'color': node_config['color'],
                    'icon': node_config['icon'],
                    'data': {
                        'ip': server['ip'],
                        'status': server['status'],
                        'region': server['region'],
                        'cpu': server['metrics']['cpu'],
                        'memory': server['metrics']['memory'],
                        'disk': server['metrics']['disk'],
                        'network': server['metrics']['network'],
                        'last_check': server['last_check'],
                        'tooltip': f"<strong>{server['name']}</strong><br/>"
                                 f"IP: {server['ip']}<br/>"
                                 f"Tipo: {server['type']}<br/>"
                                 f"Estado: {server['status']}<br/>"
                                 f"CPU: {server['metrics']['cpu']}%<br/>"
                                 f"Memoria: {server['metrics']['memory']}%<br/>"
                                 f"Disco: {server['metrics']['disk']}%<br/>"
                                 f"Red: {server['metrics']['network']} MB/s"
                    }
                }
                nodes.append(node)
            
            # Generar enlaces
            for conn in self.connections:
                link = {
                    'id': conn['id'],
                    'source': conn['from'],
                    'target': conn['to'],
                    'type': conn['type'],
                    'color': '#666',
                    'data': {
                        'latency': conn.get('latency', 0),
                        'status': conn['status'],
                        'created_at': conn['created_at'],
                        'tooltip': f"Conexión: {conn['from']} ↔ {conn['to']}<br/>"
                                 f"Tipo: {conn['type']}<br/>"
                                 f"Latencia: {conn.get('latency', 0)}ms<br/>"
                                 f"Estado: {conn['status']}"
                    }
                }
                links.append(link)
            
            fossflow_data = {
                'nodes': nodes,
                'links': links,
                'metadata': {
                    'title': 'Cluster de Servidores Ilimitados',
                    'isometric': True,
                    'scale': 1.0,
                    'total_servers': len(self.servers),
                    'total_connections': len(self.connections),
                    'clusters': len(self.clusters),
                    'last_update': datetime.now().isoformat(),
                    'real_time': self.real_time_updates
                },
                'clusters': self.clusters
            }
            
            self.fossflow_data = fossflow_data
            return fossflow_data
            
        except Exception as e:
            logger.error(f"Error generando datos FossFlow: {e}")
            return {}
    
    def generate_interactive_dashboard(self, output_file: str = "cluster_dashboard.html") -> str:
        """Genera un dashboard interactivo con FossFlow"""
        try:
            fossflow_data = self.generate_fossflow_data()
            
            # Usar concatenación de strings en lugar de f-string para evitar problemas
            html_content = self._generate_html_template(fossflow_data)
            
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(html_content)
            
            logger.info(f"Dashboard interactivo generado en {output_file}")
            return output_file
            
        except Exception as e:
            logger.error(f"Error generando dashboard: {e}")
            return ""
    
    def _generate_html_template(self, fossflow_data):
        """Genera el template HTML sin usar f-string anidados"""
        return """<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cluster Manager - Servidores Ilimitados</title>
    <script src="https://unpkg.com/react@17/umd/react.production.min.js"></script>
    <script src="https://unpkg.com/react-dom@17/umd/react-dom.production.min.js"></script>
    <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            padding: 20px;
            box-shadow: 0 2px 20px rgba(0,0,0,0.1);
            backdrop-filter: blur(10px);
        }
        
        .header h1 {
            color: #333;
            font-size: 2em;
            margin-bottom: 10px;
        }
        
        .stats {
            display: flex;
            gap: 20px;
            flex-wrap: wrap;
        }
        
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 15px 20px;
            border-radius: 10px;
            min-width: 150px;
            text-align: center;
        }
        
        .stat-number {
            font-size: 2em;
            font-weight: bold;
        }
        
        .stat-label {
            font-size: 0.9em;
            opacity: 0.9;
        }
        
        .main-container {
            display: flex;
            gap: 20px;
            padding: 20px;
            max-width: 1600px;
            margin: 0 auto;
        }
        
        .control-panel {
            background: rgba(255, 255, 255, 0.95);
            padding: 20px;
            border-radius: 15px;
            width: 350px;
            height: fit-content;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
            backdrop-filter: blur(10px);
        }
        
        .visualization-panel {
            background: rgba(255, 255, 255, 0.95);
            padding: 20px;
            border-radius: 15px;
            flex: 1;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
            backdrop-filter: blur(10px);
            min-height: 600px;
        }
        
        .form-group {
            margin-bottom: 15px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: 500;
            color: #333;
        }
        
        .form-group input, .form-group select {
            width: 100%;
            padding: 10px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 14px;
            transition: border-color 0.3s;
        }
        
        .form-group input:focus, .form-group select:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 12px 20px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 500;
            transition: transform 0.2s, box-shadow 0.2s;
            width: 100%;
            margin-bottom: 10px;
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 20px rgba(102, 126, 234, 0.4);
        }
        
        .btn-secondary {
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
        }
        
        .btn-danger {
            background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%);
        }
        
        .server-list {
            max-height: 300px;
            overflow-y: auto;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            padding: 10px;
        }
        
        .server-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 8px;
            margin-bottom: 5px;
            background: #f8f9fa;
            border-radius: 5px;
            font-size: 12px;
        }
        
        .server-item.selected {
            background: #e3f2fd;
            border: 1px solid #2196f3;
        }
        
        .cluster-diagram {
            width: 100%;
            height: 600px;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            position: relative;
            background: #fafafa;
            overflow: hidden;
        }
        
        .node {
            position: absolute;
            padding: 10px 15px;
            border-radius: 8px;
            color: white;
            font-weight: bold;
            font-size: 12px;
            text-align: center;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
            z-index: 10;
            min-width: 100px;
        }
        
        .node:hover {
            transform: scale(1.05);
            box-shadow: 0 4px 20px rgba(0,0,0,0.3);
            z-index: 20;
        }
        
        .connection {
            position: absolute;
            background: #666;
            height: 2px;
            transform-origin: left center;
            z-index: 1;
        }
        
        .tooltip {
            position: absolute;
            background: rgba(0, 0, 0, 0.9);
            color: white;
            padding: 10px;
            border-radius: 5px;
            font-size: 12px;
            z-index: 1000;
            pointer-events: none;
            display: none;
            max-width: 300px;
        }
        
        .legend {
            position: absolute;
            top: 10px;
            right: 10px;
            background: rgba(255, 255, 255, 0.9);
            padding: 10px;
            border-radius: 8px;
            font-size: 12px;
            z-index: 100;
        }
        
        .legend-item {
            display: flex;
            align-items: center;
            margin-bottom: 5px;
        }
        
        .legend-color {
            width: 20px;
            height: 20px;
            margin-right: 8px;
            border-radius: 3px;
        }
        
        .status-indicator {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            display: inline-block;
            margin-right: 5px;
        }
        
        .status-active {
            background: #4CAF50;
        }
        
        .status-inactive {
            background: #f44336;
        }
        
        .status-warning {
            background: #FF9800;
        }
        
        @keyframes pulse {
            0% { transform: scale(1); }
            50% { transform: scale(1.05); }
            100% { transform: scale(1); }
        }
        
        .pulse {
            animation: pulse 2s infinite;
        }
    </style>
</head>
<body>
    <div id="root"></div>
    
    <script type="text/babel">
        const CLUSTER_DATA = """ + json.dumps(fossflow_data) + """;
        
        function ClusterManager() {
            const [servers, setServers] = React.useState(CLUSTER_DATA.nodes || []);
            const [connections, setConnections] = React.useState(CLUSTER_DATA.links || []);
            const [selectedServer, setSelectedServer] = React.useState(null);
            const [selectedServer2, setSelectedServer2] = React.useState(null);
            const [newServer, setNewServer] = React.useState({
                id: '',
                name: '',
                type: 'web',
                ip: '',
                region: 'default'
            });
            const [tooltip, setTooltip] = React.useState({ visible: false, content: '', x: 0, y: 0 });
            
            const serverTypes = {
                'web': { color: '#4CAF50', icon: '🌐' },
                'database': { color: '#2196F3', icon: '🗄️' },
                'dns': { color: '#FF9800', icon: '🌍' },
                'cache': { color: '#9C27B0', icon: '⚡' },
                'load_balancer': { color: '#F44336', icon: '⚖️' },
                'file_system': { color: '#795548', icon: '📁' },
                'monitoring': { color: '#607D8B', icon: '📊' },
                'backup': { color: '#FF5722', icon: '💾' },
                'security': { color: '#E91E63', icon: '🛡️' }
            };
            
            const addServer = () => {
                if (!newServer.id || !newServer.name || !newServer.ip) {
                    alert('Por favor complete todos los campos');
                    return;
                }
                
                const serverNode = {
                    id: newServer.id,
                    label: `${newServer.name}\\n(${newServer.ip})`,
                    type: newServer.type,
                    color: serverTypes[newServer.type].color,
                    icon: serverTypes[newServer.type].icon,
                    data: {
                        ip: newServer.ip,
                        status: 'active',
                        region: newServer.region,
                        cpu: 0,
                        memory: 0,
                        disk: 0,
                        network: 0,
                        last_check: new Date().toISOString(),
                        tooltip: `<strong>${newServer.name}</strong><br/>IP: ${newServer.ip}<br/>Tipo: ${newServer.type}<br/>Estado: Activo`
                    }
                };
                
                setServers([...servers, serverNode]);
                setNewServer({ id: '', name: '', type: 'web', ip: '', region: 'default' });
            };
            
            const removeServer = (serverId) => {
                setServers(servers.filter(s => s.id !== serverId));
                setConnections(connections.filter(c => c.source !== serverId && c.target !== serverId));
                setSelectedServer(null);
            };
            
            const connectServers = () => {
                if (!selectedServer || !selectedServer2 || selectedServer === selectedServer2) {
                    alert('Seleccione dos servidores diferentes para conectar');
                    return;
                }
                
                const existingConnection = connections.find(c => 
                    (c.source === selectedServer && c.target === selectedServer2) ||
                    (c.source === selectedServer2 && c.target === selectedServer)
                );
                
                if (existingConnection) {
                    alert('Estos servidores ya están conectados');
                    return;
                }
                
                const newConnection = {
                    id: `${selectedServer}_${selectedServer2}_${Date.now()}`,
                    source: selectedServer,
                    target: selectedServer2,
                    type: 'standard',
                    color: '#666',
                    data: {
                        latency: Math.floor(Math.random() * 50) + 1,
                        status: 'active',
                        created_at: new Date().toISOString()
                    }
                };
                
                setConnections([...connections, newConnection]);
                setSelectedServer2(null);
            };
            
            const disconnectServers = (source, target) => {
                setConnections(connections.filter(c => 
                    !(c.source === source && c.target === target) &&
                    !(c.source === target && c.target === source)
                ));
            };
            
            const showTooltip = (content, x, y) => {
                setTooltip({ visible: true, content, x, y });
            };
            
            const hideTooltip = () => {
                setTooltip({ visible: false, content: '', x: 0, y: 0 });
            };
            
            const calculateNodePosition = (index, total) => {
                const centerX = 400;
                const centerY = 300;
                const radius = Math.min(250, 300 / Math.max(1, total / 8));
                const angle = (2 * Math.PI * index) / total;
                return {
                    x: centerX + radius * Math.cos(angle),
                    y: centerY + radius * Math.sin(angle)
                };
            };
            
            return (
                <div>
                    <div className="header">
                        <h1>🚀 Cluster Manager - Servidores Ilimitados</h1>
                        <div className="stats">
                            <div className="stat-card">
                                <div className="stat-number">{servers.length}</div>
                                <div className="stat-label">Servidores</div>
                            </div>
                            <div className="stat-card">
                                <div className="stat-number">{connections.length}</div>
                                <div className="stat-label">Conexiones</div>
                            </div>
                            <div className="stat-card">
                                <div className="stat-number">1</div>
                                <div className="stat-label">Clusters</div>
                            </div>
                            <div className="stat-card">
                                <div className="stat-number">100%</div>
                                <div className="stat-label">Disponibilidad</div>
                            </div>
                        </div>
                    </div>
                    
                    <div className="main-container">
                        <div className="control-panel">
                            <h3>🎛️ Panel de Control</h3>
                            
                            <div className="form-group">
                                <label>ID del Servidor</label>
                                <input
                                    type="text"
                                    value={newServer.id}
                                    onChange={(e) => setNewServer({...newServer, id: e.target.value})}
                                    placeholder="ej: web-server-1"
                                />
                            </div>
                            
                            <div className="form-group">
                                <label>Nombre</label>
                                <input
                                    type="text"
                                    value={newServer.name}
                                    onChange={(e) => setNewServer({...newServer, name: e.target.value})}
                                    placeholder="ej: Servidor Web Principal"
                                />
                            </div>
                            
                            <div className="form-group">
                                <label>Tipo</label>
                                <select
                                    value={newServer.type}
                                    onChange={(e) => setNewServer({...newServer, type: e.target.value})}
                                >
                                    {Object.keys(serverTypes).map(type => (
                                        <option key={type} value={type}>
                                            {serverTypes[type].icon} {type}
                                        </option>
                                    ))}
                                </select>
                            </div>
                            
                            <div className="form-group">
                                <label>Dirección IP</label>
                                <input
                                    type="text"
                                    value={newServer.ip}
                                    onChange={(e) => setNewServer({...newServer, ip: e.target.value})}
                                    placeholder="ej: 192.168.1.100"
                                />
                            </div>
                            
                            <div className="form-group">
                                <label>Región</label>
                                <input
                                    type="text"
                                    value={newServer.region}
                                    onChange={(e) => setNewServer({...newServer, region: e.target.value})}
                                    placeholder="ej: us-east-1"
                                />
                            </div>
                            
                            <button className="btn" onClick={addServer}>
                                ➕ Agregar Servidor
                            </button>
                            
                            {selectedServer && selectedServer2 && (
                                <button className="btn btn-secondary" onClick={connectServers}>
                                    🔗 Conectar Servidores
                                </button>
                            )}
                            
                            <h4>📋 Servidores Actuales</h4>
                            <div className="server-list">
                                {servers.map(server => (
                                    <div 
                                        key={server.id}
                                        className={`server-item ${selectedServer === server.id ? 'selected' : ''} ${selectedServer2 === server.id ? 'selected' : ''}`}
                                        onClick={() => {
                                            if (!selectedServer) {
                                                setSelectedServer(server.id);
                                            } else if (!selectedServer2 && server.id !== selectedServer) {
                                                setSelectedServer2(server.id);
                                            } else {
                                                setSelectedServer(server.id);
                                                setSelectedServer2(null);
                                            }
                                        }}
                                        onMouseEnter={(e) => {
                                            const rect = e.target.getBoundingClientRect();
                                            showTooltip(server.data.tooltip, rect.left, rect.top);
                                        }}
                                        onMouseLeave={hideTooltip}
                                    >
                                        <span>
                                            <span className={`status-indicator status-${server.data.status}`}></span>
                                            {serverTypes[server.type].icon} {server.label.split('\\n')[0]}
                                        </span>
                                        <button 
                                            className="btn btn-danger" 
                                            style={{width: 'auto', padding: '5px 10px', margin: '0'}}
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                removeServer(server.id);
                                            }}
                                        >
                                            🗑️
                                        </button>
                                    </div>
                                ))}
                            </div>
                            
                            {selectedServer && (
                                <div style={{marginTop: '10px', fontSize: '12px', color: '#666'}}>
                                    Seleccionado: {selectedServer}
                                    {selectedServer2 && ` ↔ ${selectedServer2}`}
                                </div>
                            )}
                        </div>
                        
                        <div className="visualization-panel">
                            <h3>🌐 Visualización del Cluster</h3>
                            <div className="cluster-diagram">
                                {/* Renderizar conexiones */}
                                {connections.map(conn => {
                                    const fromNode = servers.find(s => s.id === conn.source);
                                    const toNode = servers.find(s => s.id === conn.target);
                                    if (!fromNode || !toNode) return null;
                                    
                                    const fromPos = calculateNodePosition(servers.indexOf(fromNode), servers.length);
                                    const toPos = calculateNodePosition(servers.indexOf(toNode), servers.length);
                                    
                                    const dx = toPos.x - fromPos.x;
                                    const dy = toPos.y - fromPos.y;
                                    const length = Math.sqrt(dx * dx + dy * dy);
                                    const angle = Math.atan2(dy, dx) * 180 / Math.PI;
                                    
                                    return (
                                        <div
                                            key={conn.id}
                                            className="connection"
                                            style={{
                                                width: length + 'px',
                                                left: fromPos.x + 50 + 'px',
                                                top: fromPos.y + 25 + 'px',
                                                transform: `rotate(${angle}deg)`,
                                                backgroundColor: conn.color
                                            }}
                                            onClick={() => disconnectServers(conn.source, conn.target)}
                                            title={`Conexión: ${conn.source} ↔ ${conn.target}\\nLatencia: ${conn.data.latency}ms\\nClick para desconectar`}
                                        />
                                    );
                                })}
                                
                                {/* Renderizar nodos */}
                                {servers.map((server, index) => {
                                    const pos = calculateNodePosition(index, servers.length);
                                    return (
                                        <div
                                            key={server.id}
                                            className="node"
                                            style={{
                                                left: pos.x + 'px',
                                                top: pos.y + 'px',
                                                backgroundColor: server.color,
                                                transform: `translate(-50%, -50%) ${selectedServer === server.id || selectedServer2 === server.id ? 'scale(1.1)' : ''}`
                                            }}
                                            onMouseEnter={(e) => {
                                                const rect = e.target.getBoundingClientRect();
                                                showTooltip(server.data.tooltip, rect.left, rect.top);
                                            }}
                                            onMouseLeave={hideTooltip}
                                        >
                                            <div>{server.icon}</div>
                                            <div style={{fontSize: '10px'}}>{server.label.split('\\n')[0]}</div>
                                        </div>
                                    );
                                })}
                                
                                {/* Leyenda */}
                                <div className="legend">
                                    <h4>Tipos de Servidores</h4>
                                    {Object.entries(serverTypes).map(([type, config]) => (
                                        <div key={type} className="legend-item">
                                            <div className="legend-color" style={{backgroundColor: config.color}}></div>
                                            <span>{config.icon} {type}</span>
                                        </div>
                                    ))}
                                </div>
                                
                                {/* Tooltip */}
                                {tooltip.visible && (
                                    <div 
                                        className="tooltip"
                                        style={{
                                            left: tooltip.x + 'px',
                                            top: (tooltip.y - 60) + 'px',
                                            display: 'block'
                                        }}
                                        dangerouslySetInnerHTML={{__html: tooltip.content}}
                                    />
                                )}
                            </div>
                        </div>
                    </div>
                </div>
            );
        }
        
        ReactDOM.render(<ClusterManager />, document.getElementById('root'));
    </script>
</body>
</html>"""
    
    def start_real_time_updates(self):
        """Inicia actualizaciones en tiempo real"""
        def update_loop():
            while self.real_time_updates:
                try:
                    self._update_server_metrics()
                    time.sleep(self.update_interval)
                except Exception as e:
                    logger.error(f"Error en actualización en tiempo real: {e}")
        
        update_thread = threading.Thread(target=update_loop, daemon=True)
        update_thread.start()
        logger.info("Actualizaciones en tiempo real iniciadas")
    
    def _validate_server(self, ip: str, ports: List[int]) -> bool:
        """Valida la conectividad de un servidor"""
        try:
            for port in ports:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(3)
                result = sock.connect_ex((ip, port))
                sock.close()
                if result == 0:
                    return True
            return False
        except Exception:
            return False
    
    def _measure_latency(self, ip1: str, ip2: str) -> float:
        """Mide la latencia entre dos servidores"""
        try:
            # Simular medición de latencia (en implementación real usar ping)
            import random
            return round(random.uniform(1, 50), 2)
        except Exception:
            return 0.0
    
    def _update_server_metrics(self):
        """Actualiza métricas de los servidores"""
        for server_id, server in self.servers.items():
            # Simular métricas (en implementación real usar APIs de monitoreo)
            import random
            server['metrics'] = {
                'cpu': round(random.uniform(10, 90), 1),
                'memory': round(random.uniform(20, 85), 1),
                'disk': round(random.uniform(30, 80), 1),
                'network': round(random.uniform(10, 200), 1)
            }
            server['last_check'] = datetime.now().isoformat()
    
    def export_cluster_config(self, filename: str) -> bool:
        """Exporta la configuración del cluster a un archivo"""
        try:
            config = {
                'servers': self.servers,
                'connections': self.connections,
                'clusters': self.clusters,
                'exported_at': datetime.now().isoformat(),
                'version': '1.0'
            }
            
            with open(filename, 'w') as f:
                json.dump(config, f, indent=2)
            
            logger.info(f"Configuración exportada a {filename}")
            return True
            
        except Exception as e:
            logger.error(f"Error exportando configuración: {e}")
            return False
    
    def import_cluster_config(self, filename: str) -> bool:
        """Importa la configuración del cluster desde un archivo"""
        try:
            with open(filename, 'r') as f:
                config = json.load(f)
            
            self.servers = config.get('servers', {})
            self.connections = config.get('connections', [])
            self.clusters = config.get('clusters', {})
            
            logger.info(f"Configuración importada desde {filename}")
            return True
            
        except Exception as e:
            logger.error(f"Error importando configuración: {e}")
            return False
    
    def get_cluster_stats(self) -> Dict:
        """Obtiene estadísticas del cluster"""
        stats = {
            'total_servers': len(self.servers),
            'total_connections': len(self.connections),
            'total_clusters': len(self.clusters),
            'servers_by_type': {},
            'servers_by_region': {},
            'active_servers': 0,
            'average_cpu': 0,
            'average_memory': 0,
            'average_disk': 0
        }
        
        # Contar servidores por tipo y región
        for server in self.servers.values():
            # Por tipo
            server_type = server['type']
            stats['servers_by_type'][server_type] = stats['servers_by_type'].get(server_type, 0) + 1
            
            # Por región
            region = server['region']
            stats['servers_by_region'][region] = stats['servers_by_region'].get(region, 0) + 1
            
            # Estadísticas
            if server['status'] == 'active':
                stats['active_servers'] += 1
            
            stats['average_cpu'] += server['metrics']['cpu']
            stats['average_memory'] += server['metrics']['memory']
            stats['average_disk'] += server['metrics']['disk']
        
        # Calcular promedios
        if len(self.servers) > 0:
            stats['average_cpu'] = round(stats['average_cpu'] / len(self.servers), 1)
            stats['average_memory'] = round(stats['average_memory'] / len(self.servers), 1)
            stats['average_disk'] = round(stats['average_disk'] / len(self.servers), 1)
        
        return stats


def main():
    """Función principal de demostración"""
    print("🚀 Iniciando Sistema de Clustering Ilimitado con FossFlow")
    
    # Crear gestor del cluster
    cluster_manager = UnlimitedClusterManager()
    
    # Agregar servidores de ejemplo
    print("📝 Agregando servidores de ejemplo...")
    cluster_manager.add_server("web1", "Servidor Web 1", "web", "192.168.1.10", "us-east-1")
    cluster_manager.add_server("web2", "Servidor Web 2", "web", "192.168.1.11", "us-east-1")
    cluster_manager.add_server("db1", "Base de Datos Principal", "database", "192.168.1.20", "us-east-1")
    cluster_manager.add_server("db2", "Base de Datos Réplica", "database", "192.168.1.21", "us-east-1")
    cluster_manager.add_server("lb1", "Load Balancer", "load_balancer", "192.168.1.5", "us-east-1")
    cluster_manager.add_server("cache1", "Redis Cache", "cache", "192.168.1.30", "us-east-1")
    cluster_manager.add_server("monitor1", "Sistema de Monitoreo", "monitoring", "192.168.1.40", "us-east-1")
    cluster_manager.add_server("backup1", "Servidor de Backup", "backup", "192.168.1.50", "us-east-1")
    
    # Conectar servidores
    print("🔗 Estableciendo conexiones...")
    cluster_manager.connect_servers("lb1", "web1", "http")
    cluster_manager.connect_servers("lb1", "web2", "http")
    cluster_manager.connect_servers("web1", "db1", "database")
    cluster_manager.connect_servers("web2", "db1", "database")
    cluster_manager.connect_servers("db1", "db2", "replication")
    cluster_manager.connect_servers("web1", "cache1", "cache")
    cluster_manager.connect_servers("web2", "cache1", "cache")
    cluster_manager.connect_servers("monitor1", "web1", "monitoring")
    cluster_manager.connect_servers("monitor1", "db1", "monitoring")
    cluster_manager.connect_servers("backup1", "db1", "backup")
    
    # Crear cluster
    print("🏗️ Creando cluster principal...")
    cluster_manager.create_cluster("production_cluster", ["web1", "web2", "db1", "db2", "lb1", "cache1"])
    
    # Generar dashboard interactivo
    print("📊 Generando dashboard interactivo...")
    dashboard_file = cluster_manager.generate_interactive_dashboard()
    
    # Mostrar estadísticas
    stats = cluster_manager.get_cluster_stats()
    print(f"\n📈 Estadísticas del Cluster:")
    print(f"   Total de servidores: {stats['total_servers']}")
    print(f"   Total de conexiones: {stats['total_connections']}")
    print(f"   Servidores activos: {stats['active_servers']}")
    print(f"   CPU promedio: {stats['average_cpu']}%")
    print(f"   Memoria promedio: {stats['average_memory']}%")
    
    # Iniciar actualizaciones en tiempo real
    cluster_manager.start_real_time_updates()
    
    print(f"\n🎯 Dashboard interactivo generado: {dashboard_file}")
    print("🌐 Abra el archivo en un navegador para visualizar y gestionar el cluster")
    print("🔄 Las actualizaciones en tiempo real están activas")
    
    # Exportar configuración
    cluster_manager.export_cluster_config("cluster_config.json")
    print("💾 Configuración exportada a cluster_config.json")
    
    print("\n✅ Sistema de clustering ilimitado con FossFlow listo para usar!")


if __name__ == "__main__":
    main()