#!/usr/bin/env python3
"""
Script de pruebas para el Sistema BI de Webmin/Virtualmin
Verifica el funcionamiento de todos los componentes
"""

import os
import sys
import json
import time
import requests
import psycopg2
import psycopg2.extras
from datetime import datetime, timedelta
import subprocess
import configparser

class BISystemTester:
    def __init__(self, config_file=None):
        self.config_file = config_file or os.path.join(
            os.path.dirname(__file__), 'bi_database.conf'
        )
        self.db_config = self.load_config()
        self.api_base = "http://localhost:5000/api/v1"
        self.test_results = []

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

    def log_test(self, test_name, success, message=""):
        """Registrar resultado de prueba"""
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} - {test_name}")
        if message:
            print(f"   {message}")

        self.test_results.append({
            'test': test_name,
            'success': success,
            'message': message,
            'timestamp': datetime.now().isoformat()
        })

    def test_database_connection(self):
        """Probar conexión a la base de datos"""
        try:
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()

            # Verificar tablas
            cursor.execute("""
                SELECT table_name FROM information_schema.tables
                WHERE table_schema = 'public'
                ORDER BY table_name
            """)
            tables = cursor.fetchall()

            expected_tables = [
                'system_metrics', 'service_status', 'alerts_history',
                'pipeline_executions', 'user_activity', 'performance_predictions',
                'audit_logs'
            ]

            found_tables = [table[0] for table in tables]
            missing_tables = [t for t in expected_tables if t not in found_tables]

            conn.close()

            if missing_tables:
                self.log_test("Database Connection", False,
                            f"Missing tables: {', '.join(missing_tables)}")
                return False
            else:
                self.log_test("Database Connection", True,
                            f"Connected successfully. Found {len(found_tables)} tables.")
                return True

        except Exception as e:
            self.log_test("Database Connection", False, str(e))
            return False

    def test_data_collection(self):
        """Probar colección de datos"""
        try:
            # Ejecutar colección de datos
            script_path = os.path.join(os.path.dirname(__file__), 'python', 'bi_data_collector.py')
            result = subprocess.run(
                [sys.executable, script_path, '--once'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                self.log_test("Data Collection", True, "Data collection executed successfully")
                return True
            else:
                self.log_test("Data Collection", False,
                            f"Exit code: {result.returncode}, Error: {result.stderr}")
                return False

        except Exception as e:
            self.log_test("Data Collection", False, str(e))
            return False

    def test_api_server(self):
        """Probar servidor de APIs"""
        try:
            # Probar endpoint de salud
            response = requests.get(f"{self.api_base}/health", timeout=10)

            if response.status_code == 200:
                data = response.json()
                if data.get('status') == 'healthy':
                    self.log_test("API Server", True, "API server is healthy")
                    return True
                else:
                    self.log_test("API Server", False, f"API returned unhealthy status: {data}")
                    return False
            else:
                self.log_test("API Server", False, f"HTTP {response.status_code}")
                return False

        except requests.exceptions.RequestException as e:
            self.log_test("API Server", False, f"Connection failed: {e}")
            return False

    def test_realtime_metrics_api(self):
        """Probar API de métricas en tiempo real"""
        try:
            response = requests.get(f"{self.api_base}/metrics/realtime", timeout=10)

            if response.status_code == 200:
                data = response.json()
                if data.get('success') and 'data' in data:
                    metrics_count = len(data['data'])
                    self.log_test("Realtime Metrics API", True,
                                f"Retrieved {metrics_count} real-time metrics")
                    return True
                else:
                    self.log_test("Realtime Metrics API", False,
                                f"Invalid response format: {data}")
                    return False
            else:
                self.log_test("Realtime Metrics API", False, f"HTTP {response.status_code}")
                return False

        except Exception as e:
            self.log_test("Realtime Metrics API", False, str(e))
            return False

    def test_historical_metrics_api(self):
        """Probar API de métricas históricas"""
        try:
            params = {
                'start_date': (datetime.now() - timedelta(hours=24)).isoformat(),
                'end_date': datetime.now().isoformat(),
                'limit': 10
            }
            response = requests.get(f"{self.api_base}/metrics/historical",
                                  params=params, timeout=10)

            if response.status_code == 200:
                data = response.json()
                if data.get('success') and 'data' in data:
                    records_count = len(data['data'])
                    self.log_test("Historical Metrics API", True,
                                f"Retrieved {records_count} historical records")
                    return True
                else:
                    self.log_test("Historical Metrics API", False,
                                f"Invalid response format: {data}")
                    return False
            else:
                self.log_test("Historical Metrics API", False, f"HTTP {response.status_code}")
                return False

        except Exception as e:
            self.log_test("Historical Metrics API", False, str(e))
            return False

    def test_services_api(self):
        """Probar API de estado de servicios"""
        try:
            response = requests.get(f"{self.api_base}/services/status", timeout=10)

            if response.status_code == 200:
                data = response.json()
                if data.get('success') and 'data' in data:
                    services_count = len(data['data'])
                    self.log_test("Services API", True,
                                f"Retrieved status for {services_count} services")
                    return True
                else:
                    self.log_test("Services API", False,
                                f"Invalid response format: {data}")
                    return False
            else:
                self.log_test("Services API", False, f"HTTP {response.status_code}")
                return False

        except Exception as e:
            self.log_test("Services API", False, str(e))
            return False

    def test_alerts_api(self):
        """Probar API de alertas"""
        try:
            response = requests.get(f"{self.api_base}/alerts/active", timeout=10)

            if response.status_code == 200:
                data = response.json()
                if data.get('success') and 'data' in data:
                    alerts_count = len(data['data'])
                    self.log_test("Alerts API", True,
                                f"Retrieved {alerts_count} active alerts")
                    return True
                else:
                    self.log_test("Alerts API", False,
                                f"Invalid response format: {data}")
                    return False
            else:
                self.log_test("Alerts API", False, f"HTTP {response.status_code}")
                return False

        except Exception as e:
            self.log_test("Alerts API", False, str(e))
            return False

    def test_ml_engine(self):
        """Probar motor de machine learning"""
        try:
            script_path = os.path.join(os.path.dirname(__file__), 'python', 'bi_ml_engine.py')
            result = subprocess.run(
                [sys.executable, script_path, '--predict'],
                capture_output=True, text=True, timeout=60
            )

            if result.returncode == 0:
                self.log_test("ML Engine", True, "ML predictions executed successfully")
                return True
            else:
                self.log_test("ML Engine", False,
                            f"ML execution failed: {result.stderr[:200]}...")
                return False

        except Exception as e:
            self.log_test("ML Engine", False, str(e))
            return False

    def test_reports_generation(self):
        """Probar generación de reportes"""
        try:
            script_path = os.path.join(os.path.dirname(__file__), 'python', 'bi_reports.py')
            result = subprocess.run(
                [sys.executable, script_path, '--type', 'performance',
                 '--days', '1', '--format', 'html'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                self.log_test("Reports Generation", True, "Report generated successfully")
                return True
            else:
                self.log_test("Reports Generation", False,
                            f"Report generation failed: {result.stderr[:200]}...")
                return False

        except Exception as e:
            self.log_test("Reports Generation", False, str(e))
            return False

    def test_monitoring_integration(self):
        """Probar integración con sistema de monitoreo existente"""
        try:
            script_path = os.path.join(os.path.dirname(__file__), '..', 'monitoring',
                                     'scripts', 'integrate_monitoring.sh')
            result = subprocess.run(
                [script_path, 'test-integration'],
                capture_output=True, text=True, timeout=60
            )

            if result.returncode == 0 and 'Integration test completed' in result.stdout:
                self.log_test("Monitoring Integration", True,
                            "Integration with existing monitoring system successful")
                return True
            else:
                self.log_test("Monitoring Integration", False,
                            f"Integration test failed: {result.stderr[:200]}...")
                return False

        except Exception as e:
            self.log_test("Monitoring Integration", False, str(e))
            return False

    def check_data_volume(self):
        """Verificar volumen de datos en el sistema"""
        try:
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()

            # Contar registros en tablas principales
            tables = ['system_metrics', 'service_status', 'alerts_history', 'performance_predictions']
            data_counts = {}

            for table in tables:
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                data_counts[table] = count

            conn.close()

            total_records = sum(data_counts.values())
            self.log_test("Data Volume Check", True,
                        f"Total records: {total_records:,} "
                        f"(Metrics: {data_counts['system_metrics']:,}, "
                        f"Services: {data_counts['service_status']:,}, "
                        f"Alerts: {data_counts['alerts_history']:,}, "
                        f"Predictions: {data_counts['performance_predictions']:,})")

            return True

        except Exception as e:
            self.log_test("Data Volume Check", False, str(e))
            return False

    def run_all_tests(self):
        """Ejecutar todas las pruebas"""
        print("🧪 Iniciando pruebas del Sistema BI de Webmin/Virtualmin")
        print("=" * 60)

        # Pruebas de infraestructura
        self.test_database_connection()
        self.test_api_server()

        # Pruebas de funcionalidad
        self.test_data_collection()
        self.test_realtime_metrics_api()
        self.test_historical_metrics_api()
        self.test_services_api()
        self.test_alerts_api()

        # Pruebas avanzadas
        self.test_ml_engine()
        self.test_reports_generation()
        self.test_monitoring_integration()

        # Verificación final
        self.check_data_volume()

        print("\n" + "=" * 60)
        self.print_summary()

    def print_summary(self):
        """Imprimir resumen de pruebas"""
        total_tests = len(self.test_results)
        passed_tests = sum(1 for test in self.test_results if test['success'])
        failed_tests = total_tests - passed_tests

        print(f"📊 Resumen de Pruebas: {passed_tests}/{total_tests} exitosas")

        if failed_tests > 0:
            print("\n❌ Pruebas Fallidas:")
            for test in self.test_results:
                if not test['success']:
                    print(f"   • {test['test']}: {test['message']}")

        if passed_tests == total_tests:
            print("\n🎉 ¡Todas las pruebas pasaron exitosamente!")
            print("El Sistema BI está funcionando correctamente.")
        else:
            print(f"\n⚠️ {failed_tests} pruebas fallaron. Revise la configuración y logs.")

        # Guardar resultados en archivo
        results_file = os.path.join(os.path.dirname(__file__), 'test_results.json')
        with open(results_file, 'w') as f:
            json.dump(self.test_results, f, indent=2, default=str)

        print(f"\n📄 Resultados detallados guardados en: {results_file}")

def main():
    import argparse

    parser = argparse.ArgumentParser(description='Sistema de Pruebas para BI Webmin/Virtualmin')
    parser.add_argument('--config', help='Archivo de configuración')
    parser.add_argument('--test', choices=[
        'database', 'api', 'collection', 'ml', 'reports', 'integration', 'all'
    ], default='all', help='Prueba específica a ejecutar')

    args = parser.parse_args()

    tester = BISystemTester(args.config)

    if args.test == 'all':
        tester.run_all_tests()
    elif args.test == 'database':
        tester.test_database_connection()
    elif args.test == 'api':
        tester.test_api_server()
        tester.test_realtime_metrics_api()
        tester.test_historical_metrics_api()
        tester.test_services_api()
        tester.test_alerts_api()
    elif args.test == 'collection':
        tester.test_data_collection()
    elif args.test == 'ml':
        tester.test_ml_engine()
    elif args.test == 'reports':
        tester.test_reports_generation()
    elif args.test == 'integration':
        tester.test_monitoring_integration()

    # Imprimir resumen si no es 'all'
    if args.test != 'all':
        tester.print_summary()

if __name__ == '__main__':
    main()