#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
🛡️ MÓDULO DE SANITIZACIÓN DE ENTRADA
====================================
Sistema completo de validación y sanitización de datos de entrada
Protección contra inyecciones SQL, XSS, CSRF y otros ataques
"""

import re
import html
import json
import hashlib
import logging
from typing import Any, Dict, List, Optional, Union
from dataclasses import dataclass
from enum import Enum
import ipaddress
import urllib.parse

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ValidationType(Enum):
    """Tipos de validación disponibles"""
    STRING = "string"
    INTEGER = "integer"
    FLOAT = "float"
    EMAIL = "email"
    URL = "url"
    IP_ADDRESS = "ip_address"
    DOMAIN = "domain"
    USERNAME = "username"
    PASSWORD = "password"
    FILENAME = "filename"
    PATH = "path"
    JSON = "json"
    XML = "xml"
    HTML = "html"
    SQL = "sql"
    COMMAND = "command"
    HEX = "hex"
    BASE64 = "base64"

class ThreatLevel(Enum):
    """Niveles de amenaza detectadas"""
    SAFE = "safe"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

@dataclass
class ValidationResult:
    """Resultado de la validación"""
    is_valid: bool
    sanitized_value: Any
    threat_level: ThreatLevel
    threats_detected: List[str]
    original_value: str
    validation_type: ValidationType
    error_message: str = ""

@dataclass
class SecurityConfig:
    """Configuración de seguridad"""
    max_string_length: int = 10000
    max_array_items: int = 1000
    max_nesting_depth: int = 10
    allow_html_tags: bool = False
    allowed_html_tags: List[str] = None
    strict_sql_detection: bool = True
    detect_xss: bool = True
    detect_sqli: bool = True
    detect_command_injection: bool = True
    detect_path_traversal: bool = True
    detect_file_inclusion: bool = True
    log_all_attempts: bool = True
    
    def __post_init__(self):
        if self.allowed_html_tags is None:
            self.allowed_html_tags = ['p', 'br', 'strong', 'em', 'u']

class InputSanitizer:
    """Clase principal de sanitización de entrada"""
    
    def __init__(self, config: SecurityConfig = None):
        self.config = config or SecurityConfig()
        
        # Patrones de detección de amenazas
        self.sql_injection_patterns = [
            r'(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|UNION|SCRIPT)\b)',
            r'(\b(OR|AND)\b\s+\d+\s*=\s*\d+)',
            r'(\'\s*(OR|AND)\s*\'.*\'\s*=\s*\')',
            r'(\;\s*(DROP|DELETE|UPDATE|INSERT)\b)',
            r'(/\*.*\*/)',
            r'(\bWAITFOR\s+DELAY\b)',
            r'(\bBENCHMARK\b)',
            r'(\bSLEEP\b)',
            r'(\bLOAD_FILE\b)',
            r'(\bOUTFILE\b)',
            r'(\bINTO\s+OUTFILE\b)',
            r'(\bLOAD\s+DATA\b)',
            r'(\bINFORMATION_SCHEMA\b)',
            r'(\bSYSOBJECTS\b)',
            r'(\bSYS\.DATABASES\b)',
            r'(\bMYSQL\.USER\b)',
            r'(\bPG_\w+\b)',
            r'(\bXP_\w+\b)',
            r'(\bSP_\w+\b)',
            r'(0x[0-9a-fA-F]+)',
            r'(CHAR\s*\(\s*\d+\s*\))',
            r'(CONCAT\s*\()',
            r'(SUBSTRING\s*\()',
            r'(ASCII\s*\()',
            r'(ORD\s*\()',
            r'(LENGTH\s*\()',
            r'(\|\|)',
            r'(&&)',
            r'(<<)',
            r'(>>)'
        ]
        
        self.xss_patterns = [
            r'(<script[^>]*>.*?</script>)',
            r'(javascript\s*:)',
            r'(on\w+\s*=)',
            r'(<iframe[^>]*>)',
            r'(<object[^>]*>)',
            r'(<embed[^>]*>)',
            r'(<link[^>]*>)',
            r'(<meta[^>]*>)',
            r'(<style[^>]*>.*?</style>)',
            r'(<img[^>]*on\w+\s*=)',
            r'(<body[^>]*on\w+\s*=)',
            r'(<div[^>]*on\w+\s*=)',
            r'(<span[^>]*on\w+\s*=)',
            r'(expression\s*\()',
            r'(@import)',
            r'(vbscript\s*:)',
            r'(data\s*:)',
            r'(\.innerHTML)',
            r'(\.outerHTML)',
            r'(\document\.cookie)',
            r'(\document\.location)',
            r'(\window\.location)',
            r'(\eval\s*\()',
            r'(setTimeout\s*\()',
            r'(setInterval\s*\()',
            r'(alert\s*\()',
            r'(confirm\s*\()',
            r'(prompt\s*\()',
            r'(<svg[^>]*>)',
            r'(<math[^>]*>)',
            r'(<canvas[^>]*>)'
        ]
        
        self.command_injection_patterns = [
            r'(\|\s*\|)',
            r'(&&\s*&&)',
            r'(;\s*;)',
            r'(\$\([^)]*\))',
            r'(`[^`]*`)',
            r'(\$\{[^}]*\})',
            r'(\$\([^)]*\))',
            r'(\$\{[^}]*\})',
            r'(\$\w+\s*=)',
            r'(\.\./\.\./)',
            r'(\.\.\\\.\\)',
            r'(/\.\./)',
            r'(\\\.\\\./)',
            r'(/etc/passwd)',
            r'(/proc/)',
            r'(/sys/)',
            r'(/dev/)',
            r'(\bnc\b)',
            r'(\bnetcat\b)',
            r'(\btelnet\b)',
            r'(\bssh\b)',
            r'(\bftp\b)',
            r'(\bwget\b)',
            r'(\bcurl\b)',
            r'(\bperl\b)',
            r'(\bpython\b)',
            r'(\bbash\b)',
            r'(\bsh\b)',
            r'(\bcmd\b)',
            r'(\bpowershell\b)',
            r'(\bcmd\.exe\b)',
            r'(\bpowershell\.exe\b)',
            r'(\bwscript\.exe\b)',
            r'(\bcscript\.exe\b)'
        ]
        
        self.path_traversal_patterns = [
            r'(\.\./)',
            r'(\.\.\\)',
            r'(/\.\./)',
            r'(\\\.\\\./)',
            r'(\.\.\\\.\.\\\.)',
            r'(\.\./\.\./\.\./)',
            r'(%2e%2e%2f)',
            r'(%2e%2e%5c)',
            r'(\.\.%2f)',
            r'(\.\.%5c)',
            r'(%c0%af)',
            r'(%c1%9c)',
            r'(%c1%pc)',
            r'(%5c)',
            r'(%2f)',
            r'(\.\.%c0%af)',
            r'(\.\.%c1%9c)'
        ]
        
        # Compilar patrones para mejor rendimiento
        self._compile_patterns()
    
    def _compile_patterns(self):
        """Compilar patrones regex para mejor rendimiento"""
        self.sql_patterns = [re.compile(pattern, re.IGNORECASE) for pattern in self.sql_injection_patterns]
        self.xss_patterns = [re.compile(pattern, re.IGNORECASE) for pattern in self.xss_patterns]
        self.cmd_patterns = [re.compile(pattern, re.IGNORECASE) for pattern in self.command_injection_patterns]
        self.path_patterns = [re.compile(pattern, re.IGNORECASE) for pattern in self.path_traversal_patterns]
    
    def _detect_threats(self, value: str) -> List[str]:
        """Detectar amenazas en el valor de entrada"""
        threats = []
        
        if not isinstance(value, str):
            return threats
        
        # Detectar inyección SQL
        if self.config.detect_sqli:
            for pattern in self.sql_patterns:
                if pattern.search(value):
                    threats.append("SQL Injection")
                    break
        
        # Detectar XSS
        if self.config.detect_xss:
            for pattern in self.xss_patterns:
                if pattern.search(value):
                    threats.append("XSS")
                    break
        
        # Detectar inyección de comandos
        if self.config.detect_command_injection:
            for pattern in self.cmd_patterns:
                if pattern.search(value):
                    threats.append("Command Injection")
                    break
        
        # Detectar path traversal
        if self.config.detect_path_traversal:
            for pattern in self.path_patterns:
                if pattern.search(value):
                    threats.append("Path Traversal")
                    break
        
        # Detectar inclusion de archivos
        if self.config.detect_file_inclusion:
            if re.search(r'(php://|file://|ftp://|http://|https://|data://)', value, re.IGNORECASE):
                threats.append("File Inclusion")
        
        return threats
    
    def _calculate_threat_level(self, threats: List[str]) -> ThreatLevel:
        """Calcular nivel de amenaza basado en las amenazas detectadas"""
        if not threats:
            return ThreatLevel.SAFE
        
        # Amenazas críticas
        critical_threats = ["Command Injection", "File Inclusion"]
        if any(threat in critical_threats for threat in threats):
            return ThreatLevel.CRITICAL
        
        # Amenazas altas
        high_threats = ["SQL Injection", "XSS"]
        if any(threat in high_threats for threat in threats):
            return ThreatLevel.HIGH
        
        # Amenazas medias
        if len(threats) >= 2:
            return ThreatLevel.MEDIUM
        
        # Amenazas bajas
        return ThreatLevel.LOW
    
    def _sanitize_string(self, value: str) -> str:
        """Sanitizar string básico"""
        if not isinstance(value, str):
            return str(value)
        
        # Eliminar caracteres nulos y de control
        sanitized = re.sub(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '', value)
        
        # Limitar longitud
        if len(sanitized) > self.config.max_string_length:
            sanitized = sanitized[:self.config.max_string_length]
        
        return sanitized.strip()
    
    def _sanitize_html(self, value: str) -> str:
        """Sanitizar HTML"""
        if not isinstance(value, str):
            return str(value)
        
        # Si no se permite HTML, escapar todo
        if not self.config.allow_html_tags:
            return html.escape(value)
        
        # Permitir solo tags específicos
        # Esta es una implementación básica, en producción usaría una librería como bleach
        sanitized = html.escape(value)
        
        # Restaurar tags permitidos (implementación simplificada)
        for tag in self.config.allowed_html_tags:
            sanitized = sanitized.replace(f'<{tag}>', f'<{tag}>')
            sanitized = sanitized.replace(f'</{tag}>', f'</{tag}>')
        
        return sanitized
    
    def _validate_email(self, value: str) -> bool:
        """Validar formato de email"""
        if not isinstance(value, str):
            return False
        
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return bool(re.match(email_pattern, value))
    
    def _validate_url(self, value: str) -> bool:
        """Validar formato de URL"""
        if not isinstance(value, str):
            return False
        
        try:
            result = urllib.parse.urlparse(value)
            return all([result.scheme, result.netloc])
        except Exception:
            return False
    
    def _validate_ip_address(self, value: str) -> bool:
        """Validar dirección IP"""
        if not isinstance(value, str):
            return False
        
        try:
            ipaddress.ip_address(value)
            return True
        except ValueError:
            return False
    
    def _validate_domain(self, value: str) -> bool:
        """Validar nombre de dominio"""
        if not isinstance(value, str):
            return False
        
        # Patrón básico de dominio
        domain_pattern = r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'
        return bool(re.match(domain_pattern, value))
    
    def _validate_username(self, value: str) -> bool:
        """Validar nombre de usuario"""
        if not isinstance(value, str):
            return False
        
        # Permitir alfanuméricos, guiones bajos y puntos
        username_pattern = r'^[a-zA-Z0-9._-]{3,50}$'
        return bool(re.match(username_pattern, value))
    
    def _validate_filename(self, value: str) -> bool:
        """Validar nombre de archivo"""
        if not isinstance(value, str):
            return False
        
        # No permitir caracteres peligrosos
        dangerous_chars = r'[<>:"/\\|?*\x00-\x1f]'
        if re.search(dangerous_chars, value):
            return False
        
        # No permitir nombres reservados
        reserved_names = ['CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9']
        if value.upper() in reserved_names:
            return False
        
        return True
    
    def _validate_path(self, value: str) -> bool:
        """Validar ruta de archivo"""
        if not isinstance(value, str):
            return False
        
        # Detectar path traversal
        for pattern in self.path_patterns:
            if pattern.search(value):
                return False
        
        return True
    
    def _validate_integer(self, value: str) -> bool:
        """Validar entero"""
        if not isinstance(value, str):
            return False
        
        try:
            int(value)
            return True
        except ValueError:
            return False
    
    def _validate_float(self, value: str) -> bool:
        """Validar flotante"""
        if not isinstance(value, str):
            return False
        
        try:
            float(value)
            return True
        except ValueError:
            return False
    
    def _validate_hex(self, value: str) -> bool:
        """Validar hexadecimal"""
        if not isinstance(value, str):
            return False
        
        hex_pattern = r'^[0-9a-fA-F]+$'
        return bool(re.match(hex_pattern, value))
    
    def _validate_base64(self, value: str) -> bool:
        """Validar Base64"""
        if not isinstance(value, str):
            return False
        
        try:
            import base64
            base64.b64decode(value, validate=True)
            return True
        except Exception:
            return False
    
    def _validate_json(self, value: str) -> bool:
        """Validar JSON"""
        if not isinstance(value, str):
            return False
        
        try:
            json.loads(value)
            return True
        except json.JSONDecodeError:
            return False
    
    def _validate_xml(self, value: str) -> bool:
        """Validar XML básico"""
        if not isinstance(value, str):
            return False
        
        try:
            import xml.etree.ElementTree as ET
            ET.fromstring(value)
            return True
        except Exception:
            return False
    
    def sanitize(self, value: Any, validation_type: ValidationType) -> ValidationResult:
        """Sanitizar y validar entrada"""
        original_value = str(value) if value is not None else ""
        
        # Detectar amenazas
        threats = self._detect_threats(original_value)
        threat_level = self._calculate_threat_level(threats)
        
        # Sanitizar según tipo
        try:
            if validation_type == ValidationType.STRING:
                sanitized = self._sanitize_string(original_value)
                is_valid = True
                
            elif validation_type == ValidationType.HTML:
                sanitized = self._sanitize_html(original_value)
                is_valid = True
                
            elif validation_type == ValidationType.EMAIL:
                sanitized = original_value.strip().lower()
                is_valid = self._validate_email(sanitized)
                
            elif validation_type == ValidationType.URL:
                sanitized = original_value.strip()
                is_valid = self._validate_url(sanitized)
                
            elif validation_type == ValidationType.IP_ADDRESS:
                sanitized = original_value.strip()
                is_valid = self._validate_ip_address(sanitized)
                
            elif validation_type == ValidationType.DOMAIN:
                sanitized = original_value.strip().lower()
                is_valid = self._validate_domain(sanitized)
                
            elif validation_type == ValidationType.USERNAME:
                sanitized = original_value.strip()
                is_valid = self._validate_username(sanitized)
                
            elif validation_type == ValidationType.PASSWORD:
                # Las contraseñas se sanitizan pero no se validan fuertemente aquí
                sanitized = self._sanitize_string(original_value)
                is_valid = len(sanitized) >= 8  # Validación básica
                
            elif validation_type == ValidationType.FILENAME:
                sanitized = original_value.strip()
                is_valid = self._validate_filename(sanitized)
                
            elif validation_type == ValidationType.PATH:
                sanitized = original_value.strip()
                is_valid = self._validate_path(sanitized)
                
            elif validation_type == ValidationType.INTEGER:
                sanitized = original_value.strip()
                is_valid = self._validate_integer(sanitized)
                
            elif validation_type == ValidationType.FLOAT:
                sanitized = original_value.strip()
                is_valid = self._validate_float(sanitized)
                
            elif validation_type == ValidationType.HEX:
                sanitized = original_value.strip()
                is_valid = self._validate_hex(sanitized)
                
            elif validation_type == ValidationType.BASE64:
                sanitized = original_value.strip()
                is_valid = self._validate_base64(sanitized)
                
            elif validation_type == ValidationType.JSON:
                sanitized = original_value.strip()
                is_valid = self._validate_json(sanitized)
                
            elif validation_type == ValidationType.XML:
                sanitized = original_value.strip()
                is_valid = self._validate_xml(sanitized)
                
            elif validation_type == ValidationType.SQL:
                # SQL se sanitiza pero siempre se marca como sospechoso
                sanitized = self._sanitize_string(original_value)
                is_valid = len(threats) == 0 or "SQL Injection" in threats
                
            elif validation_type == ValidationType.COMMAND:
                # Comandos se sanitizan pero siempre se marcan como sospechosos
                sanitized = self._sanitize_string(original_value)
                is_valid = len(threats) == 0 or "Command Injection" in threats
                
            else:
                sanitized = self._sanitize_string(original_value)
                is_valid = True
            
            # Crear resultado
            result = ValidationResult(
                is_valid=is_valid,
                sanitized_value=sanitized,
                threat_level=threat_level,
                threats_detected=threats,
                original_value=original_value,
                validation_type=validation_type
            )
            
            # Log del resultado
            if self.config.log_all_attempts or threat_level != ThreatLevel.SAFE:
                self._log_validation_result(result)
            
            return result
            
        except Exception as e:
            logger.error(f"Error en sanitización: {e}")
            return ValidationResult(
                is_valid=False,
                sanitized_value="",
                threat_level=ThreatLevel.HIGH,
                threats_detected=["Sanitization Error"],
                original_value=original_value,
                validation_type=validation_type,
                error_message=str(e)
            )
    
    def _log_validation_result(self, result: ValidationResult):
        """Registrar resultado de validación"""
        log_data = {
            'timestamp': logger.handlers[0].formatter.formatTime(logger.makeRecord(
                '', 0, '', '', '', '', ''
            )),
            'validation_type': result.validation_type.value,
            'original_length': len(result.original_value),
            'sanitized_length': len(str(result.sanitized_value)),
            'is_valid': result.is_valid,
            'threat_level': result.threat_level.value,
            'threats_detected': result.threats_detected,
            'error_message': result.error_message
        }
        
        if result.threat_level == ThreatLevel.CRITICAL:
            logger.critical(f"AMENAZA CRÍTICA DETECTADA: {log_data}")
        elif result.threat_level == ThreatLevel.HIGH:
            logger.error(f"AMENAZA ALTA DETECTADA: {log_data}")
        elif result.threat_level == ThreatLevel.MEDIUM:
            logger.warning(f"AMENAZA MEDIA DETECTADA: {log_data}")
        elif result.threat_level == ThreatLevel.LOW:
            logger.info(f"Amenaza baja detectada: {log_data}")
        else:
            logger.debug(f"Validación segura: {log_data}")
    
    def sanitize_dict(self, data: Dict[str, Any], schema: Dict[str, ValidationType]) -> Dict[str, ValidationResult]:
        """Sanitizar diccionario completo con esquema"""
        results = {}
        
        for key, validation_type in schema.items():
            value = data.get(key, "")
            results[key] = self.sanitize(value, validation_type)
        
        return results
    
    def sanitize_list(self, data: List[Any], validation_type: ValidationType) -> List[ValidationResult]:
        """Sanitizar lista completa"""
        if len(data) > self.config.max_array_items:
            data = data[:self.config.max_array_items]
        
        results = []
        for item in data:
            results.append(self.sanitize(item, validation_type))
        
        return results
    
    def sanitize_nested(self, data: Any, max_depth: int = None) -> Any:
        """Sanitizar datos anidados recursivamente"""
        if max_depth is None:
            max_depth = self.config.max_nesting_depth
        
        if max_depth <= 0:
            return data
        
        if isinstance(data, dict):
            sanitized_dict = {}
            for key, value in data.items():
                sanitized_key = self.sanitize(key, ValidationType.STRING).sanitized_value
                sanitized_dict[sanitized_key] = self.sanitize_nested(value, max_depth - 1)
            return sanitized_dict
        
        elif isinstance(data, list):
            if len(data) > self.config.max_array_items:
                data = data[:self.config.max_array_items]
            
            return [self.sanitize_nested(item, max_depth - 1) for item in data]
        
        else:
            # Para valores simples, sanitizar como string
            result = self.sanitize(data, ValidationType.STRING)
            return result.sanitized_value if result.is_valid else ""
    
    def generate_security_report(self, validation_results: List[ValidationResult]) -> Dict:
        """Generar reporte de seguridad"""
        total_validations = len(validation_results)
        safe_count = sum(1 for r in validation_results if r.threat_level == ThreatLevel.SAFE)
        low_threats = sum(1 for r in validation_results if r.threat_level == ThreatLevel.LOW)
        medium_threats = sum(1 for r in validation_results if r.threat_level == ThreatLevel.MEDIUM)
        high_threats = sum(1 for r in validation_results if r.threat_level == ThreatLevel.HIGH)
        critical_threats = sum(1 for r in validation_results if r.threat_level == ThreatLevel.CRITICAL)
        
        all_threats = []
        for result in validation_results:
            all_threats.extend(result.threats_detected)
        
        unique_threats = list(set(all_threats))
        threat_counts = {threat: all_threats.count(threat) for threat in unique_threats}
        
        return {
            'summary': {
                'total_validations': total_validations,
                'safe_count': safe_count,
                'low_threats': low_threats,
                'medium_threats': medium_threats,
                'high_threats': high_threats,
                'critical_threats': critical_threats,
                'security_score': max(0, 100 - (low_threats * 5 + medium_threats * 15 + high_threats * 30 + critical_threats * 50))
            },
            'threats_detected': threat_counts,
            'detailed_results': [
                {
                    'original_value': r.original_value[:100] + '...' if len(r.original_value) > 100 else r.original_value,
                    'sanitized_value': str(r.sanitized_value)[:100] + '...' if len(str(r.sanitized_value)) > 100 else str(r.sanitized_value),
                    'validation_type': r.validation_type.value,
                    'threat_level': r.threat_level.value,
                    'threats': r.threats_detected,
                    'is_valid': r.is_valid
                }
                for r in validation_results
            ]
        }

# Función de conveniencia para uso global
_global_sanitizer = None

def get_sanitizer(config: SecurityConfig = None) -> InputSanitizer:
    """Obtener instancia global del sanitizador"""
    global _global_sanitizer
    if _global_sanitizer is None:
        _global_sanitizer = InputSanitizer(config)
    return _global_sanitizer

def sanitize_input(value: Any, validation_type: ValidationType) -> ValidationResult:
    """Función de conveniencia para sanitizar entrada individual"""
    return get_sanitizer().sanitize(value, validation_type)

def sanitize_form_data(data: Dict[str, Any], schema: Dict[str, ValidationType]) -> Dict[str, ValidationResult]:
    """Función de conveniencia para sanitizar datos de formulario"""
    return get_sanitizer().sanitize_dict(data, schema)

def main():
    """Función principal para línea de comandos"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Módulo de sanitización de entrada')
    parser.add_argument('value', help='Valor a sanitizar')
    parser.add_argument('--type', choices=[t.value for t in ValidationType], 
                       default=ValidationType.STRING.value, help='Tipo de validación')
    parser.add_argument('--config', help='Archivo de configuración JSON')
    parser.add_argument('--report', action='store_true', help='Generar reporte detallado')
    
    args = parser.parse_args()
    
    # Cargar configuración si se proporcionó
    config = SecurityConfig()
    if args.config:
        try:
            with open(args.config, 'r') as f:
                config_data = json.load(f)
                config = SecurityConfig(**config_data)
        except Exception as e:
            print(f"Error cargando configuración: {e}")
            return 1
    
    # Crear sanitizador
    sanitizer = InputSanitizer(config)
    
    # Sanitizar valor
    validation_type = ValidationType(args.type)
    result = sanitizer.sanitize(args.value, validation_type)
    
    # Mostrar resultado
    print(f"Valor original: {result.original_value}")
    print(f"Valor sanitizado: {result.sanitized_value}")
    print(f"Válido: {result.is_valid}")
    print(f"Nivel de amenaza: {result.threat_level.value}")
    print(f"Amenazas detectadas: {', '.join(result.threats_detected) if result.threats_detected else 'Ninguna'}")
    
    if result.error_message:
        print(f"Error: {result.error_message}")
    
    if args.report:
        report = sanitizer.generate_security_report([result])
        print("\nReporte de seguridad:")
        print(json.dumps(report, indent=2))
    
    return 0 if result.is_valid else 1

if __name__ == '__main__':
    import sys
    sys.exit(main())