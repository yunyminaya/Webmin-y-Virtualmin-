#!/usr/bin/env python3
"""
Módulo de Gestión de Almacenamiento y Replicación
Implementa replicación automática a múltiples destinos (local, FTP, S3, SFTP)
para el sistema de backup inteligente de Webmin/Virtualmin
"""

import os
import shutil
try:
    import paramiko
except ImportError:
    paramiko = None
try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    boto3 = None
    ClientError = None
import ftplib
import logging
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import tempfile

@dataclass
class StorageDestination:
    """Configuración de un destino de almacenamiento"""
    name: str
    type: str  # 'local', 'ftp', 'sftp', 's3', 'azure', 'gcp'
    enabled: bool = True
    config: Dict = None

    def __post_init__(self):
        if self.config is None:
            self.config = {}

@dataclass
class ReplicationResult:
    """Resultado de una operación de replicación"""
    destination: str
    success: bool
    bytes_transferred: int = 0
    transfer_time: float = 0.0
    error_message: str = ""

class StorageManager:
    """
    Gestor de almacenamiento que maneja replicación a múltiples destinos
    """

    def __init__(self, config_file: Optional[str] = None):
        """
        Inicializar el gestor de almacenamiento

        Args:
            config_file: Archivo de configuración de destinos
        """
        self.config_file = config_file or os.path.join(os.getcwd(), 'storage_config.json')
        self.destinations: Dict[str, StorageDestination] = {}
        self.logger = logging.getLogger(__name__)

        self._load_config()

    def _load_config(self):
        """Cargar configuración de destinos desde archivo"""
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r') as f:
                    config_data = json.load(f)

                for dest_data in config_data.get('destinations', []):
                    dest = StorageDestination(**dest_data)
                    self.destinations[dest.name] = dest

                self.logger.info(f"Configuración cargada: {len(self.destinations)} destinos")

            except Exception as e:
                self.logger.error(f"Error cargando configuración: {e}")

    def _save_config(self):
        """Guardar configuración de destinos"""
        try:
            config_data = {
                'destinations': [dest.__dict__ for dest in self.destinations.values()]
            }

            with open(self.config_file, 'w') as f:
                json.dump(config_data, f, indent=2)

        except Exception as e:
            self.logger.error(f"Error guardando configuración: {e}")

    def add_destination(self, destination: StorageDestination):
        """
        Agregar un nuevo destino de almacenamiento

        Args:
            destination: Configuración del destino
        """
        self.destinations[destination.name] = destination
        self._save_config()
        self.logger.info(f"Destino agregado: {destination.name} ({destination.type})")

    def remove_destination(self, name: str):
        """
        Remover un destino de almacenamiento

        Args:
            name: Nombre del destino a remover
        """
        if name in self.destinations:
            del self.destinations[name]
            self._save_config()
            self.logger.info(f"Destino removido: {name}")

    def test_destination(self, name: str) -> bool:
        """
        Probar conectividad con un destino

        Args:
            name: Nombre del destino

        Returns:
            True si la conexión es exitosa
        """
        if name not in self.destinations:
            self.logger.error(f"Destino no encontrado: {name}")
            return False

        dest = self.destinations[name]

        try:
            if dest.type == 'local':
                return self._test_local_destination(dest)
            elif dest.type == 'ftp':
                return self._test_ftp_destination(dest)
            elif dest.type == 'sftp':
                return self._test_sftp_destination(dest)
            elif dest.type == 's3':
                return self._test_s3_destination(dest)
            else:
                self.logger.error(f"Tipo de destino no soportado: {dest.type}")
                return False

        except Exception as e:
            self.logger.error(f"Error probando destino {name}: {e}")
            return False

    def _test_local_destination(self, dest: StorageDestination) -> bool:
        """Probar destino local"""
        path = dest.config.get('path', '')
        if not path:
            return False

        Path(path).mkdir(parents=True, exist_ok=True)
        test_file = Path(path) / '.test_write'
        try:
            test_file.write_text('test')
            test_file.unlink()
            return True
        except Exception:
            return False

    def _test_ftp_destination(self, dest: StorageDestination) -> bool:
        """Probar destino FTP"""
        try:
            with ftplib.FTP(dest.config['host']) as ftp:
                ftp.login(dest.config.get('user', ''), dest.config.get('password', ''))
                ftp.pwd()  # Comando simple para verificar conexión
                return True
        except Exception:
            return False

    def _test_sftp_destination(self, dest: StorageDestination) -> bool:
        """Probar destino SFTP"""
        if paramiko is None:
            return False
        try:
            transport = paramiko.Transport((dest.config['host'], dest.config.get('port', 22)))
            transport.connect(
                username=dest.config.get('user', ''),
                password=dest.config.get('password', ''),
                pkey=dest.config.get('key_file')
            )
            transport.close()
            return True
        except Exception:
            return False

    def _test_s3_destination(self, dest: StorageDestination) -> bool:
        """Probar destino S3"""
        if boto3 is None:
            return False
        try:
            s3_client = boto3.client(
                's3',
                aws_access_key_id=dest.config.get('access_key'),
                aws_secret_access_key=dest.config.get('secret_key'),
                region_name=dest.config.get('region', 'us-east-1')
            )
            s3_client.head_bucket(Bucket=dest.config['bucket'])
            return True
        except Exception:
            return False

    def replicate_file(self, file_path: str, remote_path: str = None,
                      destinations: List[str] = None) -> List[ReplicationResult]:
        """
        Replicar un archivo a múltiples destinos

        Args:
            file_path: Archivo local a replicar
            remote_path: Path remoto (opcional, usa nombre del archivo si no se especifica)
            destinations: Lista de destinos (todos si no se especifica)

        Returns:
            Lista de resultados de replicación
        """
        if not os.path.exists(file_path):
            return [ReplicationResult("local", False, error_message="Archivo no encontrado")]

        if not remote_path:
            remote_path = os.path.basename(file_path)

        # Usar todos los destinos habilitados si no se especifica
        if destinations is None:
            destinations = [name for name, dest in self.destinations.items() if dest.enabled]

        results = []

        # Replicar en paralelo
        with ThreadPoolExecutor(max_workers=len(destinations)) as executor:
            futures = []
            for dest_name in destinations:
                if dest_name in self.destinations:
                    future = executor.submit(
                        self._replicate_to_destination,
                        file_path, remote_path, dest_name
                    )
                    futures.append((future, dest_name))

            for future, dest_name in futures:
                try:
                    result = future.result()
                    results.append(result)
                except Exception as e:
                    results.append(ReplicationResult(
                        dest_name, False, error_message=str(e)
                    ))

        return results

    def _replicate_to_destination(self, file_path: str, remote_path: str,
                                dest_name: str) -> ReplicationResult:
        """
        Replicar archivo a un destino específico

        Args:
            file_path: Archivo local
            remote_path: Path remoto
            dest_name: Nombre del destino

        Returns:
            Resultado de la replicación
        """
        start_time = datetime.now()
        dest = self.destinations[dest_name]

        try:
            if dest.type == 'local':
                result = self._replicate_local(file_path, remote_path, dest)
            elif dest.type == 'ftp':
                result = self._replicate_ftp(file_path, remote_path, dest)
            elif dest.type == 'sftp':
                result = self._replicate_sftp(file_path, remote_path, dest)
            elif dest.type == 's3':
                result = self._replicate_s3(file_path, remote_path, dest)
            else:
                return ReplicationResult(dest_name, False,
                                       error_message=f"Tipo no soportado: {dest.type}")

            result.transfer_time = (datetime.now() - start_time).total_seconds()
            return result

        except Exception as e:
            return ReplicationResult(dest_name, False,
                                   error_message=str(e),
                                   transfer_time=(datetime.now() - start_time).total_seconds())

    def _replicate_local(self, file_path: str, remote_path: str,
                        dest: StorageDestination) -> ReplicationResult:
        """Replicar a destino local"""
        local_path = os.path.join(dest.config['path'], remote_path)

        # Crear directorio si no existe
        os.makedirs(os.path.dirname(local_path), exist_ok=True)

        # Copiar archivo
        shutil.copy2(file_path, local_path)
        file_size = os.path.getsize(file_path)

        return ReplicationResult(dest.name, True, bytes_transferred=file_size)

    def _replicate_ftp(self, file_path: str, remote_path: str,
                      dest: StorageDestination) -> ReplicationResult:
        """Replicar a destino FTP"""
        file_size = os.path.getsize(file_path)

        with ftplib.FTP(dest.config['host']) as ftp:
            ftp.login(dest.config.get('user', ''), dest.config.get('password', ''))

            # Crear directorios remotos si es necesario
            remote_dir = os.path.dirname(remote_path)
            if remote_dir and remote_dir != '/':
                self._create_ftp_directories(ftp, remote_dir)

            # Subir archivo
            with open(file_path, 'rb') as f:
                ftp.storbinary(f'STOR {os.path.basename(remote_path)}', f)

        return ReplicationResult(dest.name, True, bytes_transferred=file_size)

    def _create_ftp_directories(self, ftp: ftplib.FTP, remote_dir: str):
        """Crear directorios en servidor FTP"""
        dirs = remote_dir.strip('/').split('/')
        current_dir = ''

        for dir_name in dirs:
            current_dir += '/' + dir_name
            try:
                ftp.mkd(current_dir)
            except ftplib.error_perm:
                pass  # Directorio ya existe

    def _replicate_sftp(self, file_path: str, remote_path: str,
                       dest: StorageDestination) -> ReplicationResult:
        """Replicar a destino SFTP"""
        if paramiko is None:
            return ReplicationResult(dest.name, False, error_message="paramiko no disponible")
        file_size = os.path.getsize(file_path)

        transport = paramiko.Transport((dest.config['host'], dest.config.get('port', 22)))
        transport.connect(
            username=dest.config.get('user', ''),
            password=dest.config.get('password', ''),
            pkey=dest.config.get('key_file')
        )

        with paramiko.SFTPClient.from_transport(transport) as sftp:
            # Crear directorios remotos
            remote_dir = os.path.dirname(remote_path)
            if remote_dir:
                self._create_sftp_directories(sftp, remote_dir)

            # Subir archivo
            sftp.put(file_path, remote_path)

        transport.close()
        return ReplicationResult(dest.name, True, bytes_transferred=file_size)

    def _create_sftp_directories(self, sftp: Any, remote_dir: str):
        """Crear directorios en servidor SFTP"""
        dirs = remote_dir.strip('/').split('/')
        current_dir = ''

        for dir_name in dirs:
            current_dir += '/' + dir_name
            try:
                sftp.mkdir(current_dir)
            except IOError:
                pass  # Directorio ya existe

    def _replicate_s3(self, file_path: str, remote_path: str,
                     dest: StorageDestination) -> ReplicationResult:
        """Replicar a destino S3"""
        if boto3 is None:
            return ReplicationResult(dest.name, False, error_message="boto3 no disponible")
        file_size = os.path.getsize(file_path)

        s3_client = boto3.client(
            's3',
            aws_access_key_id=dest.config.get('access_key'),
            aws_secret_access_key=dest.config.get('secret_key'),
            region_name=dest.config.get('region', 'us-east-1')
        )

        # Subir archivo
        bucket = dest.config['bucket']
        key = remote_path.lstrip('/')

        # Configurar storage class
        extra_args = {}
        if dest.config.get('storage_class'):
            extra_args['StorageClass'] = dest.config['storage_class']

        # Configurar encriptación
        if dest.config.get('encryption'):
            extra_args['ServerSideEncryption'] = dest.config['encryption']

        s3_client.upload_file(file_path, bucket, key, ExtraArgs=extra_args)

        return ReplicationResult(dest.name, True, bytes_transferred=file_size)

    def list_destinations(self) -> List[Dict]:
        """
        Listar todos los destinos configurados

        Returns:
            Lista de destinos con su configuración
        """
        return [
            {
                'name': dest.name,
                'type': dest.type,
                'enabled': dest.enabled,
                'config': {k: v for k, v in dest.config.items()
                          if k not in ['password', 'secret_key', 'access_key']}  # Ocultar credenciales
            }
            for dest in self.destinations.values()
        ]

    def get_destination_status(self, name: str) -> Dict:
        """
        Obtener estado de un destino

        Args:
            name: Nombre del destino

        Returns:
            Diccionario con información del estado
        """
        if name not in self.destinations:
            return {'error': 'Destino no encontrado'}

        dest = self.destinations[name]
        status = {
            'name': dest.name,
            'type': dest.type,
            'enabled': dest.enabled,
            'reachable': False
        }

        # Probar conectividad
        status['reachable'] = self.test_destination(name)

        # Información específica por tipo
        if dest.type == 'local':
            path = dest.config.get('path', '')
            if os.path.exists(path):
                status['free_space'] = shutil.disk_usage(path).free
                status['total_space'] = shutil.disk_usage(path).total
        elif dest.type == 's3':
            # Información de bucket S3
            if boto3 is None:
                status['bucket_error'] = "boto3 no disponible"
            else:
                try:
                    s3_client = boto3.client(
                        's3',
                        aws_access_key_id=dest.config.get('access_key'),
                        aws_secret_access_key=dest.config.get('secret_key'),
                        region_name=dest.config.get('region', 'us-east-1')
                    )
                    bucket_info = s3_client.head_bucket(Bucket=dest.config['bucket'])
                    status['bucket_location'] = bucket_info.get('ResponseMetadata', {}).get('HTTPHeaders', {}).get('x-amz-bucket-region')
                except Exception as e:
                    status['bucket_error'] = str(e)

        return status

    def cleanup_destination(self, name: str, max_age_days: int = 30) -> int:
        """
        Limpiar archivos antiguos en un destino

        Args:
            name: Nombre del destino
            max_age_days: Días de retención

        Returns:
            Número de archivos eliminados
        """
        if name not in self.destinations:
            return 0

        dest = self.destinations[name]

        try:
            if dest.type == 'local':
                return self._cleanup_local_destination(dest, max_age_days)
            elif dest.type == 's3':
                return self._cleanup_s3_destination(dest, max_age_days)
            else:
                self.logger.warning(f"Limpieza no soportada para tipo: {dest.type}")
                return 0

        except Exception as e:
            self.logger.error(f"Error limpiando destino {name}: {e}")
            return 0

    def _cleanup_local_destination(self, dest: StorageDestination, max_age_days: int) -> int:
        """Limpiar archivos antiguos en destino local"""
        import time
        path = dest.config['path']
        cutoff_time = time.time() - (max_age_days * 24 * 60 * 60)

        deleted_count = 0
        for root, dirs, files in os.walk(path):
            for file in files:
                file_path = os.path.join(root, file)
                if os.path.getmtime(file_path) < cutoff_time:
                    try:
                        os.remove(file_path)
                        deleted_count += 1
                    except Exception as e:
                        self.logger.warning(f"Error eliminando {file_path}: {e}")

        return deleted_count

    def _cleanup_s3_destination(self, dest: StorageDestination, max_age_days: int) -> int:
        """Limpiar archivos antiguos en destino S3"""
        if boto3 is None:
            return 0
        import time
        cutoff_time = time.time() - (max_age_days * 24 * 60 * 60)

        s3_client = boto3.client(
            's3',
            aws_access_key_id=dest.config.get('access_key'),
            aws_secret_access_key=dest.config.get('secret_key'),
            region_name=dest.config.get('region', 'us-east-1')
        )

        bucket = dest.config['bucket']
        deleted_count = 0

        # Listar objetos
        paginator = s3_client.get_paginator('list_objects_v2')
        for page in paginator.paginate(Bucket=bucket):
            if 'Contents' in page:
                for obj in page['Contents']:
                    if obj['LastModified'].timestamp() < cutoff_time:
                        try:
                            s3_client.delete_object(Bucket=bucket, Key=obj['Key'])
                            deleted_count += 1
                        except Exception as e:
                            self.logger.warning(f"Error eliminando S3 {obj['Key']}: {e}")

        return deleted_count