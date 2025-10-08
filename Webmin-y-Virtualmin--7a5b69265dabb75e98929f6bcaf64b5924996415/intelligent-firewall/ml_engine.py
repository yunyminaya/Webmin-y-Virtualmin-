#!/usr/bin/env python3
# ml_engine.py - Motor de aprendizaje automático para detección de anomalías

import sys
import os
import pickle
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
import numpy as np

MODEL_PATH = '/etc/webmin/intelligent-firewall/models/anomaly_model.pkl'
DATA_PATH = '/var/log/intelligent-firewall/traffic_data.csv'

def load_model():
    if os.path.exists(MODEL_PATH):
        with open(MODEL_PATH, 'rb') as f:
            return pickle.load(f)
    return None

def save_model(model):
    os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
    with open(MODEL_PATH, 'wb') as f:
        pickle.dump(model, f)

def extract_features(log_line):
    # Extraer características de una línea de log
    # Placeholder: implementar parsing real de logs
    return [1.0, 2.0, 3.0]  # features dummy

def train_model():
    # Cargar datos históricos
    if not os.path.exists(DATA_PATH):
        print("No hay datos históricos para entrenar")
        return

    data = pd.read_csv(DATA_PATH)
    features = data.drop(['timestamp', 'ip'], axis=1)

    # Normalizar
    scaler = StandardScaler()
    features_scaled = scaler.fit_transform(features)

    # Entrenar Isolation Forest
    model = IsolationForest(contamination=0.1, random_state=42)
    model.fit(features_scaled)

    # Guardar modelo y scaler
    save_model({'model': model, 'scaler': scaler})
    print("Modelo entrenado y guardado")

def detect_anomalies(traffic_data):
    model_data = load_model()
    if not model_data:
        return {}

    model = model_data['model']
    scaler = model_data['scaler']

    # Procesar datos de tráfico
    features = [extract_features(line) for line in traffic_data.split('\n') if line]
    if not features:
        return {}

    features_scaled = scaler.transform(features)
    scores = model.decision_function(features_scaled)
    predictions = model.predict(features_scaled)

    # Retornar IPs anómalas con puntuaciones
    anomalies = {}
    for i, pred in enumerate(predictions):
        if pred == -1:  # Anomalía
            ip = "192.168.1.1"  # Placeholder: extraer IP real
            anomalies[ip] = float(scores[i])

    return anomalies

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 ml_engine.py [train|detect] [data]")
        sys.exit(1)

    command = sys.argv[1]

    if command == "train":
        train_model()
    elif command == "detect":
        if len(sys.argv) < 3:
            print("Faltan datos para detectar")
            sys.exit(1)
        data = sys.argv[2]
        anomalies = detect_anomalies(data)
        print(anomalies)
    else:
        print("Comando desconocido")