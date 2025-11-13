#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
🔐 SISTEMA DE CIFRADO DE DATOS
==================================
Cifrado AES-256-GCM para datos en reposo y tránsito
Gestión de claves automática con rotación segura
"""

import os
import json
import hashlib
import time
import logging
from typing import Dict, List, Optional, Tuple, Any, Union
from dataclasses import dataclass, asdict
from enum import Enum
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.backends import default_backend
from cryptography.fernet import Fernet
import base64
import secrets

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/webmin/encryption.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class EncryptionType(Enum):
    """Tipos de cifrado disponibles"""
    AES_256_GCM = "aes-256-gcm"
    AES_256_CBC = "aes-256-cbc"
    CHACHA20_POLY1305 = "chacha20-poly1305"
    RSA_4096 = "rsa-4096"
    HYBRID = "hybrid"

class KeyType(Enum):
    """Tipos de claves"""
    SYMMETRIC = "symmetric"
    ASYMMETRIC = "asymmetric"
    MASTER = "master"

@dataclass
class EncryptionKey:
    """Representación de una clave de cifrado"""
    key_id: str
    key_type: KeyType
    algorithm: str
    key_data: bytes
    salt: bytes
    iv: bytes = None
    created_at: float = None
    expires_at: float = None
    is_active: bool = True
    usage_count: int = 0
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = time.time()

@dataclass
class EncryptionResult:
    """Resultado de una operación de cifrado"""
    success: bool
    encrypted_data: bytes = None
    key_id: str = None
    nonce: bytes = None
    tag: bytes = None
    error_message: str = ""
    encryption_time: float = 0

@dataclass
class DecryptionResult:
    """Resultado de una operación de descifrado"""
    success: bool
    decrypted_data: bytes = None
    is_authenticated: bool = False
    error_message: str = ""
    decryption_time: float = 0

class EncryptionManager:
    """Gestor principal de cifrado"""
    
    def __init__(self, keys_dir: str = "/etc/webmin/encryption_keys"):
        self.keys_dir = keys_dir
        self.keys_file = os.path.join(keys_dir, "keys.json")
        self.master_key_file = os.path.join(keys_dir, "master.key")
        
        # Crear directorio de claves
        os.makedirs(keys_dir, mode=0o700, exist_ok=True)
        
        # Inicializar claves
        self.keys: Dict[str, EncryptionKey] = {}
        self.master_key: Optional[bytes] = None
        
        # Cargar claves existentes
        self._load_keys()
        
        # Inicializar clave maestra si no existe
        self._initialize_master_key()
    
    def _load_keys(self):
        """Cargar claves desde almacenamiento"""
        try:
            if os.path.exists(self.keys_file):
                with open(self.keys_file, 'r') as f:
                    keys_data = json.load(f)
                    
                    for key_id, key_info in keys_data.items():
                        # Decodificar datos de clave desde base64
                        key_data = base64.b64decode(key_info['key_data'])
                        salt = base64.b64decode(key_info['salt'])
                        
                        iv = None
                        if key_info.get('iv'):
                            iv = base64.b64decode(key_info['iv'])
                        
                        self.keys[key_id] = EncryptionKey(
                            key_id=key_id,
                            key_type=KeyType(key_info['key_type']),
                            algorithm=key_info['algorithm'],
                            key_data=key_data,
                            salt=salt,
                            iv=iv,
                            created_at=key_info.get('created_at'),
                            expires_at=key_info.get('expires_at'),
                            is_active=key_info.get('is_active', True),
                            usage_count=key_info.get('usage_count', 0)
                        )
                
                logger.info(f"Cargadas {len(self.keys)} claves de cifrado")
        except Exception as e:
            logger.error(f"Error cargando claves: {e}")
    
    def _save_keys(self):
        """Guardar claves a almacenamiento"""
        try:
            keys_data = {}
            
            for key_id, key in self.keys.items():
                # Codificar datos de clave a base64
                key_data_b64 = base64.b64encode(key.key_data).decode('utf-8')
                salt_b64 = base64.b64encode(key.salt).decode('utf-8')
                
                iv_b64 = None
                if key.iv:
                    iv_b64 = base64.b64encode(key.iv).decode('utf-8')
                
                keys_data[key_id] = {
                    'key_type': key.key_type.value,
                    'algorithm': key.algorithm,
                    'key_data': key_data_b64,
                    'salt': salt_b64,
                    'iv': iv_b64,
                    'created_at': key.created_at,
                    'expires_at': key.expires_at,
                    'is_active': key.is_active,
                    'usage_count': key.usage_count
                }
            
            with open(self.keys_file, 'w') as f:
                json.dump(keys_data, f, indent=2)
            
            os.chmod(self.keys_file, 0o600)
            logger.info("Claves guardadas exitosamente")
        except Exception as e:
            logger.error(f"Error guardando claves: {e}")
    
    def _initialize_master_key(self):
        """Inicializar clave maestra"""
        if os.path.exists(self.master_key_file):
            # Cargar clave maestra existente
            try:
                with open(self.master_key_file, 'rb') as f:
                    self.master_key = f.read()
                logger.info("Clave maestra cargada")
            except Exception as e:
                logger.error(f"Error cargando clave maestra: {e}")
                self._generate_master_key()
        else:
            self._generate_master_key()
    
    def _generate_master_key(self):
        """Generar nueva clave maestra"""
        logger.info("Generando nueva clave maestra")
        
        # Generar clave aleatoria de 256 bits
        self.master_key = secrets.token_bytes(32)
        
        # Guardar clave maestra
        with open(self.master_key_file, 'wb') as f:
            f.write(self.master_key)
        
        os.chmod(self.master_key_file, 0o600)
        logger.info("Clave maestra generada y guardada")
    
    def _derive_key(self, password: str, salt: bytes, key_length: int = 32) -> bytes:
        """Derivar clave usando PBKDF2"""
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=key_length,
            salt=salt,
            iterations=100000,
            backend=default_backend()
        )
        return kdf.derive(password.encode())
    
    def generate_symmetric_key(self, algorithm: EncryptionType = EncryptionType.AES_256_GCM, 
                           expires_days: int = 90) -> str:
        """Generar nueva clave simétrica"""
        key_id = f"sym_{int(time.time())}_{secrets.token_hex(8)}"
        
        # Generar salt
        salt = secrets.token_bytes(16)
        
        # Generar clave según algoritmo
        if algorithm == EncryptionType.AES_256_GCM:
            key_data = secrets.token_bytes(32)  # 256 bits
            iv = secrets.token_bytes(12)     # 96 bits para GCM
        elif algorithm == EncryptionType.AES_256_CBC:
            key_data = secrets.token_bytes(32)  # 256 bits
            iv = secrets.token_bytes(16)      # 128 bits para CBC
        elif algorithm == EncryptionType.CHACHA20_POLY1305:
            key_data = secrets.token_bytes(32)  # 256 bits
            iv = secrets.token_bytes(12)      # 96 bits para ChaCha20
        else:
            raise ValueError(f"Algoritmo no soportado: {algorithm}")
        
        # Crear objeto de clave
        encryption_key = EncryptionKey(
            key_id=key_id,
            key_type=KeyType.SYMMETRIC,
            algorithm=algorithm.value,
            key_data=key_data,
            salt=salt,
            iv=iv,
            expires_at=time.time() + (expires_days * 86400)
        )
        
        # Guardar clave
        self.keys[key_id] = encryption_key
        self._save_keys()
        
        logger.info(f"Clave simétrica generada: {key_id}")
        return key_id
    
    def generate_asymmetric_key_pair(self, algorithm: EncryptionType = EncryptionType.RSA_4096,
                                expires_days: int = 365) -> Tuple[str, str]:
        """Generar par de claves asimétricas"""
        public_key_id = f"pub_{int(time.time())}_{secrets.token_hex(8)}"
        private_key_id = f"priv_{int(time.time())}_{secrets.token_hex(8)}"
        
        # Generar salt
        salt = secrets.token_bytes(16)
        
        if algorithm == EncryptionType.RSA_4096:
            # Generar par de claves RSA
            private_key = rsa.generate_private_key(
                public_exponent=65537,
                key_size=4096,
                backend=default_backend()
            )
            
            # Serializar claves
            private_pem = private_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption()
            )
            
            public_key = private_key.public_key()
            public_pem = public_key.public_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PublicFormat.SubjectPublicKeyInfo
            )
        else:
            raise ValueError(f"Algoritmo no soportado: {algorithm}")
        
        # Crear objetos de clave
        expires_at = time.time() + (expires_days * 86400)
        
        private_encryption_key = EncryptionKey(
            key_id=private_key_id,
            key_type=KeyType.ASYMMETRIC,
            algorithm=algorithm.value,
            key_data=private_pem,
            salt=salt,
            expires_at=expires_at
        )
        
        public_encryption_key = EncryptionKey(
            key_id=public_key_id,
            key_type=KeyType.ASYMMETRIC,
            algorithm=algorithm.value,
            key_data=public_pem,
            salt=salt,
            expires_at=expires_at
        )
        
        # Guardar claves
        self.keys[private_key_id] = private_encryption_key
        self.keys[public_key_id] = public_encryption_key
        self._save_keys()
        
        logger.info(f"Par de claves asimétricas generado: {private_key_id}/{public_key_id}")
        return private_key_id, public_key_id
    
    def encrypt_data(self, data: Union[str, bytes], key_id: str = None, 
                  algorithm: EncryptionType = EncryptionType.AES_256_GCM) -> EncryptionResult:
        """Cifrar datos"""
        start_time = time.time()
        
        try:
            # Convertir datos a bytes si es string
            if isinstance(data, str):
                data = data.encode('utf-8')
            
            # Si no se proporciona key_id, generar una nueva clave
            if key_id is None:
                key_id = self.generate_symmetric_key(algorithm)
            
            # Obtener clave
            if key_id not in self.keys:
                return EncryptionResult(
                    success=False,
                    error_message=f"Clave no encontrada: {key_id}"
                )
            
            key = self.keys[key_id]
            
            # Verificar que la clave esté activa y no haya expirado
            if not key.is_active:
                return EncryptionResult(
                    success=False,
                    error_message=f"Clave inactiva: {key_id}"
                )
            
            if key.expires_at and key.expires_at < time.time():
                return EncryptionResult(
                    success=False,
                    error_message=f"Clave expirada: {key_id}"
                )
            
            # Cifrar según algoritmo
            if algorithm == EncryptionType.AES_256_GCM:
                result = self._encrypt_aes_gcm(data, key)
            elif algorithm == EncryptionType.AES_256_CBC:
                result = self._encrypt_aes_cbc(data, key)
            elif algorithm == EncryptionType.CHACHA20_POLY1305:
                result = self._encrypt_chacha20_poly1305(data, key)
            else:
                return EncryptionResult(
                    success=False,
                    error_message=f"Algoritmo no soportado: {algorithm}"
                )
            
            # Actualizar uso de clave
            key.usage_count += 1
            self._save_keys()
            
            result.encryption_time = time.time() - start_time
            result.key_id = key_id
            
            return result
            
        except Exception as e:
            logger.error(f"Error en cifrado: {e}")
            return EncryptionResult(
                success=False,
                error_message=str(e),
                encryption_time=time.time() - start_time
            )
    
    def _encrypt_aes_gcm(self, data: bytes, key: EncryptionKey) -> EncryptionResult:
        """Cifrar con AES-256-GCM"""
        cipher = Cipher(
            algorithms.AES(key.key_data),
            modes.GCM(key.iv),
            backend=default_backend()
        )
        
        encryptor = cipher.encryptor()
        
        # Cifrar datos
        ciphertext = encryptor.update(data) + encryptor.finalize()
        
        return EncryptionResult(
            success=True,
            encrypted_data=ciphertext,
            nonce=key.iv,
            tag=encryptor.tag
        )
    
    def _encrypt_aes_cbc(self, data: bytes, key: EncryptionKey) -> EncryptionResult:
        """Cifrar con AES-256-CBC"""
        # Añadir padding PKCS7
        padder = padding.PKCS7(128).padder()
        padded_data = padder.update(data) + padder.finalize()
        
        cipher = Cipher(
            algorithms.AES(key.key_data),
            modes.CBC(key.iv),
            backend=default_backend()
        )
        
        encryptor = cipher.encryptor()
        ciphertext = encryptor.update(padded_data) + encryptor.finalize()
        
        return EncryptionResult(
            success=True,
            encrypted_data=ciphertext,
            nonce=key.iv
        )
    
    def _encrypt_chacha20_poly1305(self, data: bytes, key: EncryptionKey) -> EncryptionResult:
        """Cifrar con ChaCha20-Poly1305"""
        from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
        
        aead = ChaCha20Poly1305(key.key_data, key.iv)
        ciphertext = aead.encrypt(data)
        
        return EncryptionResult(
            success=True,
            encrypted_data=ciphertext,
            nonce=key.iv
        )
    
    def decrypt_data(self, encrypted_data: bytes, key_id: str, nonce: bytes = None, 
                  tag: bytes = None) -> DecryptionResult:
        """Descifrar datos"""
        start_time = time.time()
        
        try:
            # Obtener clave
            if key_id not in self.keys:
                return DecryptionResult(
                    success=False,
                    error_message=f"Clave no encontrada: {key_id}"
                )
            
            key = self.keys[key_id]
            
            # Verificar que la clave esté activa
            if not key.is_active:
                return DecryptionResult(
                    success=False,
                    error_message=f"Clave inactiva: {key_id}"
                )
            
            # Descifrar según algoritmo
            if key.algorithm == EncryptionType.AES_256_GCM.value:
                result = self._decrypt_aes_gcm(encrypted_data, key, nonce, tag)
            elif key.algorithm == EncryptionType.AES_256_CBC.value:
                result = self._decrypt_aes_cbc(encrypted_data, key, nonce)
            elif key.algorithm == EncryptionType.CHACHA20_POLY1305.value:
                result = self._decrypt_chacha20_poly1305(encrypted_data, key, nonce)
            else:
                return DecryptionResult(
                    success=False,
                    error_message=f"Algoritmo no soportado: {key.algorithm}"
                )
            
            result.decryption_time = time.time() - start_time
            return result
            
        except Exception as e:
            logger.error(f"Error en descifrado: {e}")
            return DecryptionResult(
                success=False,
                error_message=str(e),
                decryption_time=time.time() - start_time
            )
    
    def _decrypt_aes_gcm(self, encrypted_data: bytes, key: EncryptionKey, nonce: bytes, tag: bytes) -> DecryptionResult:
        """Descifrar con AES-256-GCM"""
        cipher = Cipher(
            algorithms.AES(key.key_data),
            modes.GCM(nonce, tag),
            backend=default_backend()
        )
        
        decryptor = cipher.decryptor()
        plaintext = decryptor.update(encrypted_data) + decryptor.finalize()
        
        return DecryptionResult(
            success=True,
            decrypted_data=plaintext,
            is_authenticated=True
        )
    
    def _decrypt_aes_cbc(self, encrypted_data: bytes, key: EncryptionKey, nonce: bytes) -> DecryptionResult:
        """Descifrar con AES-256-CBC"""
        cipher = Cipher(
            algorithms.AES(key.key_data),
            modes.CBC(nonce),
            backend=default_backend()
        )
        
        decryptor = cipher.decryptor()
        padded_plaintext = decryptor.update(encrypted_data) + decryptor.finalize()
        
        # Remover padding PKCS7
        unpadder = padding.PKCS7(128).unpadder()
        plaintext = unpadder.update(padded_plaintext) + unpadder.finalize()
        
        return DecryptionResult(
            success=True,
            decrypted_data=plaintext,
            is_authenticated=False
        )
    
    def _decrypt_chacha20_poly1305(self, encrypted_data: bytes, key: EncryptionKey, nonce: bytes) -> DecryptionResult:
        """Descifrar con ChaCha20-Poly1305"""
        from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
        
        aead = ChaCha20Poly1305(key.key_data, nonce)
        plaintext = aead.decrypt(encrypted_data)
        
        return DecryptionResult(
            success=True,
            decrypted_data=plaintext,
            is_authenticated=True
        )
    
    def encrypt_file(self, file_path: str, output_path: str = None, key_id: str = None) -> bool:
        """Cifrar archivo completo"""
        try:
            if not os.path.exists(file_path):
                logger.error(f"Archivo no encontrado: {file_path}")
                return False
            
            # Leer archivo
            with open(file_path, 'rb') as f:
                file_data = f.read()
            
            # Cifrar datos
            result = self.encrypt_data(file_data, key_id)
            
            if not result.success:
                logger.error(f"Error cifrando archivo: {result.error_message}")
                return False
            
            # Determinar ruta de salida
            if output_path is None:
                output_path = f"{file_path}.enc"
            
            # Guardar archivo cifrado
            with open(output_path, 'wb') as f:
                # Guardar metadatos del cifrado
                metadata = {
                    'key_id': result.key_id,
                    'algorithm': 'aes-256-gcm',
                    'nonce': base64.b64encode(result.nonce).decode('utf-8'),
                    'tag': base64.b64encode(result.tag).decode('utf-8') if result.tag else None,
                    'original_filename': os.path.basename(file_path),
                    'encrypted_at': time.time()
                }
                
                # Escribir metadatos y datos cifrados
                f.write(json.dumps(metadata).encode('utf-8') + b'\n')
                f.write(result.encrypted_data)
            
            # Establecer permisos seguros
            os.chmod(output_path, 0o600)
            
            logger.info(f"Archivo cifrado: {file_path} -> {output_path}")
            return True
            
        except Exception as e:
            logger.error(f"Error cifrando archivo: {e}")
            return False
    
    def decrypt_file(self, encrypted_file_path: str, output_path: str = None) -> bool:
        """Descifrar archivo completo"""
        try:
            if not os.path.exists(encrypted_file_path):
                logger.error(f"Archivo cifrado no encontrado: {encrypted_file_path}")
                return False
            
            # Leer archivo cifrado
            with open(encrypted_file_path, 'rb') as f:
                content = f.read()
            
            # Separar metadatos y datos cifrados
            metadata_end = content.find(b'\n')
            if metadata_end == -1:
                logger.error("Formato de archivo cifrado inválido")
                return False
            
            metadata_bytes = content[:metadata_end]
            encrypted_data = content[metadata_end + 1:]
            
            # Parsear metadatos
            metadata = json.loads(metadata_bytes.decode('utf-8'))
            
            # Descifrar datos
            nonce = base64.b64decode(metadata['nonce']) if metadata['nonce'] else None
            tag = base64.b64decode(metadata['tag']) if metadata['tag'] else None
            
            result = self.decrypt_data(encrypted_data, metadata['key_id'], nonce, tag)
            
            if not result.success:
                logger.error(f"Error descifrando archivo: {result.error_message}")
                return False
            
            # Determinar ruta de salida
            if output_path is None:
                original_name = metadata.get('original_filename', 'decrypted_file')
                output_path = os.path.join(
                    os.path.dirname(encrypted_file_path),
                    original_name
                )
            
            # Guardar archivo descifrado
            with open(output_path, 'wb') as f:
                f.write(result.decrypted_data)
            
            logger.info(f"Archivo descifrado: {encrypted_file_path} -> {output_path}")
            return True
            
        except Exception as e:
            logger.error(f"Error descifrando archivo: {e}")
            return False
    
    def rotate_keys(self, force: bool = False) -> bool:
        """Rotar claves expiradas o forzar rotación"""
        try:
            current_time = time.time()
            rotated_keys = []
            
            for key_id, key in list(self.keys.items()):
                should_rotate = False
                
                # Rotar si está expirada
                if key.expires_at and key.expires_at < current_time:
                    should_rotate = True
                    logger.info(f"Rotando clave expirada: {key_id}")
                
                # Forzar rotación si se solicita
                if force and key.key_type == KeyType.SYMMETRIC:
                    should_rotate = True
                    logger.info(f"Forzando rotación de clave: {key_id}")
                
                if should_rotate:
                    # Desactivar clave antigua
                    key.is_active = False
                    
                    # Generar nueva clave
                    if key.key_type == KeyType.SYMMETRIC:
                        algorithm = EncryptionType(key.algorithm)
                        new_key_id = self.generate_symmetric_key(algorithm)
                        rotated_keys.append((key_id, new_key_id))
            
            # Guardar cambios
            self._save_keys()
            
            logger.info(f"Rotación completada. Claves rotadas: {len(rotated_keys)}")
            return True
            
        except Exception as e:
            logger.error(f"Error en rotación de claves: {e}")
            return False
    
    def list_keys(self, include_inactive: bool = False) -> List[Dict]:
        """Listar claves disponibles"""
        keys_list = []
        
        for key_id, key in self.keys.items():
            if not include_inactive and not key.is_active:
                continue
            
            key_info = {
                'key_id': key_id,
                'key_type': key.key_type.value,
                'algorithm': key.algorithm,
                'created_at': key.created_at,
                'expires_at': key.expires_at,
                'is_active': key.is_active,
                'usage_count': key.usage_count
            }
            
            # Calcular tiempo restante
            if key.expires_at:
                remaining_time = key.expires_at - time.time()
                if remaining_time > 0:
                    key_info['expires_in_days'] = int(remaining_time / 86400)
                else:
                    key_info['expired_days_ago'] = int(-remaining_time / 86400)
            
            keys_list.append(key_info)
        
        return keys_list
    
    def delete_key(self, key_id: str) -> bool:
        """Eliminar una clave"""
        try:
            if key_id not in self.keys:
                logger.error(f"Clave no encontrada: {key_id}")
                return False
            
            # No permitir eliminar clave maestra
            if self.keys[key_id].key_type == KeyType.MASTER:
                logger.error("No se puede eliminar la clave maestra")
                return False
            
            del self.keys[key_id]
            self._save_keys()
            
            logger.info(f"Clave eliminada: {key_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error eliminando clave: {e}")
            return False

def main():
    """Función principal para línea de comandos"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Sistema de cifrado de datos')
    parser.add_argument('command', choices=[
        'generate-symmetric', 'generate-asymmetric', 'encrypt', 'decrypt',
        'encrypt-file', 'decrypt-file', 'list-keys', 'rotate-keys', 'delete-key'
    ])
    parser.add_argument('--algorithm', choices=[t.value for t in EncryptionType], 
                       default=EncryptionType.AES_256_GCM.value, help='Algoritmo de cifrado')
    parser.add_argument('--key-id', help='ID de clave a usar')
    parser.add_argument('--data', help='Datos a cifrar/descifrar')
    parser.add_argument('--file', help='Archivo a procesar')
    parser.add_argument('--output', help='Archivo de salida')
    parser.add_argument('--expires-days', type=int, default=90, help='Días hasta expiración')
    parser.add_argument('--force', action='store_true', help='Forzar operación')
    
    args = parser.parse_args()
    
    # Inicializar gestor de cifrado
    manager = EncryptionManager()
    
    try:
        if args.command == 'generate-symmetric':
            algorithm = EncryptionType(args.algorithm)
            key_id = manager.generate_symmetric_key(algorithm, args.expires_days)
            print(f"Clave simétrica generada: {key_id}")
            return 0
        
        elif args.command == 'generate-asymmetric':
            algorithm = EncryptionType(args.algorithm)
            private_id, public_id = manager.generate_asymmetric_key_pair(algorithm, args.expires_days)
            print(f"Claves asimétricas generadas:")
            print(f"  Privada: {private_id}")
            print(f"  Pública: {public_id}")
            return 0
        
        elif args.command == 'encrypt':
            if not args.data:
                print("Error: se requiere --data")
                return 1
            
            algorithm = EncryptionType(args.algorithm)
            result = manager.encrypt_data(args.data, args.key_id, algorithm)
            
            if result.success:
                encrypted_b64 = base64.b64encode(result.encrypted_data).decode('utf-8')
                print(f"Datos cifrados exitosamente:")
                print(f"  Key ID: {result.key_id}")
                print(f"  Datos: {encrypted_b64}")
                if result.nonce:
                    nonce_b64 = base64.b64encode(result.nonce).decode('utf-8')
                    print(f"  Nonce: {nonce_b64}")
                if result.tag:
                    tag_b64 = base64.b64encode(result.tag).decode('utf-8')
                    print(f"  Tag: {tag_b64}")
                return 0
            else:
                print(f"Error cifrando datos: {result.error_message}")
                return 1
        
        elif args.command == 'decrypt':
            if not args.data or not args.key_id:
                print("Error: se requieren --data y --key-id")
                return 1
            
            encrypted_data = base64.b64decode(args.data)
            result = manager.decrypt_data(encrypted_data, args.key_id)
            
            if result.success:
                print(f"Datos descifrados exitosamente:")
                print(f"  Datos: {result.decrypted_data.decode('utf-8')}")
                print(f"  Autenticado: {result.is_authenticated}")
                return 0
            else:
                print(f"Error descifrando datos: {result.error_message}")
                return 1
        
        elif args.command == 'list-keys':
            keys = manager.list_keys()
            print("Claves disponibles:")
            for key in keys:
                print(f"  {key['key_id']}:")
                print(f"    Tipo: {key['key_type']}")
                print(f"    Algoritmo: {key['algorithm']}")
                print(f"    Activa: {key['is_active']}")
                print(f"    Usos: {key['usage_count']}")
                if 'expires_in_days' in key:
                    print(f"    Expira en: {key['expires_in_days']} días")
                elif 'expired_days_ago' in key:
                    print(f"    Expiró hace: {key['expired_days_ago']} días")
            return 0
        
        elif args.command == 'rotate-keys':
            if manager.rotate_keys(args.force):
                print("Rotación de claves completada")
                return 0
            else:
                print("Error en rotación de claves")
                return 1
        
        else:
            print(f"Comando {args.command} no implementado")
            return 1
    
    except Exception as e:
        print(f"Error: {e}")
        return 1

if __name__ == '__main__':
    import sys
    sys.exit(main())