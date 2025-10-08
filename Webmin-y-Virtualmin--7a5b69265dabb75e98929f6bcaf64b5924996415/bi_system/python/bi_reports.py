#!/usr/bin/env python3
"""
Sistema de Generación de Reportes para el Sistema BI de Webmin/Virtualmin
Genera reportes en PDF, HTML y Excel con análisis detallado
"""

import os
import sys
import json
import psycopg2
import psycopg2.extras
from datetime import datetime, timedelta
from jinja2 import Template
import pdfkit
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import base64
from io import BytesIO
import logging
import configparser

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/webmin/bi_reports.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class BIReports:
    def __init__(self, config_file=None):
        self.config_file = config_file or os.path.join(
            os.path.dirname(__file__), '..', 'bi_database.conf'
        )
        self.db_config = self.load_config()
        self.reports_dir = os.path.join(os.path.dirname(__file__), '..', 'reports')
        os.makedirs(self.reports_dir, exist_ok=True)

        # Configurar estilo de matplotlib
        plt.style.use('seaborn-v0_8')
        sns.set_palette("husl")

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

    def generate_performance_report(self, hostname=None, days=7, format_type='html'):
        """Generar reporte de rendimiento del sistema"""
        logger.info(f"Generando reporte de rendimiento para {hostname or 'todos'} - {days} días")

        try:
            conn = self.get_db_connection()
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Obtener datos de rendimiento
            query = """
                SELECT
                    date,
                    hostname,
                    avg_cpu,
                    max_cpu,
                    avg_memory,
                    max_memory,
                    avg_disk,
                    max_disk,
                    samples_count
                FROM system_metrics_daily
                WHERE date >= CURRENT_DATE - INTERVAL '%s days'
                ORDER BY date DESC, hostname
            """

            params = [days]
            if hostname:
                query = query.replace("ORDER BY", "AND hostname = %s ORDER BY")
                params.append(hostname)

            cursor.execute(query, params)
            performance_data = cursor.fetchall()

            # Obtener datos de uptime
            uptime_query = """
                SELECT * FROM service_uptime_daily
                WHERE date >= CURRENT_DATE - INTERVAL '%s days'
                ORDER BY date DESC, hostname, service_name
            """
            cursor.execute(uptime_query, [days])
            uptime_data = cursor.fetchall()

            # Obtener alertas
            alerts_query = """
                SELECT
                    date,
                    severity,
                    COUNT(*) as alert_count
                FROM alerts_history
                WHERE timestamp >= CURRENT_TIMESTAMP - INTERVAL '%s days'
                GROUP BY date, severity
                ORDER BY date DESC, severity
            """
            cursor.execute(alerts_query, [days])
            alerts_data = cursor.fetchall()

            conn.close()

            # Generar reportes
            report_data = {
                'title': f'Reporte de Rendimiento del Sistema',
                'hostname': hostname or 'Todos los servidores',
                'period': f'Últimos {days} días',
                'generated_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'performance_data': performance_data,
                'uptime_data': uptime_data,
                'alerts_data': alerts_data
            }

            if format_type == 'html':
                return self.generate_html_report(report_data, 'performance')
            elif format_type == 'pdf':
                return self.generate_pdf_report(report_data, 'performance')
            elif format_type == 'excel':
                return self.generate_excel_report(report_data, 'performance')

        except Exception as e:
            logger.error(f"Error generando reporte de rendimiento: {e}")
            return None

    def generate_predictive_report(self, hostname=None, days=30, format_type='html'):
        """Generar reporte de análisis predictivo"""
        logger.info(f"Generando reporte predictivo para {hostname or 'todos'} - {days} días")

        try:
            conn = self.get_db_connection()
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Obtener predicciones recientes
            query = """
                SELECT
                    timestamp,
                    hostname,
                    prediction_type,
                    prediction_value,
                    confidence,
                    time_horizon_hours
                FROM performance_predictions
                WHERE timestamp >= CURRENT_TIMESTAMP - INTERVAL '%s days'
                AND confidence > 0.5
            """

            params = [days]
            if hostname:
                query += " AND hostname = %s"
                params.append(hostname)

            query += " ORDER BY timestamp DESC"

            cursor.execute(query, params)
            predictions_data = cursor.fetchall()

            # Obtener tendencias históricas para comparación
            trends_query = """
                SELECT
                    date,
                    hostname,
                    avg_cpu,
                    avg_memory,
                    avg_disk
                FROM system_metrics_daily
                WHERE date >= CURRENT_DATE - INTERVAL '%s days'
                ORDER BY date DESC
            """
            cursor.execute(trends_query, [days])
            trends_data = cursor.fetchall()

            conn.close()

            # Análisis de tendencias
            trends_analysis = self.analyze_trends(trends_data)

            report_data = {
                'title': f'Reporte de Análisis Predictivo',
                'hostname': hostname or 'Todos los servidores',
                'period': f'Últimos {days} días',
                'generated_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'predictions_data': predictions_data,
                'trends_data': trends_data,
                'trends_analysis': trends_analysis
            }

            if format_type == 'html':
                return self.generate_html_report(report_data, 'predictive')
            elif format_type == 'pdf':
                return self.generate_pdf_report(report_data, 'predictive')
            elif format_type == 'excel':
                return self.generate_excel_report(report_data, 'predictive')

        except Exception as e:
            logger.error(f"Error generando reporte predictivo: {e}")
            return None

    def generate_comprehensive_report(self, hostname=None, days=30, format_type='html'):
        """Generar reporte completo del sistema"""
        logger.info(f"Generando reporte completo para {hostname or 'todos'} - {days} días")

        try:
            conn = self.get_db_connection()
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Recopilar todos los datos necesarios
            report_data = {
                'title': f'Reporte Completo del Sistema BI',
                'hostname': hostname or 'Todos los servidores',
                'period': f'Últimos {days} días',
                'generated_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }

            # Métricas de rendimiento
            cursor.execute("""
                SELECT * FROM system_metrics_daily
                WHERE date >= CURRENT_DATE - INTERVAL '%s days'
                ORDER BY date DESC
            """, [days])
            report_data['performance_data'] = cursor.fetchall()

            # Estado de servicios
            cursor.execute("""
                SELECT * FROM service_uptime_daily
                WHERE date >= CURRENT_DATE - INTERVAL '%s days'
                ORDER BY date DESC
            """, [days])
            report_data['uptime_data'] = cursor.fetchall()

            # Alertas
            cursor.execute("""
                SELECT * FROM alerts_history
                WHERE timestamp >= CURRENT_TIMESTAMP - INTERVAL '%s days'
                ORDER BY timestamp DESC
            """, [days])
            report_data['alerts_data'] = cursor.fetchall()

            # Predicciones
            cursor.execute("""
                SELECT * FROM performance_predictions
                WHERE timestamp >= CURRENT_TIMESTAMP - INTERVAL '%s days'
                ORDER BY timestamp DESC
            """, [days])
            report_data['predictions_data'] = cursor.fetchall()

            # Actividad de usuarios
            cursor.execute("""
                SELECT
                    date(timestamp) as date,
                    username,
                    action,
                    COUNT(*) as action_count
                FROM user_activity
                WHERE timestamp >= CURRENT_TIMESTAMP - INTERVAL '%s days'
                GROUP BY date(timestamp), username, action
                ORDER BY date DESC
            """, [days])
            report_data['user_activity'] = cursor.fetchall()

            conn.close()

            # Generar estadísticas resumen
            report_data['summary_stats'] = self.generate_summary_stats(report_data)

            if format_type == 'html':
                return self.generate_html_report(report_data, 'comprehensive')
            elif format_type == 'pdf':
                return self.generate_pdf_report(report_data, 'comprehensive')
            elif format_type == 'excel':
                return self.generate_excel_report(report_data, 'comprehensive')

        except Exception as e:
            logger.error(f"Error generando reporte completo: {e}")
            return None

    def generate_summary_stats(self, report_data):
        """Generar estadísticas resumen para reportes"""
        stats = {}

        # Estadísticas de rendimiento
        if 'performance_data' in report_data and report_data['performance_data']:
            perf_data = pd.DataFrame(report_data['performance_data'])
            stats['performance'] = {
                'avg_cpu': perf_data['avg_cpu'].mean(),
                'max_cpu': perf_data['max_cpu'].max(),
                'avg_memory': perf_data['avg_memory'].mean(),
                'max_memory': perf_data['max_memory'].max(),
                'avg_disk': perf_data['avg_disk'].mean(),
                'max_disk': perf_data['max_disk'].max(),
                'total_samples': len(perf_data)
            }

        # Estadísticas de uptime
        if 'uptime_data' in report_data and report_data['uptime_data']:
            uptime_data = pd.DataFrame(report_data['uptime_data'])
            stats['uptime'] = {
                'overall_uptime': uptime_data['uptime_percentage'].mean(),
                'services_monitored': uptime_data['service_name'].nunique(),
                'total_checks': len(uptime_data)
            }

        # Estadísticas de alertas
        if 'alerts_data' in report_data and report_data['alerts_data']:
            alerts_data = pd.DataFrame(report_data['alerts_data'])
            stats['alerts'] = {
                'total_alerts': len(alerts_data),
                'critical_alerts': len(alerts_data[alerts_data['severity'] == 'critical']),
                'warning_alerts': len(alerts_data[alerts_data['severity'] == 'warning']),
                'resolved_alerts': len(alerts_data[alerts_data.get('resolved', False)])
            }

        return stats

    def analyze_trends(self, trends_data):
        """Analizar tendencias en los datos"""
        if not trends_data:
            return {}

        df = pd.DataFrame(trends_data)

        analysis = {}

        # Análisis de tendencias de CPU
        if 'avg_cpu' in df.columns:
            cpu_trend = self.calculate_trend(df['avg_cpu'].values)
            analysis['cpu_trend'] = cpu_trend

        # Análisis de tendencias de memoria
        if 'avg_memory' in df.columns:
            memory_trend = self.calculate_trend(df['avg_memory'].values)
            analysis['memory_trend'] = memory_trend

        # Análisis de tendencias de disco
        if 'avg_disk' in df.columns:
            disk_trend = self.calculate_trend(df['avg_disk'].values)
            analysis['disk_trend'] = disk_trend

        return analysis

    def calculate_trend(self, values):
        """Calcular tendencia lineal de una serie de valores"""
        if len(values) < 2:
            return {'slope': 0, 'direction': 'stable', 'change_percent': 0}

        import numpy as np
        x = np.arange(len(values))
        slope, intercept = np.polyfit(x, values, 1)

        change_percent = (slope * len(values) / values[0]) * 100 if values[0] != 0 else 0

        if abs(change_percent) < 5:
            direction = 'stable'
        elif change_percent > 0:
            direction = 'increasing'
        else:
            direction = 'decreasing'

        return {
            'slope': slope,
            'direction': direction,
            'change_percent': change_percent
        }

    def generate_html_report(self, data, report_type):
        """Generar reporte HTML"""
        template_path = os.path.join(os.path.dirname(__file__), 'templates', f'{report_type}_report.html')

        # Template HTML básico si no existe archivo de template
        if not os.path.exists(template_path):
            html_template = self.get_html_template(report_type)
        else:
            with open(template_path, 'r') as f:
                html_template = f.read()

        template = Template(html_template)
        html_content = template.render(**data)

        # Generar gráficos
        charts_html = self.generate_charts_html(data, report_type)
        html_content = html_content.replace('{{charts}}', charts_html)

        # Guardar archivo
        filename = f"{report_type}_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.html"
        filepath = os.path.join(self.reports_dir, filename)

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(html_content)

        logger.info(f"Reporte HTML generado: {filepath}")
        return filepath

    def generate_pdf_report(self, data, report_type):
        """Generar reporte PDF"""
        # Primero generar HTML
        html_file = self.generate_html_report(data, report_type)

        if not html_file:
            return None

        # Convertir a PDF
        pdf_filename = html_file.replace('.html', '.pdf')

        try:
            pdfkit.from_file(html_file, pdf_filename)
            logger.info(f"Reporte PDF generado: {pdf_filename}")
            return pdf_filename
        except Exception as e:
            logger.error(f"Error generando PDF: {e}")
            return None

    def generate_excel_report(self, data, report_type):
        """Generar reporte Excel"""
        filename = f"{report_type}_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
        filepath = os.path.join(self.reports_dir, filename)

        try:
            with pd.ExcelWriter(filepath, engine='openpyxl') as writer:
                # Hoja de resumen
                if 'summary_stats' in data:
                    summary_df = pd.DataFrame.from_dict(data['summary_stats'], orient='index')
                    summary_df.to_excel(writer, sheet_name='Resumen')

                # Hoja de rendimiento
                if 'performance_data' in data and data['performance_data']:
                    perf_df = pd.DataFrame(data['performance_data'])
                    perf_df.to_excel(writer, sheet_name='Rendimiento')

                # Hoja de uptime
                if 'uptime_data' in data and data['uptime_data']:
                    uptime_df = pd.DataFrame(data['uptime_data'])
                    uptime_df.to_excel(writer, sheet_name='Uptime')

                # Hoja de alertas
                if 'alerts_data' in data and data['alerts_data']:
                    alerts_df = pd.DataFrame(data['alerts_data'])
                    alerts_df.to_excel(writer, sheet_name='Alertas')

                # Hoja de predicciones
                if 'predictions_data' in data and data['predictions_data']:
                    pred_df = pd.DataFrame(data['predictions_data'])
                    pred_df.to_excel(writer, sheet_name='Predicciones')

            logger.info(f"Reporte Excel generado: {filepath}")
            return filepath

        except Exception as e:
            logger.error(f"Error generando Excel: {e}")
            return None

    def generate_charts_html(self, data, report_type):
        """Generar gráficos para reportes HTML"""
        charts = []

        try:
            # Gráfico de rendimiento
            if 'performance_data' in data and data['performance_data']:
                fig, ax = plt.subplots(figsize=(10, 6))
                perf_df = pd.DataFrame(data['performance_data'])

                if not perf_df.empty:
                    ax.plot(perf_df['date'], perf_df['avg_cpu'], label='CPU', color='#e74c3c')
                    ax.plot(perf_df['date'], perf_df['avg_memory'], label='Memoria', color='#f39c12')
                    ax.plot(perf_df['date'], perf_df['avg_disk'], label='Disco', color='#9b59b6')

                    ax.set_title('Tendencias de Rendimiento del Sistema')
                    ax.set_xlabel('Fecha')
                    ax.set_ylabel('Uso (%)')
                    ax.legend()
                    ax.grid(True, alpha=0.3)

                    plt.xticks(rotation=45)
                    plt.tight_layout()

                    # Convertir a base64
                    buffer = BytesIO()
                    plt.savefig(buffer, format='png', dpi=100, bbox_inches='tight')
                    buffer.seek(0)
                    image_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')
                    charts.append(f'<img src="data:image/png;base64,{image_base64}" alt="Gráfico de Rendimiento" style="max-width:100%; height:auto;">')

                plt.close()

            # Gráfico de uptime
            if 'uptime_data' in data and data['uptime_data']:
                fig, ax = plt.subplots(figsize=(10, 6))
                uptime_df = pd.DataFrame(data['uptime_data'])

                if not uptime_df.empty:
                    # Pivot para tener servicios como columnas
                    pivot_df = uptime_df.pivot(index='date', columns='service_name', values='uptime_percentage')
                    pivot_df.plot(ax=ax, kind='line', marker='o')

                    ax.set_title('Uptime de Servicios')
                    ax.set_xlabel('Fecha')
                    ax.set_ylabel('Uptime (%)')
                    ax.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
                    ax.grid(True, alpha=0.3)

                    plt.xticks(rotation=45)
                    plt.tight_layout()

                    buffer = BytesIO()
                    plt.savefig(buffer, format='png', dpi=100, bbox_inches='tight')
                    buffer.seek(0)
                    image_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')
                    charts.append(f'<img src="data:image/png;base64,{image_base64}" alt="Gráfico de Uptime" style="max-width:100%; height:auto;">')

                plt.close()

        except Exception as e:
            logger.error(f"Error generando gráficos: {e}")

        return '\n'.join(charts)

    def get_html_template(self, report_type):
        """Obtener template HTML básico"""
        return f"""
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{{{title}}}}</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; }}
        .header {{ text-align: center; border-bottom: 2px solid #333; padding-bottom: 20px; margin-bottom: 30px; }}
        .section {{ margin-bottom: 30px; }}
        .metric {{ background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 10px 0; }}
        table {{ width: 100%; border-collapse: collapse; margin: 20px 0; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background-color: #f2f2f2; }}
        .chart {{ margin: 20px 0; text-align: center; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>{{{{title}}}}</h1>
        <p><strong>Servidor:</strong> {{{{hostname}}}}</p>
        <p><strong>Período:</strong> {{{{period}}}}</p>
        <p><strong>Generado:</strong> {{{{generated_at}}}}</p>
    </div>

    <div class="section">
        <h2>Resumen Ejecutivo</h2>
        {{% if summary_stats %}}
        <div class="metric">
            <h3>Estadísticas de Rendimiento</h3>
            <ul>
                <li>CPU Promedio: {{{{summary_stats.performance.avg_cpu:.1f}}}}%</li>
                <li>CPU Máximo: {{{{summary_stats.performance.max_cpu:.1f}}}}%</li>
                <li>Memoria Promedio: {{{{summary_stats.performance.avg_memory:.1f}}}}%</li>
                <li>Uptime General: {{{{summary_stats.uptime.overall_uptime:.1f}}}}%</li>
            </ul>
        </div>
        {{% endif %}}
    </div>

    <div class="section">
        <h2>Gráficos y Visualizaciones</h2>
        <div class="chart">
            {{{{charts}}}}
        </div>
    </div>

    <div class="section">
        <h2>Datos Detallados</h2>
        {{% if performance_data %}}
        <h3>Rendimiento del Sistema</h3>
        <table>
            <tr>
                <th>Fecha</th>
                <th>Servidor</th>
                <th>CPU Avg</th>
                <th>CPU Max</th>
                <th>Memoria Avg</th>
                <th>Disco Avg</th>
            </tr>
            {{% for item in performance_data %}}
            <tr>
                <td>{{{{item.date}}}}</td>
                <td>{{{{item.hostname}}}}</td>
                <td>{{{{item.avg_cpu:.1f}}}}%</td>
                <td>{{{{item.max_cpu:.1f}}}}%</td>
                <td>{{{{item.avg_memory:.1f}}}}%</td>
                <td>{{{{item.avg_disk:.1f}}}}%</td>
            </tr>
            {{% endfor %}}
        </table>
        {{% endif %}}
    </div>
</body>
</html>
        """

def main():
    import argparse

    parser = argparse.ArgumentParser(description='Sistema de Reportes BI')
    parser.add_argument('--config', help='Archivo de configuración')
    parser.add_argument('--type', choices=['performance', 'predictive', 'comprehensive'],
                       default='performance', help='Tipo de reporte')
    parser.add_argument('--format', choices=['html', 'pdf', 'excel'],
                       default='html', help='Formato del reporte')
    parser.add_argument('--hostname', help='Nombre del servidor (opcional)')
    parser.add_argument('--days', type=int, default=7, help='Días de datos históricos')

    args = parser.parse_args()

    reports = BIReports(args.config)

    if args.type == 'performance':
        result = reports.generate_performance_report(args.hostname, args.days, args.format)
    elif args.type == 'predictive':
        result = reports.generate_predictive_report(args.hostname, args.days, args.format)
    elif args.type == 'comprehensive':
        result = reports.generate_comprehensive_report(args.hostname, args.days, args.format)

    if result:
        print(f"Reporte generado exitosamente: {result}")
        sys.exit(0)
    else:
        print("Error generando el reporte")
        sys.exit(1)

if __name__ == '__main__':
    main()