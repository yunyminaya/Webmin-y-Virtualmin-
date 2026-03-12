#!/usr/bin/env python3
"""
Proactive Recommendation Engine - Motor de Recomendaciones Proactivas
Analiza métricas y genera recomendaciones inteligentes con implementación automática
"""

import os
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
from enum import Enum

class RecommendationPriority(Enum):
    LOW = 1
    MEDIUM = 2
    HIGH = 3
    CRITICAL = 4

class RecommendationCategory(Enum):
    PERFORMANCE = "performance"
    SECURITY = "security"
    RESOURCE_OPTIMIZATION = "resource_optimization"
    CONFIGURATION_TUNING = "configuration_tuning"
    MAINTENANCE = "maintenance"

class ProactiveRecommendationEngine:
    """
    Motor de recomendaciones proactivas que analiza métricas del sistema
    y genera recomendaciones inteligentes con implementación automática
    """

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger("ProactiveRecommendationEngine")

        # Configuración de recomendaciones
        self.rec_config = config.get("recommendation_engine", {})
        self.min_confidence = self.rec_config.get("min_confidence_threshold", 0.7)
        self.max_recommendations = self.rec_config.get("max_recommendations_per_cycle", 10)
        self.categories = self.rec_config.get("recommendation_categories", [
            "performance", "security", "resource_optimization", "configuration_tuning"
        ])
        self.auto_implement = self.rec_config.get("auto_implementation_enabled", True)

        # Estado de recomendaciones
        self.active_recommendations = []
        self.implemented_recommendations = []
        self.recommendation_history = []

        # Reglas de recomendación
        self.recommendation_rules = self._load_recommendation_rules()

        # Métricas de rendimiento
        self.performance_baselines = {}
        self.anomaly_patterns = []

        self.logger.info("🎯 Proactive Recommendation Engine inicializado")

    def generate_recommendations(self, current_metrics: Dict[str, Any],
                               predictions: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Genera recomendaciones basadas en métricas actuales y predicciones"""
        try:
            recommendations = []

            # Análisis de rendimiento actual
            performance_recs = self._analyze_performance_metrics(current_metrics)
            recommendations.extend(performance_recs)

            # Análisis predictivo
            if predictions and "predictions" in predictions:
                predictive_recs = self._analyze_predictions(predictions)
                recommendations.extend(predictive_recs)

            # Análisis de anomalías
            if "anomalies" in predictions.get("predictions", {}):
                anomaly_recs = self._analyze_anomalies(predictions["predictions"]["anomalies"])
                recommendations.extend(anomaly_recs)

            # Análisis de patrones
            if "patterns" in predictions.get("predictions", {}):
                pattern_recs = self._analyze_patterns(predictions["predictions"]["patterns"])
                recommendations.extend(pattern_recs)

            # Filtrar y priorizar recomendaciones
            filtered_recs = self._filter_and_prioritize(recommendations)

            # Registrar recomendaciones activas
            self.active_recommendations = filtered_recs

            self.logger.info(f"💡 Generadas {len(filtered_recs)} recomendaciones")

            return filtered_recs

        except Exception as e:
            self.logger.error(f"Error generando recomendaciones: {e}")
            return []

    def implement_recommendations(self, recommendations: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Implementa recomendaciones automáticamente"""
        implemented = []

        try:
            for rec in recommendations:
                if rec.get("auto_implement", False) and rec["confidence"] >= self.min_confidence:
                    success = self._implement_single_recommendation(rec)
                    if success:
                        rec["implemented_at"] = datetime.now().isoformat()
                        rec["status"] = "implemented"
                        implemented.append(rec)

                        # Mover a recomendaciones implementadas
                        self.implemented_recommendations.append(rec)

                    else:
                        rec["status"] = "failed"

            self.logger.info(f"✅ Implementadas {len(implemented)} recomendaciones automáticamente")

        except Exception as e:
            self.logger.error(f"Error implementando recomendaciones: {e}")

        return implemented

    def _analyze_performance_metrics(self, metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Analiza métricas de rendimiento actuales"""
        recommendations = []

        try:
            # Análisis de CPU
            cpu_recs = self._analyze_cpu_performance(metrics)
            recommendations.extend(cpu_recs)

            # Análisis de memoria
            memory_recs = self._analyze_memory_performance(metrics)
            recommendations.extend(memory_recs)

            # Análisis de disco
            disk_recs = self._analyze_disk_performance(metrics)
            recommendations.extend(disk_recs)

            # Análisis de servicios
            service_recs = self._analyze_service_performance(metrics)
            recommendations.extend(service_recs)

        except Exception as e:
            self.logger.error(f"Error analizando métricas de rendimiento: {e}")

        return recommendations

    def _analyze_cpu_performance(self, metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Analiza rendimiento de CPU y genera recomendaciones"""
        recommendations = []

        cpu_metrics = metrics.get("cpu", {})
        cpu_percent = cpu_metrics.get("percent", 0)
        load_1m = cpu_metrics.get("load_1m", 0)
        load_5m = cpu_metrics.get("load_5m", 0)

        # CPU alta
        if cpu_percent > 90:
            recommendations.append({
                "id": f"cpu_high_{datetime.now().timestamp()}",
                "type": "resource",
                "category": RecommendationCategory.RESOURCE_OPTIMIZATION.value,
                "priority": RecommendationPriority.HIGH.value,
                "title": "Uso de CPU Críticamente Alto",
                "description": f"CPU al {cpu_percent:.1f}%. Considerar optimización de procesos o escalado.",
                "confidence": 0.95,
                "auto_implement": True,
                "actions": [
                    {"type": "resource", "resource": "cpu", "action": "renice_processes"},
                    {"type": "resource", "resource": "cpu", "action": "kill_zombie_processes"}
                ],
                "expected_impact": "Reducir uso de CPU en 20-30%",
                "rollback_plan": "Restaurar prioridades de procesos"
            })

        elif cpu_percent > 80:
            recommendations.append({
                "id": f"cpu_elevated_{datetime.now().timestamp()}",
                "type": "resource",
                "category": RecommendationCategory.RESOURCE_OPTIMIZATION.value,
                "priority": RecommendationPriority.MEDIUM.value,
                "title": "Uso de CPU Elevado",
                "description": f"CPU al {cpu_percent:.1f}%. Monitorear y optimizar si persiste.",
                "confidence": 0.85,
                "auto_implement": False,
                "actions": [
                    {"type": "monitoring", "action": "increase_cpu_monitoring"}
                ],
                "expected_impact": "Mejorar estabilidad del sistema"
            })

        # Load average alto
        if load_1m > 5:
            recommendations.append({
                "id": f"load_high_{datetime.now().timestamp()}",
                "type": "system",
                "category": RecommendationCategory.PERFORMANCE.value,
                "priority": RecommendationPriority.HIGH.value,
                "title": "Load Average Alto",
                "description": f"Load average: {load_1m:.1f} (1m), {load_5m:.1f} (5m). Sistema sobrecargado.",
                "confidence": 0.90,
                "auto_implement": True,
                "actions": [
                    {"type": "resource", "resource": "cpu", "action": "optimize_processes"},
                    {"type": "config", "service": "apache", "action": "reduce_max_clients"}
                ],
                "expected_impact": "Reducir load average en 30-50%"
            })

        return recommendations

    def _analyze_memory_performance(self, metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Analiza rendimiento de memoria"""
        recommendations = []

        memory_metrics = metrics.get("memory", {})
        memory_percent = memory_metrics.get("percent", 0)
        swap_percent = memory_metrics.get("swap_percent", 0)

        # Memoria alta
        if memory_percent > 95:
            recommendations.append({
                "id": f"memory_critical_{datetime.now().timestamp()}",
                "type": "resource",
                "category": RecommendationCategory.RESOURCE_OPTIMIZATION.value,
                "priority": RecommendationPriority.CRITICAL.value,
                "title": "Memoria Críticamente Baja",
                "description": f"Memoria al {memory_percent:.1f}%. Riesgo de out-of-memory.",
                "confidence": 0.98,
                "auto_implement": True,
                "actions": [
                    {"type": "resource", "resource": "memory", "action": "drop_caches"},
                    {"type": "resource", "resource": "memory", "action": "kill_memory_hogs"}
                ],
                "expected_impact": "Liberar 20-40% de memoria",
                "rollback_plan": "Reinicio de servicios si es necesario"
            })

        elif memory_percent > 85:
            recommendations.append({
                "id": f"memory_high_{datetime.now().timestamp()}",
                "type": "resource",
                "category": RecommendationCategory.RESOURCE_OPTIMIZATION.value,
                "priority": RecommendationPriority.HIGH.value,
                "title": "Uso de Memoria Alto",
                "description": f"Memoria al {memory_percent:.1f}%. Optimizar uso de memoria.",
                "confidence": 0.88,
                "auto_implement": True,
                "actions": [
                    {"type": "resource", "resource": "memory", "action": "drop_caches"}
                ],
                "expected_impact": "Liberar 10-20% de memoria"
            })

        # Swap alto
        if swap_percent > 70:
            recommendations.append({
                "id": f"swap_high_{datetime.now().timestamp()}",
                "type": "resource",
                "category": RecommendationCategory.RESOURCE_OPTIMIZATION.value,
                "priority": RecommendationPriority.MEDIUM.value,
                "title": "Uso de Swap Elevado",
                "description": f"Swap al {swap_percent:.1f}%. Optimizar memoria y swap.",
                "confidence": 0.80,
                "auto_implement": True,
                "actions": [
                    {"type": "resource", "resource": "memory", "action": "optimize_swap"}
                ],
                "expected_impact": "Reducir uso de swap en 20-30%"
            })

        return recommendations

    def _analyze_disk_performance(self, metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Analiza rendimiento de disco"""
        recommendations = []

        disk_metrics = metrics.get("disk", {})
        disk_percent = disk_metrics.get("percent", 0)

        # Disco lleno
        if disk_percent > 95:
            recommendations.append({
                "id": f"disk_critical_{datetime.now().timestamp()}",
                "type": "resource",
                "category": RecommendationCategory.RESOURCE_OPTIMIZATION.value,
                "priority": RecommendationPriority.CRITICAL.value,
                "title": "Disco Críticamente Lleno",
                "description": f"Disco al {disk_percent:.1f}%. Liberar espacio inmediatamente.",
                "confidence": 0.99,
                "auto_implement": True,
                "actions": [
                    {"type": "resource", "resource": "disk", "action": "cleanup_temp"},
                    {"type": "resource", "resource": "disk", "action": "compress_logs"}
                ],
                "expected_impact": "Liberar 10-30% de espacio en disco",
                "rollback_plan": "Restaurar archivos desde backup si es necesario"
            })

        elif disk_percent > 85:
            recommendations.append({
                "id": f"disk_high_{datetime.now().timestamp()}",
                "type": "resource",
                "category": RecommendationCategory.RESOURCE_OPTIMIZATION.value,
                "priority": RecommendationPriority.HIGH.value,
                "title": "Disco Casi Lleno",
                "description": f"Disco al {disk_percent:.1f}%. Limpiar archivos innecesarios.",
                "confidence": 0.85,
                "auto_implement": True,
                "actions": [
                    {"type": "resource", "resource": "disk", "action": "cleanup_temp"}
                ],
                "expected_impact": "Liberar 5-15% de espacio en disco"
            })

        return recommendations

    def _analyze_service_performance(self, metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Analiza rendimiento de servicios"""
        recommendations = []

        services = metrics.get("services", {})

        # Apache
        apache = services.get("apache", {})
        if apache.get("active_connections", 0) > 200:
            recommendations.append({
                "id": f"apache_connections_high_{datetime.now().timestamp()}",
                "type": "config",
                "category": RecommendationCategory.CONFIGURATION_TUNING.value,
                "priority": RecommendationPriority.MEDIUM.value,
                "title": "Apache - Muchas Conexiones Activas",
                "description": f"Apache tiene {apache['active_connections']} conexiones activas. Considerar ajuste de configuración.",
                "confidence": 0.75,
                "auto_implement": False,
                "actions": [
                    {"type": "config", "service": "apache", "action": "increase_max_clients"}
                ],
                "expected_impact": "Mejorar capacidad de manejo de conexiones"
            })

        # MySQL
        mysql = services.get("mysql", {})
        if mysql.get("active_connections", 0) > 50:
            recommendations.append({
                "id": f"mysql_connections_high_{datetime.now().timestamp()}",
                "type": "config",
                "category": RecommendationCategory.CONFIGURATION_TUNING.value,
                "priority": RecommendationPriority.MEDIUM.value,
                "title": "MySQL - Muchas Conexiones Activas",
                "description": f"MySQL tiene {mysql['active_connections']} conexiones activas. Optimizar configuración.",
                "confidence": 0.75,
                "auto_implement": False,
                "actions": [
                    {"type": "config", "service": "mysql", "action": "increase_max_connections"}
                ],
                "expected_impact": "Mejorar rendimiento de base de datos"
            })

        return recommendations

    def _analyze_predictions(self, predictions: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Analiza predicciones para generar recomendaciones preventivas"""
        recommendations = []

        pred_data = predictions.get("predictions", {})

        # Predicción de CPU alta
        cpu_pred = pred_data.get("cpu", {})
        if cpu_pred.get("predicted_percent", 0) > 85:
            recommendations.append({
                "id": f"cpu_predictive_{datetime.now().timestamp()}",
                "type": "preventive",
                "category": RecommendationCategory.PERFORMANCE.value,
                "priority": RecommendationPriority.MEDIUM.value,
                "title": "Predicción: CPU Alta Próximamente",
                "description": f"Se predice CPU al {cpu_pred['predicted_percent']:.1f}% en breve. Preparar optimizaciones.",
                "confidence": cpu_pred.get("confidence", 0),
                "auto_implement": False,
                "actions": [
                    {"type": "monitoring", "action": "increase_cpu_monitoring"},
                    {"type": "preventive", "action": "schedule_maintenance"}
                ],
                "expected_impact": "Prevenir degradación del rendimiento"
            })

        # Predicción de memoria baja
        memory_pred = pred_data.get("memory", {})
        if memory_pred.get("predicted_percent", 0) > 90:
            recommendations.append({
                "id": f"memory_predictive_{datetime.now().timestamp()}",
                "type": "preventive",
                "category": RecommendationCategory.RESOURCE_OPTIMIZATION.value,
                "priority": RecommendationPriority.HIGH.value,
                "title": "Predicción: Memoria Baja Próximamente",
                "description": f"Se predice memoria al {memory_pred['predicted_percent']:.1f}%. Preparar liberación de recursos.",
                "confidence": memory_pred.get("confidence", 0),
                "auto_implement": True,
                "actions": [
                    {"type": "resource", "resource": "memory", "action": "schedule_cache_cleanup"}
                ],
                "expected_impact": "Prevenir problemas de memoria"
            })

        return recommendations

    def _analyze_anomalies(self, anomalies: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Analiza anomalías detectadas"""
        recommendations = []

        for anomaly in anomalies:
            if anomaly.get("severity") == "high":
                recommendations.append({
                    "id": f"anomaly_{anomaly.get('type', 'unknown')}_{datetime.now().timestamp()}",
                    "type": "anomaly_response",
                    "category": RecommendationCategory.SECURITY.value,
                    "priority": RecommendationPriority.HIGH.value,
                    "title": f"Anomalía Detectada: {anomaly.get('type', 'Desconocida')}",
                    "description": f"Se detectó anomalía de alta severidad: {anomaly.get('type')}. Investigar inmediatamente.",
                    "confidence": 0.95,
                    "auto_implement": False,
                    "actions": [
                        {"type": "alert", "action": "send_security_alert"},
                        {"type": "monitoring", "action": "increase_anomaly_monitoring"}
                    ],
                    "anomaly_details": anomaly,
                    "expected_impact": "Mejorar seguridad y estabilidad"
                })

        return recommendations

    def _analyze_patterns(self, patterns: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Analiza patrones de uso para recomendaciones"""
        recommendations = []

        # Horas pico
        peak_hours = patterns.get("peak_hours", [])
        if peak_hours:
            recommendations.append({
                "id": f"peak_hours_{datetime.now().timestamp()}",
                "type": "scheduling",
                "category": RecommendationCategory.PERFORMANCE.value,
                "priority": RecommendationPriority.LOW.value,
                "title": "Patrón de Horas Pico Identificado",
                "description": f"Horas pico detectadas: {', '.join(map(str, peak_hours))}. Programar mantenimiento en horas valle.",
                "confidence": 0.80,
                "auto_implement": False,
                "actions": [
                    {"type": "scheduling", "action": "schedule_maintenance_off_peak"}
                ],
                "expected_impact": "Minimizar impacto en usuarios durante mantenimiento"
            })

        return recommendations

    def _filter_and_prioritize(self, recommendations: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Filtra y prioriza recomendaciones"""
        try:
            # Filtrar por confianza mínima
            filtered = [r for r in recommendations if r.get("confidence", 0) >= self.min_confidence]

            # Ordenar por prioridad (descendente)
            filtered.sort(key=lambda x: x.get("priority", 1), reverse=True)

            # Limitar número máximo de recomendaciones
            filtered = filtered[:self.max_recommendations]

            # Añadir timestamps y IDs únicos si no existen
            for rec in filtered:
                if "id" not in rec:
                    rec["id"] = f"rec_{datetime.now().timestamp()}"
                rec["generated_at"] = datetime.now().isoformat()

            return filtered

        except Exception as e:
            self.logger.error(f"Error filtrando recomendaciones: {e}")
            return []

    def _implement_single_recommendation(self, recommendation: Dict[str, Any]) -> bool:
        """Implementa una recomendación individual"""
        try:
            actions = recommendation.get("actions", [])

            for action in actions:
                action_type = action.get("type")

                if action_type == "resource":
                    # Implementar acción de recurso
                    success = self._implement_resource_action(action)
                    if not success:
                        return False

                elif action_type == "config":
                    # Implementar cambio de configuración
                    success = self._implement_config_action(action)
                    if not success:
                        return False

                elif action_type == "monitoring":
                    # Implementar cambio de monitoreo
                    success = self._implement_monitoring_action(action)
                    if not success:
                        return False

            return True

        except Exception as e:
            self.logger.error(f"Error implementando recomendación {recommendation.get('id')}: {e}")
            return False

    def _implement_resource_action(self, action: Dict[str, Any]) -> bool:
        """Implementa acción de recurso"""
        try:
            resource = action.get("resource")
            action_name = action.get("action")

            # Aquí se integraría con IntelligentResourceManager
            # Por ahora, simulamos implementación
            self.logger.info(f"Implementando acción de recurso: {resource} - {action_name}")
            return True

        except Exception as e:
            self.logger.error(f"Error implementando acción de recurso: {e}")
            return False

    def _implement_config_action(self, action: Dict[str, Any]) -> bool:
        """Implementa acción de configuración"""
        try:
            service = action.get("service")
            action_name = action.get("action")

            # Aquí se integraría con AutoConfigOptimizer
            # Por ahora, simulamos implementación
            self.logger.info(f"Implementando acción de configuración: {service} - {action_name}")
            return True

        except Exception as e:
            self.logger.error(f"Error implementando acción de configuración: {e}")
            return False

    def _implement_monitoring_action(self, action: Dict[str, Any]) -> bool:
        """Implementa acción de monitoreo"""
        try:
            action_name = action.get("action")

            # Aquí se implementaría cambio en configuración de monitoreo
            self.logger.info(f"Implementando acción de monitoreo: {action_name}")
            return True

        except Exception as e:
            self.logger.error(f"Error implementando acción de monitoreo: {e}")
            return False

    def _load_recommendation_rules(self) -> Dict[str, Any]:
        """Carga reglas de recomendación"""
        # Reglas básicas de recomendación
        return {
            "cpu_thresholds": {"warning": 80, "critical": 95},
            "memory_thresholds": {"warning": 85, "critical": 95},
            "disk_thresholds": {"warning": 90, "critical": 98},
            "response_time_thresholds": {"warning": 2000, "critical": 5000},
            "load_average_thresholds": {"warning": 3, "critical": 8}
        }

    def get_recommendation_history(self) -> List[Dict[str, Any]]:
        """Obtiene historial de recomendaciones"""
        return self.recommendation_history

    def get_active_recommendations(self) -> List[Dict[str, Any]]:
        """Obtiene recomendaciones activas"""
        return self.active_recommendations

    def dismiss_recommendation(self, recommendation_id: str) -> bool:
        """Descarta una recomendación"""
        try:
            self.active_recommendations = [
                r for r in self.active_recommendations
                if r.get("id") != recommendation_id
            ]
            self.logger.info(f"Recomendación descartada: {recommendation_id}")
            return True
        except Exception as e:
            self.logger.error(f"Error descartando recomendación: {e}")
            return False

    def get_recommendation_stats(self) -> Dict[str, Any]:
        """Obtiene estadísticas de recomendaciones"""
        try:
            total_generated = len(self.recommendation_history)
            total_implemented = len(self.implemented_recommendations)
            total_active = len(self.active_recommendations)

            # Estadísticas por categoría
            category_stats = {}
            for rec in self.recommendation_history:
                category = rec.get("category", "unknown")
                if category not in category_stats:
                    category_stats[category] = 0
                category_stats[category] += 1

            # Estadísticas por prioridad
            priority_stats = {}
            for rec in self.recommendation_history:
                priority = rec.get("priority", 1)
                if priority not in priority_stats:
                    priority_stats[priority] = 0
                priority_stats[priority] += 1

            return {
                "total_generated": total_generated,
                "total_implemented": total_implemented,
                "total_active": total_active,
                "implementation_rate": total_implemented / total_generated if total_generated > 0 else 0,
                "category_breakdown": category_stats,
                "priority_breakdown": priority_stats,
                "timestamp": datetime.now().isoformat()
            }

        except Exception as e:
            self.logger.error(f"Error obteniendo estadísticas: {e}")
            return {}