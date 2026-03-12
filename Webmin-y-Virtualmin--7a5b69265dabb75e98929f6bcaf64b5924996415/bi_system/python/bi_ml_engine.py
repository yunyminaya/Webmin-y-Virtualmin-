#!/usr/bin/env python3
"""
Motor de Machine Learning para el Sistema BI de Webmin/Virtualmin
Implementa modelos predictivos para fallos del sistema y análisis de tendencias
"""

import os
import sys
import json
import pickle
import psycopg2
import psycopg2.extras
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from sklearn.ensemble import RandomForestClassifier, IsolationForest
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, precision_score, recall_score
import logging
import configparser
import warnings
warnings.filterwarnings('ignore')

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/webmin/bi_ml_engine.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class BIMLEngine:
    def __init__(self, config_file=None):
        self.config_file = config_file or os.path.join(
            os.path.dirname(__file__), '..', 'bi_database.conf'
        )
        self.db_config = self.load_config()
        self.models_dir = os.path.join(os.path.dirname(__file__), '..', 'models')
        os.makedirs(self.models_dir, exist_ok=True)

        # Modelos cargados
        self.failure_prediction_model = None
        self.anomaly_detection_model = None
        self.scaler = None

    def load_config(self):
        """Cargar configuración de base de datos"""
        config = configparser.ConfigParser()
        config.read(self.config_file)

        return {
            'host': config.get('DEFAULT', 'DB_HOST', fallback='localhost'),
            'port': config.getint('DEFAULT', 'DB_PORT', fallback=5432),
            'database': config.get('DEFAULT', 'DB_NAME', fallback='webmin_bi'),
            'user': config.get('DEFAULT', 'DB_USER', fallback='webmin_bi'),
            'password': config.get('DEFAULT', 'DB_PASS', fallback='')
        }

    def get_db_connection(self):
        """Obtener conexión a la base de datos"""
        return psycopg2.connect(**self.db_config)

    def load_historical_data(self, days=30):
        """Cargar datos históricos para entrenamiento"""
        logger.info(f"Cargando datos históricos de los últimos {days} días")

        try:
            conn = self.get_db_connection()
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Obtener métricas del sistema
            cursor.execute("""
                SELECT
                    timestamp,
                    hostname,
                    cpu_usage,
                    memory_usage,
                    disk_usage,
                    load_average,
                    network_rx,
                    network_tx
                FROM system_metrics
                WHERE timestamp >= CURRENT_TIMESTAMP - INTERVAL '%s days'
                AND cpu_usage IS NOT NULL
                AND memory_usage IS NOT NULL
                ORDER BY timestamp ASC
            """, [days])

            metrics_data = cursor.fetchall()

            # Obtener alertas para crear etiquetas de fallos
            cursor.execute("""
                SELECT
                    timestamp,
                    hostname,
                    alert_type,
                    severity
                FROM alerts_history
                WHERE timestamp >= CURRENT_TIMESTAMP - INTERVAL '%s days'
                AND severity IN ('critical', 'error')
                ORDER BY timestamp ASC
            """, [days])

            alerts_data = cursor.fetchall()
            conn.close()

            return pd.DataFrame(metrics_data), pd.DataFrame(alerts_data)

        except Exception as e:
            logger.error(f"Error cargando datos históricos: {e}")
            return None, None

    def prepare_training_data(self, metrics_df, alerts_df, prediction_window_hours=24):
        """Preparar datos para entrenamiento de modelos"""
        if metrics_df is None or metrics_df.empty:
            return None

        logger.info("Preparando datos de entrenamiento")

        # Crear características
        df = metrics_df.copy()

        # Convertir timestamp a datetime si no lo es
        df['timestamp'] = pd.to_datetime(df['timestamp'])

        # Crear características rolling (últimas 1, 6, 24 horas)
        numeric_cols = ['cpu_usage', 'memory_usage', 'disk_usage', 'load_average']

        for col in numeric_cols:
            # Última hora
            df[f'{col}_1h_mean'] = df.groupby('hostname')[col].rolling('1H').mean().reset_index(0, drop=True)
            df[f'{col}_1h_std'] = df.groupby('hostname')[col].rolling('1H').std().reset_index(0, drop=True)
            df[f'{col}_1h_max'] = df.groupby('hostname')[col].rolling('1H').max().reset_index(0, drop=True)

            # Últimas 6 horas
            df[f'{col}_6h_mean'] = df.groupby('hostname')[col].rolling('6H').mean().reset_index(0, drop=True)
            df[f'{col}_6h_trend'] = df.groupby('hostname')[col].rolling('6H').apply(
                lambda x: np.polyfit(range(len(x)), x, 1)[0] if len(x) > 1 else 0
            ).reset_index(0, drop=True)

            # Últimas 24 horas
            df[f'{col}_24h_mean'] = df.groupby('hostname')[col].rolling('24H').mean().reset_index(0, drop=True)

        # Crear etiquetas de fallos futuros
        df['failure_in_window'] = 0

        if alerts_df is not None and not alerts_df.empty:
            alerts_df['timestamp'] = pd.to_datetime(alerts_df['timestamp'])

            for idx, row in df.iterrows():
                future_alerts = alerts_df[
                    (alerts_df['hostname'] == row['hostname']) &
                    (alerts_df['timestamp'] > row['timestamp']) &
                    (alerts_df['timestamp'] <= row['timestamp'] + timedelta(hours=prediction_window_hours))
                ]

                if not future_alerts.empty:
                    df.at[idx, 'failure_in_window'] = 1

        # Seleccionar características finales
        feature_cols = [col for col in df.columns if col not in ['timestamp', 'hostname', 'failure_in_window']]
        feature_cols.extend([f'{col}_1h_mean' for col in numeric_cols])
        feature_cols.extend([f'{col}_1h_std' for col in numeric_cols])
        feature_cols.extend([f'{col}_1h_max' for col in numeric_cols])
        feature_cols.extend([f'{col}_6h_mean' for col in numeric_cols])
        feature_cols.extend([f'{col}_6h_trend' for col in numeric_cols])
        feature_cols.extend([f'{col}_24h_mean' for col in numeric_cols])

        # Filtrar columnas que existen
        feature_cols = [col for col in feature_cols if col in df.columns]

        # Remover filas con NaN
        df_clean = df.dropna(subset=feature_cols + ['failure_in_window'])

        if df_clean.empty:
            logger.warning("No hay suficientes datos para entrenamiento")
            return None

        X = df_clean[feature_cols]
        y = df_clean['failure_in_window']

        logger.info(f"Datos preparados: {len(X)} muestras, {len(feature_cols)} características")
        logger.info(f"Distribución de clases: {y.value_counts().to_dict()}")

        return X, y, feature_cols

    def train_failure_prediction_model(self, days=30):
        """Entrenar modelo de predicción de fallos"""
        logger.info("Entrenando modelo de predicción de fallos")

        # Cargar datos
        metrics_df, alerts_df = self.load_historical_data(days)

        # Preparar datos
        result = self.prepare_training_data(metrics_df, alerts_df)
        if result is None:
            return False

        X, y, feature_cols = result

        if len(X) < 100:
            logger.warning("Insuficientes datos para entrenamiento")
            return False

        # Dividir datos
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )

        # Escalar características
        self.scaler = StandardScaler()
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)

        # Entrenar modelo
        self.failure_prediction_model = RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            random_state=42,
            class_weight='balanced'
        )

        self.failure_prediction_model.fit(X_train_scaled, y_train)

        # Evaluar modelo
        y_pred = self.failure_prediction_model.predict(X_test_scaled)
        accuracy = accuracy_score(y_test, y_pred)
        precision = precision_score(y_test, y_pred, zero_division=0)
        recall = recall_score(y_test, y_pred, zero_division=0)

        logger.info(f"Modelo entrenado - Accuracy: {accuracy:.3f}, Precision: {precision:.3f}, Recall: {recall:.3f}")

        # Guardar modelo
        self.save_model('failure_prediction', {
            'model': self.failure_prediction_model,
            'scaler': self.scaler,
            'feature_cols': feature_cols,
            'metrics': {
                'accuracy': accuracy,
                'precision': precision,
                'recall': recall,
                'training_samples': len(X_train),
                'test_samples': len(X_test)
            },
            'trained_at': datetime.now().isoformat()
        })

        return True

    def train_anomaly_detection_model(self, days=30):
        """Entrenar modelo de detección de anomalías"""
        logger.info("Entrenando modelo de detección de anomalías")

        # Cargar datos
        metrics_df, _ = self.load_historical_data(days)

        if metrics_df is None or metrics_df.empty:
            return False

        # Preparar características
        numeric_cols = ['cpu_usage', 'memory_usage', 'disk_usage', 'load_average']
        X = metrics_df[numeric_cols].dropna()

        if len(X) < 100:
            logger.warning("Insuficientes datos para detección de anomalías")
            return False

        # Escalar datos
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)

        # Entrenar modelo
        self.anomaly_detection_model = IsolationForest(
            n_estimators=100,
            contamination=0.1,  # 10% de anomalías esperadas
            random_state=42
        )

        self.anomaly_detection_model.fit(X_scaled)

        # Guardar modelo
        self.save_model('anomaly_detection', {
            'model': self.anomaly_detection_model,
            'scaler': scaler,
            'feature_cols': numeric_cols,
            'trained_at': datetime.now().isoformat()
        })

        logger.info("Modelo de detección de anomalías entrenado")
        return True

    def predict_failures(self, current_metrics, hostname):
        """Predecir probabilidad de fallos futuros"""
        if not self.failure_prediction_model or not self.scaler:
            if not self.load_model('failure_prediction'):
                return None

        try:
            # Preparar características (simplificado para predicción en tiempo real)
            features = [
                current_metrics.get('cpu_usage', 0),
                current_metrics.get('memory_usage', 0),
                current_metrics.get('disk_usage', 0),
                current_metrics.get('load_average', 0)
            ]

            # Crear características rolling simuladas (usar valores actuales)
            feature_cols = []
            for col_name in ['cpu_usage', 'memory_usage', 'disk_usage', 'load_average']:
                base_val = current_metrics.get(col_name, 0)
                feature_cols.extend([
                    base_val,  # 1h_mean
                    base_val * 0.1,  # 1h_std (simulado)
                    base_val * 1.2,  # 1h_max (simulado)
                    base_val,  # 6h_mean
                    0,  # 6h_trend (simulado)
                    base_val   # 24h_mean
                ])

            # Asegurar que tenemos las características correctas
            if hasattr(self, 'model_metadata') and 'feature_cols' in self.model_metadata:
                expected_features = len(self.model_metadata['feature_cols'])
                if len(feature_cols) < expected_features:
                    feature_cols.extend([0] * (expected_features - len(feature_cols)))
                feature_cols = feature_cols[:expected_features]

            # Escalar y predecir
            features_scaled = self.scaler.transform([feature_cols])
            prediction_proba = self.failure_prediction_model.predict_proba(features_scaled)[0]

            failure_probability = prediction_proba[1]  # Probabilidad de clase positiva (fallo)

            return {
                'hostname': hostname,
                'failure_probability': float(failure_probability),
                'confidence': float(max(prediction_proba)),
                'prediction_type': 'system_failure',
                'time_horizon_hours': 24,
                'features_used': feature_cols
            }

        except Exception as e:
            logger.error(f"Error en predicción de fallos: {e}")
            return None

    def detect_anomalies(self, current_metrics, hostname):
        """Detectar anomalías en métricas actuales"""
        if not self.anomaly_detection_model:
            if not self.load_model('anomaly_detection'):
                return None

        try:
            features = [
                current_metrics.get('cpu_usage', 0),
                current_metrics.get('memory_usage', 0),
                current_metrics.get('disk_usage', 0),
                current_metrics.get('load_average', 0)
            ]

            # Cargar scaler del modelo
            model_data = self.load_model('anomaly_detection')
            if model_data and 'scaler' in model_data:
                features_scaled = model_data['scaler'].transform([features])
                anomaly_score = self.anomaly_detection_model.decision_function(features_scaled)[0]
                is_anomaly = self.anomaly_detection_model.predict(features_scaled)[0] == -1

                return {
                    'hostname': hostname,
                    'is_anomaly': bool(is_anomaly),
                    'anomaly_score': float(anomaly_score),
                    'features': features
                }

        except Exception as e:
            logger.error(f"Error en detección de anomalías: {e}")

        return None

    def save_model(self, model_name, model_data):
        """Guardar modelo en archivo"""
        try:
            filepath = os.path.join(self.models_dir, f'{model_name}_model.pkl')
            with open(filepath, 'wb') as f:
                pickle.dump(model_data, f)
            logger.info(f"Modelo {model_name} guardado en {filepath}")
            return True
        except Exception as e:
            logger.error(f"Error guardando modelo {model_name}: {e}")
            return False

    def load_model(self, model_name):
        """Cargar modelo desde archivo"""
        try:
            filepath = os.path.join(self.models_dir, f'{model_name}_model.pkl')
            if not os.path.exists(filepath):
                return None

            with open(filepath, 'rb') as f:
                model_data = pickle.load(f)

            # Cargar componentes del modelo
            if model_name == 'failure_prediction':
                self.failure_prediction_model = model_data['model']
                self.scaler = model_data['scaler']
                self.model_metadata = model_data
            elif model_name == 'anomaly_detection':
                self.anomaly_detection_model = model_data['model']

            logger.info(f"Modelo {model_name} cargado")
            return model_data

        except Exception as e:
            logger.error(f"Error cargando modelo {model_name}: {e}")
            return None

    def store_predictions(self, predictions):
        """Almacenar predicciones en la base de datos"""
        if not predictions:
            return False

        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()

            for pred in predictions:
                cursor.execute("""
                    INSERT INTO performance_predictions
                    (hostname, prediction_type, prediction_value, confidence,
                     time_horizon_hours, features_used, model_version)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, (
                    pred['hostname'],
                    pred.get('prediction_type', 'unknown'),
                    pred.get('failure_probability', pred.get('anomaly_score', 0)),
                    pred.get('confidence', 0.5),
                    pred.get('time_horizon_hours', 24),
                    json.dumps(pred.get('features_used', pred.get('features', []))),
                    'v1.0'
                ))

            conn.commit()
            conn.close()

            logger.info(f"{len(predictions)} predicciones almacenadas")
            return True

        except Exception as e:
            logger.error(f"Error almacenando predicciones: {e}")
            return False

    def run_prediction_cycle(self):
        """Ejecutar ciclo completo de predicciones"""
        logger.info("Ejecutando ciclo de predicciones ML")

        # Cargar modelos si no están cargados
        if not self.failure_prediction_model:
            self.load_model('failure_prediction')
        if not self.anomaly_detection_model:
            self.load_model('anomaly_detection')

        if not self.failure_prediction_model and not self.anomaly_detection_model:
            logger.warning("No hay modelos entrenados disponibles")
            return False

        # Obtener métricas actuales
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("""
                SELECT DISTINCT ON (hostname)
                    hostname,
                    cpu_usage,
                    memory_usage,
                    disk_usage,
                    load_average
                FROM system_metrics
                WHERE timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
                ORDER BY hostname, timestamp DESC
            """)

            current_metrics = cursor.fetchall()
            conn.close()

        except Exception as e:
            logger.error(f"Error obteniendo métricas actuales: {e}")
            return False

        predictions = []

        # Generar predicciones para cada host
        for metrics in current_metrics:
            hostname = metrics['hostname']

            # Predicción de fallos
            if self.failure_prediction_model:
                failure_pred = self.predict_failures(metrics, hostname)
                if failure_pred:
                    predictions.append(failure_pred)

            # Detección de anomalías
            if self.anomaly_detection_model:
                anomaly_pred = self.detect_anomalies(metrics, hostname)
                if anomaly_pred and anomaly_pred['is_anomaly']:
                    predictions.append({
                        'hostname': hostname,
                        'prediction_type': 'anomaly_detected',
                        'prediction_value': anomaly_pred['anomaly_score'],
                        'confidence': 0.8,
                        'time_horizon_hours': 1,
                        'features_used': anomaly_pred['features']
                    })

        # Almacenar predicciones
        if predictions:
            self.store_predictions(predictions)

        logger.info(f"Ciclo de predicciones completado: {len(predictions)} predicciones generadas")
        return True

def main():
    import argparse

    parser = argparse.ArgumentParser(description='Motor de Machine Learning para Sistema BI')
    parser.add_argument('--config', help='Archivo de configuración')
    parser.add_argument('--train', action='store_true', help='Entrenar modelos')
    parser.add_argument('--predict', action='store_true', help='Ejecutar predicciones')
    parser.add_argument('--days', type=int, default=30, help='Días de datos históricos para entrenamiento')

    args = parser.parse_args()

    engine = BIMLEngine(args.config)

    if args.train:
        logger.info("Iniciando entrenamiento de modelos")
        engine.train_failure_prediction_model(args.days)
        engine.train_anomaly_detection_model(args.days)
    elif args.predict:
        logger.info("Ejecutando predicciones")
        engine.run_prediction_cycle()
    else:
        # Modo continuo
        logger.info("Iniciando modo continuo")
        while True:
            try:
                engine.run_prediction_cycle()
            except Exception as e:
                logger.error(f"Error en ciclo continuo: {e}")

            # Esperar 1 hora para el siguiente ciclo
            import time
            time.sleep(3600)

if __name__ == '__main__':
    main()