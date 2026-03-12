#!/usr/bin/env python3
"""
Dashboard Web del Sistema de Backup Inteligente
API REST completa y interfaz web moderna para gestión de backups
"""

import os
import json
import logging
from datetime import datetime, timedelta
from flask import Flask, render_template, request, jsonify, send_from_directory
from flask_cors import CORS
import threading
import time
from typing import Dict, List, Optional
from pathlib import Path

# Importar componentes del sistema
from ..core.backup_engine import IntelligentBackupEngine, BackupJob, BackupResult

class BackupDashboard:
    """
    Dashboard web completo para el sistema de backup inteligente
    """

    def __init__(self, backup_engine: IntelligentBackupEngine, host: str = '0.0.0.0', port: int = 8080):
        """
        Inicializar el dashboard

        Args:
            backup_engine: Instancia del motor de backup
            host: Host para el servidor
            port: Puerto para el servidor
        """
        self.backup_engine = backup_engine
        self.host = host
        self.port = port

        # Crear aplicación Flask
        self.app = Flask(__name__,
                        template_folder=os.path.join(os.path.dirname(__file__), 'templates'),
                        static_folder=os.path.join(os.path.dirname(__file__), 'static'))

        CORS(self.app)  # Habilitar CORS para API

        # Configurar logging
        self.logger = logging.getLogger(__name__)

        # Cache de resultados recientes
        self.recent_results: Dict[str, BackupResult] = {}
        self.running_jobs: Dict[str, threading.Thread] = {}

        # Registrar rutas
        self._register_routes()

    def _register_routes(self):
        """Registrar todas las rutas de la aplicación"""

        @self.app.route('/')
        def index():
            """Página principal del dashboard"""
            return render_template('dashboard.html')

        @self.app.route('/api/status')
        def api_status():
            """Estado general del sistema"""
            return jsonify(self.backup_engine.get_backup_status())

        @self.app.route('/api/health')
        def api_health():
            """Salud del sistema"""
            return jsonify(self.backup_engine.get_system_health())

        @self.app.route('/api/jobs', methods=['GET'])
        def api_get_jobs():
            """Obtener lista de trabajos"""
            jobs = []
            for job_id, job in self.backup_engine.jobs.items():
                jobs.append({
                    'id': job.job_id,
                    'name': job.name,
                    'source_paths': job.source_paths,
                    'schedule': job.schedule,
                    'compression': job.compression,
                    'encryption': job.encryption,
                    'deduplication': job.deduplication,
                    'replication_destinations': job.replication_destinations,
                    'retention_days': job.retention_days,
                    'incremental': job.incremental,
                    'verify_integrity': job.verify_integrity,
                    'is_running': job_id in self.running_jobs
                })
            return jsonify({'jobs': jobs})

        @self.app.route('/api/jobs', methods=['POST'])
        def api_create_job():
            """Crear nuevo trabajo de backup"""
            try:
                data = request.get_json()

                job = BackupJob(
                    job_id=data['id'],
                    name=data['name'],
                    source_paths=data['source_paths'],
                    destination=data.get('destination', '/backups'),
                    schedule=data.get('schedule', 'manual'),
                    compression=data.get('compression', True),
                    encryption=data.get('encryption', True),
                    deduplication=data.get('deduplication', True),
                    replication_destinations=data.get('replication_destinations', []),
                    retention_days=data.get('retention_days', 30),
                    incremental=data.get('incremental', True),
                    verify_integrity=data.get('verify_integrity', True)
                )

                self.backup_engine.create_backup_job(job)
                return jsonify({'success': True, 'message': 'Trabajo creado exitosamente'})

            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 400

        @self.app.route('/api/jobs/<job_id>/run', methods=['POST'])
        def api_run_job(job_id):
            """Ejecutar un trabajo de backup"""
            if job_id in self.running_jobs:
                return jsonify({'success': False, 'error': 'Trabajo ya en ejecución'}), 409

            # Ejecutar en hilo separado
            thread = threading.Thread(target=self._run_job_async, args=(job_id,))
            thread.daemon = True
            self.running_jobs[job_id] = thread
            thread.start()

            return jsonify({'success': True, 'message': 'Trabajo iniciado'})

        @self.app.route('/api/jobs/<job_id>/status')
        def api_job_status(job_id):
            """Obtener estado de un trabajo"""
            status = {
                'job_id': job_id,
                'is_running': job_id in self.running_jobs,
                'last_result': None
            }

            if job_id in self.recent_results:
                result = self.recent_results[job_id]
                status['last_result'] = {
                    'success': result.success,
                    'start_time': result.start_time.isoformat(),
                    'end_time': result.end_time.isoformat(),
                    'processing_time': result.processing_time,
                    'total_files': result.total_files,
                    'total_size': result.total_size,
                    'compressed_size': result.compressed_size,
                    'compression_ratio': result.compression_ratio,
                    'error_message': result.error_message
                }

                if result.deduplication_stats:
                    status['last_result']['deduplication'] = {
                        'space_saved': result.deduplication_stats.space_saved,
                        'ratio': result.deduplication_stats.unique_blocks / result.deduplication_stats.total_blocks if result.deduplication_stats.total_blocks > 0 else 1.0
                    }

                if result.replication_results:
                    status['last_result']['replication'] = [
                        {
                            'destination': r.destination,
                            'success': r.success,
                            'bytes_transferred': r.bytes_transferred,
                            'transfer_time': r.transfer_time,
                            'error': r.error_message
                        } for r in result.replication_results
                    ]

            return jsonify(status)

        @self.app.route('/api/restore', methods=['POST'])
        def api_restore():
            """Restaurar un backup"""
            try:
                data = request.get_json()
                backup_id = data['backup_id']
                target_path = data['target_path']
                files_to_restore = data.get('files', None)

                result = self.backup_engine.restore_backup(backup_id, target_path, files_to_restore)

                return jsonify({
                    'success': True,
                    'files_restored': result.files_restored,
                    'total_size_restored': result.total_size_restored,
                    'processing_time': result.processing_time,
                    'errors': result.errors
                })

            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 400

        @self.app.route('/api/storage/destinations', methods=['GET'])
        def api_get_destinations():
            """Obtener destinos de almacenamiento"""
            return jsonify({'destinations': self.backup_engine.storage_manager.list_destinations()})

        @self.app.route('/api/storage/destinations', methods=['POST'])
        def api_add_destination():
            """Agregar destino de almacenamiento"""
            try:
                from ..storage.storage_manager import StorageDestination
                data = request.get_json()

                dest = StorageDestination(
                    name=data['name'],
                    type=data['type'],
                    enabled=data.get('enabled', True),
                    config=data.get('config', {})
                )

                self.backup_engine.storage_manager.add_destination(dest)
                return jsonify({'success': True, 'message': 'Destino agregado'})

            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 400

        @self.app.route('/api/verification/history')
        def api_verification_history():
            """Obtener historial de verificaciones"""
            from ..verification.verifier import IntegrityVerifier
            verifier = IntegrityVerifier()
            history = verifier.get_verification_history()
            return jsonify({'history': history})

        @self.app.route('/api/logs')
        def api_get_logs():
            """Obtener logs recientes del sistema"""
            # En implementación real, leer desde archivo de logs
            logs = [
                {
                    'timestamp': datetime.now().isoformat(),
                    'level': 'INFO',
                    'message': 'Sistema de backup operativo'
                }
            ]
            return jsonify({'logs': logs})

        @self.app.route('/static/<path:filename>')
        def static_files(filename):
            """Servir archivos estáticos"""
            return send_from_directory(self.app.static_folder, filename)

    def _run_job_async(self, job_id: str):
        """Ejecutar trabajo de backup de forma asíncrona"""
        try:
            self.logger.info(f"Ejecutando trabajo asíncrono: {job_id}")
            result = self.backup_engine.run_backup_job(job_id)
            self.recent_results[job_id] = result

            if result.success:
                self.logger.info(f"Trabajo completado exitosamente: {job_id}")
            else:
                self.logger.error(f"Trabajo fallido: {job_id} - {result.error_message}")

        except Exception as e:
            self.logger.error(f"Error ejecutando trabajo {job_id}: {e}")
        finally:
            # Limpiar hilo completado
            self.running_jobs.pop(job_id, None)

    def start(self):
        """Iniciar el servidor del dashboard"""
        self.logger.info(f"Iniciando dashboard en {self.host}:{self.port}")
        self.app.run(host=self.host, port=self.port, debug=False, threaded=True)

    def stop(self):
        """Detener el servidor del dashboard"""
        # En Flask, no hay método directo para detener, pero podemos usar un flag
        pass