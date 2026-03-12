#!/usr/bin/env python3
"""
Servidor de APIs REST para el Sistema BI de Webmin/Virtualmin
Proporciona endpoints para métricas, predicciones y reportes
"""

import os
import sys
import json
import psycopg2
import psycopg2.extras
from datetime import datetime, timedelta
from flask import Flask, request, jsonify, Response
from flask_cors import CORS
import pandas as pd
import logging
import configparser
from functools import wraps

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/webmin/bi_api_server.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class BIServer:
    def __init__(self, config_file=None):
        self.config_file = config_file or os.path.join(
            os.path.dirname(__file__), '..', 'bi_database.conf'
        )
        self.db_config = self.load_config()
        self.app = Flask(__name__)
        CORS(self.app)

        # Configurar rutas
        self.setup_routes()

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

    def require_auth(self, f):
        """Decorador para requerir autenticación (placeholder)"""
        @wraps(f)
        def decorated_function(*args, **kwargs):
            # TODO: Implementar autenticación Webmin
            # Por ahora, permitir todo
            return f(*args, **kwargs)
        return decorated_function

    def setup_routes(self):
        """Configurar todas las rutas de la API"""

        @self.app.route('/api/v1/health', methods=['GET'])
        def health_check():
            """Verificar estado del servicio"""
            return jsonify({
                'status': 'healthy',
                'timestamp': datetime.now().isoformat(),
                'version': '1.0.0'
            })

        @self.app.route('/api/v1/metrics/realtime', methods=['GET'])
        @self.require_auth
        def get_realtime_metrics():
            """Obtener métricas en tiempo real"""
            try:
                conn = self.get_db_connection()
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

                # Obtener últimas métricas por hostname
                cursor.execute("""
                    SELECT DISTINCT ON (hostname)
                        hostname,
                        timestamp,
                        cpu_usage,
                        memory_usage,
                        disk_usage,
                        load_average,
                        network_rx,
                        network_tx
                    FROM system_metrics
                    ORDER BY hostname, timestamp DESC
                """)

                metrics = cursor.fetchall()
                conn.close()

                return jsonify({
                    'success': True,
                    'data': [dict(row) for row in metrics],
                    'timestamp': datetime.now().isoformat()
                })

            except Exception as e:
                logger.error(f"Error obteniendo métricas en tiempo real: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500

        @self.app.route('/api/v1/metrics/historical', methods=['GET'])
        @self.require_auth
        def get_historical_metrics():
            """Obtener métricas históricas con filtros"""
            try:
                # Parámetros de consulta
                hostname = request.args.get('hostname')
                start_date = request.args.get('start_date')
                end_date = request.args.get('end_date')
                limit = int(request.args.get('limit', 1000))
                group_by = request.args.get('group_by', 'hour')  # hour, day, week

                if not start_date:
                    start_date = (datetime.now() - timedelta(days=7)).isoformat()
                if not end_date:
                    end_date = datetime.now().isoformat()

                conn = self.get_db_connection()
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

                # Construir consulta con agrupación
                if group_by == 'hour':
                    time_group = "date_trunc('hour', timestamp)"
                elif group_by == 'day':
                    time_group = "date_trunc('day', timestamp)"
                elif group_by == 'week':
                    time_group = "date_trunc('week', timestamp)"
                else:
                    time_group = "timestamp"

                query = f"""
                    SELECT
                        {time_group} as time_group,
                        hostname,
                        AVG(cpu_usage) as avg_cpu,
                        MAX(cpu_usage) as max_cpu,
                        AVG(memory_usage) as avg_memory,
                        MAX(memory_usage) as max_memory,
                        AVG(disk_usage) as avg_disk,
                        MAX(disk_usage) as max_disk,
                        COUNT(*) as samples
                    FROM system_metrics
                    WHERE timestamp BETWEEN %s AND %s
                """

                params = [start_date, end_date]

                if hostname:
                    query += " AND hostname = %s"
                    params.append(hostname)

                query += f"""
                    GROUP BY {time_group}, hostname
                    ORDER BY time_group DESC
                    LIMIT %s
                """
                params.append(limit)

                cursor.execute(query, params)
                data = cursor.fetchall()
                conn.close()

                return jsonify({
                    'success': True,
                    'data': [dict(row) for row in data],
                    'query': {
                        'hostname': hostname,
                        'start_date': start_date,
                        'end_date': end_date,
                        'group_by': group_by,
                        'limit': limit
                    }
                })

            except Exception as e:
                logger.error(f"Error obteniendo métricas históricas: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500

        @self.app.route('/api/v1/services/status', methods=['GET'])
        @self.require_auth
        def get_services_status():
            """Obtener estado actual de servicios"""
            try:
                conn = self.get_db_connection()
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

                # Obtener estado más reciente de cada servicio
                cursor.execute("""
                    SELECT DISTINCT ON (hostname, service_name)
                        hostname,
                        service_name,
                        status,
                        timestamp,
                        pid,
                        memory_mb,
                        cpu_percent
                    FROM service_status
                    ORDER BY hostname, service_name, timestamp DESC
                """)

                services = cursor.fetchall()
                conn.close()

                return jsonify({
                    'success': True,
                    'data': [dict(row) for row in services],
                    'timestamp': datetime.now().isoformat()
                })

            except Exception as e:
                logger.error(f"Error obteniendo estado de servicios: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500

        @self.app.route('/api/v1/alerts/active', methods=['GET'])
        @self.require_auth
        def get_active_alerts():
            """Obtener alertas activas"""
            try:
                severity = request.args.get('severity')
                hostname = request.args.get('hostname')
                limit = int(request.args.get('limit', 100))

                conn = self.get_db_connection()
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

                query = """
                    SELECT id, timestamp, hostname, alert_type, severity, message
                    FROM alerts_history
                    WHERE resolved = FALSE
                """

                params = []

                if severity:
                    query += " AND severity = %s"
                    params.append(severity)

                if hostname:
                    query += " AND hostname = %s"
                    params.append(hostname)

                query += " ORDER BY timestamp DESC LIMIT %s"
                params.append(limit)

                cursor.execute(query, params)
                alerts = cursor.fetchall()
                conn.close()

                return jsonify({
                    'success': True,
                    'data': [dict(row) for row in alerts],
                    'count': len(alerts)
                })

            except Exception as e:
                logger.error(f"Error obteniendo alertas activas: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500

        @self.app.route('/api/v1/analytics/uptime', methods=['GET'])
        @self.require_auth
        def get_uptime_analytics():
            """Obtener análisis de uptime de servicios"""
            try:
                days = int(request.args.get('days', 30))
                hostname = request.args.get('hostname')

                conn = self.get_db_connection()
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

                # Usar la vista service_uptime_daily
                query = """
                    SELECT * FROM service_uptime_daily
                    WHERE date >= CURRENT_DATE - INTERVAL '%s days'
                """
                params = [days]

                if hostname:
                    query += " AND hostname = %s"
                    params.append(hostname)

                query += " ORDER BY date DESC, hostname, service_name"

                cursor.execute(query, params)
                data = cursor.fetchall()
                conn.close()

                return jsonify({
                    'success': True,
                    'data': [dict(row) for row in data],
                    'period_days': days
                })

            except Exception as e:
                logger.error(f"Error obteniendo análisis de uptime: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500

        @self.app.route('/api/v1/analytics/performance', methods=['GET'])
        @self.require_auth
        def get_performance_analytics():
            """Obtener análisis de rendimiento del sistema"""
            try:
                days = int(request.args.get('days', 7))
                hostname = request.args.get('hostname')

                conn = self.get_db_connection()
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

                # Usar la vista system_metrics_daily
                query = """
                    SELECT * FROM system_metrics_daily
                    WHERE date >= CURRENT_DATE - INTERVAL '%s days'
                """
                params = [days]

                if hostname:
                    query += " AND hostname = %s"
                    params.append(hostname)

                query += " ORDER BY date DESC, hostname"

                cursor.execute(query, params)
                data = cursor.fetchall()
                conn.close()

                return jsonify({
                    'success': True,
                    'data': [dict(row) for row in data],
                    'period_days': days
                })

            except Exception as e:
                logger.error(f"Error obteniendo análisis de rendimiento: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500

        @self.app.route('/api/v1/predictions/failures', methods=['GET'])
        @self.require_auth
        def get_failure_predictions():
            """Obtener predicciones de fallos"""
            try:
                hostname = request.args.get('hostname')
                prediction_type = request.args.get('type')
                limit = int(request.args.get('limit', 50))

                conn = self.get_db_connection()
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

                query = """
                    SELECT
                        timestamp,
                        hostname,
                        prediction_type,
                        prediction_value,
                        confidence,
                        time_horizon_hours,
                        model_version
                    FROM performance_predictions
                    WHERE confidence > 0.7
                """

                params = []

                if hostname:
                    query += " AND hostname = %s"
                    params.append(hostname)

                if prediction_type:
                    query += " AND prediction_type = %s"
                    params.append(prediction_type)

                query += " ORDER BY timestamp DESC LIMIT %s"
                params.append(limit)

                cursor.execute(query, params)
                predictions = cursor.fetchall()
                conn.close()

                return jsonify({
                    'success': True,
                    'data': [dict(row) for row in predictions],
                    'count': len(predictions)
                })

            except Exception as e:
                logger.error(f"Error obteniendo predicciones de fallos: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500

        @self.app.route('/api/v1/reports/generate', methods=['POST'])
        @self.require_auth
        def generate_report():
            """Generar un reporte personalizado"""
            try:
                data = request.get_json()

                report_type = data.get('type', 'performance')
                start_date = data.get('start_date')
                end_date = data.get('end_date')
                hostname = data.get('hostname')
                format_type = data.get('format', 'json')

                # Aquí se implementaría la lógica de generación de reportes
                # Por ahora, devolver una respuesta básica

                return jsonify({
                    'success': True,
                    'report_id': f"report_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
                    'type': report_type,
                    'status': 'generating',
                    'message': 'Reporte en proceso de generación'
                })

            except Exception as e:
                logger.error(f"Error generando reporte: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500

    def run(self, host='0.0.0.0', port=5000, debug=False):
        """Ejecutar el servidor"""
        logger.info(f"Iniciando servidor BI API en {host}:{port}")
        self.app.run(host=host, port=port, debug=debug)

def main():
    import argparse

    parser = argparse.ArgumentParser(description='Servidor de APIs REST para Sistema BI')
    parser.add_argument('--host', default='0.0.0.0', help='Host para el servidor')
    parser.add_argument('--port', type=int, default=5000, help='Puerto para el servidor')
    parser.add_argument('--config', help='Archivo de configuración')
    parser.add_argument('--debug', action='store_true', help='Modo debug')

    args = parser.parse_args()

    server = BIServer(args.config)
    server.run(host=args.host, port=args.port, debug=args.debug)

if __name__ == '__main__':
    main()