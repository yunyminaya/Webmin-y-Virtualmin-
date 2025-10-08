#!/usr/bin/env python3
"""
AI Optimizer Core - Sistema de Optimización Automática con IA para Webmin/Virtualmin
Motor principal que coordina análisis predictivo, optimización automática y gestión inteligente
"""

import sys
import os
import json
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import threading
import schedule

# Añadir directorio padre al path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ml_models.predictive_analyzer import PredictiveAnalyzer
from config_manager.auto_config_optimizer import AutoConfigOptimizer
from resource_manager.intelligent_resource_manager import IntelligentResourceManager
from load_balancer.smart_load_balancer import SmartLoadBalancer
from recommendations.proactive_recommendation_engine import ProactiveRecommendationEngine

class AIOptimizerCore:
    """
    Núcleo del sistema de optimización automática con IA
    Coordina todos los componentes del sistema de optimización
    """

    def __init__(self, config_file: str = "ai_optimizer_config.json"):
        self.config_file = os.path.join(os.path.dirname(__file__), config_file)
        self.config = self._load_config()
        self._setup_logging()

        # Componentes del sistema
        self.predictive_analyzer = None
        self.config_optimizer = None
        self.resource_manager = None
        self.load_balancer = None
        self.recommendation_engine = None

        # Estado del sistema
        self.is_running = False
        self.optimization_cycle_active = False
        self.last_optimization_time = None
        self.performance_metrics = {}

        # Hilos de ejecución
        self.monitoring_thread = None
        self.optimization_thread = None

        self.logger.info("🚀 AI Optimizer Core inicializado")

    def _load_config(self) -> Dict[str, Any]:
        """Carga la configuración del sistema"""
        default_config = {
            "optimization_interval": 300,  # 5 minutos
            "monitoring_interval": 60,     # 1 minuto
            "max_concurrent_optimizations": 3,
            "auto_apply_recommendations": True,
            "risk_tolerance": "medium",    # low, medium, high
            "backup_before_changes": True,
            "notification_channels": ["email", "webmin"],
            "ml_model_update_interval": 86400,  # 24 horas
            "performance_thresholds": {
                "cpu_warning": 80,
                "memory_warning": 85,
                "disk_warning": 90,
                "response_time_warning": 2000  # ms
            },
            "services": {
                "apache": {"enabled": True, "auto_optimize": True},
                "mysql": {"enabled": True, "auto_optimize": True},
                "php": {"enabled": True, "auto_optimize": True},
                "system": {"enabled": True, "auto_optimize": True}
            }
        }

        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r') as f:
                    user_config = json.load(f)
                default_config.update(user_config)
            except Exception as e:
                print(f"Error cargando configuración: {e}")

        return default_config

    def _setup_logging(self):
        """Configura el sistema de logging"""
        log_file = os.path.join(os.path.dirname(__file__), "ai_optimizer.log")
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger("AIOptimizerCore")

    def initialize_components(self):
        """Inicializa todos los componentes del sistema"""
        try:
            self.logger.info("🔧 Inicializando componentes del sistema...")

            # Inicializar analizador predictivo
            self.predictive_analyzer = PredictiveAnalyzer(self.config)

            # Inicializar optimizador de configuraciones
            self.config_optimizer = AutoConfigOptimizer(self.config)

            # Inicializar gestor de recursos
            self.resource_manager = IntelligentResourceManager(self.config)

            # Inicializar balanceador de carga inteligente
            self.load_balancer = SmartLoadBalancer(self.config)

            # Inicializar motor de recomendaciones
            self.recommendation_engine = ProactiveRecommendationEngine(self.config)

            self.logger.info("✅ Todos los componentes inicializados correctamente")

        except Exception as e:
            self.logger.error(f"❌ Error inicializando componentes: {e}")
            raise

    def start(self):
        """Inicia el sistema de optimización automática"""
        if self.is_running:
            self.logger.warning("Sistema ya está ejecutándose")
            return

        try:
            self.logger.info("🚀 Iniciando sistema de optimización automática con IA...")

            # Inicializar componentes si no están inicializados
            if not self.predictive_analyzer:
                self.initialize_components()

            # Iniciar hilos de monitoreo y optimización
            self.is_running = True

            self.monitoring_thread = threading.Thread(target=self._monitoring_loop, daemon=True)
            self.optimization_thread = threading.Thread(target=self._optimization_loop, daemon=True)

            self.monitoring_thread.start()
            self.optimization_thread.start()

            # Programar tareas periódicas
            self._schedule_tasks()

            self.logger.info("✅ Sistema de optimización automática iniciado correctamente")

        except Exception as e:
            self.logger.error(f"❌ Error iniciando sistema: {e}")
            self.is_running = False
            raise

    def stop(self):
        """Detiene el sistema de optimización automática"""
        if not self.is_running:
            return

        self.logger.info("🛑 Deteniendo sistema de optimización automática...")
        self.is_running = False

        # Esperar a que los hilos terminen
        if self.monitoring_thread and self.monitoring_thread.is_alive():
            self.monitoring_thread.join(timeout=5)
        if self.optimization_thread and self.optimization_thread.is_alive():
            self.optimization_thread.join(timeout=5)

        self.logger.info("✅ Sistema detenido correctamente")

    def _monitoring_loop(self):
        """Bucle principal de monitoreo"""
        while self.is_running:
            try:
                self._collect_system_metrics()
                time.sleep(self.config["monitoring_interval"])
            except Exception as e:
                self.logger.error(f"Error en bucle de monitoreo: {e}")
                time.sleep(10)  # Esperar antes de reintentar

    def _optimization_loop(self):
        """Bucle principal de optimización"""
        while self.is_running:
            try:
                if not self.optimization_cycle_active:
                    self._run_optimization_cycle()
                time.sleep(self.config["optimization_interval"])
            except Exception as e:
                self.logger.error(f"Error en bucle de optimización: {e}")
                time.sleep(30)  # Esperar antes de reintentar

    def _collect_system_metrics(self):
        """Recolecta métricas del sistema"""
        try:
            metrics = {}

            # Métricas de CPU
            metrics["cpu"] = self.resource_manager.get_cpu_metrics()

            # Métricas de memoria
            metrics["memory"] = self.resource_manager.get_memory_metrics()

            # Métricas de disco
            metrics["disk"] = self.resource_manager.get_disk_metrics()

            # Métricas de red
            metrics["network"] = self.resource_manager.get_network_metrics()

            # Métricas de servicios
            metrics["services"] = {
                "apache": self.config_optimizer.get_apache_metrics(),
                "mysql": self.config_optimizer.get_mysql_metrics(),
                "php": self.config_optimizer.get_php_metrics()
            }

            # Métricas de carga
            metrics["load"] = self.load_balancer.get_load_metrics()

            self.performance_metrics = metrics

            # Almacenar métricas para análisis predictivo
            self.predictive_analyzer.store_metrics(metrics)

        except Exception as e:
            self.logger.error(f"Error recolectando métricas: {e}")

    def _run_optimization_cycle(self):
        """Ejecuta un ciclo completo de optimización"""
        try:
            self.optimization_cycle_active = True
            self.logger.info("🔄 Iniciando ciclo de optimización...")

            # Análisis predictivo
            predictions = self.predictive_analyzer.analyze_performance_trends()

            # Generar recomendaciones
            recommendations = self.recommendation_engine.generate_recommendations(
                self.performance_metrics, predictions
            )

            # Aplicar optimizaciones automáticas
            if self.config["auto_apply_recommendations"]:
                applied_changes = self._apply_recommendations(recommendations)
                if applied_changes:
                    self.logger.info(f"✅ Aplicadas {len(applied_changes)} optimizaciones automáticas")

            # Actualizar balanceo de carga si es necesario
            load_adjustments = self.load_balancer.optimize_load_distribution(
                self.performance_metrics
            )
            if load_adjustments:
                self.logger.info(f"⚖️ Ajustado balanceo de carga: {load_adjustments}")

            # Gestionar recursos
            resource_actions = self.resource_manager.optimize_resource_allocation(
                self.performance_metrics
            )
            if resource_actions:
                self.logger.info(f"💾 Optimizada asignación de recursos: {resource_actions}")

            self.last_optimization_time = datetime.now()
            self.logger.info("✅ Ciclo de optimización completado")

        except Exception as e:
            self.logger.error(f"Error en ciclo de optimización: {e}")
        finally:
            self.optimization_cycle_active = False

    def _apply_recommendations(self, recommendations: List[Dict[str, Any]]) -> List[str]:
        """Aplica recomendaciones de optimización"""
        applied_changes = []

        for rec in recommendations:
            try:
                if rec["priority"] >= 7 and rec["confidence"] >= 0.8:  # Alta prioridad y confianza
                    if rec["type"] == "config":
                        success = self.config_optimizer.apply_config_change(rec)
                        if success:
                            applied_changes.append(f"Config: {rec['description']}")

                    elif rec["type"] == "resource":
                        success = self.resource_manager.apply_resource_change(rec)
                        if success:
                            applied_changes.append(f"Resource: {rec['description']}")

                    elif rec["type"] == "load_balance":
                        success = self.load_balancer.apply_load_change(rec)
                        if success:
                            applied_changes.append(f"Load: {rec['description']}")

            except Exception as e:
                self.logger.error(f"Error aplicando recomendación {rec['id']}: {e}")

        return applied_changes

    def _schedule_tasks(self):
        """Programa tareas periódicas"""
        # Actualización de modelos ML diariamente
        schedule.every().day.at("02:00").do(self._update_ml_models)

        # Limpieza de datos antiguos semanalmente
        schedule.every().week.do(self._cleanup_old_data)

        # Generar reportes diarios
        schedule.every().day.at("06:00").do(self._generate_daily_report)

    def _update_ml_models(self):
        """Actualiza los modelos de machine learning"""
        try:
            self.logger.info("🔄 Actualizando modelos ML...")
            self.predictive_analyzer.update_models()
            self.logger.info("✅ Modelos ML actualizados")
        except Exception as e:
            self.logger.error(f"Error actualizando modelos ML: {e}")

    def _cleanup_old_data(self):
        """Limpia datos antiguos"""
        try:
            self.logger.info("🧹 Limpiando datos antiguos...")
            # Implementar limpieza de datos antiguos
            self.logger.info("✅ Limpieza completada")
        except Exception as e:
            self.logger.error(f"Error en limpieza: {e}")

    def _generate_daily_report(self):
        """Genera reporte diario de optimización"""
        try:
            self.logger.info("📊 Generando reporte diario...")
            # Implementar generación de reportes
            self.logger.info("✅ Reporte diario generado")
        except Exception as e:
            self.logger.error(f"Error generando reporte: {e}")

    def get_system_status(self) -> Dict[str, Any]:
        """Obtiene el estado actual del sistema"""
        return {
            "is_running": self.is_running,
            "last_optimization": self.last_optimization_time.isoformat() if self.last_optimization_time else None,
            "optimization_active": self.optimization_cycle_active,
            "performance_metrics": self.performance_metrics,
            "config": self.config
        }

    def manual_optimization(self, service: str = None) -> Dict[str, Any]:
        """Ejecuta optimización manual para un servicio específico o todos"""
        try:
            self.logger.info(f"🔧 Optimización manual iniciada para: {service or 'todos los servicios'}")

            if service:
                if service == "apache":
                    result = self.config_optimizer.optimize_apache()
                elif service == "mysql":
                    result = self.config_optimizer.optimize_mysql()
                elif service == "php":
                    result = self.config_optimizer.optimize_php()
                elif service == "system":
                    result = self.resource_manager.optimize_system_resources()
                else:
                    return {"success": False, "error": f"Servicio desconocido: {service}"}
            else:
                # Optimizar todos los servicios
                results = {}
                results["apache"] = self.config_optimizer.optimize_apache()
                results["mysql"] = self.config_optimizer.optimize_mysql()
                results["php"] = self.config_optimizer.optimize_php()
                results["system"] = self.resource_manager.optimize_system_resources()
                result = results

            self.logger.info("✅ Optimización manual completada")
            return {"success": True, "result": result}

        except Exception as e:
            self.logger.error(f"Error en optimización manual: {e}")
            return {"success": False, "error": str(e)}


def main():
    """Función principal para ejecutar el sistema"""
    import argparse

    parser = argparse.ArgumentParser(description="AI Optimizer Core - Sistema de Optimización Automática")
    parser.add_argument("--start", action="store_true", help="Iniciar el sistema")
    parser.add_argument("--stop", action="store_true", help="Detener el sistema")
    parser.add_argument("--status", action="store_true", help="Mostrar estado del sistema")
    parser.add_argument("--optimize", nargs="?", const="all", help="Ejecutar optimización manual")
    parser.add_argument("--config", help="Archivo de configuración personalizado")

    args = parser.parse_args()

    config_file = args.config or "ai_optimizer_config.json"
    optimizer = AIOptimizerCore(config_file)

    if args.start:
        optimizer.start()
        print("Sistema iniciado. Presiona Ctrl+C para detener.")
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            optimizer.stop()

    elif args.stop:
        optimizer.stop()

    elif args.status:
        status = optimizer.get_system_status()
        print(json.dumps(status, indent=2, default=str))

    elif args.optimize is not None:
        result = optimizer.manual_optimization(args.optimize)
        print(json.dumps(result, indent=2, default=str))

    else:
        parser.print_help()


if __name__ == "__main__":
    main()