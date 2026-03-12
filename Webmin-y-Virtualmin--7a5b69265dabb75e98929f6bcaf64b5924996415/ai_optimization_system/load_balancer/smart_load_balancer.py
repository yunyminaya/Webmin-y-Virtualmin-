#!/usr/bin/env python3
"""
Smart Load Balancer - Balanceador de Carga Inteligente
Analiza patrones de uso y distribuye carga de manera inteligente
"""

import os
import json
import time
import logging
import threading
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
from collections import defaultdict
import psutil

class SmartLoadBalancer:
    """
    Balanceador de carga inteligente que analiza patrones de uso
    y distribuye recursos de manera óptima
    """

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger("SmartLoadBalancer")

        # Estado del balanceador
        self.nodes = {}  # Nodos disponibles para balanceo
        self.load_patterns = {}  # Patrones de carga por hora/día
        self.current_distribution = {}  # Distribución actual de carga
        self.performance_history = []  # Historial de rendimiento

        # Configuración de balanceo
        self.algorithm = config.get("load_balancing", {}).get("algorithm", "least_connections")
        self.health_check_interval = config.get("load_balancing", {}).get("health_check_interval", 30)
        self.max_connections_per_server = config.get("load_balancing", {}).get("max_connections_per_server", 1000)

        # Umbrales de balanceo
        self.cpu_threshold = config.get("performance_thresholds", {}).get("cpu_warning", 80)
        self.memory_threshold = config.get("performance_thresholds", {}).get("memory_warning", 85)

        # Hilos de monitoreo
        self.monitoring_thread = None
        self.is_running = False

        # Cargar estado anterior si existe
        self._load_state()

        self.logger.info("⚖️ Smart Load Balancer inicializado")

    def start(self):
        """Inicia el balanceador de carga"""
        if self.is_running:
            return

        self.is_running = True
        self.monitoring_thread = threading.Thread(target=self._monitoring_loop, daemon=True)
        self.monitoring_thread.start()

        self.logger.info("✅ Balanceador de carga iniciado")

    def stop(self):
        """Detiene el balanceador de carga"""
        self.is_running = False
        if self.monitoring_thread and self.monitoring_thread.is_alive():
            self.monitoring_thread.join(timeout=5)

        self._save_state()
        self.logger.info("🛑 Balanceador de carga detenido")

    def add_node(self, node_id: str, node_config: Dict[str, Any]) -> bool:
        """Añade un nodo al balanceador"""
        try:
            self.nodes[node_id] = {
                "config": node_config,
                "status": "unknown",
                "load": 0,
                "connections": 0,
                "last_health_check": None,
                "performance_score": 100,
                "enabled": True
            }

            self.logger.info(f"➕ Nodo añadido: {node_id}")
            return True

        except Exception as e:
            self.logger.error(f"Error añadiendo nodo {node_id}: {e}")
            return False

    def remove_node(self, node_id: str) -> bool:
        """Remueve un nodo del balanceador"""
        if node_id in self.nodes:
            del self.nodes[node_id]
            self.logger.info(f"➖ Nodo removido: {node_id}")
            return True
        return False

    def optimize_load_distribution(self, current_metrics: Dict[str, Any]) -> Dict[str, Any]:
        """Optimiza la distribución de carga basada en métricas actuales"""
        try:
            if not self.nodes:
                return {"action": "none", "reason": "no_nodes_available"}

            # Analizar carga actual
            load_analysis = self._analyze_current_load(current_metrics)

            # Detectar desequilibrios
            imbalances = self._detect_load_imbalances(load_analysis)

            if not imbalances:
                return {"action": "maintain", "reason": "load_balanced"}

            # Calcular redistribución óptima
            redistribution = self._calculate_optimal_redistribution(imbalances, load_analysis)

            # Aplicar redistribución
            success = self._apply_load_redistribution(redistribution)

            if success:
                self.logger.info(f"⚖️ Redistribución aplicada: {redistribution}")
                return {
                    "action": "redistributed",
                    "redistribution": redistribution,
                    "timestamp": datetime.now().isoformat()
                }
            else:
                return {"action": "failed", "reason": "redistribution_failed"}

        except Exception as e:
            self.logger.error(f"Error optimizando distribución de carga: {e}")
            return {"action": "error", "reason": str(e)}

    def get_load_metrics(self) -> Dict[str, Any]:
        """Obtiene métricas actuales de carga"""
        try:
            metrics = {
                "total_nodes": len(self.nodes),
                "active_nodes": len([n for n in self.nodes.values() if n["status"] == "healthy"]),
                "total_load": sum(n["load"] for n in self.nodes.values()),
                "average_load": 0,
                "load_distribution": {},
                "timestamp": datetime.now().isoformat()
            }

            if self.nodes:
                metrics["average_load"] = metrics["total_load"] / len(self.nodes)
                metrics["load_distribution"] = {
                    node_id: node["load"] for node_id, node in self.nodes.items()
                }

            return metrics

        except Exception as e:
            self.logger.error(f"Error obteniendo métricas de carga: {e}")
            return {}

    def predict_load_patterns(self, hours_ahead: int = 24) -> Dict[str, Any]:
        """Predice patrones de carga futuros"""
        try:
            predictions = {
                "hourly_predictions": [],
                "peak_hours": [],
                "recommended_scaling": {},
                "confidence": 0
            }

            # Análisis de patrones históricos
            if len(self.performance_history) < 24:  # Necesitamos al menos 24 horas de datos
                return predictions

            # Calcular promedios por hora
            hourly_patterns = self._analyze_hourly_patterns()

            # Predecir carga futura
            for hour in range(hours_ahead):
                future_hour = (datetime.now() + timedelta(hours=hour)).hour
                predicted_load = hourly_patterns.get(future_hour, 50)  # Default 50%

                predictions["hourly_predictions"].append({
                    "hour": future_hour,
                    "predicted_load": predicted_load,
                    "timestamp": (datetime.now() + timedelta(hours=hour)).isoformat()
                })

            # Identificar horas pico
            peak_threshold = sum(hourly_patterns.values()) / len(hourly_patterns) * 1.5
            predictions["peak_hours"] = [
                hour for hour, load in hourly_patterns.items()
                if load > peak_threshold
            ]

            # Recomendaciones de escalado
            predictions["recommended_scaling"] = self._calculate_scaling_recommendations(
                predictions["hourly_predictions"]
            )

            predictions["confidence"] = 0.8  # Placeholder - implementar cálculo real

            return predictions

        except Exception as e:
            self.logger.error(f"Error prediciendo patrones de carga: {e}")
            return {}

    def apply_load_change(self, change_request: Dict[str, Any]) -> bool:
        """Aplica un cambio en la distribución de carga"""
        try:
            change_type = change_request.get("type")
            target_node = change_request.get("node")
            new_load = change_request.get("load")

            if target_node not in self.nodes:
                self.logger.error(f"Nodo no encontrado: {target_node}")
                return False

            if change_type == "redirect_traffic":
                # Implementar redirección de tráfico
                self.nodes[target_node]["load"] = new_load
                self.logger.info(f"Tráfico redirigido a {target_node}: {new_load}%")
                return True

            elif change_type == "scale_up":
                # Implementar escalado hacia arriba
                self._scale_node_up(target_node)
                return True

            elif change_type == "scale_down":
                # Implementar escalado hacia abajo
                self._scale_node_down(target_node)
                return True

            else:
                self.logger.error(f"Tipo de cambio no soportado: {change_type}")
                return False

        except Exception as e:
            self.logger.error(f"Error aplicando cambio de carga: {e}")
            return False

    def _monitoring_loop(self):
        """Bucle de monitoreo continuo"""
        while self.is_running:
            try:
                self._perform_health_checks()
                self._update_load_patterns()
                self._record_performance_metrics()

                time.sleep(self.health_check_interval)

            except Exception as e:
                self.logger.error(f"Error en bucle de monitoreo: {e}")
                time.sleep(10)

    def _perform_health_checks(self):
        """Realiza chequeos de salud en todos los nodos"""
        for node_id, node in self.nodes.items():
            try:
                # Chequeo básico de conectividad
                is_healthy = self._check_node_health(node_id, node)

                # Actualizar estado del nodo
                node["status"] = "healthy" if is_healthy else "unhealthy"
                node["last_health_check"] = datetime.now()

                # Calcular score de rendimiento
                node["performance_score"] = self._calculate_performance_score(node)

            except Exception as e:
                self.logger.error(f"Error chequeando salud de {node_id}: {e}")
                node["status"] = "error"

    def _check_node_health(self, node_id: str, node: Dict[str, Any]) -> bool:
        """Verifica la salud de un nodo específico"""
        try:
            # Implementar diferentes tipos de chequeos según el tipo de nodo
            node_type = node["config"].get("type", "server")

            if node_type == "web_server":
                return self._check_web_server_health(node["config"])
            elif node_type == "database":
                return self._check_database_health(node["config"])
            elif node_type == "application":
                return self._check_application_health(node["config"])
            else:
                # Chequeo genérico - ping básico
                return self._check_generic_health(node["config"])

        except Exception as e:
            self.logger.error(f"Error en chequeo de salud de {node_id}: {e}")
            return False

    def _check_web_server_health(self, config: Dict[str, Any]) -> bool:
        """Chequea salud de servidor web"""
        try:
            import requests
            url = config.get("health_check_url", f"http://{config.get('host', 'localhost')}:{config.get('port', 80)}/health")
            response = requests.get(url, timeout=5)
            return response.status_code == 200
        except:
            return False

    def _check_database_health(self, config: Dict[str, Any]) -> bool:
        """Chequea salud de base de datos"""
        try:
            import mysql.connector
            conn = mysql.connector.connect(
                host=config.get("host", "localhost"),
                user=config.get("user", "root"),
                password=config.get("password", ""),
                database=config.get("database", ""),
                connection_timeout=5
            )
            conn.close()
            return True
        except:
            return False

    def _check_application_health(self, config: Dict[str, Any]) -> bool:
        """Chequea salud de aplicación"""
        try:
            # Chequeo de proceso
            import subprocess
            result = subprocess.run(
                ["pgrep", "-f", config.get("process_name", "")],
                capture_output=True,
                timeout=5
            )
            return result.returncode == 0
        except:
            return False

    def _check_generic_health(self, config: Dict[str, Any]) -> bool:
        """Chequeo de salud genérico"""
        try:
            import socket
            host = config.get("host", "localhost")
            port = config.get("port", 80)

            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((host, port))
            sock.close()

            return result == 0
        except:
            return False

    def _calculate_performance_score(self, node: Dict[str, Any]) -> float:
        """Calcula score de rendimiento de un nodo"""
        try:
            # Factores que afectan el score
            health_weight = 0.4
            load_weight = 0.3
            response_weight = 0.3

            # Score de salud (0-100)
            health_score = 100 if node["status"] == "healthy" else 0

            # Score de carga (mejor cuando está balanceado)
            load_score = max(0, 100 - abs(node["load"] - 50) * 2)

            # Score de respuesta (placeholder - implementar medición real)
            response_score = 100  # Placeholder

            total_score = (
                health_score * health_weight +
                load_score * load_weight +
                response_score * response_weight
            )

            return total_score

        except Exception as e:
            self.logger.error(f"Error calculando score de rendimiento: {e}")
            return 0

    def _analyze_current_load(self, metrics: Dict[str, Any]) -> Dict[str, Any]:
        """Analiza la carga actual del sistema"""
        analysis = {
            "total_cpu": metrics.get("cpu", {}).get("percent", 0),
            "total_memory": metrics.get("memory", {}).get("percent", 0),
            "total_connections": sum(n["connections"] for n in self.nodes.values()),
            "node_loads": {node_id: node["load"] for node_id, node in self.nodes.items()},
            "average_load": 0,
            "load_variance": 0
        }

        if self.nodes:
            loads = list(analysis["node_loads"].values())
            analysis["average_load"] = sum(loads) / len(loads)
            analysis["load_variance"] = sum((x - analysis["average_load"]) ** 2 for x in loads) / len(loads)

        return analysis

    def _detect_load_imbalances(self, load_analysis: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Detecta desequilibrios en la carga"""
        imbalances = []

        try:
            threshold = 20  # 20% de diferencia se considera desequilibrio

            for node_id, load in load_analysis["node_loads"].items():
                deviation = abs(load - load_analysis["average_load"])
                if deviation > threshold:
                    imbalances.append({
                        "node": node_id,
                        "current_load": load,
                        "target_load": load_analysis["average_load"],
                        "deviation": deviation,
                        "direction": "overloaded" if load > load_analysis["average_load"] else "underloaded"
                    })

            # Ordenar por severidad de desequilibrio
            imbalances.sort(key=lambda x: x["deviation"], reverse=True)

        except Exception as e:
            self.logger.error(f"Error detectando desequilibrios: {e}")

        return imbalances

    def _calculate_optimal_redistribution(self, imbalances: List[Dict[str, Any]],
                                        load_analysis: Dict[str, Any]) -> Dict[str, Any]:
        """Calcula la redistribución óptima de carga"""
        redistribution = {
            "transfers": [],
            "expected_improvement": 0
        }

        try:
            # Algoritmo simple: mover carga desde nodos sobrecargados a subutilizados
            overloaded = [imb for imb in imbalances if imb["direction"] == "overloaded"]
            underloaded = [imb for imb in imbalances if imb["direction"] == "underloaded"]

            for over in overloaded:
                for under in underloaded:
                    # Calcular cuánto mover
                    transfer_amount = min(
                        over["deviation"] / 2,  # Mitad de la desviación
                        (100 - under["current_load"]) / 2  # Mitad de la capacidad disponible
                    )

                    if transfer_amount > 5:  # Solo transferencias significativas
                        redistribution["transfers"].append({
                            "from_node": over["node"],
                            "to_node": under["node"],
                            "amount": transfer_amount
                        })

                        # Actualizar cargas esperadas
                        over["current_load"] -= transfer_amount
                        under["current_load"] += transfer_amount

            # Calcular mejora esperada
            new_variance = sum(
                (load - load_analysis["average_load"]) ** 2
                for load in [n["load"] for n in self.nodes.values()]
            ) / len(self.nodes)

            redistribution["expected_improvement"] = load_analysis["load_variance"] - new_variance

        except Exception as e:
            self.logger.error(f"Error calculando redistribución: {e}")

        return redistribution

    def _apply_load_redistribution(self, redistribution: Dict[str, Any]) -> bool:
        """Aplica la redistribución calculada de carga"""
        try:
            for transfer in redistribution["transfers"]:
                from_node = transfer["from_node"]
                to_node = transfer["to_node"]
                amount = transfer["amount"]

                # Actualizar cargas en los nodos
                if from_node in self.nodes and to_node in self.nodes:
                    self.nodes[from_node]["load"] = max(0, self.nodes[from_node]["load"] - amount)
                    self.nodes[to_node]["load"] = min(100, self.nodes[to_node]["load"] + amount)

                    # Aquí se implementaría la lógica real de redirección de tráfico
                    # Por ejemplo: actualizar configuración de proxy reverso, DNS, etc.

            return True

        except Exception as e:
            self.logger.error(f"Error aplicando redistribución: {e}")
            return False

    def _analyze_hourly_patterns(self) -> Dict[int, float]:
        """Analiza patrones de carga por hora"""
        patterns = defaultdict(list)

        try:
            # Agrupar datos por hora
            for entry in self.performance_history[-168:]:  # Última semana
                hour = datetime.fromisoformat(entry["timestamp"]).hour
                avg_load = sum(n["load"] for n in entry.get("nodes", {}).values()) / len(entry.get("nodes", {}))
                patterns[hour].append(avg_load)

            # Calcular promedios por hora
            return {hour: sum(loads) / len(loads) for hour, loads in patterns.items()}

        except Exception as e:
            self.logger.error(f"Error analizando patrones horarios: {e}")
            return {}

    def _calculate_scaling_recommendations(self, predictions: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Calcula recomendaciones de escalado"""
        recommendations = {
            "scale_up_hours": [],
            "scale_down_hours": [],
            "max_load_predicted": 0,
            "recommended_capacity": 1
        }

        try:
            high_load_threshold = 80
            low_load_threshold = 30

            max_load = 0
            for pred in predictions:
                load = pred["predicted_load"]
                max_load = max(max_load, load)

                if load > high_load_threshold:
                    recommendations["scale_up_hours"].append(pred["hour"])
                elif load < low_load_threshold:
                    recommendations["scale_down_hours"].append(pred["hour"])

            recommendations["max_load_predicted"] = max_load

            # Calcular capacidad recomendada
            if max_load > 90:
                recommendations["recommended_capacity"] = 3
            elif max_load > 70:
                recommendations["recommended_capacity"] = 2
            else:
                recommendations["recommended_capacity"] = 1

        except Exception as e:
            self.logger.error(f"Error calculando recomendaciones de escalado: {e}")

        return recommendations

    def _update_load_patterns(self):
        """Actualiza patrones de carga"""
        try:
            current_hour = datetime.now().hour
            current_load = sum(n["load"] for n in self.nodes.values()) / len(self.nodes) if self.nodes else 0

            if current_hour not in self.load_patterns:
                self.load_patterns[current_hour] = []

            self.load_patterns[current_hour].append(current_load)

            # Mantener solo últimas 7 mediciones por hora
            if len(self.load_patterns[current_hour]) > 7:
                self.load_patterns[current_hour] = self.load_patterns[current_hour][-7:]

        except Exception as e:
            self.logger.error(f"Error actualizando patrones de carga: {e}")

    def _record_performance_metrics(self):
        """Registra métricas de rendimiento"""
        try:
            entry = {
                "timestamp": datetime.now().isoformat(),
                "nodes": {node_id: dict(node) for node_id, node in self.nodes.items()},
                "total_load": sum(n["load"] for n in self.nodes.values()),
                "healthy_nodes": len([n for n in self.nodes.values() if n["status"] == "healthy"])
            }

            self.performance_history.append(entry)

            # Mantener historial limitado
            if len(self.performance_history) > 1000:
                self.performance_history = self.performance_history[-1000:]

        except Exception as e:
            self.logger.error(f"Error registrando métricas: {e}")

    def _scale_node_up(self, node_id: str):
        """Escala un nodo hacia arriba"""
        if node_id in self.nodes:
            self.nodes[node_id]["load"] = min(100, self.nodes[node_id]["load"] + 20)
            self.logger.info(f"⬆️ Nodo escalado hacia arriba: {node_id}")

    def _scale_node_down(self, node_id: str):
        """Escala un nodo hacia abajo"""
        if node_id in self.nodes:
            self.nodes[node_id]["load"] = max(0, self.nodes[node_id]["load"] - 20)
            self.logger.info(f"⬇️ Nodo escalado hacia abajo: {node_id}")

    def _load_state(self):
        """Carga estado guardado del balanceador"""
        try:
            state_file = os.path.join(os.path.dirname(__file__), "load_balancer_state.json")
            if os.path.exists(state_file):
                with open(state_file, 'r') as f:
                    state = json.load(f)

                self.nodes = state.get("nodes", {})
                self.load_patterns = state.get("load_patterns", {})
                self.current_distribution = state.get("current_distribution", {})

                self.logger.info("📂 Estado del balanceador cargado")

        except Exception as e:
            self.logger.error(f"Error cargando estado: {e}")

    def _save_state(self):
        """Guarda estado del balanceador"""
        try:
            state = {
                "nodes": self.nodes,
                "load_patterns": self.load_patterns,
                "current_distribution": self.current_distribution,
                "timestamp": datetime.now().isoformat()
            }

            state_file = os.path.join(os.path.dirname(__file__), "load_balancer_state.json")
            with open(state_file, 'w') as f:
                json.dump(state, f, indent=2, default=str)

            self.logger.info("💾 Estado del balanceador guardado")

        except Exception as e:
            self.logger.error(f"Error guardando estado: {e}")

    def get_status(self) -> Dict[str, Any]:
        """Obtiene estado completo del balanceador"""
        return {
            "is_running": self.is_running,
            "nodes": self.nodes,
            "load_metrics": self.get_load_metrics(),
            "load_patterns": self.load_patterns,
            "performance_history_count": len(self.performance_history),
            "algorithm": self.algorithm
        }