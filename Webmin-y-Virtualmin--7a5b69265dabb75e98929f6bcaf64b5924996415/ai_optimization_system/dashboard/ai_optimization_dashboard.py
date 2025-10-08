#!/usr/bin/env python3
"""
AI Optimization Dashboard - Dashboard de Optimización con IA
Interfaz web para monitorear y controlar el sistema de optimización
"""

import os
import json
import threading
from datetime import datetime, timedelta
from flask import Flask, render_template, jsonify, request, Response
from flask_cors import CORS
import logging

class AIOptimizationDashboard:
    """
    Dashboard web para el sistema de optimización con IA
    Proporciona interfaz para monitoreo y control en tiempo real
    """

    def __init__(self, ai_optimizer_core, host: str = "localhost", port: int = 8888):
        self.ai_optimizer = ai_optimizer_core
        self.host = host
        self.port = port

        # Configurar Flask
        self.app = Flask(__name__,
                        template_folder=os.path.join(os.path.dirname(__file__), "templates"),
                        static_folder=os.path.join(os.path.dirname(__file__), "static"))

        CORS(self.app)

        # Configurar logging
        self.logger = logging.getLogger("AIOptimizationDashboard")

        # Configurar rutas
        self._setup_routes()

        # Datos en tiempo real
        self.real_time_data = {}
        self.update_thread = None
        self.is_running = False

        self.logger.info(f"📊 Dashboard inicializado en {host}:{port}")

    def _setup_routes(self):
        """Configura las rutas del dashboard"""

        @self.app.route('/')
        def index():
            """Página principal del dashboard"""
            return render_template('index.html')

        @self.app.route('/api/status')
        def get_status():
            """Obtiene estado general del sistema"""
            try:
                status = self.ai_optimizer.get_system_status()
                return jsonify(status)
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route('/api/metrics')
        def get_metrics():
            """Obtiene métricas actuales"""
            try:
                # Combinar métricas de todos los componentes
                metrics = {}

                # Métricas de recursos
                if hasattr(self.ai_optimizer, 'resource_manager'):
                    metrics.update(self.ai_optimizer.resource_manager.get_resource_usage_report())

                # Predicciones
                if hasattr(self.ai_optimizer, 'predictive_analyzer'):
                    predictions = self.ai_optimizer.predictive_analyzer.analyze_performance_trends()
                    metrics["predictions"] = predictions

                # Recomendaciones activas
                if hasattr(self.ai_optimizer, 'recommendation_engine'):
                    recommendations = self.ai_optimizer.recommendation_engine.get_active_recommendations()
                    metrics["active_recommendations"] = recommendations

                return jsonify(metrics)

            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route('/api/recommendations')
        def get_recommendations():
            """Obtiene recomendaciones activas"""
            try:
                if hasattr(self.ai_optimizer, 'recommendation_engine'):
                    recommendations = self.ai_optimizer.recommendation_engine.get_active_recommendations()
                    return jsonify({"recommendations": recommendations})
                else:
                    return jsonify({"recommendations": []})

            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route('/api/optimization-history')
        def get_optimization_history():
            """Obtiene historial de optimizaciones"""
            try:
                history = []

                # Historial de configuraciones
                if hasattr(self.ai_optimizer, 'config_optimizer'):
                    config_history = self.ai_optimizer.config_optimizer.get_optimization_history()
                    history.extend([{"type": "config", **item} for item in config_history])

                # Historial de recursos
                if hasattr(self.ai_optimizer, 'resource_manager'):
                    resource_history = self.ai_optimizer.resource_manager.get_optimization_history()
                    history.extend([{"type": "resource", **item} for item in resource_history])

                # Historial de recomendaciones
                if hasattr(self.ai_optimizer, 'recommendation_engine'):
                    rec_history = self.ai_optimizer.recommendation_engine.get_recommendation_history()
                    history.extend([{"type": "recommendation", **item} for item in rec_history])

                # Ordenar por timestamp
                history.sort(key=lambda x: x.get("timestamp", ""), reverse=True)

                return jsonify({"history": history[:50]})  # Últimas 50

            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route('/api/load-balancer')
        def get_load_balancer_status():
            """Obtiene estado del balanceador de carga"""
            try:
                if hasattr(self.ai_optimizer, 'load_balancer'):
                    status = self.ai_optimizer.load_balancer.get_status()
                    return jsonify(status)
                else:
                    return jsonify({"error": "Load balancer not available"})

            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @self.app.route('/api/manual-optimization', methods=['POST'])
        def manual_optimization():
            """Ejecuta optimización manual"""
            try:
                data = request.get_json()
                service = data.get('service', 'all')

                result = self.ai_optimizer.manual_optimization(service)
                return jsonify(result)

            except Exception as e:
                return jsonify({"success": False, "error": str(e)}), 500

        @self.app.route('/api/recommendation-action', methods=['POST'])
        def recommendation_action():
            """Ejecuta acción sobre recomendación"""
            try:
                data = request.get_json()
                action = data.get('action')
                recommendation_id = data.get('recommendation_id')

                if action == 'implement' and hasattr(self.ai_optimizer, 'recommendation_engine'):
                    # Implementar recomendación
                    recommendations = self.ai_optimizer.recommendation_engine.get_active_recommendations()
                    rec = next((r for r in recommendations if r.get('id') == recommendation_id), None)

                    if rec:
                        success = self.ai_optimizer.recommendation_engine._implement_single_recommendation(rec)
                        return jsonify({"success": success})

                elif action == 'dismiss' and hasattr(self.ai_optimizer, 'recommendation_engine'):
                    # Descartar recomendación
                    success = self.ai_optimizer.recommendation_engine.dismiss_recommendation(recommendation_id)
                    return jsonify({"success": success})

                return jsonify({"success": False, "error": "Invalid action"})

            except Exception as e:
                return jsonify({"success": False, "error": str(e)}), 500

        @self.app.route('/api/system-control', methods=['POST'])
        def system_control():
            """Control del sistema (start/stop)"""
            try:
                data = request.get_json()
                action = data.get('action')

                if action == 'start':
                    # Aquí se implementaría el inicio del sistema
                    return jsonify({"success": True, "message": "Sistema iniciado"})

                elif action == 'stop':
                    # Aquí se implementaría la detención del sistema
                    return jsonify({"success": True, "message": "Sistema detenido"})

                elif action == 'restart':
                    # Aquí se implementaría el reinicio del sistema
                    return jsonify({"success": True, "message": "Sistema reiniciado"})

                return jsonify({"success": False, "error": "Acción no válida"})

            except Exception as e:
                return jsonify({"success": False, "error": str(e)}), 500

        @self.app.route('/api/real-time')
        def real_time_stream():
            """Stream de datos en tiempo real"""
            def generate():
                while self.is_running:
                    try:
                        # Generar datos en tiempo real
                        data = {
                            "timestamp": datetime.now().isoformat(),
                            "cpu": getattr(self.ai_optimizer.resource_manager, 'get_cpu_metrics', lambda: {})(),
                            "memory": getattr(self.ai_optimizer.resource_manager, 'get_memory_metrics', lambda: {})(),
                            "disk": getattr(self.ai_optimizer.resource_manager, 'get_disk_metrics', lambda: {})()
                        }

                        yield f"data: {json.dumps(data)}\n\n"
                        threading.Event().wait(1)  # Actualizar cada segundo

                    except Exception as e:
                        self.logger.error(f"Error en stream real-time: {e}")
                        break

            return Response(generate(), mimetype='text/event-stream')

    def start(self):
        """Inicia el dashboard"""
        if self.is_running:
            return

        self.is_running = True

        # Iniciar hilo de actualización de datos
        self.update_thread = threading.Thread(target=self._update_real_time_data, daemon=True)
        self.update_thread.start()

        self.logger.info(f"🚀 Dashboard iniciado en http://{self.host}:{self.port}")

        # Ejecutar Flask en un hilo separado
        dashboard_thread = threading.Thread(target=self._run_flask, daemon=True)
        dashboard_thread.start()

    def stop(self):
        """Detiene el dashboard"""
        self.is_running = False
        if self.update_thread and self.update_thread.is_alive():
            self.update_thread.join(timeout=5)

        self.logger.info("🛑 Dashboard detenido")

    def _run_flask(self):
        """Ejecuta la aplicación Flask"""
        try:
            self.app.run(host=self.host, port=self.port, debug=False, threaded=True)
        except Exception as e:
            self.logger.error(f"Error ejecutando Flask: {e}")

    def _update_real_time_data(self):
        """Actualiza datos en tiempo real"""
        while self.is_running:
            try:
                # Actualizar métricas en tiempo real
                self.real_time_data = {
                    "timestamp": datetime.now().isoformat(),
                    "system_status": self.ai_optimizer.get_system_status(),
                    "current_metrics": self._get_current_metrics_summary()
                }

                threading.Event().wait(5)  # Actualizar cada 5 segundos

            except Exception as e:
                self.logger.error(f"Error actualizando datos real-time: {e}")
                threading.Event().wait(10)

    def _get_current_metrics_summary(self) -> Dict[str, Any]:
        """Obtiene resumen de métricas actuales"""
        try:
            summary = {}

            if hasattr(self.ai_optimizer, 'resource_manager'):
                cpu = self.ai_optimizer.resource_manager.get_cpu_metrics()
                memory = self.ai_optimizer.resource_manager.get_memory_metrics()
                disk = self.ai_optimizer.resource_manager.get_disk_metrics()

                summary = {
                    "cpu_percent": cpu.get("percent", 0),
                    "memory_percent": memory.get("percent", 0),
                    "disk_percent": disk.get("percent", 0),
                    "load_average": cpu.get("load_1m", 0)
                }

            return summary

        except Exception as e:
            self.logger.error(f"Error obteniendo resumen de métricas: {e}")
            return {}