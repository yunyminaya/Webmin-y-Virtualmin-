#!/usr/bin/env python3
"""
Predictive Analyzer - Módulo de Análisis Predictivo con Machine Learning
Utiliza algoritmos ML para predecir rendimiento del sistema y detectar anomalías
"""

import sys
import os
import json
import pickle
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
import logging
import threading
from sklearn.ensemble import RandomForestRegressor, IsolationForest
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, mean_squared_error
import joblib

class PredictiveAnalyzer:
    """
    Analizador predictivo que utiliza machine learning para:
    - Predecir uso de recursos (CPU, memoria, disco)
    - Detectar anomalías en el rendimiento
    - Predecir tiempos de respuesta
    - Identificar patrones de carga
    """

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger("PredictiveAnalyzer")

        # Modelos ML
        self.cpu_predictor = None
        self.memory_predictor = None
        self.disk_predictor = None
        self.response_time_predictor = None
        self.anomaly_detector = None

        # Escaladores para normalización
        self.scaler = StandardScaler()

        # Datos históricos
        self.metrics_history = []
        self.max_history_size = 10000

        # Modelos entrenados
        self.models_dir = os.path.join(os.path.dirname(__file__), "trained_models")
        os.makedirs(self.models_dir, exist_ok=True)

        # Estado del sistema
        self.is_trained = False
        self.last_training_time = None
        self.model_accuracy = {}

        self.logger.info("🔮 Predictive Analyzer inicializado")

    def store_metrics(self, metrics: Dict[str, Any]):
        """Almacena métricas para entrenamiento de modelos"""
        try:
            # Crear entrada de datos con timestamp
            data_point = {
                "timestamp": datetime.now().isoformat(),
                "cpu_percent": metrics.get("cpu", {}).get("percent", 0),
                "cpu_load_1m": metrics.get("cpu", {}).get("load_1m", 0),
                "cpu_load_5m": metrics.get("cpu", {}).get("load_5m", 0),
                "cpu_load_15m": metrics.get("cpu", {}).get("load_15m", 0),
                "memory_percent": metrics.get("memory", {}).get("percent", 0),
                "memory_used": metrics.get("memory", {}).get("used", 0),
                "memory_available": metrics.get("memory", {}).get("available", 0),
                "disk_percent": metrics.get("disk", {}).get("percent", 0),
                "disk_used": metrics.get("disk", {}).get("used", 0),
                "disk_free": metrics.get("disk", {}).get("free", 0),
                "network_rx": metrics.get("network", {}).get("rx_bytes", 0),
                "network_tx": metrics.get("network", {}).get("tx_bytes", 0),
                "apache_requests": metrics.get("services", {}).get("apache", {}).get("requests_per_second", 0),
                "apache_connections": metrics.get("services", {}).get("apache", {}).get("active_connections", 0),
                "mysql_queries": metrics.get("services", {}).get("mysql", {}).get("queries_per_second", 0),
                "mysql_connections": metrics.get("services", {}).get("mysql", {}).get("active_connections", 0),
                "php_processes": metrics.get("services", {}).get("php", {}).get("active_processes", 0),
                "load_average": metrics.get("load", {}).get("average", 0),
                "response_time": metrics.get("services", {}).get("apache", {}).get("avg_response_time", 0)
            }

            self.metrics_history.append(data_point)

            # Mantener tamaño máximo del historial
            if len(self.metrics_history) > self.max_history_size:
                self.metrics_history = self.metrics_history[-self.max_history_size:]

            # Entrenar modelos si hay suficientes datos
            if len(self.metrics_history) >= 100 and not self.is_trained:
                threading.Thread(target=self._train_models_async, daemon=True).start()

        except Exception as e:
            self.logger.error(f"Error almacenando métricas: {e}")

    def analyze_performance_trends(self) -> Dict[str, Any]:
        """Analiza tendencias de rendimiento usando modelos ML"""
        try:
            if not self.is_trained:
                return self._get_basic_analysis()

            predictions = {}

            # Preparar datos recientes
            recent_data = self._get_recent_data(hours=1)

            if len(recent_data) < 10:
                return self._get_basic_analysis()

            # Predicciones de CPU
            cpu_prediction = self._predict_cpu_usage(recent_data)
            predictions["cpu"] = cpu_prediction

            # Predicciones de memoria
            memory_prediction = self._predict_memory_usage(recent_data)
            predictions["memory"] = memory_prediction

            # Predicciones de disco
            disk_prediction = self._predict_disk_usage(recent_data)
            predictions["disk"] = disk_prediction

            # Predicciones de tiempo de respuesta
            response_prediction = self._predict_response_time(recent_data)
            predictions["response_time"] = response_prediction

            # Detección de anomalías
            anomalies = self._detect_anomalies(recent_data)
            predictions["anomalies"] = anomalies

            # Análisis de patrones
            patterns = self._analyze_patterns(recent_data)
            predictions["patterns"] = patterns

            return {
                "predictions": predictions,
                "confidence": self.model_accuracy,
                "timestamp": datetime.now().isoformat()
            }

        except Exception as e:
            self.logger.error(f"Error analizando tendencias: {e}")
            return self._get_basic_analysis()

    def _predict_cpu_usage(self, data: pd.DataFrame) -> Dict[str, Any]:
        """Predice uso futuro de CPU"""
        try:
            if not self.cpu_predictor:
                return {"predicted_percent": 0, "confidence": 0}

            # Preparar features
            features = self._prepare_cpu_features(data)

            # Hacer predicción
            prediction = self.cpu_predictor.predict(features.iloc[-1:])[0]

            # Calcular intervalo de confianza
            confidence = self._calculate_prediction_confidence(features, self.cpu_predictor)

            return {
                "predicted_percent": max(0, min(100, prediction)),
                "confidence": confidence,
                "trend": self._calculate_trend(data["cpu_percent"].tail(10).values),
                "peak_expected": prediction > self.config["performance_thresholds"]["cpu_warning"]
            }

        except Exception as e:
            self.logger.error(f"Error prediciendo CPU: {e}")
            return {"predicted_percent": 0, "confidence": 0}

    def _predict_memory_usage(self, data: pd.DataFrame) -> Dict[str, Any]:
        """Predice uso futuro de memoria"""
        try:
            if not self.memory_predictor:
                return {"predicted_percent": 0, "confidence": 0}

            features = self._prepare_memory_features(data)
            prediction = self.memory_predictor.predict(features.iloc[-1:])[0]
            confidence = self._calculate_prediction_confidence(features, self.memory_predictor)

            return {
                "predicted_percent": max(0, min(100, prediction)),
                "confidence": confidence,
                "trend": self._calculate_trend(data["memory_percent"].tail(10).values),
                "critical_expected": prediction > self.config["performance_thresholds"]["memory_warning"]
            }

        except Exception as e:
            self.logger.error(f"Error prediciendo memoria: {e}")
            return {"predicted_percent": 0, "confidence": 0}

    def _predict_disk_usage(self, data: pd.DataFrame) -> Dict[str, Any]:
        """Predice uso futuro de disco"""
        try:
            if not self.disk_predictor:
                return {"predicted_percent": 0, "confidence": 0}

            features = self._prepare_disk_features(data)
            prediction = self.disk_predictor.predict(features.iloc[-1:])[0]
            confidence = self._calculate_prediction_confidence(features, self.disk_predictor)

            return {
                "predicted_percent": max(0, min(100, prediction)),
                "confidence": confidence,
                "trend": self._calculate_trend(data["disk_percent"].tail(10).values),
                "warning_expected": prediction > self.config["performance_thresholds"]["disk_warning"]
            }

        except Exception as e:
            self.logger.error(f"Error prediciendo disco: {e}")
            return {"predicted_percent": 0, "confidence": 0}

    def _predict_response_time(self, data: pd.DataFrame) -> Dict[str, Any]:
        """Predice tiempo de respuesta futuro"""
        try:
            if not self.response_time_predictor:
                return {"predicted_ms": 0, "confidence": 0}

            features = self._prepare_response_features(data)
            prediction = self.response_time_predictor.predict(features.iloc[-1:])[0]
            confidence = self._calculate_prediction_confidence(features, self.response_time_predictor)

            return {
                "predicted_ms": max(0, prediction),
                "confidence": confidence,
                "trend": self._calculate_trend(data["response_time"].tail(10).values),
                "slow_expected": prediction > self.config["performance_thresholds"]["response_time_warning"]
            }

        except Exception as e:
            self.logger.error(f"Error prediciendo respuesta: {e}")
            return {"predicted_ms": 0, "confidence": 0}

    def _detect_anomalies(self, data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Detecta anomalías en las métricas"""
        anomalies = []

        try:
            if not self.anomaly_detector:
                return anomalies

            # Preparar datos para detección de anomalías
            features = self._prepare_anomaly_features(data)
            anomaly_scores = self.anomaly_detector.decision_function(features)
            predictions = self.anomaly_detector.predict(features)

            # Identificar anomalías recientes
            recent_anomalies = np.where(predictions == -1)[0]
            for idx in recent_anomalies[-5:]:  # Últimas 5 anomalías
                anomaly_time = data.iloc[idx]["timestamp"]
                score = anomaly_scores[idx]

                # Clasificar tipo de anomalía
                anomaly_type = self._classify_anomaly(data.iloc[idx])

                anomalies.append({
                    "timestamp": anomaly_time,
                    "type": anomaly_type,
                    "severity": "high" if abs(score) > 0.8 else "medium",
                    "score": float(score),
                    "metrics": {
                        "cpu": data.iloc[idx]["cpu_percent"],
                        "memory": data.iloc[idx]["memory_percent"],
                        "disk": data.iloc[idx]["disk_percent"]
                    }
                })

        except Exception as e:
            self.logger.error(f"Error detectando anomalías: {e}")

        return anomalies

    def _analyze_patterns(self, data: pd.DataFrame) -> Dict[str, Any]:
        """Analiza patrones en los datos de rendimiento"""
        try:
            patterns = {
                "peak_hours": self._identify_peak_hours(data),
                "load_patterns": self._identify_load_patterns(data),
                "resource_correlations": self._analyze_resource_correlations(data),
                "seasonal_trends": self._detect_seasonal_trends(data)
            }

            return patterns

        except Exception as e:
            self.logger.error(f"Error analizando patrones: {e}")
            return {}

    def _train_models_async(self):
        """Entrena modelos ML de forma asíncrona"""
        try:
            self.logger.info("🤖 Iniciando entrenamiento de modelos ML...")

            if len(self.metrics_history) < 100:
                self.logger.warning("Datos insuficientes para entrenamiento")
                return

            # Convertir a DataFrame
            df = pd.DataFrame(self.metrics_history)
            df["timestamp"] = pd.to_datetime(df["timestamp"])

            # Entrenar modelos
            self._train_cpu_model(df)
            self._train_memory_model(df)
            self._train_disk_model(df)
            self._train_response_time_model(df)
            self._train_anomaly_detector(df)

            # Guardar modelos
            self._save_models()

            self.is_trained = True
            self.last_training_time = datetime.now()

            self.logger.info("✅ Modelos ML entrenados y guardados")

        except Exception as e:
            self.logger.error(f"Error entrenando modelos: {e}")

    def _train_cpu_model(self, df: pd.DataFrame):
        """Entrena modelo de predicción de CPU"""
        try:
            # Preparar datos
            features = self._prepare_cpu_features(df)
            target = df["cpu_percent"].shift(-1).dropna()  # Predecir siguiente valor
            features = features.iloc[:-1]  # Alinear con target

            if len(features) < 50:
                return

            # Dividir datos
            X_train, X_test, y_train, y_test = train_test_split(
                features, target, test_size=0.2, random_state=42
            )

            # Entrenar modelo
            self.cpu_predictor = RandomForestRegressor(
                n_estimators=100,
                max_depth=10,
                random_state=42
            )
            self.cpu_predictor.fit(X_train, y_train)

            # Evaluar modelo
            y_pred = self.cpu_predictor.predict(X_test)
            mae = mean_absolute_error(y_test, y_pred)
            self.model_accuracy["cpu"] = 1 - (mae / 100)  # Normalizar a 0-1

            self.logger.info(".2f")

        except Exception as e:
            self.logger.error(f"Error entrenando modelo CPU: {e}")

    def _train_memory_model(self, df: pd.DataFrame):
        """Entrena modelo de predicción de memoria"""
        try:
            features = self._prepare_memory_features(df)
            target = df["memory_percent"].shift(-1).dropna()
            features = features.iloc[:-1]

            if len(features) < 50:
                return

            X_train, X_test, y_train, y_test = train_test_split(
                features, target, test_size=0.2, random_state=42
            )

            self.memory_predictor = RandomForestRegressor(
                n_estimators=100,
                max_depth=10,
                random_state=42
            )
            self.memory_predictor.fit(X_train, y_train)

            y_pred = self.memory_predictor.predict(X_test)
            mae = mean_absolute_error(y_test, y_pred)
            self.model_accuracy["memory"] = 1 - (mae / 100)

            self.logger.info(".2f")

        except Exception as e:
            self.logger.error(f"Error entrenando modelo memoria: {e}")

    def _train_disk_model(self, df: pd.DataFrame):
        """Entrena modelo de predicción de disco"""
        try:
            features = self._prepare_disk_features(df)
            target = df["disk_percent"].shift(-1).dropna()
            features = features.iloc[:-1]

            if len(features) < 50:
                return

            X_train, X_test, y_train, y_test = train_test_split(
                features, target, test_size=0.2, random_state=42
            )

            self.disk_predictor = RandomForestRegressor(
                n_estimators=100,
                max_depth=10,
                random_state=42
            )
            self.disk_predictor.fit(X_train, y_train)

            y_pred = self.disk_predictor.predict(X_test)
            mae = mean_absolute_error(y_test, y_pred)
            self.model_accuracy["disk"] = 1 - (mae / 100)

            self.logger.info(".2f")

        except Exception as e:
            self.logger.error(f"Error entrenando modelo disco: {e}")

    def _train_response_time_model(self, df: pd.DataFrame):
        """Entrena modelo de predicción de tiempo de respuesta"""
        try:
            features = self._prepare_response_features(df)
            target = df["response_time"].shift(-1).dropna()
            features = features.iloc[:-1]

            if len(features) < 50:
                return

            X_train, X_test, y_train, y_test = train_test_split(
                features, target, test_size=0.2, random_state=42
            )

            self.response_time_predictor = RandomForestRegressor(
                n_estimators=100,
                max_depth=10,
                random_state=42
            )
            self.response_time_predictor.fit(X_train, y_train)

            y_pred = self.response_time_predictor.predict(X_test)
            mae = mean_absolute_error(y_test, y_pred)
            self.model_accuracy["response_time"] = 1 - (mae / 5000)  # Normalizar basado en threshold

            self.logger.info(".2f")

        except Exception as e:
            self.logger.error(f"Error entrenando modelo respuesta: {e}")

    def _train_anomaly_detector(self, df: pd.DataFrame):
        """Entrena detector de anomalías"""
        try:
            features = self._prepare_anomaly_features(df)

            if len(features) < 50:
                return

            self.anomaly_detector = IsolationForest(
                contamination=0.1,
                random_state=42
            )
            self.anomaly_detector.fit(features)

            self.logger.info("✅ Detector de anomalías entrenado")

        except Exception as e:
            self.logger.error(f"Error entrenando detector de anomalías: {e}")

    def _prepare_cpu_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Prepara features para modelo de CPU"""
        features = df[[
            "cpu_load_1m", "cpu_load_5m", "cpu_load_15m",
            "memory_percent", "apache_requests", "mysql_queries",
            "network_rx", "network_tx"
        ]].copy()

        # Añadir features derivadas
        features["cpu_trend_5"] = df["cpu_percent"].rolling(5).mean()
        features["cpu_trend_10"] = df["cpu_percent"].rolling(10).mean()
        features["hour"] = pd.to_datetime(df["timestamp"]).dt.hour
        features["day_of_week"] = pd.to_datetime(df["timestamp"]).dt.dayofweek

        return features.fillna(0)

    def _prepare_memory_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Prepara features para modelo de memoria"""
        features = df[[
            "cpu_percent", "apache_connections", "php_processes",
            "mysql_connections", "load_average"
        ]].copy()

        features["memory_trend_5"] = df["memory_percent"].rolling(5).mean()
        features["memory_trend_10"] = df["memory_percent"].rolling(10).mean()
        features["hour"] = pd.to_datetime(df["timestamp"]).dt.hour

        return features.fillna(0)

    def _prepare_disk_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Prepara features para modelo de disco"""
        features = df[[
            "cpu_percent", "memory_percent", "apache_requests",
            "mysql_queries", "network_tx"
        ]].copy()

        features["disk_trend_5"] = df["disk_percent"].rolling(5).mean()
        features["disk_growth_rate"] = df["disk_used"].diff()
        features["day_of_week"] = pd.to_datetime(df["timestamp"]).dt.dayofweek

        return features.fillna(0)

    def _prepare_response_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Prepara features para modelo de tiempo de respuesta"""
        features = df[[
            "cpu_percent", "memory_percent", "apache_requests",
            "apache_connections", "load_average"
        ]].copy()

        features["response_trend_5"] = df["response_time"].rolling(5).mean()
        features["response_trend_10"] = df["response_time"].rolling(10).mean()
        features["hour"] = pd.to_datetime(df["timestamp"]).dt.hour

        return features.fillna(0)

    def _prepare_anomaly_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Prepara features para detector de anomalías"""
        features = df[[
            "cpu_percent", "memory_percent", "disk_percent",
            "cpu_load_1m", "cpu_load_5m", "cpu_load_15m",
            "apache_requests", "mysql_queries", "response_time"
        ]].copy()

        # Normalizar features
        features = pd.DataFrame(
            self.scaler.fit_transform(features),
            columns=features.columns
        )

        return features.fillna(0)

    def _calculate_prediction_confidence(self, features: pd.DataFrame, model) -> float:
        """Calcula confianza de la predicción"""
        try:
            # Usar validación cruzada simple para estimar confianza
            predictions = []
            for _ in range(5):
                sample = features.sample(n=min(50, len(features)), random_state=42)
                pred = model.predict(sample)
                predictions.extend(pred)

            confidence = 1 - (np.std(predictions) / np.mean(predictions))
            return max(0, min(1, confidence))

        except:
            return 0.5

    def _calculate_trend(self, values: np.ndarray) -> str:
        """Calcula tendencia de una serie de valores"""
        if len(values) < 5:
            return "stable"

        recent_avg = np.mean(values[-3:])
        previous_avg = np.mean(values[:-3])

        diff = recent_avg - previous_avg
        threshold = np.std(values) * 0.1

        if diff > threshold:
            return "increasing"
        elif diff < -threshold:
            return "decreasing"
        else:
            return "stable"

    def _classify_anomaly(self, data_point: pd.Series) -> str:
        """Clasifica el tipo de anomalía"""
        cpu = data_point["cpu_percent"]
        memory = data_point["memory_percent"]
        disk = data_point["disk_percent"]
        response = data_point["response_time"]

        if cpu > 90:
            return "high_cpu_usage"
        elif memory > 95:
            return "high_memory_usage"
        elif disk > 95:
            return "high_disk_usage"
        elif response > 5000:
            return "slow_response_time"
        elif cpu > 80 and memory > 85:
            return "resource_contention"
        else:
            return "performance_anomaly"

    def _identify_peak_hours(self, df: pd.DataFrame) -> List[int]:
        """Identifica horas pico de uso"""
        try:
            hourly_avg = df.groupby(pd.to_datetime(df["timestamp"]).dt.hour)["cpu_percent"].mean()
            peak_hours = hourly_avg[hourly_avg > hourly_avg.quantile(0.8)].index.tolist()
            return peak_hours
        except:
            return []

    def _identify_load_patterns(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Identifica patrones de carga"""
        try:
            patterns = {
                "daily_pattern": df.groupby(pd.to_datetime(df["timestamp"]).dt.hour)["cpu_percent"].mean().to_dict(),
                "weekly_pattern": df.groupby(pd.to_datetime(df["timestamp"]).dt.dayofweek)["cpu_percent"].mean().to_dict(),
                "peak_load": df["cpu_percent"].max(),
                "average_load": df["cpu_percent"].mean()
            }
            return patterns
        except:
            return {}

    def _analyze_resource_correlations(self, df: pd.DataFrame) -> Dict[str, float]:
        """Analiza correlaciones entre recursos"""
        try:
            correlations = {
                "cpu_memory": df["cpu_percent"].corr(df["memory_percent"]),
                "cpu_disk": df["cpu_percent"].corr(df["disk_percent"]),
                "memory_disk": df["memory_percent"].corr(df["disk_percent"]),
                "cpu_response": df["cpu_percent"].corr(df["response_time"]),
                "memory_response": df["memory_percent"].corr(df["response_time"])
            }
            return correlations
        except:
            return {}

    def _detect_seasonal_trends(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Detecta tendencias estacionales"""
        try:
            trends = {
                "hourly_trend": df.set_index("timestamp").resample("H")["cpu_percent"].mean().to_dict(),
                "daily_trend": df.set_index("timestamp").resample("D")["cpu_percent"].mean().to_dict()
            }
            return trends
        except:
            return {}

    def _get_recent_data(self, hours: int = 1) -> pd.DataFrame:
        """Obtiene datos recientes para análisis"""
        try:
            cutoff_time = datetime.now() - timedelta(hours=hours)
            recent_data = [
                point for point in self.metrics_history
                if datetime.fromisoformat(point["timestamp"]) > cutoff_time
            ]
            return pd.DataFrame(recent_data)
        except:
            return pd.DataFrame()

    def _get_basic_analysis(self) -> Dict[str, Any]:
        """Retorna análisis básico cuando no hay modelos entrenados"""
        return {
            "predictions": {
                "cpu": {"predicted_percent": 0, "confidence": 0},
                "memory": {"predicted_percent": 0, "confidence": 0},
                "disk": {"predicted_percent": 0, "confidence": 0},
                "response_time": {"predicted_ms": 0, "confidence": 0},
                "anomalies": [],
                "patterns": {}
            },
            "confidence": {},
            "timestamp": datetime.now().isoformat(),
            "note": "Modelos no entrenados - análisis básico"
        }

    def _save_models(self):
        """Guarda modelos entrenados en disco"""
        try:
            models = {
                "cpu_predictor": self.cpu_predictor,
                "memory_predictor": self.memory_predictor,
                "disk_predictor": self.disk_predictor,
                "response_time_predictor": self.response_time_predictor,
                "anomaly_detector": self.anomaly_detector,
                "scaler": self.scaler,
                "accuracy": self.model_accuracy,
                "training_time": datetime.now().isoformat()
            }

            model_file = os.path.join(self.models_dir, "trained_models.pkl")
            with open(model_file, "wb") as f:
                pickle.dump(models, f)

            self.logger.info("💾 Modelos guardados en disco")

        except Exception as e:
            self.logger.error(f"Error guardando modelos: {e}")

    def load_models(self):
        """Carga modelos entrenados desde disco"""
        try:
            model_file = os.path.join(self.models_dir, "trained_models.pkl")
            if os.path.exists(model_file):
                with open(model_file, "rb") as f:
                    models = pickle.load(f)

                self.cpu_predictor = models.get("cpu_predictor")
                self.memory_predictor = models.get("memory_predictor")
                self.disk_predictor = models.get("disk_predictor")
                self.response_time_predictor = models.get("response_time_predictor")
                self.anomaly_detector = models.get("anomaly_detector")
                self.scaler = models.get("scaler")
                self.model_accuracy = models.get("accuracy", {})
                self.last_training_time = models.get("training_time")

                if all([self.cpu_predictor, self.memory_predictor, self.disk_predictor]):
                    self.is_trained = True
                    self.logger.info("📂 Modelos cargados desde disco")
                else:
                    self.logger.warning("Algunos modelos no pudieron cargarse")

        except Exception as e:
            self.logger.error(f"Error cargando modelos: {e}")

    def update_models(self):
        """Actualiza modelos con nuevos datos"""
        try:
            if len(self.metrics_history) >= 100:
                self.logger.info("🔄 Actualizando modelos ML...")
                self._train_models_async()
                self.logger.info("✅ Modelos actualizados")
            else:
                self.logger.info("Datos insuficientes para actualizar modelos")

        except Exception as e:
            self.logger.error(f"Error actualizando modelos: {e}")

    def get_model_status(self) -> Dict[str, Any]:
        """Obtiene estado de los modelos"""
        return {
            "is_trained": self.is_trained,
            "last_training": self.last_training_time,
            "accuracy": self.model_accuracy,
            "data_points": len(self.metrics_history),
            "models_available": {
                "cpu_predictor": self.cpu_predictor is not None,
                "memory_predictor": self.memory_predictor is not None,
                "disk_predictor": self.disk_predictor is not None,
                "response_time_predictor": self.response_time_predictor is not None,
                "anomaly_detector": self.anomaly_detector is not None
            }
        }