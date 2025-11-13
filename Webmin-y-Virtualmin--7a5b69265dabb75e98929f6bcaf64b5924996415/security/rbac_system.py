#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
🔐 SISTEMA DE CONTROL DE ACCESO BASADO EN ROLES (RBAC)
====================================================
Sistema centralizado de gestión de permisos para Webmin/Virtualmin
Implementa políticas de seguridad granulares y auditoría completa
"""

import json
import hashlib
import time
import os
import sys
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Set, Tuple
from dataclasses import dataclass, asdict
from enum import Enum
import logging

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/webmin/rbac_audit.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class Permission(Enum):
    """Enumeración de permisos del sistema"""
    # Permisos de sistema
    SYSTEM_READ = "system:read"
    SYSTEM_WRITE = "system:write"
    SYSTEM_ADMIN = "system:admin"
    
    # Permisos de usuarios
    USER_READ = "user:read"
    USER_WRITE = "user:write"
    USER_CREATE = "user:create"
    USER_DELETE = "user:delete"
    USER_ADMIN = "user:admin"
    
    # Permisos de dominios
    DOMAIN_READ = "domain:read"
    DOMAIN_CREATE = "domain:create"
    DOMAIN_UPDATE = "domain:update"
    DOMAIN_DELETE = "domain:delete"
    DOMAIN_ADMIN = "domain:admin"
    
    # Permisos de bases de datos
    DB_READ = "database:read"
    DB_WRITE = "database:write"
    DB_CREATE = "database:create"
    DB_DELETE = "database:delete"
    DB_ADMIN = "database:admin"
    
    # Permisos de email
    EMAIL_READ = "email:read"
    EMAIL_WRITE = "email:write"
    EMAIL_ADMIN = "email:admin"
    
    # Permisos de SSL
    SSL_READ = "ssl:read"
    SSL_CREATE = "ssl:create"
    SSL_UPDATE = "ssl:update"
    SSL_DELETE = "ssl:delete"
    SSL_ADMIN = "ssl:admin"
    
    # Permisos de backups
    BACKUP_READ = "backup:read"
    BACKUP_CREATE = "backup:create"
    BACKUP_RESTORE = "backup:restore"
    BACKUP_DELETE = "backup:delete"
    BACKUP_ADMIN = "backup:admin"
    
    # Permisos de seguridad
    SECURITY_READ = "security:read"
    SECURITY_WRITE = "security:write"
    SECURITY_ADMIN = "security:admin"
    
    # Permisos de monitoreo
    MONITORING_READ = "monitoring:read"
    MONITORING_WRITE = "monitoring:write"
    MONITORING_ADMIN = "monitoring:admin"

@dataclass
class Role:
    """Definición de un rol del sistema"""
    name: str
    description: str
    permissions: Set[Permission]
    is_system_role: bool = False
    created_at: float = None
    updated_at: float = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = time.time()
        if self.updated_at is None:
            self.updated_at = time.time()

@dataclass
class User:
    """Definición de un usuario del sistema"""
    username: str
    email: str
    roles: List[str]
    is_active: bool = True
    created_at: float = None
    last_login: float = None
    failed_login_attempts: int = 0
    locked_until: float = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = time.time()

@dataclass
class AccessLog:
    """Registro de acceso para auditoría"""
    timestamp: float
    username: str
    action: str
    resource: str
    permission: str
    ip_address: str
    user_agent: str
    success: bool
    reason: str = ""

class RBACManager:
    """Gestor principal del sistema RBAC"""
    
    def __init__(self, config_dir: str = "/etc/webmin/rbac"):
        self.config_dir = config_dir
        self.roles_file = os.path.join(config_dir, "roles.json")
        self.users_file = os.path.join(config_dir, "users.json")
        self.access_log_file = os.path.join(config_dir, "access.log")
        
        # Crear directorio de configuración si no existe
        os.makedirs(config_dir, mode=0o700, exist_ok=True)
        
        # Inicializar datos
        self.roles: Dict[str, Role] = {}
        self.users: Dict[str, User] = {}
        
        # Cargar datos existentes
        self._load_data()
        
        # Inicializar roles por defecto si no existen
        self._initialize_default_roles()
    
    def _load_data(self):
        """Cargar datos desde archivos"""
        try:
            # Cargar roles
            if os.path.exists(self.roles_file):
                with open(self.roles_file, 'r') as f:
                    roles_data = json.load(f)
                    for role_name, role_data in roles_data.items():
                        permissions = {Permission(p) for p in role_data['permissions']}
                        self.roles[role_name] = Role(
                            name=role_data['name'],
                            description=role_data['description'],
                            permissions=permissions,
                            is_system_role=role_data.get('is_system_role', False),
                            created_at=role_data.get('created_at'),
                            updated_at=role_data.get('updated_at')
                        )
                logger.info(f"Cargados {len(self.roles)} roles")
            
            # Cargar usuarios
            if os.path.exists(self.users_file):
                with open(self.users_file, 'r') as f:
                    users_data = json.load(f)
                    for username, user_data in users_data.items():
                        self.users[username] = User(
                            username=user_data['username'],
                            email=user_data['email'],
                            roles=user_data['roles'],
                            is_active=user_data.get('is_active', True),
                            created_at=user_data.get('created_at'),
                            last_login=user_data.get('last_login'),
                            failed_login_attempts=user_data.get('failed_login_attempts', 0),
                            locked_until=user_data.get('locked_until')
                        )
                logger.info(f"Cargados {len(self.users)} usuarios")
        except Exception as e:
            logger.error(f"Error cargando datos RBAC: {e}")
    
    def _save_data(self):
        """Guardar datos a archivos"""
        try:
            # Guardar roles
            roles_data = {}
            for role_name, role in self.roles.items():
                roles_data[role_name] = {
                    'name': role.name,
                    'description': role.description,
                    'permissions': [p.value for p in role.permissions],
                    'is_system_role': role.is_system_role,
                    'created_at': role.created_at,
                    'updated_at': role.updated_at
                }
            
            with open(self.roles_file, 'w') as f:
                json.dump(roles_data, f, indent=2)
            os.chmod(self.roles_file, 0o600)
            
            # Guardar usuarios
            users_data = {}
            for username, user in self.users.items():
                users_data[username] = asdict(user)
            
            with open(self.users_file, 'w') as f:
                json.dump(users_data, f, indent=2)
            os.chmod(self.users_file, 0o600)
            
            logger.info("Datos RBAC guardados exitosamente")
        except Exception as e:
            logger.error(f"Error guardando datos RBAC: {e}")
    
    def _initialize_default_roles(self):
        """Inicializar roles por defecto del sistema"""
        default_roles = {
            'super_admin': Role(
                name='super_admin',
                description='Administrador con acceso completo al sistema',
                permissions={p for p in Permission},
                is_system_role=True
            ),
            'admin': Role(
                name='admin',
                description='Administrador con acceso a la mayoría de funciones',
                permissions={
                    Permission.SYSTEM_READ,
                    Permission.USER_ADMIN,
                    Permission.DOMAIN_ADMIN,
                    Permission.DB_ADMIN,
                    Permission.EMAIL_ADMIN,
                    Permission.SSL_ADMIN,
                    Permission.BACKUP_ADMIN,
                    Permission.MONITORING_READ
                },
                is_system_role=True
            ),
            'reseller': Role(
                name='reseller',
                description='Revendedor con gestión de dominios y usuarios',
                permissions={
                    Permission.USER_READ,
                    Permission.USER_CREATE,
                    Permission.USER_WRITE,
                    Permission.DOMAIN_ADMIN,
                    Permission.DB_READ,
                    Permission.DB_CREATE,
                    Permission.DB_WRITE,
                    Permission.EMAIL_READ,
                    Permission.EMAIL_WRITE,
                    Permission.SSL_READ,
                    Permission.SSL_CREATE,
                    Permission.BACKUP_READ,
                    Permission.BACKUP_CREATE,
                    Permission.MONITORING_READ
                },
                is_system_role=True
            ),
            'domain_admin': Role(
                name='domain_admin',
                description='Administrador de dominio',
                permissions={
                    Permission.USER_READ,
                    Permission.USER_CREATE,
                    Permission.USER_WRITE,
                    Permission.DOMAIN_READ,
                    Permission.DOMAIN_UPDATE,
                    Permission.DB_READ,
                    Permission.DB_WRITE,
                    Permission.EMAIL_READ,
                    Permission.EMAIL_WRITE,
                    Permission.SSL_READ,
                    Permission.BACKUP_READ,
                    Permission.BACKUP_CREATE,
                    Permission.MONITORING_READ
                },
                is_system_role=True
            ),
            'user': Role(
                name='user',
                description='Usuario básico con acceso limitado',
                permissions={
                    Permission.USER_READ,
                    Permission.DOMAIN_READ,
                    Permission.DB_READ,
                    Permission.EMAIL_READ,
                    Permission.EMAIL_WRITE,
                    Permission.SSL_READ,
                    Permission.BACKUP_READ,
                    Permission.MONITORING_READ
                },
                is_system_role=True
            ),
            'readonly': Role(
                name='readonly',
                description='Usuario de solo lectura',
                permissions={
                    Permission.USER_READ,
                    Permission.DOMAIN_READ,
                    Permission.DB_READ,
                    Permission.EMAIL_READ,
                    Permission.SSL_READ,
                    Permission.BACKUP_READ,
                    Permission.MONITORING_READ
                },
                is_system_role=True
            )
        }
        
        # Agregar roles por defecto si no existen
        for role_name, role in default_roles.items():
            if role_name not in self.roles:
                self.roles[role_name] = role
                logger.info(f"Rol por defecto creado: {role_name}")
        
        # Guardar si se agregaron nuevos roles
        self._save_data()
    
    def create_role(self, name: str, description: str, permissions: List[Permission]) -> bool:
        """Crear un nuevo rol"""
        if name in self.roles:
            logger.error(f"El rol {name} ya existe")
            return False
        
        if not name.isalnum() and '_' not in name:
            logger.error("El nombre del rol solo puede contener caracteres alfanuméricos y guiones bajos")
            return False
        
        role = Role(
            name=name,
            description=description,
            permissions=set(permissions)
        )
        
        self.roles[name] = role
        self._save_data()
        
        logger.info(f"Rol creado: {name}")
        return True
    
    def update_role(self, name: str, description: str = None, permissions: List[Permission] = None) -> bool:
        """Actualizar un rol existente"""
        if name not in self.roles:
            logger.error(f"El rol {name} no existe")
            return False
        
        role = self.roles[name]
        
        # No permitir modificar roles del sistema
        if role.is_system_role:
            logger.error(f"No se puede modificar el rol del sistema: {name}")
            return False
        
        if description is not None:
            role.description = description
        
        if permissions is not None:
            role.permissions = set(permissions)
        
        role.updated_at = time.time()
        self._save_data()
        
        logger.info(f"Rol actualizado: {name}")
        return True
    
    def delete_role(self, name: str) -> bool:
        """Eliminar un rol"""
        if name not in self.roles:
            logger.error(f"El rol {name} no existe")
            return False
        
        role = self.roles[name]
        
        # No permitir eliminar roles del sistema
        if role.is_system_role:
            logger.error(f"No se puede eliminar el rol del sistema: {name}")
            return False
        
        # Verificar que no haya usuarios con este rol
        for user in self.users.values():
            if name in user.roles:
                logger.error(f"No se puede eliminar el rol {name}: está asignado a usuarios")
                return False
        
        del self.roles[name]
        self._save_data()
        
        logger.info(f"Rol eliminado: {name}")
        return True
    
    def create_user(self, username: str, email: str, roles: List[str]) -> bool:
        """Crear un nuevo usuario"""
        if username in self.users:
            logger.error(f"El usuario {username} ya existe")
            return False
        
        # Verificar que todos los roles existan
        for role_name in roles:
            if role_name not in self.roles:
                logger.error(f"El rol {role_name} no existe")
                return False
        
        user = User(
            username=username,
            email=email,
            roles=roles
        )
        
        self.users[username] = user
        self._save_data()
        
        logger.info(f"Usuario creado: {username}")
        return True
    
    def update_user(self, username: str, email: str = None, roles: List[str] = None) -> bool:
        """Actualizar un usuario existente"""
        if username not in self.users:
            logger.error(f"El usuario {username} no existe")
            return False
        
        user = self.users[username]
        
        if email is not None:
            user.email = email
        
        if roles is not None:
            # Verificar que todos los roles existan
            for role_name in roles:
                if role_name not in self.roles:
                    logger.error(f"El rol {role_name} no existe")
                    return False
            user.roles = roles
        
        self._save_data()
        
        logger.info(f"Usuario actualizado: {username}")
        return True
    
    def delete_user(self, username: str) -> bool:
        """Eliminar un usuario"""
        if username not in self.users:
            logger.error(f"El usuario {username} no existe")
            return False
        
        del self.users[username]
        self._save_data()
        
        logger.info(f"Usuario eliminado: {username}")
        return True
    
    def lock_user(self, username: str, duration_hours: int = 24) -> bool:
        """Bloquear un usuario temporalmente"""
        if username not in self.users:
            logger.error(f"El usuario {username} no existe")
            return False
        
        user = self.users[username]
        user.locked_until = time.time() + (duration_hours * 3600)
        self._save_data()
        
        logger.warning(f"Usuario bloqueado: {username} por {duration_hours} horas")
        return True
    
    def unlock_user(self, username: str) -> bool:
        """Desbloquear un usuario"""
        if username not in self.users:
            logger.error(f"El usuario {username} no existe")
            return False
        
        user = self.users[username]
        user.locked_until = None
        user.failed_login_attempts = 0
        self._save_data()
        
        logger.info(f"Usuario desbloqueado: {username}")
        return True
    
    def check_permission(self, username: str, permission: Permission, resource: str = None) -> Tuple[bool, str]:
        """Verificar si un usuario tiene un permiso específico"""
        if username not in self.users:
            return False, "Usuario no existe"
        
        user = self.users[username]
        
        # Verificar si el usuario está activo
        if not user.is_active:
            return False, "Usuario inactivo"
        
        # Verificar si el usuario está bloqueado
        if user.locked_until and user.locked_until > time.time():
            return False, "Usuario bloqueado"
        
        # Verificar permisos en todos los roles del usuario
        for role_name in user.roles:
            if role_name in self.roles:
                role = self.roles[role_name]
                if permission in role.permissions:
                    return True, "Permiso concedido"
        
        return False, "Permiso denegado"
    
    def log_access(self, username: str, action: str, resource: str, permission: Permission, 
                  ip_address: str, user_agent: str, success: bool, reason: str = ""):
        """Registrar acceso para auditoría"""
        log_entry = AccessLog(
            timestamp=time.time(),
            username=username,
            action=action,
            resource=resource,
            permission=permission.value,
            ip_address=ip_address,
            user_agent=user_agent,
            success=success,
            reason=reason
        )
        
        # Guardar en archivo de log
        with open(self.access_log_file, 'a') as f:
            log_data = {
                'timestamp': log_entry.timestamp,
                'username': log_entry.username,
                'action': log_entry.action,
                'resource': log_entry.resource,
                'permission': log_entry.permission,
                'ip_address': log_entry.ip_address,
                'user_agent': log_entry.user_agent,
                'success': log_entry.success,
                'reason': log_entry.reason
            }
            f.write(json.dumps(log_data) + '\n')
        
        # También registrar en el logger del sistema
        if success:
            logger.info(f"ACCESO PERMITIDO: {username} -> {action} on {resource}")
        else:
            logger.warning(f"ACCESO DENEGADO: {username} -> {action} on {resource} ({reason})")
    
    def get_user_permissions(self, username: str) -> Set[Permission]:
        """Obtener todos los permisos de un usuario"""
        if username not in self.users:
            return set()
        
        user = self.users[username]
        all_permissions = set()
        
        for role_name in user.roles:
            if role_name in self.roles:
                role = self.roles[role_name]
                all_permissions.update(role.permissions)
        
        return all_permissions
    
    def list_roles(self) -> List[Dict]:
        """Listar todos los roles"""
        return [
            {
                'name': role.name,
                'description': role.description,
                'permissions': [p.value for p in role.permissions],
                'is_system_role': role.is_system_role,
                'created_at': role.created_at,
                'updated_at': role.updated_at
            }
            for role in self.roles.values()
        ]
    
    def list_users(self) -> List[Dict]:
        """Listar todos los usuarios"""
        return [
            {
                'username': user.username,
                'email': user.email,
                'roles': user.roles,
                'is_active': user.is_active,
                'created_at': user.created_at,
                'last_login': user.last_login,
                'failed_login_attempts': user.failed_login_attempts,
                'locked_until': user.locked_until
            }
            for user in self.users.values()
        ]
    
    def get_access_logs(self, username: str = None, start_time: float = None, 
                      end_time: float = None, limit: int = 100) -> List[Dict]:
        """Obtener logs de acceso con filtros"""
        logs = []
        
        try:
            with open(self.access_log_file, 'r') as f:
                for line in f:
                    if not line.strip():
                        continue
                    
                    log_entry = json.loads(line)
                    
                    # Aplicar filtros
                    if username and log_entry['username'] != username:
                        continue
                    
                    if start_time and log_entry['timestamp'] < start_time:
                        continue
                    
                    if end_time and log_entry['timestamp'] > end_time:
                        continue
                    
                    logs.append(log_entry)
                    
                    if len(logs) >= limit:
                        break
        except FileNotFoundError:
            pass
        
        # Ordenar por timestamp descendente
        logs.sort(key=lambda x: x['timestamp'], reverse=True)
        
        return logs

def main():
    """Función principal para línea de comandos"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Sistema RBAC para Webmin/Virtualmin')
    parser.add_argument('command', choices=[
        'create-role', 'list-roles', 'delete-role',
        'create-user', 'list-users', 'delete-user',
        'check-permission', 'lock-user', 'unlock-user',
        'list-logs'
    ])
    parser.add_argument('--name', help='Nombre de rol o usuario')
    parser.add_argument('--description', help='Descripción del rol')
    parser.add_argument('--email', help='Email del usuario')
    parser.add_argument('--roles', help='Roles del usuario (separados por comas)')
    parser.add_argument('--permissions', help='Permisos del rol (separados por comas)')
    parser.add_argument('--username', help='Nombre de usuario para verificar permisos')
    parser.add_argument('--permission', help='Permiso a verificar')
    parser.add_argument('--resource', help='Recurso al que se accede')
    parser.add_argument('--ip', help='Dirección IP')
    parser.add_argument('--user-agent', help='User agent')
    parser.add_argument('--duration', type=int, default=24, help='Duración del bloqueo en horas')
    
    args = parser.parse_args()
    
    # Inicializar gestor RBAC
    rbac = RBACManager()
    
    try:
        if args.command == 'create-role':
            if not args.name or not args.description or not args.permissions:
                print("Error: se requieren --name, --description y --permissions")
                return 1
            
            permissions = [Permission(p.strip()) for p in args.permissions.split(',')]
            if rbac.create_role(args.name, args.description, permissions):
                print(f"Rol {args.name} creado exitosamente")
                return 0
            else:
                print(f"Error al crear rol {args.name}")
                return 1
        
        elif args.command == 'list-roles':
            roles = rbac.list_roles()
            print("Roles del sistema:")
            for role in roles:
                print(f"  {role['name']}: {role['description']}")
                print(f"    Permisos: {', '.join(role['permissions'])}")
            return 0
        
        elif args.command == 'create-user':
            if not args.name or not args.email or not args.roles:
                print("Error: se requieren --name, --email y --roles")
                return 1
            
            roles = [r.strip() for r in args.roles.split(',')]
            if rbac.create_user(args.name, args.email, roles):
                print(f"Usuario {args.name} creado exitosamente")
                return 0
            else:
                print(f"Error al crear usuario {args.name}")
                return 1
        
        elif args.command == 'list-users':
            users = rbac.list_users()
            print("Usuarios del sistema:")
            for user in users:
                print(f"  {user['username']} ({user['email']}): {', '.join(user['roles'])}")
                if user['locked_until']:
                    unlock_time = datetime.fromtimestamp(user['locked_until'])
                    print(f"    🔒 Bloqueado hasta: {unlock_time}")
            return 0
        
        elif args.command == 'check-permission':
            if not args.username or not args.permission:
                print("Error: se requieren --username y --permission")
                return 1
            
            permission = Permission(args.permission)
            has_permission, reason = rbac.check_permission(args.username, permission, args.resource)
            
            if has_permission:
                print(f"✅ Permiso concedido: {args.permission}")
                return 0
            else:
                print(f"❌ Permiso denegado: {reason}")
                return 1
        
        elif args.command == 'lock-user':
            if not args.name:
                print("Error: se requiere --name")
                return 1
            
            if rbac.lock_user(args.name, args.duration):
                print(f"Usuario {args.name} bloqueado por {args.duration} horas")
                return 0
            else:
                print(f"Error al bloquear usuario {args.name}")
                return 1
        
        elif args.command == 'unlock-user':
            if not args.name:
                print("Error: se requiere --name")
                return 1
            
            if rbac.unlock_user(args.name):
                print(f"Usuario {args.name} desbloqueado")
                return 0
            else:
                print(f"Error al desbloquear usuario {args.name}")
                return 1
        
        else:
            print(f"Comando {args.command} no implementado")
            return 1
    
    except Exception as e:
        print(f"Error: {e}")
        return 1

if __name__ == '__main__':
    sys.exit(main())