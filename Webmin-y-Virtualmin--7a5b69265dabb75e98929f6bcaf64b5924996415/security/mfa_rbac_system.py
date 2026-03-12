#!/usr/bin/env python3

# Sistema de Autenticación Multifactor (MFA) y Control de Acceso Basado en Roles (RBAC)
# para Virtualmin Enterprise

import json
import os
import sys
import time
import hashlib
import secrets
import logging
import sqlite3
import subprocess
import re
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any

# Instalar dependencias si no están disponibles
try:
    import pyotp
    import qrcode
    from flask import Flask, request, jsonify, session, redirect, url_for, render_template
    from flask_cors import CORS
    import jwt
    from werkzeug.security import generate_password_hash, check_password_hash
except ImportError as e:
    print(f"Error: Missing dependency - {e}")
    print("Please install required packages: pip install pyotp qrcode flask flask-cors pyjwt werkzeug")
    sys.exit(1)

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/virtualmin-enterprise/mfa_rbac.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class MFARBACSystem:
    def __init__(self, config_file=None):
        """Inicializar el sistema MFA/RBAC"""
        self.config = self.load_config(config_file)
        self.db_path = self.config.get('database', {}).get('path', '/opt/virtualmin-enterprise/security/mfa_rbac.db')
        self.jwt_secret = self.config.get('security', {}).get('jwt_secret', self.generate_jwt_secret())
        self.jwt_expiration = self.config.get('security', {}).get('jwt_expiration', 3600)
        self.mfa_issuer = self.config.get('mfa', {}).get('issuer', 'Virtualmin Enterprise')
        self.session_timeout = self.config.get('security', {}).get('session_timeout', 1800)  # 30 minutos
        
        # Crear directorios necesarios
        self.create_directories()
        
        # Inicializar base de datos
        self.init_database()
        
        # Inicializar aplicación Flask
        self.app = Flask(__name__)
        self.app.secret_key = self.config.get('security', {}).get('app_secret', self.generate_app_secret())
        CORS(self.app)
        
        # Configurar rutas de Flask
        self.setup_flask_routes()
    
    def load_config(self, config_file):
        """Cargar configuración desde archivo"""
        default_config = {
            "database": {
                "path": "/opt/virtualmin-enterprise/security/mfa_rbac.db"
            },
            "security": {
                "jwt_secret": "",
                "jwt_expiration": 3600,
                "app_secret": "",
                "session_timeout": 1800,
                "max_login_attempts": 5,
                "lockout_duration": 900
            },
            "mfa": {
                "issuer": "Virtualmin Enterprise",
                "qr_code_path": "/opt/virtualmin-enterprise/security/qrcodes",
                "require_mfa": True,
                "backup_codes_count": 10
            },
            "rbac": {
                "default_role": "user",
                "roles": {
                    "admin": {
                        "permissions": ["*"],
                        "description": "Administrador con acceso completo"
                    },
                    "operator": {
                        "permissions": [
                            "virtualmin:read", "virtualmin:write",
                            "webmin:read", "webmin:write",
                            "users:read", "users:write",
                            "domains:read", "domains:write"
                        ],
                        "description": "Operador con permisos de gestión"
                    },
                    "user": {
                        "permissions": [
                            "virtualmin:read",
                            "domains:read"
                        ],
                        "description": "Usuario con permisos de solo lectura"
                    }
                }
            },
            "notification": {
                "email_enabled": False,
                "smtp_server": "",
                "smtp_port": 587,
                "smtp_username": "",
                "smtp_password": "",
                "slack_webhook": ""
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
            '/opt/virtualmin-enterprise/security',
            os.path.dirname(self.db_path),
            self.config['mfa']['qr_code_path'],
            '/var/log/virtualmin-enterprise'
        ]
        
        for directory in directories:
            try:
                os.makedirs(directory, exist_ok=True)
                logger.info(f"Directorio creado: {directory}")
            except OSError as e:
                logger.error(f"Error al crear directorio {directory}: {e}")
    
    def generate_jwt_secret(self):
        """Generar secreto para JWT"""
        return secrets.token_urlsafe(32)
    
    def generate_app_secret(self):
        """Generar secreto para la aplicación Flask"""
        return secrets.token_hex(16)
    
    def init_database(self):
        """Inicializar base de datos SQLite"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Crear tabla de usuarios
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    username TEXT UNIQUE NOT NULL,
                    password_hash TEXT NOT NULL,
                    email TEXT,
                    mfa_secret TEXT,
                    mfa_enabled BOOLEAN DEFAULT 0,
                    role TEXT DEFAULT 'user',
                    is_active BOOLEAN DEFAULT 1,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    last_login TIMESTAMP,
                    login_attempts INTEGER DEFAULT 0,
                    locked_until TIMESTAMP
                )
            ''')
            
            # Crear tabla de roles
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS roles (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT UNIQUE NOT NULL,
                    permissions TEXT,
                    description TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Crear tabla de sesiones
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS sessions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT UNIQUE NOT NULL,
                    user_id INTEGER,
                    ip_address TEXT,
                    user_agent TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    expires_at TIMESTAMP,
                    is_active BOOLEAN DEFAULT 1,
                    FOREIGN KEY (user_id) REFERENCES users (id)
                )
            ''')
            
            # Crear tabla de códigos de respaldo MFA
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS mfa_backup_codes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER,
                    code_hash TEXT,
                    used BOOLEAN DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_id) REFERENCES users (id)
                )
            ''')
            
            # Crear tabla de logs de auditoría
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS audit_logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER,
                    action TEXT,
                    resource TEXT,
                    ip_address TEXT,
                    user_agent TEXT,
                    success BOOLEAN,
                    details TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_id) REFERENCES users (id)
                )
            ''')
            
            # Insertar roles por defecto
            for role_name, role_data in self.config['rbac']['roles'].items():
                cursor.execute('''
                    INSERT OR IGNORE INTO roles (name, permissions, description)
                    VALUES (?, ?, ?)
                ''', (
                    role_name,
                    json.dumps(role_data['permissions']),
                    role_data['description']
                ))
            
            # Crear usuario admin por defecto si no existe
            cursor.execute('SELECT COUNT(*) FROM users WHERE username = "admin"')
            if cursor.fetchone()[0] == 0:
                admin_password = self.generate_secure_password()
                admin_password_hash = generate_password_hash(admin_password)
                
                cursor.execute('''
                    INSERT INTO users (username, password_hash, role, mfa_enabled)
                    VALUES (?, ?, ?, ?)
                ''', ('admin', admin_password_hash, 'admin', 0))
                
                logger.warning(f"Usuario admin creado con contraseña: {admin_password}")
                logger.warning("Por favor, cambie la contraseña del usuario admin inmediatamente")
            
            conn.commit()
            conn.close()
            
            logger.info("Base de datos inicializada")
            return True
        except Exception as e:
            logger.error(f"Error al inicializar base de datos: {e}")
            return False
    
    def generate_secure_password(self, length=12):
        """Generar una contraseña segura"""
        alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
        return ''.join(secrets.choice(alphabet) for _ in range(length))
    
    def get_db_connection(self):
        """Obtener conexión a la base de datos"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn
    
    def authenticate_user(self, username, password, ip_address=None, user_agent=None):
        """Autenticar usuario"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            # Obtener usuario
            cursor.execute('SELECT * FROM users WHERE username = ?', (username,))
            user = cursor.fetchone()
            
            if not user:
                self.log_audit_event(None, 'login', 'user', ip_address, user_agent, False, 'User not found')
                return {'success': False, 'message': 'Usuario o contraseña incorrectos'}
            
            # Verificar si el usuario está bloqueado
            if user['locked_until'] and user['locked_until'] > datetime.now():
                self.log_audit_event(user['id'], 'login', 'user', ip_address, user_agent, False, 'Account locked')
                return {'success': False, 'message': 'Cuenta bloqueada. Inténtelo más tarde.'}
            
            # Verificar contraseña
            if not check_password_hash(user['password_hash'], password):
                # Incrementar intentos de inicio de sesión
                login_attempts = user['login_attempts'] + 1
                max_attempts = self.config['security']['max_login_attempts']
                lockout_duration = self.config['security']['lockout_duration']
                
                if login_attempts >= max_attempts:
                    # Bloquear cuenta
                    locked_until = datetime.now() + timedelta(seconds=lockout_duration)
                    cursor.execute('''
                        UPDATE users SET login_attempts = ?, locked_until = ?
                        WHERE id = ?
                    ''', (login_attempts, locked_until, user['id']))
                    
                    self.log_audit_event(user['id'], 'login', 'user', ip_address, user_agent, False, 'Account locked due to multiple failed attempts')
                    conn.commit()
                    
                    return {'success': False, 'message': f'Cuenta bloqueada por {lockout_duration} segundos. Inténtelo más tarde.'}
                else:
                    # Actualizar intentos de inicio de sesión
                    cursor.execute('UPDATE users SET login_attempts = ? WHERE id = ?', (login_attempts, user['id']))
                    conn.commit()
                
                self.log_audit_event(user['id'], 'login', 'user', ip_address, user_agent, False, 'Invalid password')
                return {'success': False, 'message': 'Usuario o contraseña incorrectos'}
            
            # Restablecer intentos de inicio de sesión
            cursor.execute('UPDATE users SET login_attempts = 0, last_login = ? WHERE id = ?', (datetime.now(), user['id']))
            conn.commit()
            
            self.log_audit_event(user['id'], 'login', 'user', ip_address, user_agent, True, 'Successful login')
            
            return {
                'success': True,
                'user': {
                    'id': user['id'],
                    'username': user['username'],
                    'email': user['email'],
                    'role': user['role'],
                    'mfa_enabled': user['mfa_enabled']
                }
            }
        except Exception as e:
            logger.error(f"Error en autenticación: {e}")
            return {'success': False, 'message': 'Error en el servidor'}
        finally:
            if 'conn' in locals():
                conn.close()
    
    def verify_mfa(self, user_id, mfa_code, backup_code=False):
        """Verificar código MFA"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            # Obtener usuario
            cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
            user = cursor.fetchone()
            
            if not user:
                return {'success': False, 'message': 'Usuario no encontrado'}
            
            if not user['mfa_enabled']:
                return {'success': True, 'message': 'MFA no está habilitado para este usuario'}
            
            if backup_code:
                # Verificar código de respaldo
                cursor.execute('''
                    SELECT * FROM mfa_backup_codes
                    WHERE user_id = ? AND used = 0 AND code_hash = ?
                ''', (user_id, hashlib.sha256(mfa_code.encode()).hexdigest()))
                
                backup_code_entry = cursor.fetchone()
                
                if backup_code_entry:
                    # Marcar código como usado
                    cursor.execute('UPDATE mfa_backup_codes SET used = 1 WHERE id = ?', (backup_code_entry['id'],))
                    conn.commit()
                    
                    self.log_audit_event(user_id, 'mfa', 'backup_code', None, None, True, 'Backup code used')
                    return {'success': True, 'message': 'Código de respaldo válido'}
                else:
                    self.log_audit_event(user_id, 'mfa', 'backup_code', None, None, False, 'Invalid backup code')
                    return {'success': False, 'message': 'Código de respaldo inválido o ya usado'}
            else:
                # Verificar código TOTP
                if not user['mfa_secret']:
                    return {'success': False, 'message': 'Secreto MFA no configurado'}
                
                totp = pyotp.TOTP(user['mfa_secret'])
                
                if totp.verify(mfa_code, valid_window=1):
                    self.log_audit_event(user_id, 'mfa', 'totp', None, None, True, 'TOTP code verified')
                    return {'success': True, 'message': 'Código MFA válido'}
                else:
                    self.log_audit_event(user_id, 'mfa', 'totp', None, None, False, 'Invalid TOTP code')
                    return {'success': False, 'message': 'Código MFA inválido'}
        except Exception as e:
            logger.error(f"Error en verificación MFA: {e}")
            return {'success': False, 'message': 'Error en el servidor'}
        finally:
            if 'conn' in locals():
                conn.close()
    
    def generate_mfa_secret(self, user_id):
        """Generar secreto MFA para un usuario"""
        try:
            mfa_secret = pyotp.random_base32()
            
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            # Actualizar secreto MFA del usuario
            cursor.execute('UPDATE users SET mfa_secret = ? WHERE id = ?', (mfa_secret, user_id))
            conn.commit()
            
            # Generar códigos de respaldo
            backup_codes = []
            for _ in range(self.config['mfa']['backup_codes_count']):
                backup_code = self.generate_secure_password(8)
                backup_code_hash = hashlib.sha256(backup_code.encode()).hexdigest()
                
                cursor.execute('''
                    INSERT INTO mfa_backup_codes (user_id, code_hash)
                    VALUES (?, ?)
                ''', (user_id, backup_code_hash))
                
                backup_codes.append(backup_code)
            
            conn.close()
            
            self.log_audit_event(user_id, 'mfa', 'setup', None, None, True, 'MFA secret generated')
            
            return {
                'success': True,
                'mfa_secret': mfa_secret,
                'backup_codes': backup_codes
            }
        except Exception as e:
            logger.error(f"Error al generar secreto MFA: {e}")
            return {'success': False, 'message': 'Error en el servidor'}
    
    def generate_mfa_qr_code(self, username, mfa_secret):
        """Generar código QR para configuración MFA"""
        try:
            totp_uri = pyotp.totp.TOTP(mfa_secret).provisioning_uri(
                name=username,
                issuer_name=self.mfa_issuer
            )
            
            # Generar código QR
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=10,
                border=4,
            )
            qr.add_data(totp_uri)
            qr.make(fit=True)
            
            # Crear imagen del código QR
            qr_image = qr.make_image(fill_color="black", back_color="white")
            
            # Guardar imagen
            qr_code_path = os.path.join(self.config['mfa']['qr_code_path'], f"{username}_mfa_qr.png")
            qr_image.save(qr_code_path)
            
            return {
                'success': True,
                'qr_code_path': qr_code_path,
                'totp_uri': totp_uri
            }
        except Exception as e:
            logger.error(f"Error al generar código QR MFA: {e}")
            return {'success': False, 'message': 'Error en el servidor'}
    
    def enable_mfa(self, user_id):
        """Habilitar MFA para un usuario"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            # Verificar que el usuario tenga secreto MFA
            cursor.execute('SELECT mfa_secret FROM users WHERE id = ?', (user_id,))
            user = cursor.fetchone()
            
            if not user or not user['mfa_secret']:
                return {'success': False, 'message': 'Secreto MFA no configurado'}
            
            # Habilitar MFA
            cursor.execute('UPDATE users SET mfa_enabled = 1 WHERE id = ?', (user_id,))
            conn.commit()
            
            self.log_audit_event(user_id, 'mfa', 'enable', None, None, True, 'MFA enabled')
            
            return {'success': True, 'message': 'MFA habilitado'}
        except Exception as e:
            logger.error(f"Error al habilitar MFA: {e}")
            return {'success': False, 'message': 'Error en el servidor'}
        finally:
            if 'conn' in locals():
                conn.close()
    
    def disable_mfa(self, user_id):
        """Deshabilitar MFA para un usuario"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            # Deshabilitar MFA
            cursor.execute('UPDATE users SET mfa_enabled = 0 WHERE id = ?', (user_id,))
            conn.commit()
            
            self.log_audit_event(user_id, 'mfa', 'disable', None, None, True, 'MFA disabled')
            
            return {'success': True, 'message': 'MFA deshabilitado'}
        except Exception as e:
            logger.error(f"Error al deshabilitar MFA: {e}")
            return {'success': False, 'message': 'Error en el servidor'}
        finally:
            if 'conn' in locals():
                conn.close()
    
    def check_permission(self, user_id, permission):
        """Verificar si un usuario tiene un permiso específico"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            # Obtener rol del usuario
            cursor.execute('SELECT role FROM users WHERE id = ?', (user_id,))
            user = cursor.fetchone()
            
            if not user:
                return False
            
            # Obtener permisos del rol
            cursor.execute('SELECT permissions FROM roles WHERE name = ?', (user['role'],))
            role = cursor.fetchone()
            
            if not role:
                return False
            
            permissions = json.loads(role['permissions'])
            
            # Verificar permiso
            if '*' in permissions:
                return True
            
            return permission in permissions
        except Exception as e:
            logger.error(f"Error al verificar permiso: {e}")
            return False
        finally:
            if 'conn' in locals():
                conn.close()
    
    def create_session(self, user_id, ip_address=None, user_agent=None):
        """Crear sesión de usuario"""
        try:
            session_id = secrets.token_urlsafe(32)
            expires_at = datetime.now() + timedelta(seconds=self.jwt_expiration)
            
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            # Crear sesión
            cursor.execute('''
                INSERT INTO sessions (session_id, user_id, ip_address, user_agent, expires_at)
                VALUES (?, ?, ?, ?, ?)
            ''', (session_id, user_id, ip_address, user_agent, expires_at))
            
            conn.commit()
            
            # Generar token JWT
            cursor.execute('SELECT username, role FROM users WHERE id = ?', (user_id,))
            user = cursor.fetchone()
            
            payload = {
                'user_id': user_id,
                'username': user['username'],
                'role': user['role'],
                'session_id': session_id,
                'exp': expires_at.timestamp()
            }
            
            token = jwt.encode(payload, self.jwt_secret, algorithm='HS256')
            
            self.log_audit_event(user_id, 'session', 'create', ip_address, user_agent, True, 'Session created')
            
            return {
                'success': True,
                'token': token,
                'session_id': session_id,
                'expires_at': expires_at.isoformat()
            }
        except Exception as e:
            logger.error(f"Error al crear sesión: {e}")
            return {'success': False, 'message': 'Error en el servidor'}
        finally:
            if 'conn' in locals():
                conn.close()
    
    def validate_session(self, token, ip_address=None):
        """Validar sesión de usuario"""
        try:
            # Decodificar token JWT
            payload = jwt.decode(token, self.jwt_secret, algorithms=['HS256'])
            session_id = payload.get('session_id')
            user_id = payload.get('user_id')
            
            if not session_id or not user_id:
                return {'success': False, 'message': 'Token inválido'}
            
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            # Verificar sesión en base de datos
            cursor.execute('''
                SELECT * FROM sessions
                WHERE session_id = ? AND user_id = ? AND is_active = 1 AND expires_at > ?
            ''', (session_id, user_id, datetime.now()))
            
            session = cursor.fetchone()
            
            if not session:
                return {'success': False, 'message': 'Sesión inválida o expirada'}
            
            # Verificar dirección IP si se requiere
            if ip_address and session['ip_address'] != ip_address:
                self.log_audit_event(user_id, 'session', 'validate', ip_address, None, False, 'IP address mismatch')
                return {'success': False, 'message': 'Dirección IP no coincide'}
            
            # Obtener información del usuario
            cursor.execute('SELECT username, role, mfa_enabled FROM users WHERE id = ?', (user_id))
            user = cursor.fetchone()
            
            return {
                'success': True,
                'user': {
                    'id': user_id,
                    'username': user['username'],
                    'role': user['role'],
                    'mfa_enabled': user['mfa_enabled']
                }
            }
        except jwt.ExpiredSignatureError:
            return {'success': False, 'message': 'Sesión expirada'}
        except jwt.InvalidTokenError:
            return {'success': False, 'message': 'Token inválido'}
        except Exception as e:
            logger.error(f"Error al validar sesión: {e}")
            return {'success': False, 'message': 'Error en el servidor'}
        finally:
            if 'conn' in locals():
                conn.close()
    
    def revoke_session(self, session_id):
        """Revocar sesión"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            # Marcar sesión como inactiva
            cursor.execute('UPDATE sessions SET is_active = 0 WHERE session_id = ?', (session_id,))
            conn.commit()
            
            self.log_audit_event(None, 'session', 'revoke', None, None, True, f'Session {session_id} revoked')
            
            return {'success': True, 'message': 'Sesión revocada'}
        except Exception as e:
            logger.error(f"Error al revocar sesión: {e}")
            return {'success': False, 'message': 'Error en el servidor'}
        finally:
            if 'conn' in locals():
                conn.close()
    
    def log_audit_event(self, user_id, action, resource, ip_address, user_agent, success, details):
        """Registrar evento de auditoría"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO audit_logs (user_id, action, resource, ip_address, user_agent, success, details)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (user_id, action, resource, ip_address, user_agent, success, details))
            
            conn.commit()
        except Exception as e:
            logger.error(f"Error al registrar evento de auditoría: {e}")
        finally:
            if 'conn' in locals():
                conn.close()
    
    def setup_flask_routes(self):
        """Configurar rutas de Flask"""
        
        @self.app.route('/api/auth/login', methods=['POST'])
        def api_login():
            """API de inicio de sesión"""
            data = request.get_json()
            username = data.get('username')
            password = data.get('password')
            ip_address = request.remote_addr
            user_agent = request.headers.get('User-Agent')
            
            if not username or not password:
                return jsonify({'success': False, 'message': 'Usuario y contraseña requeridos'}), 400
            
            # Autenticar usuario
            auth_result = self.authenticate_user(username, password, ip_address, user_agent)
            
            if not auth_result['success']:
                return jsonify(auth_result), 401
            
            user = auth_result['user']
            
            # Verificar si se requiere MFA
            if self.config['mfa']['require_mfa'] and user['mfa_enabled']:
                return jsonify({
                    'success': True,
                    'require_mfa': True,
                    'user_id': user['id']
                }), 200
            
            # Crear sesión
            session_result = self.create_session(user['id'], ip_address, user_agent)
            
            if not session_result['success']:
                return jsonify(session_result), 500
            
            return jsonify({
                'success': True,
                'require_mfa': False,
                'token': session_result['token'],
                'user': user
            }), 200
        
        @self.app.route('/api/auth/mfa', methods=['POST'])
        def api_mfa():
            """API de verificación MFA"""
            data = request.get_json()
            user_id = data.get('user_id')
            mfa_code = data.get('mfa_code')
            backup_code = data.get('backup_code', False)
            ip_address = request.remote_addr
            user_agent = request.headers.get('User-Agent')
            
            if not user_id or not mfa_code:
                return jsonify({'success': False, 'message': 'ID de usuario y código MFA requeridos'}), 400
            
            # Verificar código MFA
            mfa_result = self.verify_mfa(user_id, mfa_code, backup_code)
            
            if not mfa_result['success']:
                return jsonify(mfa_result), 401
            
            # Crear sesión
            session_result = self.create_session(user_id, ip_address, user_agent)
            
            if not session_result['success']:
                return jsonify(session_result), 500
            
            return jsonify({
                'success': True,
                'token': session_result['token']
            }), 200
        
        @self.app.route('/api/auth/validate', methods=['POST'])
        def api_validate():
            """API de validación de sesión"""
            data = request.get_json()
            token = data.get('token')
            ip_address = request.remote_addr
            
            if not token:
                return jsonify({'success': False, 'message': 'Token requerido'}), 400
            
            # Validar sesión
            session_result = self.validate_session(token, ip_address)
            
            if not session_result['success']:
                return jsonify(session_result), 401
            
            return jsonify(session_result), 200
        
        @self.app.route('/api/auth/logout', methods=['POST'])
        def api_logout():
            """API de cierre de sesión"""
            data = request.get_json()
            token = data.get('token')
            
            if not token:
                return jsonify({'success': False, 'message': 'Token requerido'}), 400
            
            try:
                # Decodificar token para obtener session_id
                payload = jwt.decode(token, self.jwt_secret, algorithms=['HS256'])
                session_id = payload.get('session_id')
                
                if not session_id:
                    return jsonify({'success': False, 'message': 'Token inválido'}), 400
                
                # Revocar sesión
                revoke_result = self.revoke_session(session_id)
                
                if not revoke_result['success']:
                    return jsonify(revoke_result), 500
                
                return jsonify({'success': True, 'message': 'Sesión cerrada'}), 200
            except Exception as e:
                return jsonify({'success': False, 'message': 'Error al cerrar sesión'}), 500
        
        @self.app.route('/api/mfa/setup', methods=['POST'])
        def api_mfa_setup():
            """API de configuración MFA"""
            data = request.get_json()
            token = data.get('token')
            
            if not token:
                return jsonify({'success': False, 'message': 'Token requerido'}), 400
            
            # Validar sesión
            session_result = self.validate_session(token)
            
            if not session_result['success']:
                return jsonify(session_result), 401
            
            user_id = session_result['user']['id']
            username = session_result['user']['username']
            
            # Generar secreto MFA
            mfa_result = self.generate_mfa_secret(user_id)
            
            if not mfa_result['success']:
                return jsonify(mfa_result), 500
            
            # Generar código QR
            qr_result = self.generate_mfa_qr_code(username, mfa_result['mfa_secret'])
            
            if not qr_result['success']:
                return jsonify(qr_result), 500
            
            return jsonify({
                'success': True,
                'qr_code_path': qr_result['qr_code_path'],
                'backup_codes': mfa_result['backup_codes']
            }), 200
        
        @self.app.route('/api/mfa/enable', methods=['POST'])
        def api_mfa_enable():
            """API para habilitar MFA"""
            data = request.get_json()
            token = data.get('token')
            
            if not token:
                return jsonify({'success': False, 'message': 'Token requerido'}), 400
            
            # Validar sesión
            session_result = self.validate_session(token)
            
            if not session_result['success']:
                return jsonify(session_result), 401
            
            user_id = session_result['user']['id']
            
            # Habilitar MFA
            enable_result = self.enable_mfa(user_id)
            
            if not enable_result['success']:
                return jsonify(enable_result), 500
            
            return jsonify(enable_result), 200
        
        @self.app.route('/api/mfa/disable', methods=['POST'])
        def api_mfa_disable():
            """API para deshabilitar MFA"""
            data = request.get_json()
            token = data.get('token')
            
            if not token:
                return jsonify({'success': False, 'message': 'Token requerido'}), 400
            
            # Validar sesión
            session_result = self.validate_session(token)
            
            if not session_result['success']:
                return jsonify(session_result), 401
            
            user_id = session_result['user']['id']
            
            # Deshabilitar MFA
            disable_result = self.disable_mfa(user_id)
            
            if not disable_result['success']:
                return jsonify(disable_result), 500
            
            return jsonify(disable_result), 200
        
        @self.app.route('/api/permissions/check', methods=['POST'])
        def api_check_permission():
            """API para verificar permisos"""
            data = request.get_json()
            token = data.get('token')
            permission = data.get('permission')
            
            if not token or not permission:
                return jsonify({'success': False, 'message': 'Token y permiso requeridos'}), 400
            
            # Validar sesión
            session_result = self.validate_session(token)
            
            if not session_result['success']:
                return jsonify(session_result), 401
            
            user_id = session_result['user']['id']
            
            # Verificar permiso
            has_permission = self.check_permission(user_id, permission)
            
            return jsonify({
                'success': True,
                'has_permission': has_permission
            }), 200
    
    def run_flask_app(self, host='0.0.0.0', port=5000, debug=False):
        """Ejecutar aplicación Flask"""
        logger.info(f"Iniciando aplicación Flask en {host}:{port}")
        self.app.run(host=host, port=port, debug=debug)
    
    def integrate_with_virtualmin(self):
        """Integrar con Virtualmin"""
        try:
            # Configurar autenticación de Virtualmin para usar nuestro sistema
            virtualmin_auth_script = "/opt/virtualmin-enterprise/security/virtualmin_auth.pl"
            
            with open(virtualmin_auth_script, 'w') as f:
                f.write('''#!/usr/bin/perl
# Script de autenticación de Virtualmin que utiliza el sistema MFA/RBAC

use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use HTTP::Request::Common;

# Configuración
my $api_url = "http://localhost:5000";
my $api_timeout = 30;

# Función para autenticar usuario
sub authenticate_user {
    my ($username, $password, $ip) = @_;
    
    my $ua = LWP::UserAgent->new();
    $ua->timeout($api_timeout);
    
    my $request = POST(
        "$api_url/api/auth/login",
        Content_Type => 'application/json',
        Content => encode_json({
            username => $username,
            password => $password
        })
    );
    
    $request->header('User-Agent' => "Virtualmin-Auth-Script");
    $request->header('X-Forwarded-For' => $ip) if $ip;
    
    my $response = $ua->request($request);
    
    if ($response->is_success) {
        my $result = decode_json($response->content);
        
        if ($result->{success}) {
            if ($result->{require_mfa}) {
                # Requiere verificación MFA
                print "MFA_REQUIRED:$result->{user_id}\\n";
                return 1;
            } else {
                # Autenticación exitosa
                print "SUCCESS:$result->{token}\\n";
                return 1;
            }
        } else {
            # Autenticación fallida
            print "FAILED:$result->{message}\\n";
            return 0;
        }
    } else {
        # Error de conexión
        print "ERROR:Cannot connect to authentication service\\n";
        return 0;
    }
}

# Función para verificar MFA
sub verify_mfa {
    my ($user_id, $mfa_code, $backup_code) = @_;
    
    my $ua = LWP::UserAgent->new();
    $ua->timeout($api_timeout);
    
    my $request = POST(
        "$api_url/api/auth/mfa",
        Content_Type => 'application/json',
        Content => encode_json({
            user_id => $user_id,
            mfa_code => $mfa_code,
            backup_code => $backup_code || 0
        })
    );
    
    my $response = $ua->request($request);
    
    if ($response->is_success) {
        my $result = decode_json($response->content);
        
        if ($result->{success}) {
            # MFA verificado
            print "MFA_SUCCESS:$result->{token}\\n";
            return 1;
        } else {
            # MFA fallido
            print "MFA_FAILED:$result->{message}\\n";
            return 0;
        }
    } else {
        # Error de conexión
        print "ERROR:Cannot connect to authentication service\\n";
        return 0;
    }
}

# Función para verificar permisos
sub check_permission {
    my ($token, $permission) = @_;
    
    my $ua = LWP::UserAgent->new();
    $ua->timeout($api_timeout);
    
    my $request = POST(
        "$api_url/api/permissions/check",
        Content_Type => 'application/json',
        Content => encode_json({
            token => $token,
            permission => $permission
        })
    );
    
    my $response = $ua->request($request);
    
    if ($response->is_success) {
        my $result = decode_json($response->content);
        
        if ($result->{success}) {
            if ($result->{has_permission}) {
                # Permiso concedido
                print "PERMISSION_GRANTED\\n";
                return 1;
            } else {
                # Permiso denegado
                print "PERMISSION_DENIED\\n";
                return 0;
            }
        } else {
            # Error
            print "ERROR:$result->{message}\\n";
            return 0;
        }
    } else {
        # Error de conexión
        print "ERROR:Cannot connect to authentication service\\n";
        return 0;
    }
}

# Procesar argumentos
my $action = shift @ARGV;
my $username = shift @ARGV;
my $password = shift @ARGV;
my $ip = shift @ARGV;

if ($action eq 'auth') {
    authenticate_user($username, $password, $ip);
} elsif ($action eq 'mfa') {
    my $user_id = $username;
    my $mfa_code = $password;
    my $backup_code = $ip;
    
    verify_mfa($user_id, $mfa_code, $backup_code);
} elsif ($action eq 'permission') {
    my $token = $username;
    my $permission = $password;
    
    check_permission($token, $permission);
} else {
    print "ERROR:Invalid action\\n";
}
''')
            
            # Hacer ejecutable el script
            os.chmod(virtualmin_auth_script, 0o755)
            
            # Configurar Virtualmin para usar nuestro script de autenticación
            virtualmin_config = "/etc/webmin/miniserv.conf"
            
            # Backup del archivo de configuración
            if os.path.exists(virtualmin_config):
                subprocess.run(["cp", virtualmin_config, f"{virtualmin_config}.backup"], check=True)
            
            # Añadir configuración de autenticación externa
            with open(virtualmin_config, 'a') as f:
                f.write("\n# Virtualmin Enterprise MFA/RBAC Authentication\n")
                f.write("external_auth=1\n")
                f.write(f"external_auth_program={virtualmin_auth_script}\n")
            
            # Reiniciar Webmin
            subprocess.run(["systemctl", "restart", "webmin"], check=True)
            
            logger.info("Integración con Virtualmin completada")
            return True
        except Exception as e:
            logger.error(f"Error al integrar con Virtualmin: {e}")
            return False

def main():
    """Función principal"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Sistema MFA/RBAC para Virtualmin Enterprise')
    parser.add_argument('--config', help='Archivo de configuración', default='/opt/virtualmin-enterprise/security/mfa_rbac_config.json')
    parser.add_argument('--run', action='store_true', help='Ejecutar servidor Flask')
    parser.add_argument('--host', default='0.0.0.0', help='Host para el servidor Flask')
    parser.add_argument('--port', type=int, default=5000, help='Puerto para el servidor Flask')
    parser.add_argument('--debug', action='store_true', help='Modo debug')
    parser.add_argument('--integrate', action='store_true', help='Integrar con Virtualmin')
    
    args = parser.parse_args()
    
    # Inicializar sistema
    mfa_rbac = MFARBACSystem(args.config)
    
    if args.integrate:
        # Integrar con Virtualmin
        success = mfa_rbac.integrate_with_virtualmin()
        sys.exit(0 if success else 1)
    elif args.run:
        # Ejecutar servidor Flask
        mfa_rbac.run_flask_app(host=args.host, port=args.port, debug=args.debug)
    else:
        logger.error("Debe especificar una acción. Use --run para ejecutar el servidor o --integrate para integrar con Virtualmin.")
        sys.exit(1)

if __name__ == "__main__":
    main()