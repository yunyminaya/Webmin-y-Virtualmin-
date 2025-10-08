from typing import List, Dict, Any, Optional
from .unified_manager import manager
import logging
import time
import threading
import json

logger = logging.getLogger(__name__)

class MultiCloudMonitor:
    """Monitor unificado para recursos multi-nube"""

    def __init__(self):
        self.metrics = {}
        self.alerts = []
        self.monitoring_interval = 60  # segundos
        self.alert_thresholds = {
            'cpu_usage': 80.0,
            'memory_usage': 85.0,
            'disk_usage': 90.0,
            'network_errors': 5,
            'response_time': 5000  # ms
        }
        self._monitoring_thread = None
        self._running = False

    def start_monitoring(self):
        """Inicia el monitoreo de recursos"""
        if self._running:
            return

        self._running = True
        self._monitoring_thread = threading.Thread(target=self._monitoring_loop)
        self._monitoring_thread.daemon = True
        self._monitoring_thread.start()
        logger.info("Monitoreo multi-nube iniciado")

    def stop_monitoring(self):
        """Detiene el monitoreo"""
        self._running = False
        if self._monitoring_thread:
            self._monitoring_thread.join()
        logger.info("Monitoreo multi-nube detenido")

    def _monitoring_loop(self):
        """Loop principal de monitoreo"""
        while self._running:
            try:
                self._collect_metrics()
                self._check_alerts()
                self._cleanup_old_metrics()
                time.sleep(self.monitoring_interval)
            except Exception as e:
                logger.error(f"Error en monitoring loop: {e}")
                time.sleep(self.monitoring_interval)

    def _collect_metrics(self):
        """Recopila métricas de todos los proveedores"""
        timestamp = time.time()

        for provider_name in ['aws', 'azure', 'gcp']:
            try:
                provider_instance = manager.get_provider(provider_name)

                # Métricas de VMs
                vm_metrics = self._collect_vm_metrics(provider_instance, provider_name)

                # Métricas de storage
                storage_metrics = self._collect_storage_metrics(provider_instance, provider_name)

                # Métricas de red
                network_metrics = self._collect_network_metrics(provider_instance, provider_name)

                # Métricas de costos
                cost_metrics = self._collect_cost_metrics(provider_instance, provider_name)

                # Almacenar métricas
                self.metrics[f"{provider_name}_{timestamp}"] = {
                    'timestamp': timestamp,
                    'provider': provider_name,
                    'vm_metrics': vm_metrics,
                    'storage_metrics': storage_metrics,
                    'network_metrics': network_metrics,
                    'cost_metrics': cost_metrics
                }

            except Exception as e:
                logger.error(f"Error recopilando métricas de {provider_name}: {e}")

    def _collect_vm_metrics(self, provider_instance, provider_name: str) -> Dict[str, Any]:
        """Recopila métricas de VMs"""
        vms = provider_instance.list_vms()

        total_vms = len(vms)
        running_vms = sum(1 for vm in vms if vm['status'] in ['running', 'active'])
        stopped_vms = total_vms - running_vms

        # Métricas simuladas (en producción usar APIs de monitoreo reales)
        return {
            'total_vms': total_vms,
            'running_vms': running_vms,
            'stopped_vms': stopped_vms,
            'avg_cpu_usage': 45.5,  # %
            'avg_memory_usage': 62.3,  # %
            'total_vcpu': sum(self._estimate_vcpu(vm.get('instance_type', 't2.micro')) for vm in vms),
            'vms': [{'id': vm['id'], 'status': vm['status']} for vm in vms]
        }

    def _collect_storage_metrics(self, provider_instance, provider_name: str) -> Dict[str, Any]:
        """Recopila métricas de storage"""
        storage = provider_instance.list_storage()

        total_storage_gb = sum(s.get('size_gb', 0) for s in storage if s.get('size_gb'))
        used_storage_gb = total_storage_gb * 0.75  # Estimación

        return {
            'total_storage_gb': total_storage_gb,
            'used_storage_gb': used_storage_gb,
            'free_storage_gb': total_storage_gb - used_storage_gb,
            'usage_percentage': (used_storage_gb / total_storage_gb * 100) if total_storage_gb > 0 else 0,
            'storage_items': len(storage)
        }

    def _collect_network_metrics(self, provider_instance, provider_name: str) -> Dict[str, Any]:
        """Recopila métricas de red"""
        # Métricas simuladas
        return {
            'bytes_in': 1024000,  # bytes
            'bytes_out': 980000,  # bytes
            'packets_in': 15000,
            'packets_out': 12000,
            'errors_in': 2,
            'errors_out': 1,
            'latency_ms': 25.5
        }

    def _collect_cost_metrics(self, provider_instance, provider_name: str) -> Dict[str, Any]:
        """Recopila métricas de costos"""
        try:
            costs = provider_instance.get_costs()
            return {
                'total_cost': costs.get('total', 0),
                'currency': costs.get('currency', 'USD'),
                'period': costs.get('period', 'unknown'),
                'cost_trend': 'stable'  # increasing, decreasing, stable
            }
        except Exception as e:
            logger.error(f"Error obteniendo costos de {provider_name}: {e}")
            return {'total_cost': 0, 'error': str(e)}

    def _estimate_vcpu(self, instance_type: str) -> int:
        """Estima vCPUs basado en tipo de instancia"""
        # Mapas simplificados
        vcpu_map = {
            't2.micro': 1, 't2.small': 1, 't2.medium': 2,
            'Standard_B1s': 1, 'Standard_B2s': 2,
            'f1-micro': 1, 'g1-small': 1, 'n1-standard-1': 1
        }
        return vcpu_map.get(instance_type, 1)

    def _check_alerts(self):
        """Verifica condiciones de alerta"""
        latest_metrics = self._get_latest_metrics()

        if not latest_metrics:
            return

        # Verificar umbrales
        for metric_key, metric_data in latest_metrics.items():
            self._check_threshold_alerts(metric_data)

        # Verificar consistencia entre proveedores
        self._check_cross_provider_alerts(latest_metrics)

    def _check_threshold_alerts(self, metric_data: Dict[str, Any]):
        """Verifica alertas de umbrales"""
        vm_metrics = metric_data.get('vm_metrics', {})
        storage_metrics = metric_data.get('storage_metrics', {})

        # Alerta de CPU alta
        if vm_metrics.get('avg_cpu_usage', 0) > self.alert_thresholds['cpu_usage']:
            self._create_alert(
                'high_cpu_usage',
                f"CPU usage {vm_metrics['avg_cpu_usage']:.1f}% exceeds threshold {self.alert_thresholds['cpu_usage']}%",
                'warning',
                metric_data
            )

        # Alerta de memoria alta
        if vm_metrics.get('avg_memory_usage', 0) > self.alert_thresholds['memory_usage']:
            self._create_alert(
                'high_memory_usage',
                f"Memory usage {vm_metrics['avg_memory_usage']:.1f}% exceeds threshold {self.alert_thresholds['memory_usage']}%",
                'warning',
                metric_data
            )

        # Alerta de disco lleno
        if storage_metrics.get('usage_percentage', 0) > self.alert_thresholds['disk_usage']:
            self._create_alert(
                'high_disk_usage',
                f"Disk usage {storage_metrics['usage_percentage']:.1f}% exceeds threshold {self.alert_thresholds['disk_usage']}%",
                'critical',
                metric_data
            )

    def _check_cross_provider_alerts(self, all_metrics: Dict[str, Any]):
        """Verifica alertas entre proveedores"""
        providers = list(all_metrics.keys())

        if len(providers) < 2:
            return

        # Verificar balance de carga
        running_counts = [all_metrics[p]['vm_metrics']['running_vms'] for p in providers]
        avg_running = sum(running_counts) / len(running_counts)

        for i, provider in enumerate(providers):
            deviation = abs(running_counts[i] - avg_running) / avg_running
            if deviation > 0.5:  # 50% de desviación
                self._create_alert(
                    'load_imbalance',
                    f"Load imbalance detected in {provider}: {running_counts[i]} running VMs vs average {avg_running:.1f}",
                    'info',
                    all_metrics[provider]
                )

    def _create_alert(self, alert_type: str, message: str, severity: str, metric_data: Dict[str, Any]):
        """Crea una nueva alerta"""
        alert = {
            'id': f"alert_{int(time.time())}_{len(self.alerts)}",
            'type': alert_type,
            'message': message,
            'severity': severity,
            'timestamp': time.time(),
            'provider': metric_data.get('provider'),
            'metric_data': metric_data,
            'acknowledged': False
        }

        self.alerts.append(alert)
        logger.warning(f"Alert created: {alert_type} - {message}")

    def _cleanup_old_metrics(self, retention_hours: int = 24):
        """Limpia métricas antiguas"""
        cutoff_time = time.time() - (retention_hours * 60 * 60)
        old_keys = [k for k in self.metrics.keys() if self.metrics[k]['timestamp'] < cutoff_time]

        for key in old_keys:
            del self.metrics[key]

        if old_keys:
            logger.info(f"Limpiadas {len(old_keys)} métricas antiguas")

    def get_current_metrics(self) -> Dict[str, Any]:
        """Obtiene las métricas más recientes"""
        return self._get_latest_metrics()

    def _get_latest_metrics(self) -> Dict[str, Any]:
        """Obtiene las métricas más recientes por proveedor"""
        latest = {}
        providers = ['aws', 'azure', 'gcp']

        for provider in providers:
            provider_metrics = {k: v for k, v in self.metrics.items() if v['provider'] == provider}
            if provider_metrics:
                latest_key = max(provider_metrics.keys(), key=lambda k: provider_metrics[k]['timestamp'])
                latest[provider] = provider_metrics[latest_key]

        return latest

    def get_alerts(self, acknowledged: bool = None, severity: str = None) -> List[Dict[str, Any]]:
        """Obtiene alertas filtradas"""
        alerts = self.alerts

        if acknowledged is not None:
            alerts = [a for a in alerts if a['acknowledged'] == acknowledged]

        if severity:
            alerts = [a for a in alerts if a['severity'] == severity]

        return alerts[-50:]  # Últimas 50 alertas

    def acknowledge_alert(self, alert_id: str):
        """Reconoce una alerta"""
        for alert in self.alerts:
            if alert['id'] == alert_id:
                alert['acknowledged'] = True
                logger.info(f"Alert {alert_id} acknowledged")
                break

    def get_dashboard_data(self) -> Dict[str, Any]:
        """Obtiene datos para el dashboard de monitoreo"""
        latest_metrics = self._get_latest_metrics()
        active_alerts = self.get_alerts(acknowledged=False)

        return {
            'timestamp': time.time(),
            'metrics': latest_metrics,
            'alerts': active_alerts,
            'summary': {
                'total_providers': len(latest_metrics),
                'total_alerts': len(active_alerts),
                'critical_alerts': len([a for a in active_alerts if a['severity'] == 'critical']),
                'warning_alerts': len([a for a in active_alerts if a['severity'] == 'warning'])
            }
        }

# Instancia global del monitor
monitor = MultiCloudMonitor()