#!/usr/bin/env python3

"""
SIEM ML Anomaly Detector
Uses machine learning to detect anomalous patterns in security events
"""

import sqlite3
import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.model_selection import train_test_split
import joblib
import os
import sys
from datetime import datetime, timedelta
import json

class SIEMAnomalyDetector:
    def __init__(self, db_path='siem_events.db'):
        self.db_path = db_path
        self.model_path = 'ml_model.pkl'
        self.scaler_path = 'scaler.pkl'
        self.encoders_path = 'encoders.pkl'
        self.model = None
        self.scaler = None
        self.encoders = {}

    def connect_db(self):
        return sqlite3.connect(self.db_path)

    def load_data(self, hours=24):
        """Load recent events for analysis"""
        conn = self.connect_db()
        query = f"""
        SELECT id, timestamp, source, event_type, severity, ip_address, message
        FROM events
        WHERE timestamp > datetime('now', '-{hours} hours')
        AND processed = 0
        """
        df = pd.read_sql_query(query, conn)
        conn.close()

        if df.empty:
            return None

        # Convert timestamp to datetime
        df['timestamp'] = pd.to_datetime(df['timestamp'])

        # Extract time features
        df['hour'] = df['timestamp'].dt.hour
        df['day_of_week'] = df['timestamp'].dt.dayofweek
        df['month'] = df['timestamp'].dt.month

        # Count events per source/type per hour
        features = df.groupby(['source', 'event_type', 'hour', 'day_of_week']).size().reset_index(name='count')

        # Pivot to create feature matrix
        feature_matrix = features.pivot_table(
            index=['source', 'event_type'],
            columns=['hour', 'day_of_week'],
            values='count',
            fill_value=0
        ).reset_index()

        return feature_matrix

    def train_model(self, contamination=0.1):
        """Train anomaly detection model"""
        print("Training ML model...")

        # Load historical data (last 7 days)
        data = self.load_data(hours=168)
        if data is None or len(data) < 10:
            print("Insufficient data for training")
            return False

        # Prepare features
        feature_cols = [col for col in data.columns if col not in ['source', 'event_type']]
        X = data[feature_cols].values

        # Scale features
        self.scaler = StandardScaler()
        X_scaled = self.scaler.fit_transform(X)

        # Train Isolation Forest
        self.model = IsolationForest(
            contamination=contamination,
            random_state=42,
            n_estimators=100
        )
        self.model.fit(X_scaled)

        # Save model and scaler
        joblib.dump(self.model, self.model_path)
        joblib.dump(self.scaler, self.scaler_path)

        # Update model info in database
        conn = self.connect_db()
        conn.execute("""
        INSERT OR REPLACE INTO ml_models (name, model_type, accuracy, last_trained, active)
        VALUES (?, ?, ?, ?, ?)
        """, ('anomaly_detector', 'isolation_forest', 0.9, datetime.now().isoformat(), 1))
        conn.commit()
        conn.close()

        print("Model trained successfully")
        return True

    def load_model(self):
        """Load trained model"""
        if os.path.exists(self.model_path) and os.path.exists(self.scaler_path):
            self.model = joblib.load(self.model_path)
            self.scaler = joblib.load(self.scaler_path)
            return True
        return False

    def detect_anomalies(self):
        """Detect anomalies in recent events"""
        if not self.load_model():
            print("No trained model found")
            return

        print("Detecting anomalies...")

        # Load recent data (last hour)
        data = self.load_data(hours=1)
        if data is None:
            return

        # Prepare features
        feature_cols = [col for col in data.columns if col not in ['source', 'event_type']]
        X = data[feature_cols].values
        X_scaled = self.scaler.transform(X)

        # Predict anomalies
        predictions = self.model.predict(X_scaled)

        # Process anomalies
        conn = self.connect_db()
        for i, pred in enumerate(predictions):
            if pred == -1:  # Anomaly
                source = data.iloc[i]['source']
                event_type = data.iloc[i]['event_type']

                # Get recent events of this type
                event_ids = conn.execute("""
                SELECT id FROM events
                WHERE source = ? AND event_type = ?
                AND timestamp > datetime('now', '-1 hours')
                AND processed = 0
                """, (source, event_type)).fetchall()

                if event_ids:
                    event_ids_str = ','.join(str(eid[0]) for eid in event_ids)

                    # Create alert
                    conn.execute("""
                    INSERT INTO alerts (rule_id, severity, title, description, event_ids)
                    VALUES (?, ?, ?, ?, ?)
                    """, (
                        None,  # ML-based, no rule_id
                        'high',
                        'ML Anomaly Detected',
                        f'Anomalous pattern detected in {source}/{event_type} events',
                        f'[{event_ids_str}]'
                    ))

                    # Mark events as processed
                    conn.executemany("""
                    UPDATE events SET processed = 1 WHERE id = ?
                    """, [(eid[0],) for eid in event_ids])

                    print(f"Anomaly detected: {source}/{event_type}")

        conn.commit()
        conn.close()

    def update_baseline(self):
        """Update baseline with normal patterns"""
        # This would be called periodically to update the model with new normal patterns
        # For now, retrain weekly
        pass

def main():
    detector = SIEMAnomalyDetector()

    # Check if model exists and is recent
    conn = detector.connect_db()
    model_info = conn.execute("""
    SELECT last_trained FROM ml_models
    WHERE name = 'anomaly_detector' AND active = 1
    """).fetchone()
    conn.close()

    needs_training = True
    if model_info:
        last_trained = datetime.fromisoformat(model_info[0])
        if (datetime.now() - last_trained).days < 7:  # Retrain weekly
            needs_training = False

    if needs_training:
        if detector.train_model():
            print("Model trained")
        else:
            print("Failed to train model")
            return

    # Detect anomalies
    detector.detect_anomalies()

if __name__ == '__main__':
    main()