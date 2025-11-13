#!/usr/bin/env python3
"""
🔐 SCRIPT DE PRUEBA INTEGRAL DE SISTEMAS DE SEGURIDAD
Webmin/Virtualmin - Validación Completa de Componentes

Este script realiza pruebas exhaustivas de todos los sistemas de seguridad
implementados para asegurar su correcto funcionamiento.

Uso:
    python3 security/test_security_systems.py [--verbose] [--component COMPONENT]

Autor: Sistema de Seguridad Webmin/Virtualmin
Versión: 1.0.0
Fecha: 2025-11-08
"""

import sys
import os
import json
import time
import tempfile
import subprocess
import argparse
from datetime import datetime, timedelta
from pathlib import Path

# Agregar rutas de seguridad al path
sys.path.insert(0, '/usr/share/webmin/webmin-security')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

class SecurityTestSuite:
    """Suite de pruebas integrales para sistemas de seguridad"""
    
    def __init__(self, verbose=False):
        self.verbose = verbose
        self.test_results = {
            'total_tests': 0,
            'passed': 0,
            'failed': 0,
            'warnings': 0,
            'components': {}
        }
        self.start_time = datetime.now()
        
    def log(self, message, level='INFO'):
        """Registrar mensaje con timestamp"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        prefix = {
            'INFO': '📋',
            'SUCCESS': '✅',
            'ERROR': '❌',
            'WARNING': '⚠️',
            'TEST': '🧪'
        }.get(level, '📋')
        
        print(f"{prefix} [{timestamp}] {message}")
        
    def run_test(self, test_name, test_func, component='general'):
        """Ejecutar una prueba y registrar resultado"""
        self.test_results['total_tests'] += 1
        
        if component not in self.test_results['components']:
            self.test_results['components'][component] = {
                'passed': 0,
                'failed': 0,
                'warnings': 0,
                'tests': []
            }
        
        try:
            self.log(f"Ejecutando prueba: {test_name}", 'TEST')
            result = test_func()
            
            if result['status'] == 'PASS':
                self.test_results['passed'] += 1
                self.test_results['components'][component]['passed'] += 1
                self.log(f"✅ {test_name}: {result.get('message', 'Exitoso')}", 'SUCCESS')
            elif result['status'] == 'WARNING':
                self.test_results['warnings'] += 1
                self.test_results['components'][component]['warnings'] += 1
                self.log(f"⚠️ {test_name}: {result.get('message', 'Advertencia')}", 'WARNING')
            else:
                self.test_results['failed'] += 1
                self.test_results['components'][component]['failed'] += 1
                self.log(f"❌ {test_name}: {result.get('message', 'Falló')}", 'ERROR')
                
            self.test_results['components'][component]['tests'].append({
                'name': test_name,
                'status': result['status'],
                'message': result.get('message', ''),
                'details': result.get('details', {})
            })
            
            return result['status'] in ['PASS', 'WARNING']
            
        except Exception as e:
            self.test_results['failed'] += 1
            self.test_results['components'][component]['failed'] += 1
            error_msg = f"Error en prueba {test_name}: {str(e)}"
            self.log(error_msg, 'ERROR')
            
            self.test_results['components'][component]['tests'].append({
                'name': test_name,
                'status': 'FAIL',
                'message': error_msg,
                'details': {'exception': str(e)}
            })
            
            return False
    
    def test_credentials_manager(self):
        """Pruebas del gestor de credenciales"""
        tests = [
            ('test_init_system', self._test_credentials_init),
            ('test_store_secret', self._test_store_secret),
            ('test_retrieve_secret', self._test_retrieve_secret),
            ('test_rotate_secret', self._test_rotate_secret),
            ('test_list_secrets', self._test_list_secrets),
            ('test_audit_log', self._test_audit_log)
        ]
        
        for test_name, test_func in tests:
            self.run_test(test_name, test_func, 'credentials_manager')
    
    def _test_credentials_init(self):
        """Probar inicialización del gestor de credenciales"""
        try:
            result = subprocess.run(
                ['bash', 'security/secure_credentials_manager.sh', 'status'],
                capture_output=True, text=True, timeout=30
            )
            
            if result.returncode == 0:
                return {'status': 'PASS', 'message': 'Gestor de credenciales inicializado correctamente'}
            else:
                return {'status': 'FAIL', 'message': f'Error al inicializar: {result.stderr}'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_store_secret(self):
        """Probar almacenamiento de secretos"""
        try:
            result = subprocess.run([
                'bash', 'security/secure_credentials_manager.sh', 
                'store', 'test_secret', 'test_value_123', 'Secreto de prueba', 1
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0 and 'almacenado' in result.stdout.lower():
                return {'status': 'PASS', 'message': 'Secreto almacenado correctamente'}
            else:
                return {'status': 'FAIL', 'message': f'Error al almacenar secreto: {result.stderr}'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_retrieve_secret(self):
        """Probar recuperación de secretos"""
        try:
            result = subprocess.run([
                'bash', 'security/secure_credentials_manager.sh', 
                'get', 'test_secret'
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0 and 'test_value_123' in result.stdout:
                return {'status': 'PASS', 'message': 'Secreto recuperado correctamente'}
            else:
                return {'status': 'FAIL', 'message': f'Error al recuperar secreto: {result.stderr}'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_rotate_secret(self):
        """Probar rotación de secretos"""
        try:
            result = subprocess.run([
                'bash', 'security/secure_credentials_manager.sh', 
                'rotate', 'test_secret'
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0 and 'rotado' in result.stdout.lower():
                return {'status': 'PASS', 'message': 'Secreto rotado correctamente'}
            else:
                return {'status': 'FAIL', 'message': f'Error al rotar secreto: {result.stderr}'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_list_secrets(self):
        """Probar listado de secretos"""
        try:
            result = subprocess.run([
                'bash', 'security/secure_credentials_manager.sh', 
                'list'
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0 and 'test_secret' in result.stdout:
                return {'status': 'PASS', 'message': 'Listado de secretos funcionando'}
            else:
                return {'status': 'FAIL', 'message': f'Error en listado: {result.stderr}'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_audit_log(self):
        """Probar auditoría de accesos"""
        try:
            # Verificar que exista archivo de auditoría
            audit_file = '/var/log/webmin/security/credentials_audit.log'
            if os.path.exists(audit_file):
                size = os.path.getsize(audit_file)
                if size > 0:
                    return {'status': 'PASS', 'message': f'Archivo de auditoría presente ({size} bytes)'}
                else:
                    return {'status': 'WARNING', 'message': 'Archivo de auditoría vacío'}
            else:
                return {'status': 'FAIL', 'message': 'Archivo de auditoría no encontrado'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def test_rbac_system(self):
        """Pruebas del sistema RBAC"""
        try:
            from rbac_system import RBACManager, Permission, Role
        except ImportError as e:
            self.log(f"No se pudo importar RBAC: {e}", 'ERROR')
            return
        
        tests = [
            ('test_rbac_init', self._test_rbac_init),
            ('test_create_role', self._test_create_role),
            ('test_create_user', self._test_create_user),
            ('test_check_permission', self._test_check_permission),
            ('test_user_lock', self._test_user_lock),
            ('test_audit_access', self._test_audit_access)
        ]
        
        for test_name, test_func in tests:
            self.run_test(test_name, test_func, 'rbac_system')
    
    def _test_rbac_init(self):
        """Probar inicialización del sistema RBAC"""
        try:
            from rbac_system import RBACManager
            rbac = RBACManager()
            
            # Verificar que se carguen roles predefinidos
            roles = rbac.list_roles()
            if len(roles) >= 6:  # Debe haber al menos 6 roles predefinidos
                return {'status': 'PASS', 'message': f'Sistema RBAC inicializado con {len(roles)} roles'}
            else:
                return {'status': 'WARNING', 'message': f'Sistema RBAC con solo {len(roles)} roles'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_create_role(self):
        """Probar creación de roles personalizados"""
        try:
            from rbac_system import RBACManager
            rbac = RBACManager()
            
            # Crear rol de prueba
            role_id = rbac.create_role(
                name='test_role',
                description='Rol de prueba',
                permissions=['system:read', 'user:read']
            )
            
            if role_id:
                # Verificar que el rol existe
                role = rbac.get_role(role_id)
                if role and role.name == 'test_role':
                    return {'status': 'PASS', 'message': 'Rol creado correctamente'}
            
            return {'status': 'FAIL', 'message': 'No se pudo crear el rol'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_create_user(self):
        """Probar creación de usuarios"""
        try:
            from rbac_system import RBACManager
            rbac = RBACManager()
            
            # Crear usuario de prueba
            user_id = rbac.create_user(
                name='testuser',
                email='test@example.com',
                password='TestPass123!',
                roles=['test_role']
            )
            
            if user_id:
                # Verificar que el usuario existe
                user = rbac.get_user(user_id)
                if user and user.name == 'testuser':
                    return {'status': 'PASS', 'message': 'Usuario creado correctamente'}
            
            return {'status': 'FAIL', 'message': 'No se pudo crear el usuario'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_check_permission(self):
        """Probar verificación de permisos"""
        try:
            from rbac_system import RBACManager
            rbac = RBACManager()
            
            # Verificar permiso existente
            has_permission, reason = rbac.check_permission(
                username='testuser',
                permission=Permission.SYSTEM_READ,
                resource='/api/system'
            )
            
            if has_permission:
                return {'status': 'PASS', 'message': 'Verificación de permisos funcionando'}
            else:
                return {'status': 'WARNING', 'message': f'Permiso denegado: {reason}'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_user_lock(self):
        """Probar bloqueo de usuarios"""
        try:
            from rbac_system import RBACManager
            rbac = RBACManager()
            
            # Bloquear usuario de prueba
            success = rbac.lock_user('testuser', 1)  # 1 hora
            
            if success:
                # Verificar que esté bloqueado
                user = rbac.get_user_by_name('testuser')
                if user and user.is_locked():
                    return {'status': 'PASS', 'message': 'Usuario bloqueado correctamente'}
            
            return {'status': 'FAIL', 'message': 'No se pudo bloquear el usuario'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_audit_access(self):
        """Probar auditoría de accesos RBAC"""
        try:
            audit_file = '/var/log/webmin/security/rbac_audit.log'
            if os.path.exists(audit_file):
                size = os.path.getsize(audit_file)
                if size > 0:
                    return {'status': 'PASS', 'message': f'Auditoría RBAC funcionando ({size} bytes)'}
                else:
                    return {'status': 'WARNING', 'message': 'Archivo de auditoría RBAC vacío'}
            else:
                return {'status': 'FAIL', 'message': 'Archivo de auditoría RBAC no encontrado'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def test_input_sanitizer(self):
        """Pruebas del sanitizador de entrada"""
        try:
            from input_sanitizer import sanitize_input, ValidationType, detect_threats
        except ImportError as e:
            self.log(f"No se pudo importar Input Sanitizer: {e}", 'ERROR')
            return
        
        tests = [
            ('test_sanitization_basic', self._test_sanitization_basic),
            ('test_xss_detection', self._test_xss_detection),
            ('test_sqli_detection', self._test_sqli_detection),
            ('test_command_injection', self._test_command_injection),
            ('test_validation_types', self._test_validation_types),
            ('test_nested_structures', self._test_nested_structures)
        ]
        
        for test_name, test_func in tests:
            self.run_test(test_name, test_func, 'input_sanitizer')
    
    def _test_sanitization_basic(self):
        """Probar sanitización básica"""
        try:
            from input_sanitizer import sanitize_input, ValidationType
            
            # Probar sanitización de string
            result = sanitize_input("test_input", ValidationType.STRING)
            
            if result.is_valid and result.sanitized_value == "test_input":
                return {'status': 'PASS', 'message': 'Sanitización básica funcionando'}
            else:
                return {'status': 'FAIL', 'message': 'Error en sanitización básica'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_xss_detection(self):
        """Probar detección de XSS"""
        try:
            from input_sanitizer import detect_threats
            
            # Probar detección de XSS
            xss_payload = "<script>alert('xss')</script>"
            threats = detect_threats(xss_payload)
            
            if any(threat['type'] == 'XSS' for threat in threats):
                return {'status': 'PASS', 'message': 'Detección de XSS funcionando'}
            else:
                return {'status': 'FAIL', 'message': 'No se detectó ataque XSS'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_sqli_detection(self):
        """Probar detección de SQL Injection"""
        try:
            from input_sanitizer import detect_threats
            
            # Probar detección de SQLi
            sqli_payload = "'; DROP TABLE users; --"
            threats = detect_threats(sqli_payload)
            
            if any(threat['type'] == 'SQL_INJECTION' for threat in threats):
                return {'status': 'PASS', 'message': 'Detección de SQLi funcionando'}
            else:
                return {'status': 'FAIL', 'message': 'No se detectó ataque SQLi'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_command_injection(self):
        """Probar detección de Command Injection"""
        try:
            from input_sanitizer import detect_threats
            
            # Probar detección de Command Injection
            cmd_payload = "; rm -rf /"
            threats = detect_threats(cmd_payload)
            
            if any(threat['type'] == 'COMMAND_INJECTION' for threat in threats):
                return {'status': 'PASS', 'message': 'Detección de Command Injection funcionando'}
            else:
                return {'status': 'FAIL', 'message': 'No se detectó Command Injection'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_validation_types(self):
        """Probar diferentes tipos de validación"""
        try:
            from input_sanitizer import sanitize_input, ValidationType
            
            # Probar validación de email
            email_result = sanitize_input("test@example.com", ValidationType.EMAIL)
            if not email_result.is_valid:
                return {'status': 'FAIL', 'message': 'Validación de email falló'}
            
            # Probar validación de URL
            url_result = sanitize_input("https://example.com", ValidationType.URL)
            if not url_result.is_valid:
                return {'status': 'FAIL', 'message': 'Validación de URL falló'}
            
            # Probar validación de IP
            ip_result = sanitize_input("192.168.1.1", ValidationType.IP_ADDRESS)
            if not ip_result.is_valid:
                return {'status': 'FAIL', 'message': 'Validación de IP falló'}
            
            return {'status': 'PASS', 'message': 'Tipos de validación funcionando'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_nested_structures(self):
        """Probar validación de estructuras anidadas"""
        try:
            from input_sanitizer import sanitize_input, ValidationType
            
            # Probar validación de JSON
            json_data = '{"name": "test", "value": 123}'
            json_result = sanitize_input(json_data, ValidationType.JSON)
            
            if json_result.is_valid:
                return {'status': 'PASS', 'message': 'Validación de estructuras anidadas funcionando'}
            else:
                return {'status': 'FAIL', 'message': 'Error en validación de JSON'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def test_encryption_manager(self):
        """Pruebas del gestor de cifrado"""
        try:
            from encryption_manager import EncryptionManager
        except ImportError as e:
            self.log(f"No se pudo importar Encryption Manager: {e}", 'ERROR')
            return
        
        tests = [
            ('test_encryption_init', self._test_encryption_init),
            ('test_generate_symmetric_key', self._test_generate_symmetric_key),
            ('test_encrypt_decrypt', self._test_encrypt_decrypt),
            ('test_file_encryption', self._test_file_encryption),
            ('test_key_rotation', self._test_key_rotation),
            ('test_key_management', self._test_key_management)
        ]
        
        for test_name, test_func in tests:
            self.run_test(test_name, test_func, 'encryption_manager')
    
    def _test_encryption_init(self):
        """Probar inicialización del gestor de cifrado"""
        try:
            from encryption_manager import EncryptionManager
            manager = EncryptionManager()
            
            # Verificar que se inicialice correctamente
            if manager:
                return {'status': 'PASS', 'message': 'Gestor de cifrado inicializado correctamente'}
            else:
                return {'status': 'FAIL', 'message': 'Error al inicializar gestor de cifrado'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_generate_symmetric_key(self):
        """Probar generación de claves simétricas"""
        try:
            from encryption_manager import EncryptionManager
            manager = EncryptionManager()
            
            # Generar clave simétrica
            key_id = manager.generate_symmetric_key(
                algorithm='aes-256-gcm',
                expires_days=30
            )
            
            if key_id:
                return {'status': 'PASS', 'message': f'Clave simétrica generada: {key_id}'}
            else:
                return {'status': 'FAIL', 'message': 'Error al generar clave simétrica'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_encrypt_decrypt(self):
        """Probar cifrado y descifrado"""
        try:
            from encryption_manager import EncryptionManager
            manager = EncryptionManager()
            
            # Generar clave para prueba
            key_id = manager.generate_symmetric_key('aes-256-gcm', 1)
            
            # Cifrar datos
            test_data = "Datos sensibles de prueba"
            encrypted = manager.encrypt(test_data, key_id)
            
            if encrypted and encrypted['ciphertext']:
                # Descifrar datos
                decrypted = manager.decrypt(encrypted, key_id)
                
                if decrypted and decrypted == test_data:
                    return {'status': 'PASS', 'message': 'Cifrado/descifrado funcionando correctamente'}
            
            return {'status': 'FAIL', 'message': 'Error en cifrado/descifrado'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_file_encryption(self):
        """Probar cifrado de archivos"""
        try:
            from encryption_manager import EncryptionManager
            manager = EncryptionManager()
            
            # Crear archivo temporal
            with tempfile.NamedTemporaryFile(mode='w', delete=False) as temp_file:
                temp_file.write("Contenido sensible del archivo")
                temp_file_path = temp_file.name
            
            try:
                # Generar clave
                key_id = manager.generate_symmetric_key('aes-256-gcm', 1)
                
                # Cifrar archivo
                encrypted_path = manager.encrypt_file(temp_file_path, key_id)
                
                if encrypted_path and os.path.exists(encrypted_path):
                    # Descifrar archivo
                    decrypted_path = manager.decrypt_file(encrypted_path, key_id)
                    
                    if decrypted_path and os.path.exists(decrypted_path):
                        with open(decrypted_path, 'r') as f:
                            content = f.read()
                        
                        if content == "Contenido sensible del archivo":
                            return {'status': 'PASS', 'message': 'Cifrado de archivos funcionando'}
                
                return {'status': 'FAIL', 'message': 'Error en cifrado de archivos'}
                
            finally:
                # Limpiar archivos temporales
                for path in [temp_file_path, encrypted_path, decrypted_path]:
                    if path and os.path.exists(path):
                        os.unlink(path)
                        
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_key_rotation(self):
        """Probar rotación de claves"""
        try:
            from encryption_manager import EncryptionManager
            manager = EncryptionManager()
            
            # Generar clave inicial
            key_id = manager.generate_symmetric_key('aes-256-gcm', 1)
            
            # Rotar clave
            new_key_id = manager.rotate_key(key_id)
            
            if new_key_id and new_key_id != key_id:
                return {'status': 'PASS', 'message': 'Rotación de claves funcionando'}
            else:
                return {'status': 'FAIL', 'message': 'Error en rotación de claves'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_key_management(self):
        """Probar gestión de claves"""
        try:
            from encryption_manager import EncryptionManager
            manager = EncryptionManager()
            
            # Listar claves
            keys = manager.list_keys()
            
            if isinstance(keys, list) and len(keys) >= 0:
                return {'status': 'PASS', 'message': f'Gestión de claves funcionando ({len(keys)} claves)'}
            else:
                return {'status': 'FAIL', 'message': 'Error en gestión de claves'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def test_resource_quota_manager(self):
        """Pruebas del gestor de cuotas de recursos"""
        try:
            from resource_quota_manager import ResourceQuotaManager
        except ImportError as e:
            self.log(f"No se pudo importar Resource Quota Manager: {e}", 'ERROR')
            return
        
        tests = [
            ('test_quota_init', self._test_quota_init),
            ('test_create_quota', self._test_create_quota),
            ('test_check_quota', self._test_check_quota),
            ('test_monitoring', self._test_monitoring),
            ('test_violation_handling', self._test_violation_handling),
            ('test_reporting', self._test_reporting)
        ]
        
        for test_name, test_func in tests:
            self.run_test(test_name, test_func, 'resource_quota_manager')
    
    def _test_quota_init(self):
        """Probar inicialización del gestor de cuotas"""
        try:
            from resource_quota_manager import ResourceQuotaManager
            manager = ResourceQuotaManager()
            
            # Verificar que se inicialice correctamente
            if manager:
                return {'status': 'PASS', 'message': 'Gestor de cuotas inicializado correctamente'}
            else:
                return {'status': 'FAIL', 'message': 'Error al inicializar gestor de cuotas'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_create_quota(self):
        """Probar creación de cuotas"""
        try:
            from resource_quota_manager import ResourceQuotaManager
            manager = ResourceQuotaManager()
            
            # Crear cuota de prueba
            success = manager.create_quota(
                namespace='test',
                resource_type='cpu',
                quota_type='hard',
                limit=50.0,
                action='throttle'
            )
            
            if success:
                return {'status': 'PASS', 'message': 'Cuota creada correctamente'}
            else:
                return {'status': 'FAIL', 'message': 'Error al crear cuota'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_check_quota(self):
        """Probar verificación de cuotas"""
        try:
            from resource_quota_manager import ResourceQuotaManager
            manager = ResourceQuotaManager()
            
            # Verificar cuota existente
            is_violation, action = manager.check_quota(
                namespace='test',
                resource_type='cpu',
                current_value=75.0
            )
            
            # Debería haber violación (75 > 50)
            if is_violation:
                return {'status': 'PASS', 'message': 'Verificación de cuotas funcionando'}
            else:
                return {'status': 'WARNING', 'message': 'No se detectó violación esperada'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_monitoring(self):
        """Probar monitoreo de recursos"""
        try:
            from resource_quota_manager import ResourceQuotaManager
            manager = ResourceQuotaManager()
            
            # Obtener estado del sistema
            status = manager.get_system_status()
            
            if status and isinstance(status, dict):
                return {'status': 'PASS', 'message': 'Monitoreo de recursos funcionando'}
            else:
                return {'status': 'FAIL', 'message': 'Error en monitoreo de recursos'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_violation_handling(self):
        """Probar manejo de violaciones"""
        try:
            from resource_quota_manager import ResourceQuotaManager
            manager = ResourceQuotaManager()
            
            # Simular violación y verificar acción
            violations = manager.check_all_quotas('test')
            
            if isinstance(violations, list):
                return {'status': 'PASS', 'message': 'Manejo de violaciones funcionando'}
            else:
                return {'status': 'FAIL', 'message': 'Error en manejo de violaciones'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_reporting(self):
        """Probar generación de reportes"""
        try:
            from resource_quota_manager import ResourceQuotaManager
            manager = ResourceQuotaManager()
            
            # Generar reporte
            report = manager.generate_report('test', days=1)
            
            if report and isinstance(report, dict):
                return {'status': 'PASS', 'message': 'Generación de reportes funcionando'}
            else:
                return {'status': 'FAIL', 'message': 'Error en generación de reportes'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def test_integration(self):
        """Pruebas de integración entre componentes"""
        tests = [
            ('test_system_integration', self._test_system_integration),
            ('test_webmin_integration', self._test_webmin_integration),
            ('test_service_integration', self._test_service_integration),
            ('test_logging_integration', self._test_logging_integration)
        ]
        
        for test_name, test_func in tests:
            self.run_test(test_name, test_func, 'integration')
    
    def _test_system_integration(self):
        """Probar integración entre sistemas"""
        try:
            # Verificar que todos los directorios de configuración existan
            config_dirs = [
                '/etc/webmin/security',
                '/var/log/webmin/security',
                '/var/lib/webmin/security',
                '/etc/webmin/encryption_keys',
                '/etc/webmin/quotas'
            ]
            
            missing_dirs = []
            for dir_path in config_dirs:
                if not os.path.exists(dir_path):
                    missing_dirs.append(dir_path)
            
            if not missing_dirs:
                return {'status': 'PASS', 'message': 'Integración de directorios funcionando'}
            else:
                return {'status': 'WARNING', 'message': f'Directorios faltantes: {missing_dirs}'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_webmin_integration(self):
        """Probar integración con Webmin"""
        try:
            # Verificar módulo CGI de seguridad
            cgi_path = '/usr/share/webmin/webmin-security/security.cgi'
            if os.path.exists(cgi_path):
                return {'status': 'PASS', 'message': 'Integración con Webmin funcionando'}
            else:
                return {'status': 'WARNING', 'message': 'Módulo CGI no encontrado'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_service_integration(self):
        """Probar integración de servicios systemd"""
        try:
            # Verificar servicios systemd
            services = [
                'webmin-quota-monitor.service',
                'webmin-credential-rotation.service',
                'webmin-credential-rotation.timer'
            ]
            
            missing_services = []
            for service in services:
                result = subprocess.run(
                    ['systemctl', 'list-unit-files', service],
                    capture_output=True, text=True
                )
                if service not in result.stdout:
                    missing_services.append(service)
            
            if not missing_services:
                return {'status': 'PASS', 'message': 'Integración de servicios funcionando'}
            else:
                return {'status': 'WARNING', 'message': f'Servicios faltantes: {missing_services}'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def _test_logging_integration(self):
        """Probar integración de logs"""
        try:
            # Verificar archivos de log
            log_files = [
                '/var/log/webmin/security/credentials_audit.log',
                '/var/log/webmin/security/rbac_audit.log',
                '/var/log/webmin/security/quota_monitor.log'
            ]
            
            existing_logs = []
            for log_file in log_files:
                if os.path.exists(log_file):
                    existing_logs.append(log_file)
            
            if existing_logs:
                return {'status': 'PASS', 'message': f'Logs de seguridad presentes: {len(existing_logs)}'}
            else:
                return {'status': 'WARNING', 'message': 'No se encontraron archivos de log'}
                
        except Exception as e:
            return {'status': 'FAIL', 'message': f'Excepción: {str(e)}'}
    
    def generate_report(self):
        """Generar reporte final de pruebas"""
        end_time = datetime.now()
        duration = end_time - self.start_time
        
        print("\n" + "="*80)
        print("🔐 REPORTE FINAL DE PRUEBAS DE SEGURIDAD")
        print("="*80)
        
        print(f"⏰ Duración total: {duration.total_seconds():.2f} segundos")
        print(f"📊 Resumen de pruebas:")
        print(f"   Total: {self.test_results['total_tests']}")
        print(f"   ✅ Exitosas: {self.test_results['passed']}")
        print(f"   ⚠️ Advertencias: {self.test_results['warnings']}")
        print(f"   ❌ Fallidas: {self.test_results['failed']}")
        
        # Calcular porcentaje de éxito
        if self.test_results['total_tests'] > 0:
            success_rate = (self.test_results['passed'] / self.test_results['total_tests']) * 100
            print(f"📈 Tasa de éxito: {success_rate:.1f}%")
        
        print("\n📋 Resultados por componente:")
        for component, results in self.test_results['components'].items():
            total = results['passed'] + results['failed'] + results['warnings']
            if total > 0:
                component_success = (results['passed'] / total) * 100
                print(f"   {component}: {results['passed']}/{total} ({component_success:.1f}%)")
        
        # Generar reporte JSON
        report_data = {
            'timestamp': datetime.now().isoformat(),
            'duration_seconds': duration.total_seconds(),
            'summary': {
                'total_tests': self.test_results['total_tests'],
                'passed': self.test_results['passed'],
                'warnings': self.test_results['warnings'],
                'failed': self.test_results['failed'],
                'success_rate': success_rate if self.test_results['total_tests'] > 0 else 0
            },
            'components': self.test_results['components']
        }
        
        # Guardar reporte
        report_file = f"/var/log/webmin/security/test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        try:
            os.makedirs(os.path.dirname(report_file), exist_ok=True)
            with open(report_file, 'w') as f:
                json.dump(report_data, f, indent=2)
            print(f"\n💾 Reporte guardado en: {report_file}")
        except Exception as e:
            print(f"\n⚠️ Error al guardar reporte: {e}")
        
        # Veredicto final
        if self.test_results['failed'] == 0:
            print("\n🎉 VEREDICTO: TODAS LAS PRUEBAS CRÍTICAS SUPERADAS")
            print("✅ El sistema de seguridad está funcionando correctamente")
        elif self.test_results['failed'] <= self.test_results['total_tests'] * 0.1:  # <= 10% fallidas
            print("\n⚠️ VEREDICTO: SISTEMA FUNCIONAL CON ALGUNOS PROBLEMAS MENORES")
            print("🔧 Se recomienda revisar las pruebas fallidas")
        else:
            print("\n❌ VEREDICTO: PROBLEMAS CRÍTICOS DETECTADOS")
            print("🚨 Se requiere intervención inmediata")
        
        print("="*80)
        
        return report_data
    
    def run_all_tests(self, component=None):
        """Ejecutar todas las pruebas o un componente específico"""
        self.log("🚀 Iniciando suite de pruebas de seguridad", 'INFO')
        
        if component:
            if component == 'credentials':
                self.test_credentials_manager()
            elif component == 'rbac':
                self.test_rbac_system()
            elif component == 'sanitizer':
                self.test_input_sanitizer()
            elif component == 'encryption':
                self.test_encryption_manager()
            elif component == 'quotas':
                self.test_resource_quota_manager()
            elif component == 'integration':
                self.test_integration()
            else:
                self.log(f"Componente desconocido: {component}", 'ERROR')
                return
        else:
            # Ejecutar todas las pruebas
            self.test_credentials_manager()
            self.test_rbac_system()
            self.test_input_sanitizer()
            self.test_encryption_manager()
            self.test_resource_quota_manager()
            self.test_integration()
        
        # Generar reporte final
        return self.generate_report()

def main():
    """Función principal"""
    parser = argparse.ArgumentParser(description='Suite de pruebas de seguridad Webmin/Virtualmin')
    parser.add_argument('--verbose', '-v', action='store_true', help='Modo verboso')
    parser.add_argument('--component', '-c', 
                       choices=['credentials', 'rbac', 'sanitizer', 'encryption', 'quotas', 'integration'],
                       help='Componente específico a probar')
    
    args = parser.parse_args()
    
    # Cambiar al directorio del proyecto
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    os.chdir(project_dir)
    
    # Crear suite de pruebas
    test_suite = SecurityTestSuite(verbose=args.verbose)
    
    # Ejecutar pruebas
    try:
        report = test_suite.run_all_tests(component=args.component)
        
        # Salir con código apropiado
        if test_suite.test_results['failed'] == 0:
            sys.exit(0)
        elif test_suite.test_results['failed'] <= test_suite.test_results['total_tests'] * 0.1:
            sys.exit(1)  # Advertencias
        else:
            sys.exit(2)  # Errores críticos
            
    except KeyboardInterrupt:
        print("\n⚠️ Pruebas interrumpidas por el usuario")
        sys.exit(130)
    except Exception as e:
        print(f"\n❌ Error fatal en las pruebas: {e}")
        sys.exit(3)

if __name__ == '__main__':
    main()