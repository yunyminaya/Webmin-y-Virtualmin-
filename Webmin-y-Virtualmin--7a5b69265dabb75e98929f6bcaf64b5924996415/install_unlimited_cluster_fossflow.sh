#!/bin/bash
# Instalador del Sistema de Clustering Ilimitado con FossFlow
# Para Webmin/Virtualmin Enterprise

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/unlimited-cluster-fossflow"
WEBMIN_MODULE_DIR="/usr/share/webmin/unlimited-cluster"
SERVICE_NAME="unlimited-cluster-fossflow"
LOG_FILE="/var/log/unlimited-cluster-install.log"

# Función de logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}" | tee -a "$LOG_FILE"
}

# Verificar si se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script debe ejecutarse como root (use sudo)"
    fi
}

# Verificar prerrequisitos
check_prerequisites() {
    log "Verificando prerrequisitos..."
    
    # Verificar sistema operativo
    if ! grep -q "Ubuntu\|Debian\|CentOS\|Red Hat" /etc/os-release; then
        error "Sistema operativo no soportado. Se requiere Ubuntu, Debian, CentOS o Red Hat"
    fi
    
    # Verificar Python 3
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python 3 no está instalado"
    fi
    
    # Verificar pip
    if ! command -v pip3 >/dev/null 2>&1; then
        error "pip3 no está instalado"
    fi
    
    # Verificar Webmin/Virtualmin
    if ! command -v webmin >/dev/null 2>&1; then
        warning "Webmin no está instalado. Se instalará el modo standalone"
    fi
    
    log "Prerrequisitos verificados correctamente"
}

# Instalar dependencias
install_dependencies() {
    log "Instalando dependencias..."
    
    # Actualizar paquetes
    apt-get update -qq || yum update -y -q
    
    # Instalar paquetes del sistema
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y \
            python3 python3-pip python3-venv \
            nginx nodejs npm \
            git curl wget jq \
            build-essential \
            redis-server \
            supervisor \
            >/dev/null 2>&1
    else
        yum install -y \
            python3 python3-pip \
            nginx nodejs npm \
            git curl wget jq \
            gcc gcc-c++ make \
            redis \
            supervisor \
            >/dev/null 2>&1
    fi
    
    # Instalar dependencias Python
    pip3 install --upgrade pip >/dev/null 2>&1
    pip3 install \
        flask flask-socketio \
        requests \
        boto3 \
        kubernetes \
        prometheus-client \
        psutil \
        paramiko \
        python-dotenv \
        >/dev/null 2>&1
    
    log "Dependencias instaladas correctamente"
}

# Crear estructura de directorios
create_directories() {
    log "Creando estructura de directorios..."
    
    mkdir -p "$INSTALL_DIR"/{bin,config,data,logs,static,templates}
    mkdir -p "$WEBMIN_MODULE_DIR"
    mkdir -p "/etc/$SERVICE_NAME"
    mkdir -p "/var/lib/$SERVICE_NAME"
    mkdir -p "/var/log/$SERVICE_NAME"
    
    # Establecer permisos
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$WEBMIN_MODULE_DIR"
    chmod 755 "/etc/$SERVICE_NAME"
    chmod 755 "/var/lib/$SERVICE_NAME"
    chmod 755 "/var/log/$SERVICE_NAME"
    
    log "Estructura de directorios creada"
}

# Instalar el gestor del cluster
install_cluster_manager() {
    log "Instalando gestor del cluster..."
    
    # Copiar script principal
    cp "$SCRIPT_DIR/unlimited_cluster_fossflow_manager.py" "$INSTALL_DIR/bin/"
    chmod +x "$INSTALL_DIR/bin/unlimited_cluster_fossflow_manager.py"
    
    # Crear enlace simbólico
    ln -sf "$INSTALL_DIR/bin/unlimited_cluster_fossflow_manager.py" "/usr/local/bin/unlimited-cluster-manager"
    
    log "Gestor del cluster instalado"
}

# Crear servicio web
create_web_service() {
    log "Creando servicio web..."
    
    # Crear aplicación Flask
    cat > "$INSTALL_DIR/bin/web_app.py" << 'EOF'
#!/usr/bin/env python3
"""
Aplicación web para el gestor de clustering ilimitado
"""

import os
import sys
import json
import logging
from flask import Flask, render_template, request, jsonify, send_from_directory
from flask_socketio import SocketIO, emit
import threading
import time

# Agregar directorio del gestor al path
sys.path.insert(0, '/opt/unlimited-cluster-fossflow/bin')
from unlimited_cluster_fossflow_manager import UnlimitedClusterManager

app = Flask(__name__)
app.config['SECRET_KEY'] = 'unlimited-cluster-fossflow-secret-key'
socketio = SocketIO(app, cors_allowed_origins="*")

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Instancia global del gestor
cluster_manager = UnlimitedClusterManager()

@app.route('/')
def index():
    """Página principal"""
    return render_template('index.html')

@app.route('/api/servers', methods=['GET'])
def get_servers():
    """Obtener lista de servidores"""
    try:
        fossflow_data = cluster_manager.generate_fossflow_data()
        return jsonify(fossflow_data)
    except Exception as e:
        logger.error(f"Error obteniendo servidores: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/servers', methods=['POST'])
def add_server():
    """Agregar nuevo servidor"""
    try:
        data = request.json
        success = cluster_manager.add_server(
            data['id'], data['name'], data['type'],
            data['ip'], data.get('region', 'default')
        )
        
        if success:
            # Emitir actualización a todos los clientes
            emit_server_update()
            return jsonify({'success': True})
        else:
            return jsonify({'error': 'No se pudo agregar el servidor'}), 400
    except Exception as e:
        logger.error(f"Error agregando servidor: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/servers/<server_id>', methods=['DELETE'])
def remove_server(server_id):
    """Eliminar servidor"""
    try:
        success = cluster_manager.remove_server(server_id)
        if success:
            emit_server_update()
            return jsonify({'success': True})
        else:
            return jsonify({'error': 'No se pudo eliminar el servidor'}), 400
    except Exception as e:
        logger.error(f"Error eliminando servidor: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/connections', methods=['POST'])
def connect_servers():
    """Conectar dos servidores"""
    try:
        data = request.json
        success = cluster_manager.connect_servers(
            data['from'], data['to'], data.get('type', 'standard')
        )
        
        if success:
            emit_server_update()
            return jsonify({'success': True})
        else:
            return jsonify({'error': 'No se pudieron conectar los servidores'}), 400
    except Exception as e:
        logger.error(f"Error conectando servidores: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/connections', methods=['DELETE'])
def disconnect_servers():
    """Desconectar dos servidores"""
    try:
        data = request.json
        success = cluster_manager.disconnect_servers(data['from'], data['to'])
        
        if success:
            emit_server_update()
            return jsonify({'success': True})
        else:
            return jsonify({'error': 'No se pudieron desconectar los servidores'}), 400
    except Exception as e:
        logger.error(f"Error desconectando servidores: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/clusters', methods=['POST'])
def create_cluster():
    """Crear nuevo cluster"""
    try:
        data = request.json
        success = cluster_manager.create_cluster(data['name'], data['servers'])
        
        if success:
            emit_server_update()
            return jsonify({'success': True})
        else:
            return jsonify({'error': 'No se pudo crear el cluster'}), 400
    except Exception as e:
        logger.error(f"Error creando cluster: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/stats')
def get_stats():
    """Obtener estadísticas del cluster"""
    try:
        stats = cluster_manager.get_cluster_stats()
        return jsonify(stats)
    except Exception as e:
        logger.error(f"Error obteniendo estadísticas: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/export')
def export_config():
    """Exportar configuración del cluster"""
    try:
        filename = f"/tmp/cluster_config_{int(time.time())}.json"
        cluster_manager.export_cluster_config(filename)
        return send_from_directory('/tmp', os.path.basename(filename), as_attachment=True)
    except Exception as e:
        logger.error(f"Error exportando configuración: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/import', methods=['POST'])
def import_config():
    """Importar configuración del cluster"""
    try:
        if 'file' not in request.files:
            return jsonify({'error': 'No se proporcionó archivo'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'No se seleccionó archivo'}), 400
        
        # Guardar archivo temporalmente
        temp_file = f"/tmp/import_{int(time.time())}.json"
        file.save(temp_file)
        
        # Importar configuración
        success = cluster_manager.import_cluster_config(temp_file)
        
        # Limpiar archivo temporal
        os.remove(temp_file)
        
        if success:
            emit_server_update()
            return jsonify({'success': True})
        else:
            return jsonify({'error': 'No se pudo importar la configuración'}), 400
    except Exception as e:
        logger.error(f"Error importando configuración: {e}")
        return jsonify({'error': str(e)}), 500

@socketio.on('connect')
def handle_connect():
    """Manejar conexión de cliente"""
    logger.info("Cliente conectado")
    emit_server_update()

@socketio.on('disconnect')
def handle_disconnect():
    """Manejar desconexión de cliente"""
    logger.info("Cliente desconectado")

def emit_server_update():
    """Emitir actualización de servidores a todos los clientes"""
    try:
        fossflow_data = cluster_manager.generate_fossflow_data()
        socketio.emit('server_update', fossflow_data)
    except Exception as e:
        logger.error(f"Error emitiendo actualización: {e}")

def background_updater():
    """Actualizador en segundo plano"""
    while True:
        try:
            emit_server_update()
            time.sleep(5)  # Actualizar cada 5 segundos
        except Exception as e:
            logger.error(f"Error en actualizador: {e}")
            time.sleep(10)

if __name__ == '__main__':
    # Iniciar actualizador en segundo plano
    updater_thread = threading.Thread(target=background_updater, daemon=True)
    updater_thread.start()
    
    # Iniciar servidor
    socketio.run(app, host='0.0.0.0', port=8080, debug=False)
EOF
    
    chmod +x "$INSTALL_DIR/bin/web_app.py"
    
    # Crear plantilla HTML
    cat > "$INSTALL_DIR/templates/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cluster Manager - Servidores Ilimitados</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/socket.io/4.0.1/socket.io.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
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
        
        .connection-status {
            position: absolute;
            top: 10px;
            left: 10px;
            background: rgba(255, 255, 255, 0.9);
            padding: 10px;
            border-radius: 8px;
            font-size: 12px;
            z-index: 100;
        }
        
        .connection-status.connected {
            color: #4CAF50;
        }
        
        .connection-status.disconnected {
            color: #f44336;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Cluster Manager - Servidores Ilimitados</h1>
        <div class="stats">
            <div class="stat-card">
                <div class="stat-number" id="total-servers">0</div>
                <div class="stat-label">Servidores</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="total-connections">0</div>
                <div class="stat-label">Conexiones</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="total-clusters">0</div>
                <div class="stat-label">Clusters</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="active-servers">0</div>
                <div class="stat-label">Activos</div>
            </div>
        </div>
    </div>
    
    <div class="main-container">
        <div class="control-panel">
            <h3>🎛️ Panel de Control</h3>
            
            <div class="form-group">
                <label>ID del Servidor</label>
                <input type="text" id="server-id" placeholder="ej: web-server-1">
            </div>
            
            <div class="form-group">
                <label>Nombre</label>
                <input type="text" id="server-name" placeholder="ej: Servidor Web Principal">
            </div>
            
            <div class="form-group">
                <label>Tipo</label>
                <select id="server-type">
                    <option value="web">🌐 Web</option>
                    <option value="database">🗄️ Database</option>
                    <option value="dns">🌍 DNS</option>
                    <option value="cache">⚡ Cache</option>
                    <option value="load_balancer">⚖️ Load Balancer</option>
                    <option value="file_system">📁 File System</option>
                    <option value="monitoring">📊 Monitoring</option>
                    <option value="backup">💾 Backup</option>
                    <option value="security">🛡️ Security</option>
                </select>
            </div>
            
            <div class="form-group">
                <label>Dirección IP</label>
                <input type="text" id="server-ip" placeholder="ej: 192.168.1.100">
            </div>
            
            <div class="form-group">
                <label>Región</label>
                <input type="text" id="server-region" placeholder="ej: us-east-1" value="default">
            </div>
            
            <button class="btn" onclick="addServer()">➕ Agregar Servidor</button>
            
            <div class="form-group">
                <button class="btn btn-secondary" onclick="connectSelected()">🔗 Conectar Seleccionados</button>
            </div>
            
            <div class="form-group">
                <label>Nombre del Cluster</label>
                <input type="text" id="cluster-name" placeholder="ej: production-cluster">
            </div>
            
            <button class="btn" onclick="createCluster()">🏗️ Crear Cluster</button>
            
            <div class="form-group">
                <button class="btn btn-secondary" onclick="exportConfig()">💾 Exportar Configuración</button>
                <input type="file" id="import-file" style="display: none;" onchange="importConfig()">
                <button class="btn btn-secondary" onclick="document.getElementById('import-file').click()">📁 Importar Configuración</button>
            </div>
            
            <h4>📋 Servidores Actuales</h4>
            <div class="server-list" id="server-list"></div>
        </div>
        
        <div class="visualization-panel">
            <h3>🌐 Visualización del Cluster</h3>
            <div class="connection-status" id="connection-status">
                🔴 Desconectado
            </div>
            <div class="cluster-diagram" id="cluster-diagram">
                <div class="legend">
                    <h4>Tipos de Servidores</h4>
                    <div class="legend-item"><div class="legend-color" style="background: #4CAF50;"></div>🌐 Web</div>
                    <div class="legend-item"><div class="legend-color" style="background: #2196F3;"></div>🗄️ Database</div>
                    <div class="legend-item"><div class="legend-color" style="background: #FF9800;"></div>🌍 DNS</div>
                    <div class="legend-item"><div class="legend-color" style="background: #9C27B0;"></div>⚡ Cache</div>
                    <div class="legend-item"><div class="legend-color" style="background: #F44336;"></div>⚖️ Load Balancer</div>
                    <div class="legend-item"><div class="legend-color" style="background: #795548;"></div>📁 File System</div>
                    <div class="legend-item"><div class="legend-color" style="background: #607D8B;"></div>📊 Monitoring</div>
                    <div class="legend-item"><div class="legend-color" style="background: #FF5722;"></div>💾 Backup</div>
                    <div class="legend-item"><div class="legend-color" style="background: #E91E63;"></div>🛡️ Security</div>
                </div>
                <div class="tooltip" id="tooltip"></div>
            </div>
        </div>
    </div>
    
    <script>
        const socket = io();
        let servers = [];
        let connections = [];
        let selectedServers = new Set();
        
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
        
        // Socket events
        socket.on('connect', function() {
            document.getElementById('connection-status').innerHTML = '🟢 Conectado';
            document.getElementById('connection-status').className = 'connection-status connected';
        });
        
        socket.on('disconnect', function() {
            document.getElementById('connection-status').innerHTML = '🔴 Desconectado';
            document.getElementById('connection-status').className = 'connection-status disconnected';
        });
        
        socket.on('server_update', function(data) {
            updateVisualization(data);
        });
        
        function updateVisualization(data) {
            servers = data.nodes || [];
            connections = data.links || [];
            
            // Actualizar estadísticas
            document.getElementById('total-servers').textContent = servers.length;
            document.getElementById('total-connections').textContent = connections.length;
            document.getElementById('total-clusters').textContent = data.clusters || 0;
            document.getElementById('active-servers').textContent = servers.filter(s => s.data.status === 'active').length;
            
            // Actualizar lista de servidores
            updateServerList();
            
            // Actualizar diagrama
            renderDiagram();
        }
        
        function updateServerList() {
            const serverList = document.getElementById('server-list');
            serverList.innerHTML = '';
            
            servers.forEach(server => {
                const item = document.createElement('div');
                item.className = 'server-item';
                if (selectedServers.has(server.id)) {
                    item.classList.add('selected');
                }
                
                item.innerHTML = `
                    <span>
                        <span class="status-indicator status-${server.data.status}"></span>
                        ${serverTypes[server.type].icon} ${server.label.split('\\n')[0]}
                    </span>
                    <button class="btn btn-danger" style="width: auto; padding: 5px 10px; margin: 0;" onclick="removeServer('${server.id}')">🗑️</button>
                `;
                
                item.onclick = function(e) {
                    if (!e.target.classList.contains('btn')) {
                        toggleServerSelection(server.id);
                    }
                };
                
                serverList.appendChild(item);
            });
        }
        
        function toggleServerSelection(serverId) {
            if (selectedServers.has(serverId)) {
                selectedServers.delete(serverId);
            } else {
                selectedServers.add(serverId);
            }
            updateServerList();
        }
        
        function renderDiagram() {
            const diagram = document.getElementById('cluster-diagram');
            
            // Limpiar diagrama (excepto leyenda y tooltip)
            const elements = diagram.querySelectorAll('.node, .connection');
            elements.forEach(el => el.remove());
            
            // Calcular posiciones
            const positions = {};
            servers.forEach((server, index) => {
                const centerX = 400;
                const centerY = 300;
                const radius = Math.min(250, 300 / Math.max(1, servers.length / 8));
                const angle = (2 * Math.PI * index) / servers.length;
                positions[server.id] = {
                    x: centerX + radius * Math.cos(angle),
                    y: centerY + radius * Math.sin(angle)
                };
            });
            
            // Renderizar conexiones
            connections.forEach(conn => {
                const fromNode = servers.find(s => s.id === conn.source);
                const toNode = servers.find(s => s.id === conn.target);
                if (!fromNode || !toNode) return;
                
                const fromPos = positions[conn.source];
                const toPos = positions[conn.target];
                
                const dx = toPos.x - fromPos.x;
                const dy = toPos.y - fromPos.y;
                const length = Math.sqrt(dx * dx + dy * dy);
                const angle = Math.atan2(dy, dx) * 180 / Math.PI;
                
                const connection = document.createElement('div');
                connection.className = 'connection';
                connection.style.width = length + 'px';
                connection.style.left = fromPos.x + 50 + 'px';
                connection.style.top = fromPos.y + 25 + 'px';
                connection.style.transform = `rotate(${angle}deg)`;
                connection.style.backgroundColor = conn.color;
                connection.title = `Conexión: ${conn.source} ↔ ${conn.target}\\nLatencia: ${conn.data.latency}ms\\nClick para desconectar`;
                connection.onclick = function() { disconnectServers(conn.source, conn.target); };
                
                diagram.appendChild(connection);
            });
            
            // Renderizar nodos
            servers.forEach(server => {
                const pos = positions[server.id];
                const node = document.createElement('div');
                node.className = 'node';
                node.style.left = pos.x + 'px';
                node.style.top = pos.y + 'px';
                node.style.backgroundColor = server.color;
                node.style.transform = 'translate(-50%, -50%)';
                
                node.innerHTML = `
                    <div>${server.icon}</div>
                    <div style="font-size: 10px;">${server.label.split('\\n')[0]}</div>
                `;
                
                node.onmouseenter = function(e) {
                    showTooltip(server.data.tooltip, e.pageX, e.pageY);
                };
                
                node.onmouseleave = function() {
                    hideTooltip();
                };
                
                diagram.appendChild(node);
            });
        }
        
        function showTooltip(content, x, y) {
            const tooltip = document.getElementById('tooltip');
            tooltip.innerHTML = content;
            tooltip.style.left = x + 'px';
            tooltip.style.top = (y - 60) + 'px';
            tooltip.style.display = 'block';
        }
        
        function hideTooltip() {
            document.getElementById('tooltip').style.display = 'none';
        }
        
        async function addServer() {
            const serverData = {
                id: document.getElementById('server-id').value,
                name: document.getElementById('server-name').value,
                type: document.getElementById('server-type').value,
                ip: document.getElementById('server-ip').value,
                region: document.getElementById('server-region').value
            };
            
            if (!serverData.id || !serverData.name || !serverData.ip) {
                alert('Por favor complete todos los campos');
                return;
            }
            
            try {
                const response = await fetch('/api/servers', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(serverData)
                });
                
                const result = await response.json();
                if (result.success) {
                    // Limpiar formulario
                    document.getElementById('server-id').value = '';
                    document.getElementById('server-name').value = '';
                    document.getElementById('server-ip').value = '';
                    document.getElementById('server-region').value = 'default';
                } else {
                    alert('Error: ' + (result.error || 'Error desconocido'));
                }
            } catch (error) {
                alert('Error de conexión: ' + error.message);
            }
        }
        
        async function removeServer(serverId) {
            if (!confirm('¿Está seguro de eliminar este servidor?')) return;
            
            try {
                const response = await fetch(`/api/servers/${serverId}`, {
                    method: 'DELETE'
                });
                
                const result = await response.json();
                if (!result.success) {
                    alert('Error: ' + (result.error || 'Error desconocido'));
                }
            } catch (error) {
                alert('Error de conexión: ' + error.message);
            }
        }
        
        async function connectSelected() {
            if (selectedServers.size !== 2) {
                alert('Seleccione exactamente 2 servidores para conectar');
                return;
            }
            
            const [server1, server2] = Array.from(selectedServers);
            
            try {
                const response = await fetch('/api/connections', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ from: server1, to: server2 })
                });
                
                const result = await response.json();
                if (result.success) {
                    selectedServers.clear();
                    updateServerList();
                } else {
                    alert('Error: ' + (result.error || 'Error desconocido'));
                }
            } catch (error) {
                alert('Error de conexión: ' + error.message);
            }
        }
        
        async function disconnectServers(server1, server2) {
            if (!confirm('¿Está seguro de desconectar estos servidores?')) return;
            
            try {
                const response = await fetch('/api/connections', {
                    method: 'DELETE',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ from: server1, to: server2 })
                });
                
                const result = await response.json();
                if (!result.success) {
                    alert('Error: ' + (result.error || 'Error desconocido'));
                }
            } catch (error) {
                alert('Error de conexión: ' + error.message);
            }
        }
        
        async function createCluster() {
            const clusterName = document.getElementById('cluster-name').value;
            const serverList = Array.from(selectedServers);
            
            if (!clusterName || serverList.length === 0) {
                alert('Ingrese un nombre para el cluster y seleccione al menos un servidor');
                return;
            }
            
            try {
                const response = await fetch('/api/clusters', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ name: clusterName, servers: serverList })
                });
                
                const result = await response.json();
                if (result.success) {
                    document.getElementById('cluster-name').value = '';
                    selectedServers.clear();
                    updateServerList();
                } else {
                    alert('Error: ' + (result.error || 'Error desconocido'));
                }
            } catch (error) {
                alert('Error de conexión: ' + error.message);
            }
        }
        
        async function exportConfig() {
            try {
                window.open('/api/export', '_blank');
            } catch (error) {
                alert('Error: ' + error.message);
            }
        }
        
        async function importConfig() {
            const fileInput = document.getElementById('import-file');
            const file = fileInput.files[0];
            
            if (!file) return;
            
            const formData = new FormData();
            formData.append('file', file);
            
            try {
                const response = await fetch('/api/import', {
                    method: 'POST',
                    body: formData
                });
                
                const result = await response.json();
                if (result.success) {
                    alert('Configuración importada exitosamente');
                } else {
                    alert('Error: ' + (result.error || 'Error desconocido'));
                }
            } catch (error) {
                alert('Error de conexión: ' + error.message);
            }
            
            // Limpiar input
            fileInput.value = '';
        }
        
        // Cargar datos iniciales
        fetch('/api/servers')
            .then(response => response.json())
            .then(data => updateVisualization(data))
            .catch(error => console.error('Error cargando datos:', error));
    </script>
</body>
</html>
EOF
    
    log "Servicio web creado"
}

# Configurar servicio systemd
create_systemd_service() {
    log "Configurando servicio systemd..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=Unlimited Cluster FossFlow Manager
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/bin/web_app.py
Restart=always
RestartSec=10
Environment=PYTHONPATH=$INSTALL_DIR/bin

[Install]
WantedBy=multi-user.target
EOF
    
    # Recargar systemd y habilitar servicio
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    log "Servicio systemd configurado"
}

# Configurar Nginx
configure_nginx() {
    log "Configurando Nginx..."
    
    cat > "/etc/nginx/sites-available/$SERVICE_NAME" << EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /socket.io {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    # Activar sitio
    ln -sf "/etc/nginx/sites-available/$SERVICE_NAME" "/etc/nginx/sites-enabled/"
    rm -f "/etc/nginx/sites-enabled/default"
    
    # Probar configuración y reiniciar Nginx
    nginx -t && systemctl reload nginx
    
    log "Nginx configurado"
}

# Crear módulo de Webmin (si está instalado)
create_webmin_module() {
    if command -v webmin >/dev/null 2>&1; then
        log "Creando módulo de Webmin..."
        
        # Crear estructura del módulo
        mkdir -p "$WEBMIN_MODULE_DIR"
        
        # Crear descriptor del módulo
        cat > "$WEBMIN_MODULE_DIR/module.info" << EOF
desc=Unlimited Cluster FossFlow Manager
desc_es=Gestor de Clustering Ilimitado con FossFlow
category=system
longdesc=Manage unlimited server clusters with visual FossFlow integration
longdesc_es=Gestiona clusters ilimitados de servidores con integración visual FossFlow
version=1.0
url=/unlimited-cluster/
EOF
        
        # Crear CGI principal
        cat > "$WEBMIN_MODULE_DIR/index.cgi" << 'EOF'
#!/usr/bin/perl

# Módulo de Webmin para Unlimited Cluster FossFlow Manager

require './ui-lib.pl';
&ui_print_header(undef, "Unlimited Cluster Manager", "", undef, 1, 1);

# Redirigir a la aplicación web principal
print "<script>window.location.href = 'http://$ENV{'HTTP_HOST'}/';</script>\n";

&ui_print_footer("/", "index.cgi");
EOF
        
        chmod +x "$WEBMIN_MODULE_DIR/index.cgi"
        
        # Configurar Webmin para que reconozca el módulo
        if [[ -f "/etc/webmin/miniserv.conf" ]]; then
            if ! grep -q "$SERVICE_NAME" /etc/webmin/miniserv.conf; then
                echo "root=$SERVICE_NAME" >> /etc/webmin/miniserv.conf
                systemctl restart webmin
            fi
        fi
        
        log "Módulo de Webmin creado"
    fi
}

# Crear scripts de utilidad
create_utility_scripts() {
    log "Creando scripts de utilidad..."
    
    # Script de gestión
    cat > "$INSTALL_DIR/bin/clusterctl" << 'EOF'
#!/bin/bash
# Script de control del cluster

SCRIPT_DIR="/opt/unlimited-cluster-fossflow/bin"
SERVICE_NAME="unlimited-cluster-fossflow"

case "$1" in
    start)
        echo "Iniciando Unlimited Cluster FossFlow Manager..."
        systemctl start $SERVICE_NAME
        ;;
    stop)
        echo "Deteniendo Unlimited Cluster FossFlow Manager..."
        systemctl stop $SERVICE_NAME
        ;;
    restart)
        echo "Reiniciando Unlimited Cluster FossFlow Manager..."
        systemctl restart $SERVICE_NAME
        ;;
    status)
        systemctl status $SERVICE_NAME
        ;;
    logs)
        journalctl -u $SERVICE_NAME -f
        ;;
    manage)
        echo "Abriendo interfaz de gestión..."
        python3 $SCRIPT_DIR/unlimited_cluster_fossflow_manager.py
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status|logs|manage}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$INSTALL_DIR/bin/clusterctl"
    ln -sf "$INSTALL_DIR/bin/clusterctl" "/usr/local/bin/clusterctl"
    
    # Script de diagnóstico
    cat > "$INSTALL_DIR/bin/cluster-diagnose" << 'EOF'
#!/bin/bash
# Script de diagnóstico del cluster

echo "🔍 Diagnosticando Unlimited Cluster FossFlow Manager..."
echo

# Verificar servicio
echo "📋 Estado del servicio:"
systemctl is-active unlimited-cluster-fossflow
systemctl is-enabled unlimited-cluster-fossflow
echo

# Verificar puertos
echo "🌐 Puertos en escucha:"
netstat -tlnp | grep -E ":(80|8080|22)"
echo

# Verificar procesos
echo "💻 Procesos relacionados:"
ps aux | grep -E "(python|nginx)" | grep -E "(cluster|fossflow)" | grep -v grep
echo

# Verificar recursos
echo "📊 Uso de recursos:"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memoria: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "Disco: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
echo

# Verificar logs recientes
echo "📝 Logs recientes:"
journalctl -u unlimited-cluster-fossflow --no-pager -n 10 --output=cat
echo

echo "✅ Diagnóstico completado"
EOF
    
    chmod +x "$INSTALL_DIR/bin/cluster-diagnose"
    ln -sf "$INSTALL_DIR/bin/cluster-diagnose" "/usr/local/bin/cluster-diagnose"
    
    log "Scripts de utilidad creados"
}

# Configurar firewall
configure_firewall() {
    log "Configurando firewall..."
    
    # Si está UFW
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 80/tcp >/dev/null 2>&1
        ufw allow 8080/tcp >/dev/null 2>&1
        ufw allow 22/tcp >/dev/null 2>&1
    fi
    
    # Si está firewalld
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-service=http >/dev/null 2>&1
        firewall-cmd --permanent --add-port=8080/tcp >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
    fi
    
    log "Firewall configurado"
}

# Iniciar servicios
start_services() {
    log "Iniciando servicios..."
    
    # Iniciar servicio principal
    systemctl start "$SERVICE_NAME"
    
    # Verificar que esté corriendo
    sleep 3
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "✅ Unlimited Cluster FossFlow Manager iniciado correctamente"
    else
        error "❌ Error al iniciar el servicio"
    fi
    
    # Probar acceso web
    sleep 2
    if curl -s http://localhost >/dev/null; then
        log "✅ Interfaz web accesible"
    else
        warning "⚠️ La interfaz web podría no ser accesible externamente"
    fi
}

# Mostrar información post-instalación
show_post_install_info() {
    log "🎉 Instalación completada exitosamente!"
    echo
    echo -e "${CYAN}📋 Información de Acceso:${NC}"
    echo -e "   Interfaz Web: ${GREEN}http://$(hostname -I | awk '{print $1}')${NC}"
    echo -e "   Puerto: ${GREEN}80${NC} (Nginx) / ${GREEN}8080${NC} (Directo)"
    echo
    echo -e "${CYAN}🛠️ Comandos Útiles:${NC}"
    echo -e "   clusterctl start      - Iniciar servicio"
    echo -e "   clusterctl stop       - Detener servicio"
    echo -e "   clusterctl restart    - Reiniciar servicio"
    echo -e "   clusterctl status     - Ver estado"
    echo -e "   clusterctl logs       - Ver logs"
    echo -e "   clusterctl manage     - Gestionar cluster localmente"
    echo -e "   cluster-diagnose      - Diagnóstico completo"
    echo
    echo -e "${CYAN}📁 Directorios Importantes:${NC}"
    echo -e "   Instalación: ${GREEN}$INSTALL_DIR${NC}"
    echo -e "   Configuración: ${GREEN}/etc/$SERVICE_NAME${NC}"
    echo -e "   Logs: ${GREEN}/var/log/$SERVICE_NAME${NC}"
    echo
    echo -e "${CYAN}🌐 Integración con Webmin:${NC}"
    if command -v webmin >/dev/null 2>&1; then
        echo -e "   ✅ Módulo de Webmin instalado"
        echo -e "   Acceso: ${GREEN}https://$(hostname -I | awk '{print $1}'):10000/unlimited-cluster/${NC}"
    else
        echo -e "   ⚠️ Webmin no detectado (instalación standalone)"
    fi
    echo
    echo -e "${CYAN}🔧 Configuración Inicial:${NC}"
    echo -e "   1. Abra la interfaz web en su navegador"
    echo -e "   2. Agregue sus primeros servidores"
    echo -e "   3. Conecte los servidores visualmente"
    echo -e "   4. Cree sus primeros clusters"
    echo
    echo -e "${PURPLE}🎯 ¡Sistema de Clustering Ilimitado con FossFlow listo para usar!${NC}"
}

# Función principal
main() {
    echo -e "${PURPLE}============================================================================${NC}"
    echo -e "${CYAN}🚀 Instalador - Unlimited Cluster FossFlow Manager${NC}"
    echo -e "${CYAN}   Sistema de Clustering Ilimitado con Visualización FossFlow${NC}"
    echo -e "${PURPLE}============================================================================${NC}"
    echo
    
    log "Iniciando instalación de Unlimited Cluster FossFlow Manager..."
    log "Log de instalación: $LOG_FILE"
    
    # Ejecutar pasos de instalación
    check_root
    check_prerequisites
    install_dependencies
    create_directories
    install_cluster_manager
    create_web_service
    create_systemd_service
    configure_nginx
    create_webmin_module
    create_utility_scripts
    configure_firewall
    start_services
    show_post_install_info
    
    echo
    log "✅ Instalación completada exitosamente!"
    echo -e "${GREEN}🎉 Unlimited Cluster FossFlow Manager está listo para usar!${NC}"
}

# Ejecutar función principal
main "$@"