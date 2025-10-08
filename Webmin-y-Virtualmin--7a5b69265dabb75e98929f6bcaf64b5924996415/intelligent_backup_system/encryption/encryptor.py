#!/usr/bin/env python3
"""
Módulo de Encriptación AES-256
Implementa encriptación y desencriptación AES-256 con PBKDF2
para el sistema de backup inteligente de Webmin/Virtualmin
"""

import os
import hashlib
import hmac
import secrets
from typing import Optional, Tuple, BinaryIO, Dict
from dataclasses import dataclass
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import padding
import base64
import logging
from pathlib import Path

@dataclass
class EncryptionResult:
    """Resultado de una operación de encriptación"""
    success: bool
    encrypted_size: int = 0
    key_salt: bytes = None
    hmac_digest: bytes = None
    error_message: str = ""
    data: bytes = None

@dataclass
class DecryptionResult:
    """Resultado de una operación de desencriptación"""
    success: bool
    decrypted_size: int = 0
    data: bytes = None
    error_message: str = ""

class AES256Encryptor:
    """
    Encriptador AES-256 con PBKDF2 para derivación de claves
    y HMAC-SHA256 para integridad
    """

    # Constantes de encriptación
    KEY_SIZE = 32  # 256 bits
    IV_SIZE = 16   # 128 bits para AES
    SALT_SIZE = 32 # 256 bits de salt
    PBKDF2_ITERATIONS = 100000  # Número de iteraciones PBKDF2
    HMAC_SIZE = 32  # 256 bits para HMAC

    def __init__(self, key_file: Optional[str] = None):
        """
        Inicializar el encriptador

        Args:
            key_file: Archivo donde almacenar/recuperar la clave maestra
        """
        self.key_file = key_file or os.path.join(os.getcwd(), 'backup_master.key')
        self.logger = logging.getLogger(__name__)

        # Cargar o generar clave maestra
        self.master_key = self._load_or_generate_master_key()

    def _load_or_generate_master_key(self) -> bytes:
        """
        Cargar clave maestra desde archivo o generar una nueva

        Returns:
            Clave maestra de 256 bits
        """
        key_path = Path(self.key_file)

        if key_path.exists():
            try:
                with open(key_path, 'rb') as f:
                    # Leer clave en formato base64
                    encoded_key = f.read().strip()
                    key = base64.b64decode(encoded_key)

                    if len(key) != self.KEY_SIZE:
                        raise ValueError(f"Clave inválida en {self.key_file}")

                    self.logger.info("Clave maestra cargada desde archivo")
                    return key

            except Exception as e:
                self.logger.warning(f"Error cargando clave maestra: {e}")

        # Generar nueva clave
        key = secrets.token_bytes(self.KEY_SIZE)

        # Guardar clave
        try:
            key_path.parent.mkdir(parents=True, exist_ok=True)
            with open(key_path, 'wb') as f:
                encoded_key = base64.b64encode(key)
                f.write(encoded_key)
                f.write(b'\n')

            # Establecer permisos restrictivos
            os.chmod(key_path, 0o600)

            self.logger.info("Nueva clave maestra generada y guardada")

        except Exception as e:
            self.logger.error(f"Error guardando clave maestra: {e}")

        return key

    def _derive_key(self, password: str, salt: bytes) -> bytes:
        """
        Derivar clave usando PBKDF2

        Args:
            password: Contraseña base
            salt: Salt aleatorio

        Returns:
            Clave derivada de 256 bits
        """
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=self.KEY_SIZE,
            salt=salt,
            iterations=self.PBKDF2_ITERATIONS,
            backend=default_backend()
        )

        return kdf.derive(password.encode('utf-8'))

    def _generate_hmac(self, key: bytes, data: bytes) -> bytes:
        """
        Generar HMAC-SHA256 para integridad

        Args:
            key: Clave HMAC
            data: Datos a hashear

        Returns:
            Digest HMAC
        """
        return hmac.new(key, data, hashlib.sha256).digest()

    def _verify_hmac(self, key: bytes, data: bytes, expected_digest: bytes) -> bool:
        """
        Verificar HMAC-SHA256

        Args:
            key: Clave HMAC
            data: Datos a verificar
            expected_digest: Digest esperado

        Returns:
            True si el HMAC es válido
        """
        calculated_digest = self._generate_hmac(key, data)
        return hmac.compare_digest(calculated_digest, expected_digest)

    def encrypt_data(self, data: bytes, password: Optional[str] = None) -> EncryptionResult:
        """
        Encriptar datos usando AES-256

        Args:
            data: Datos a encriptar
            password: Contraseña opcional (usa clave maestra si no se proporciona)

        Returns:
            Resultado de la encriptación
        """
        try:
            # Generar salt aleatorio
            salt = secrets.token_bytes(self.SALT_SIZE)

            # Usar contraseña o clave maestra
            if password:
                encryption_key = self._derive_key(password, salt)
            else:
                encryption_key = self.master_key

            # Generar IV aleatorio
            iv = secrets.token_bytes(self.IV_SIZE)

            # Crear cipher AES-256 CBC
            cipher = Cipher(
                algorithms.AES(encryption_key),
                modes.CBC(iv),
                backend=default_backend()
            )
            encryptor = cipher.encryptor()

            # Aplicar padding PKCS7
            padder = padding.PKCS7(algorithms.AES.block_size).padder()
            padded_data = padder.update(data) + padder.finalize()

            # Encriptar datos
            encrypted_data = encryptor.update(padded_data) + encryptor.finalize()

            # Generar HMAC de los datos encriptados
            hmac_key = secrets.token_bytes(self.KEY_SIZE)  # Clave HMAC independiente
            hmac_digest = self._generate_hmac(hmac_key, encrypted_data)

            # Combinar todo: salt + hmac_key + iv + hmac_digest + encrypted_data
            result_data = (
                salt +
                hmac_key +
                iv +
                hmac_digest +
                encrypted_data
            )

            return EncryptionResult(
                success=True,
                encrypted_size=len(result_data),
                key_salt=salt,
                hmac_digest=hmac_digest,
                data=result_data
            )

        except Exception as e:
            self.logger.error(f"Error en encriptación: {e}")
            return EncryptionResult(
                success=False,
                error_message=str(e)
            )

    def decrypt_data(self, encrypted_data: bytes, password: Optional[str] = None) -> DecryptionResult:
        """
        Desencriptar datos usando AES-256

        Args:
            encrypted_data: Datos encriptados
            password: Contraseña opcional

        Returns:
            Resultado de la desencriptación
        """
        try:
            if len(encrypted_data) < self.SALT_SIZE + self.KEY_SIZE + self.IV_SIZE + self.HMAC_SIZE:
                raise ValueError("Datos encriptados demasiado cortos")

            # Extraer componentes
            pos = 0
            salt = encrypted_data[pos:pos + self.SALT_SIZE]
            pos += self.SALT_SIZE

            hmac_key = encrypted_data[pos:pos + self.KEY_SIZE]
            pos += self.KEY_SIZE

            iv = encrypted_data[pos:pos + self.IV_SIZE]
            pos += self.IV_SIZE

            hmac_digest = encrypted_data[pos:pos + self.HMAC_SIZE]
            pos += self.HMAC_SIZE

            encrypted_payload = encrypted_data[pos:]

            # Verificar HMAC
            if not self._verify_hmac(hmac_key, encrypted_payload, hmac_digest):
                raise ValueError("Verificación HMAC fallida - datos corruptos")

            # Derivar clave de encriptación
            if password:
                decryption_key = self._derive_key(password, salt)
            else:
                decryption_key = self.master_key

            # Crear cipher para desencriptación
            cipher = Cipher(
                algorithms.AES(decryption_key),
                modes.CBC(iv),
                backend=default_backend()
            )
            decryptor = cipher.decryptor()

            # Desencriptar
            padded_data = decryptor.update(encrypted_payload) + decryptor.finalize()

            # Remover padding
            unpadder = padding.PKCS7(algorithms.AES.block_size).unpadder()
            data = unpadder.update(padded_data) + unpadder.finalize()

            return DecryptionResult(
                success=True,
                decrypted_size=len(data),
                data=data
            )

        except Exception as e:
            self.logger.error(f"Error en desencriptación: {e}")
            return DecryptionResult(
                success=False,
                error_message=str(e)
            )

    def encrypt_file(self, input_path: str, output_path: str,
                    password: Optional[str] = None) -> EncryptionResult:
        """
        Encriptar un archivo completo

        Args:
            input_path: Archivo a encriptar
            output_path: Archivo de salida encriptado
            password: Contraseña opcional

        Returns:
            Resultado de la encriptación
        """
        try:
            # Leer archivo de entrada
            with open(input_path, 'rb') as f:
                data = f.read()

            # Encriptar datos
            result = self.encrypt_data(data, password)

            if not result.success:
                return result

            # Escribir archivo encriptado
            with open(output_path, 'wb') as f:
                # Escribir header de identificación
                f.write(b'IBENC01')  # Intelligent Backup Encrypted v1

                # Escribir datos encriptados
                f.write(result.key_salt)
                f.write(result.hmac_digest)
                f.write(data)  # Los datos encriptados ya incluyen todo el metadata

            # Establecer permisos restrictivos
            os.chmod(output_path, 0o600)

            self.logger.info(f"Archivo encriptado: {input_path} -> {output_path}")
            return result

        except Exception as e:
            self.logger.error(f"Error encriptando archivo {input_path}: {e}")
            return EncryptionResult(
                success=False,
                error_message=str(e)
            )

    def decrypt_file(self, input_path: str, output_path: str,
                    password: Optional[str] = None) -> DecryptionResult:
        """
        Desencriptar un archivo completo

        Args:
            input_path: Archivo encriptado
            output_path: Archivo de salida desencriptado
            password: Contraseña opcional

        Returns:
            Resultado de la desencriptación
        """
        try:
            # Leer archivo encriptado
            with open(input_path, 'rb') as f:
                # Verificar header
                header = f.read(7)
                if header != b'IBENC01':
                    raise ValueError("Formato de archivo encriptado no reconocido")

                # Leer datos encriptados
                encrypted_data = f.read()

            # Desencriptar datos
            result = self.decrypt_data(encrypted_data, password)

            if not result.success:
                return result

            # Escribir archivo desencriptado
            with open(output_path, 'wb') as f:
                f.write(result.data)

            self.logger.info(f"Archivo desencriptado: {input_path} -> {output_path}")
            return result

        except Exception as e:
            self.logger.error(f"Error desencriptando archivo {input_path}: {e}")
            return DecryptionResult(
                success=False,
                error_message=str(e)
            )

    def change_password(self, old_password: str, new_password: str) -> bool:
        """
        Cambiar la contraseña de encriptación (re-encripta la clave maestra)

        Args:
            old_password: Contraseña actual
            new_password: Nueva contraseña

        Returns:
            True si se cambió correctamente
        """
        try:
            # Leer clave maestra actual
            with open(self.key_file, 'rb') as f:
                encoded_key = f.read().strip()
                current_key = base64.b64decode(encoded_key)

            # Encriptar con nueva contraseña
            result = self.encrypt_data(current_key, new_password)

            if not result.success:
                return False

            # Guardar nueva clave encriptada
            with open(self.key_file, 'wb') as f:
                f.write(base64.b64encode(result.key_salt))
                f.write(b'\n')
                f.write(base64.b64encode(result.hmac_digest))
                f.write(b'\n')
                f.write(base64.b64encode(current_key))  # La clave maestra en sí

            self.logger.info("Contraseña de encriptación cambiada")
            return True

        except Exception as e:
            self.logger.error(f"Error cambiando contraseña: {e}")
            return False

    def generate_backup_key(self, password: str, key_file: str) -> bool:
        """
        Generar una nueva clave de backup independiente

        Args:
            password: Contraseña para proteger la clave
            key_file: Archivo donde guardar la clave

        Returns:
            True si se generó correctamente
        """
        try:
            # Generar nueva clave
            new_key = secrets.token_bytes(self.KEY_SIZE)

            # Encriptar con contraseña
            result = self.encrypt_data(new_key, password)

            if not result.success:
                return False

            # Guardar clave encriptada
            key_path = Path(key_file)
            key_path.parent.mkdir(parents=True, exist_ok=True)

            with open(key_path, 'wb') as f:
                f.write(b'IBKEY01')  # Intelligent Backup Key v1
                f.write(result.key_salt)
                f.write(result.hmac_digest)
                f.write(new_key)  # Datos encriptados

            os.chmod(key_path, 0o600)

            self.logger.info(f"Nueva clave de backup generada: {key_file}")
            return True

        except Exception as e:
            self.logger.error(f"Error generando clave de backup: {e}")
            return False

    def validate_encrypted_file(self, file_path: str) -> bool:
        """
        Validar que un archivo está correctamente encriptado

        Args:
            file_path: Path al archivo encriptado

        Returns:
            True si el archivo es válido
        """
        try:
            with open(file_path, 'rb') as f:
                # Verificar header
                header = f.read(7)
                if header != b'IBENC01':
                    return False

                # Verificar que tiene datos suficientes
                data = f.read()
                min_size = self.SALT_SIZE + self.KEY_SIZE + self.IV_SIZE + self.HMAC_SIZE

                return len(data) >= min_size

        except Exception:
            return False

    def get_encryption_info(self) -> Dict:
        """
        Obtener información sobre la configuración de encriptación

        Returns:
            Diccionario con información de encriptación
        """
        return {
            'algorithm': 'AES-256-CBC',
            'key_derivation': 'PBKDF2-SHA256',
            'pbkdf2_iterations': self.PBKDF2_ITERATIONS,
            'hmac_algorithm': 'HMAC-SHA256',
            'master_key_file': self.key_file,
            'master_key_exists': Path(self.key_file).exists(),
            'key_size_bits': self.KEY_SIZE * 8,
            'salt_size_bytes': self.SALT_SIZE
        }