#!/usr/bin/env python3
"""
Módulo de Integración con Sistema de Monitoreo Avanzado
Integra el sistema de backup inteligente con el monitoreo avanzado existente
para alertas y métricas unificadas
"""

import os
import sqlite3
import json
import logging
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
import subprocess
import threading
import time

@dataclass
class MonitoringMetric:
    """Métrica para enviar al sistema de monitoreo"""
    name: str
    value: float
    unit: str = ""
    timestamp: Optional[datetime] = None

@dataclass
class MonitoringAlert:
    """Alerta para enviar al sistema de monitoreo"""
    alert_type: str
    severity: str  # 'CRITICAL', 'WARNING', 'INFO'
    message: str
    source: str = "intelligent_backup"

class MonitoringIntegration:
    """
    Integración completa con el sistema de monitoreo avanzado
    existente de Webmin/Virtualmin
    """

    def __init__(self, monitoring_script: str = None, db_path: str = None):
        """
        Inicializar la integración con monitoreo

        Args:
            monitoring_script: Path al script de monitoreo avanzado
            db_path: Path a la base de datos del sistema de monitoreo
        """
        self.monitoring_script = monitoring_script or self._find_monitoring_script()
        self.db_path = db_path or "/var/lib/advanced_monitoring/metrics.db"
        self.logger = logging.getLogger(__name__)

        # Verificar que el sistema de monitoreo existe
        self.monitoring_available = self._check_monitoring_system()

        if self.monitoring_available:
            self.logger.info("Sistema de monitoreo avanzado detectado y disponible")
        else:
            self.logger.warning("Sistema de monitoreo avanzado no disponible")

    def _find_monitoring_script(self) -> str:
        """Buscar el script de monitoreo avanzado"""
        possible_paths = [
            "/usr/local/bin/advanced_monitoring.sh",
            "/opt/webmin/advanced_monitoring.sh",
            "./advanced_monitoring.sh",
            "../advanced_monitoring.sh"
        ]

        for path in possible_paths:
            if os.path.exists(path) and os.access(path, os.X_OK):
                return path

        # Buscar en el directorio actual del proyecto
        script_path = Path(__file__).parent.parent.parent / "advanced_monitoring.sh"
        if script_path.exists():
            return str(script_path)

        return "advanced_monitoring.sh"  # Fallback

    def _check_monitoring_system(self) -> bool:
        """Verificar que el sistema de monitoreo está disponible"""
        try:
            # Verificar que existe el script
            if not os.path.exists(self.monitoring_script):
                return False

            # Verificar que existe la base de datos
            if not os.path.exists(self.db_path):
                return False

            # Verificar que podemos escribir en la BD
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='metrics'")
                return cursor.fetchone() is not None

        except Exception as e:
            self.logger.warning(f"Error verificando sistema de monitoreo: {e}")
            return False

    def send_metric(self, metric: MonitoringMetric):
        """
        Enviar una métrica al sistema de monitoreo

        Args:
            metric: Métrica a enviar
        """
        if not self.monitoring_available:
            return

        try:
            with sqlite3.connect(self.db_path) as conn:
                timestamp = metric.timestamp or datetime.now()

                conn.execute('''
                    INSERT INTO metrics (timestamp, metric_type, metric_name, value, unit)
                    VALUES (?, ?, ?, ?, ?)
                ''', (
                    timestamp.isoformat(),
                    'backup',
                    metric.name,
                    metric.value,
                    metric.unit
                ))

                conn.commit()

            self.logger.debug(f"Métrica enviada: {metric.name} = {metric.value} {metric.unit}")

        except Exception as e:
            self.logger.error(f"Error enviando métrica {metric.name}: {e}")

    def send_metrics_batch(self, metrics: List[MonitoringMetric]):
        """
        Enviar múltiples métricas en lote

        Args:
            metrics: Lista de métricas
        """
        if not self.monitoring_available or not metrics:
            return

        try:
            with sqlite3.connect(self.db_path) as conn:
                for metric in metrics:
                    timestamp = metric.timestamp or datetime.now()

                    conn.execute('''
                        INSERT INTO metrics (timestamp, metric_type, metric_name, value, unit)
                        VALUES (?, ?, ?, ?, ?)
                    ''', (
                        timestamp.isoformat(),
                        'backup',
                        metric.name,
                        metric.value,
                        metric.unit
                    ))

                conn.commit()

            self.logger.debug(f"{len(metrics)} métricas enviadas al sistema de monitoreo")

        except Exception as e:
            self.logger.error(f"Error enviando métricas en lote: {e}")

    def send_alert(self, alert: MonitoringAlert):
        """
        Enviar una alerta al sistema de monitoreo

        Args:
            alert: Alerta a enviar
        """
        if not self.monitoring_available:
            return

        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.execute('''
                    INSERT INTO alerts (timestamp, alert_type, severity, message)
                    VALUES (?, ?, ?, ?)
                ''', (
                    datetime.now().isoformat(),
                    f"BACKUP_{alert.alert_type}",
                    alert.severity,
                    f"[{alert.source}] {alert.message}"
                ))

                conn.commit()

            self.logger.info(f"Alerta enviada: {alert.alert_type} ({alert.severity})")

            # También intentar enviar por email/Telegram si está configurado
            self._send_external_alert(alert)

        except Exception as e:
            self.logger.error(f"Error enviando alerta {alert.alert_type}: {e}")

    def _send_external_alert(self, alert: MonitoringAlert):
        """Enviar alerta por canales externos (email, Telegram)"""
        try:
            # Intentar ejecutar el script de monitoreo para enviar alertas
            if os.path.exists(self.monitoring_script):
                subject = f"[{alert.severity}] Backup Alert: {alert.alert_type}"
                message = f"Source: {alert.source}\n\n{alert.message}\n\nTimestamp: {datetime.now().isoformat()}"

                # Ejecutar script con parámetros de alerta
                cmd = [
                    self.monitoring_script,
                    "--alert",
                    subject,
                    message,
                    alert.severity
                ]

                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=30
                )

                if result.returncode == 0:
                    self.logger.debug("Alerta externa enviada correctamente")
                else:
                    self.logger.warning(f"Error enviando alerta externa: {result.stderr}")

        except subprocess.TimeoutExpired:
            self.logger.warning("Timeout enviando alerta externa")
        except Exception as e:
            self.logger.warning(f"Error enviando alerta externa: {e}")

    def get_backup_metrics_history(self, metric_name: str, hours: int = 24) -> List[Dict]:
        """
        Obtener historial de métricas de backup

        Args:
            metric_name: Nombre de la métrica
            hours: Horas de historial

        Returns:
            Lista de puntos de datos históricos
        """
        if not self.monitoring_available:
            return []

        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.execute('''
                    SELECT strftime('%s', timestamp)*1000 as time_ms, value, unit
                    FROM metrics
                    WHERE metric_type = 'backup' AND metric_name = ?
                    AND timestamp >= datetime('now', '-{} hours')
                    ORDER BY timestamp
                '''.format(hours), (metric_name,))

                return [
                    {
                        'timestamp': int(row[0]),
                        'value': row[1],
                        'unit': row[2] or ''
                    }
                    for row in cursor
                ]

        except Exception as e:
            self.logger.error(f"Error obteniendo historial de métricas: {e}")
            return []

    def get_backup_alerts_history(self, hours: int = 24) -> List[Dict]:
        """
        Obtener historial de alertas de backup

        Args:
            hours: Horas de historial

        Returns:
            Lista de alertas históricas
        """
        if not self.monitoring_available:
            return []

        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.execute('''
                    SELECT timestamp, alert_type, severity, message, resolved
                    FROM alerts
                    WHERE alert_type LIKE 'BACKUP_%'
                    AND timestamp >= datetime('now', '-{} hours')
                    ORDER BY timestamp DESC
                '''.format(hours))

                return [
                    {
                        'timestamp': row[0],
                        'alert_type': row[1].replace('BACKUP_', ''),
                        'severity': row[2],
                        'message': row[3],
                        'resolved': bool(row[4])
                    }
                    for row in cursor
                ]

        except Exception as e:
            self.logger.error(f"Error obteniendo historial de alertas: {e}")
            return []

    def report_backup_started(self, job_id: str, job_name: str):
        """
        Reportar inicio de trabajo de backup

        Args:
            job_id: ID del trabajo
            job_name: Nombre del trabajo
        """
        self.send_metric(MonitoringMetric(
            name=f"backup_job_started_{job_id}",
            value=1,
            unit="event"
        ))

        self.send_alert(MonitoringAlert(
            alert_type="BACKUP_STARTED",
            severity="INFO",
            message=f"Trabajo de backup '{job_name}' ({job_id}) iniciado"
        ))

    def report_backup_completed(self, job_id: str, job_name: str, result: Any):
        """
        Reportar finalización de trabajo de backup

        Args:
            job_id: ID del trabajo
            job_name: Nombre del trabajo
            result: Resultado del backup
        """
        # Métricas de resultado
        metrics = [
            MonitoringMetric(f"backup_job_completed_{job_id}", 1, "event"),
            MonitoringMetric(f"backup_files_processed_{job_id}", getattr(result, 'total_files', 0), "count"),
            MonitoringMetric(f"backup_size_processed_{job_id}", getattr(result, 'total_size', 0), "bytes"),
            MonitoringMetric(f"backup_compressed_size_{job_id}", getattr(result, 'compressed_size', 0), "bytes"),
            MonitoringMetric(f"backup_processing_time_{job_id}", getattr(result, 'processing_time', 0), "seconds"),
        ]

        # Agregar métricas de deduplicación si existen
        if hasattr(result, 'deduplication_stats') and result.deduplication_stats:
            dedup = result.deduplication_stats
            metrics.extend([
                MonitoringMetric(f"backup_deduplication_ratio_{job_id}", dedup.unique_blocks / dedup.total_blocks if dedup.total_blocks > 0 else 1.0, "ratio"),
                MonitoringMetric(f"backup_space_saved_{job_id}", dedup.space_saved, "bytes"),
            ])

        self.send_metrics_batch(metrics)

        # Alerta de resultado
        if getattr(result, 'success', False):
            self.send_alert(MonitoringAlert(
                alert_type="BACKUP_SUCCESS",
                severity="INFO",
                message=f"Backup '{job_name}' completado exitosamente. "
                       f"Archivos: {getattr(result, 'total_files', 0)}, "
                       f"Tamaño: {getattr(result, 'total_size', 0)} bytes, "
                       f"Tiempo: {getattr(result, 'processing_time', 0):.2f}s"
            ))
        else:
            self.send_alert(MonitoringAlert(
                alert_type="BACKUP_FAILED",
                severity="CRITICAL",
                message=f"Backup '{job_name}' falló: {getattr(result, 'error_message', 'Error desconocido')}"
            ))

    def report_backup_restored(self, backup_id: str, target_path: str, result: Any):
        """
        Reportar restauración de backup

        Args:
            backup_id: ID del backup restaurado
            target_path: Destino de la restauración
            result: Resultado de la restauración
        """
        metrics = [
            MonitoringMetric("backup_restore_completed", 1, "event"),
            MonitoringMetric("backup_files_restored", getattr(result, 'files_restored', 0), "count"),
            MonitoringMetric("backup_size_restored", getattr(result, 'total_size_restored', 0), "bytes"),
            MonitoringMetric("backup_restore_time", getattr(result, 'processing_time', 0), "seconds"),
        ]

        self.send_metrics_batch(metrics)

        if getattr(result, 'errors', None):
            self.send_alert(MonitoringAlert(
                alert_type="BACKUP_RESTORE_WARNING",
                severity="WARNING",
                message=f"Restauración de backup {backup_id} completada con {len(result.errors)} errores: {', '.join(result.errors[:3])}"
            ))
        else:
            self.send_alert(MonitoringAlert(
                alert_type="BACKUP_RESTORE_SUCCESS",
                severity="INFO",
                message=f"Backup {backup_id} restaurado exitosamente en {target_path}. "
                       f"Archivos: {getattr(result, 'files_restored', 0)}, "
                       f"Tamaño: {getattr(result, 'total_size_restored', 0)} bytes"
            ))

    def report_verification_completed(self, backup_id: str, result: Any):
        """
        Reportar resultado de verificación de integridad

        Args:
            backup_id: ID del backup verificado
            result: Resultado de la verificación
        """
        metrics = [
            MonitoringMetric("backup_verification_completed", 1, "event"),
            MonitoringMetric("backup_files_verified", getattr(result, 'total_files', 0), "count"),
            MonitoringMetric("backup_files_valid", getattr(result, 'valid_files', 0), "count"),
            MonitoringMetric("backup_files_corrupted", getattr(result, 'corrupted_files', 0), "count"),
            MonitoringMetric("backup_files_missing", getattr(result, 'missing_files', 0), "count"),
            MonitoringMetric("backup_verification_time", getattr(result, 'processing_time', 0), "seconds"),
        ]

        self.send_metrics_batch(metrics)

        # Calcular puntuación de salud
        total_files = getattr(result, 'total_files', 0)
        valid_files = getattr(result, 'valid_files', 0)

        if total_files > 0:
            health_score = (valid_files / total_files) * 100

            if health_score < 80:
                severity = "CRITICAL"
            elif health_score < 95:
                severity = "WARNING"
            else:
                severity = "INFO"

            self.send_alert(MonitoringAlert(
                alert_type="BACKUP_VERIFICATION_RESULT",
                severity=severity,
                message=f"Verificación de backup {backup_id}: {valid_files}/{total_files} archivos válidos "
                       f"({health_score:.1f}% salud). "
                       f"Corruptos: {getattr(result, 'corrupted_files', 0)}, "
                       f"Faltantes: {getattr(result, 'missing_files', 0)}"
            ))

    def report_storage_issue(self, destination: str, issue: str):
        """
        Reportar problema de almacenamiento

        Args:
            destination: Destino con problema
            issue: Descripción del problema
        """
        self.send_alert(MonitoringAlert(
            alert_type="BACKUP_STORAGE_ISSUE",
            severity="WARNING",
            message=f"Problema de almacenamiento en {destination}: {issue}"
        ))

    def report_replication_issue(self, destination: str, error: str):
        """
        Reportar problema de replicación

        Args:
            destination: Destino con problema
            error: Error de replicación
        """
        self.send_alert(MonitoringAlert(
            alert_type="BACKUP_REPLICATION_FAILED",
            severity="CRITICAL",
            message=f"Fallo de replicación a {destination}: {error}"
        ))

    def get_system_health_status(self) -> Dict[str, Any]:
        """
        Obtener estado de salud del sistema de backup integrado

        Returns:
            Diccionario con estado de salud
        """
        status = {
            'monitoring_integration': self.monitoring_available,
            'timestamp': datetime.now().isoformat(),
            'metrics': {},
            'alerts': {}
        }

        if self.monitoring_available:
            try:
                # Obtener métricas recientes
                recent_metrics = {}
                metric_names = [
                    'backup_job_completed', 'backup_files_processed',
                    'backup_space_saved', 'backup_verification_completed'
                ]

                for metric_name in metric_names:
                    history = self.get_backup_metrics_history(metric_name, hours=1)
                    if history:
                        recent_metrics[metric_name] = history[-1]['value']

                status['metrics'] = recent_metrics

                # Obtener alertas recientes
                recent_alerts = self.get_backup_alerts_history(hours=24)
                unresolved_alerts = [a for a in recent_alerts if not a['resolved']]

                status['alerts'] = {
                    'total_recent': len(recent_alerts),
                    'unresolved': len(unresolved_alerts),
                    'critical_count': len([a for a in unresolved_alerts if a['severity'] == 'CRITICAL']),
                    'warning_count': len([a for a in unresolved_alerts if a['severity'] == 'WARNING'])
                }

            except Exception as e:
                self.logger.error(f"Error obteniendo estado de salud: {e}")
                status['error'] = str(e)

        return status

    def start_monitoring_thread(self):
        """
        Iniciar hilo de monitoreo continuo
        Envía métricas periódicas del sistema de backup
        """
        def monitoring_loop():
            while True:
                try:
                    # Enviar métricas de estado del sistema
                    self._send_system_metrics()

                    # Verificar estado de destinos de almacenamiento
                    self._check_storage_destinations()

                except Exception as e:
                    self.logger.error(f"Error en monitoring loop: {e}")

                # Esperar 5 minutos
                time.sleep(300)

        thread = threading.Thread(target=monitoring_loop, daemon=True)
        thread.start()
        self.logger.info("Hilo de monitoreo continuo iniciado")

    def _send_system_metrics(self):
        """Enviar métricas del estado del sistema"""
        # Estas métricas serían obtenidas del motor de backup
        # Por ahora enviamos métricas dummy para demostración
        metrics = [
            MonitoringMetric("backup_system_status", 1, "status"),
            MonitoringMetric("backup_monitoring_integration", 1 if self.monitoring_available else 0, "status"),
        ]

        self.send_metrics_batch(metrics)

    def _check_storage_destinations(self):
        """Verificar estado de destinos de almacenamiento"""
        # Esta función verificaría periódicamente los destinos
        # y reportaría problemas
        pass

    def export_monitoring_data(self, output_file: str, hours: int = 24):
        """
        Exportar datos de monitoreo para análisis

        Args:
            output_file: Archivo de salida
            hours: Horas de datos a exportar
        """
        data = {
            'export_timestamp': datetime.now().isoformat(),
            'hours': hours,
            'metrics': {},
            'alerts': self.get_backup_alerts_history(hours)
        }

        # Obtener todas las métricas de backup
        metric_names = [
            'backup_job_completed', 'backup_files_processed', 'backup_size_processed',
            'backup_compressed_size', 'backup_processing_time', 'backup_deduplication_ratio',
            'backup_space_saved', 'backup_verification_completed', 'backup_files_verified',
            'backup_files_valid', 'backup_files_corrupted', 'backup_files_missing',
            'backup_restore_completed', 'backup_files_restored', 'backup_size_restored'
        ]

        for metric_name in metric_names:
            data['metrics'][metric_name] = self.get_backup_metrics_history(metric_name, hours)

        try:
            with open(output_file, 'w') as f:
                json.dump(data, f, indent=2, default=str)

            self.logger.info(f"Datos de monitoreo exportados a {output_file}")

        except Exception as e:
            self.logger.error(f"Error exportando datos de monitoreo: {e}")

    def cleanup_old_data(self, days: int = 90):
        """
        Limpiar datos antiguos de monitoreo

        Args:
            days: Días de retención
        """
        if not self.monitoring_available:
            return

        try:
            cutoff_date = (datetime.now() - timedelta(days=days)).isoformat()

            with sqlite3.connect(self.db_path) as conn:
                # Limpiar métricas antiguas
                conn.execute('''
                    DELETE FROM metrics
                    WHERE metric_type = 'backup' AND timestamp < ?
                ''', (cutoff_date,))

                # Limpiar alertas antiguas resueltas
                conn.execute('''
                    DELETE FROM alerts
                    WHERE alert_type LIKE 'BACKUP_%' AND resolved = 1 AND timestamp < ?
                ''', (cutoff_date,))

                deleted_metrics = conn.total_changes

                conn.commit()

            self.logger.info(f"Limpieza completada: {deleted_metrics} registros antiguos eliminados")

        except Exception as e:
            self.logger.error(f"Error limpiando datos antiguos: {e}")