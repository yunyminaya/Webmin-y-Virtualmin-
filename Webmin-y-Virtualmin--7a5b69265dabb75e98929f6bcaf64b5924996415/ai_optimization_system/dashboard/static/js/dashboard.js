// AI Optimization Dashboard JavaScript

class DashboardManager {
    constructor() {
        this.charts = {};
        this.realTimeData = [];
        this.maxDataPoints = 50;
        this.updateInterval = 5000; // 5 segundos
        this.eventSource = null;

        this.init();
    }

    init() {
        this.setupCharts();
        this.connectRealTimeUpdates();
        this.loadInitialData();
        this.setupEventListeners();

        // Actualización periódica de datos
        setInterval(() => this.updateDashboard(), this.updateInterval);
    }

    setupCharts() {
        // Gráfico de rendimiento
        const ctx = document.getElementById('performanceChart').getContext('2d');
        this.charts.performance = new Chart(ctx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'CPU %',
                    data: [],
                    borderColor: '#007bff',
                    backgroundColor: 'rgba(0, 123, 255, 0.1)',
                    tension: 0.4,
                    fill: true
                }, {
                    label: 'Memoria %',
                    data: [],
                    borderColor: '#28a745',
                    backgroundColor: 'rgba(40, 167, 69, 0.1)',
                    tension: 0.4,
                    fill: true
                }, {
                    label: 'Disco %',
                    data: [],
                    borderColor: '#ffc107',
                    backgroundColor: 'rgba(255, 193, 7, 0.1)',
                    tension: 0.4,
                    fill: true
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100
                    }
                },
                plugins: {
                    legend: {
                        position: 'top'
                    }
                },
                animation: {
                    duration: 1000
                }
            }
        });
    }

    connectRealTimeUpdates() {
        // Conectar a stream de datos en tiempo real
        this.eventSource = new EventSource('/api/real-time');

        this.eventSource.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);
                this.handleRealTimeData(data);
            } catch (e) {
                console.error('Error parsing real-time data:', e);
            }
        };

        this.eventSource.onerror = (error) => {
            console.error('EventSource error:', error);
            // Reconectar después de un delay
            setTimeout(() => this.connectRealTimeUpdates(), 5000);
        };
    }

    handleRealTimeData(data) {
        // Actualizar métricas en tiempo real
        this.updateMetrics(data);

        // Añadir datos al gráfico
        this.addChartData(data);

        // Actualizar indicadores visuales
        this.updateVisualIndicators(data);
    }

    updateMetrics(data) {
        // Actualizar valores de métricas
        if (data.cpu) {
            document.getElementById('cpu-percent').textContent = data.cpu.percent || 0;
            document.getElementById('cpu-load').textContent = (data.cpu.load_1m || 0).toFixed(1);
            document.getElementById('cpu-progress').style.width = `${data.cpu.percent || 0}%`;
        }

        if (data.memory) {
            document.getElementById('memory-percent').textContent = data.memory.percent || 0;
            document.getElementById('memory-used').textContent = ((data.memory.used || 0) / (1024**3)).toFixed(1);
            document.getElementById('memory-progress').style.width = `${data.memory.percent || 0}%`;
        }

        if (data.disk) {
            document.getElementById('disk-percent').textContent = data.disk.percent || 0;
            document.getElementById('disk-free').textContent = ((data.disk.free || 0) / (1024**3)).toFixed(1);
            document.getElementById('disk-progress').style.width = `${data.disk.percent || 0}%`;
        }

        if (data.load_avg !== undefined) {
            document.getElementById('load-avg').textContent = data.load_avg.toFixed(1);
        }
    }

    addChartData(data) {
        const now = new Date();
        const timeLabel = now.toLocaleTimeString();

        // Añadir nueva etiqueta de tiempo
        this.charts.performance.data.labels.push(timeLabel);

        // Mantener solo las últimas N etiquetas
        if (this.charts.performance.data.labels.length > this.maxDataPoints) {
            this.charts.performance.data.labels.shift();
        }

        // Añadir datos
        this.charts.performance.data.datasets[0].data.push(data.cpu?.percent || 0);
        this.charts.performance.data.datasets[1].data.push(data.memory?.percent || 0);
        this.charts.performance.data.datasets[2].data.push(data.disk?.percent || 0);

        // Mantener solo las últimas N puntos de datos
        this.charts.performance.data.datasets.forEach(dataset => {
            if (dataset.data.length > this.maxDataPoints) {
                dataset.data.shift();
            }
        });

        this.charts.performance.update('none'); // Actualizar sin animación
    }

    updateVisualIndicators(data) {
        // Actualizar colores de indicadores según umbrales
        this.updateIndicatorColor('cpu-percent', data.cpu?.percent || 0, 80, 95);
        this.updateIndicatorColor('memory-percent', data.memory?.percent || 0, 85, 95);
        this.updateIndicatorColor('disk-percent', data.disk?.percent || 0, 90, 98);
    }

    updateIndicatorColor(elementId, value, warningThreshold, criticalThreshold) {
        const element = document.getElementById(elementId);
        if (!element) return;

        // Remover clases anteriores
        element.classList.remove('text-warning', 'text-danger', 'metric-critical');

        if (value >= criticalThreshold) {
            element.classList.add('text-danger', 'metric-critical');
        } else if (value >= warningThreshold) {
            element.classList.add('text-warning');
        }
    }

    loadInitialData() {
        // Cargar datos iniciales
        this.updateDashboard();
        this.loadRecommendations();
        this.loadOptimizationHistory();
        this.loadLoadBalancerStatus();
        this.loadPredictions();
    }

    updateDashboard() {
        // Actualizar métricas principales
        fetch('/api/metrics')
            .then(response => response.json())
            .then(data => {
                this.updatePredictions(data.predictions);
                this.updateServiceStatus(data);
            })
            .catch(error => console.error('Error updating dashboard:', error));
    }

    updatePredictions(predictions) {
        if (!predictions || !predictions.predictions) return;

        const pred = predictions.predictions;

        // Actualizar predicciones en la UI
        if (pred.cpu) {
            document.getElementById('cpu-prediction').textContent = `${pred.cpu.predicted_percent?.toFixed(1) || '--'}%`;
            document.getElementById('cpu-confidence').textContent = pred.cpu.confidence ? `${(pred.cpu.confidence * 100).toFixed(0)}%` : '--';
        }

        if (pred.memory) {
            document.getElementById('memory-prediction').textContent = `${pred.memory.predicted_percent?.toFixed(1) || '--'}%`;
            document.getElementById('memory-confidence').textContent = pred.memory.confidence ? `${(pred.memory.confidence * 100).toFixed(0)}%` : '--';
        }

        if (pred.disk) {
            document.getElementById('disk-prediction').textContent = `${pred.disk.predicted_percent?.toFixed(1) || '--'}%`;
            document.getElementById('disk-confidence').textContent = pred.disk.confidence ? `${(pred.disk.confidence * 100).toFixed(0)}%` : '--';
        }
    }

    loadRecommendations() {
        fetch('/api/recommendations')
            .then(response => response.json())
            .then(data => {
                this.renderRecommendations(data.recommendations || []);
            })
            .catch(error => console.error('Error loading recommendations:', error));
    }

    renderRecommendations(recommendations) {
        const container = document.getElementById('recommendations-list');

        if (recommendations.length === 0) {
            container.innerHTML = '<div class="text-center text-muted"><i class="fas fa-check-circle"></i> No hay recomendaciones pendientes</div>';
            return;
        }

        container.innerHTML = recommendations.map(rec => `
            <div class="recommendation-card ${rec.priority === 4 ? 'high' : rec.priority === 3 ? 'medium' : 'low'}">
                <div class="recommendation-title">${rec.title || 'Recomendación'}</div>
                <div class="recommendation-description">${rec.description || ''}</div>
                <div class="recommendation-actions mt-2">
                    <span class="confidence-badge bg-${rec.priority === 4 ? 'danger' : rec.priority === 3 ? 'warning' : 'success'}">
                        Confianza: ${(rec.confidence * 100).toFixed(0)}%
                    </span>
                    <button class="btn btn-sm btn-outline-primary ms-2" onclick="implementRecommendation('${rec.id}')">
                        <i class="fas fa-play"></i> Implementar
                    </button>
                    <button class="btn btn-sm btn-outline-secondary ms-1" onclick="dismissRecommendation('${rec.id}')">
                        <i class="fas fa-times"></i> Descartar
                    </button>
                </div>
            </div>
        `).join('');
    }

    loadOptimizationHistory() {
        fetch('/api/optimization-history')
            .then(response => response.json())
            .then(data => {
                this.renderOptimizationHistory(data.history || []);
            })
            .catch(error => console.error('Error loading optimization history:', error));
    }

    renderOptimizationHistory(history) {
        const container = document.getElementById('optimization-history');

        if (history.length === 0) {
            container.innerHTML = '<div class="text-center text-muted">No hay historial de optimizaciones</div>';
            return;
        }

        container.innerHTML = history.map(item => `
            <div class="optimization-item">
                <div class="d-flex justify-content-between">
                    <span class="optimization-type">${item.type || 'optimización'}</span>
                    <small class="optimization-time">${new Date(item.timestamp).toLocaleString()}</small>
                </div>
                <div class="text-muted small">${item.optimizations ? item.optimizations.length : 0} cambios aplicados</div>
            </div>
        `).join('');
    }

    loadLoadBalancerStatus() {
        fetch('/api/load-balancer')
            .then(response => response.json())
            .then(data => {
                document.getElementById('active-nodes').textContent = data.active_nodes || 0;
                document.getElementById('avg-load').textContent = data.average_load ? data.average_load.toFixed(1) : '0';
            })
            .catch(error => console.error('Error loading load balancer status:', error));
    }

    loadPredictions() {
        // Las predicciones se cargan con updateDashboard
    }

    updateServiceStatus(data) {
        // Actualizar estado de servicios basado en métricas
        const services = data.services || {};

        this.updateServiceIndicator('apache-status', services.apache ? 'success' : 'secondary', services.apache ? 'Activo' : 'Verificando...');
        this.updateServiceIndicator('mysql-status', services.mysql ? 'success' : 'secondary', services.mysql ? 'Activo' : 'Verificando...');
        this.updateServiceIndicator('php-status', services.php ? 'success' : 'secondary', services.php ? 'Activo' : 'Verificando...');
    }

    updateServiceIndicator(elementId, statusClass, text) {
        const element = document.getElementById(elementId);
        if (!element) return;

        const badge = element.querySelector('.badge');
        if (badge) {
            badge.className = `badge bg-${statusClass}`;
            badge.textContent = text;
        }
    }

    setupEventListeners() {
        // Aquí se pueden añadir event listeners adicionales
    }
}

// Funciones globales para botones
function manualOptimization() {
    if (confirm('¿Ejecutar optimización manual de todos los servicios?')) {
        fetch('/api/manual-optimization', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ service: 'all' })
        })
        .then(response => response.json())
        .then(data => {
            showNotification(data.success ? 'success' : 'error',
                           data.success ? 'Optimización completada' : 'Error en optimización');
            if (data.success) {
                // Recargar datos después de optimización
                setTimeout(() => window.location.reload(), 2000);
            }
        })
        .catch(error => {
            console.error('Error:', error);
            showNotification('error', 'Error ejecutando optimización');
        });
    }
}

function toggleAutoMode() {
    // Implementar toggle de modo automático
    const autoModeSpan = document.getElementById('auto-mode');
    const currentMode = autoModeSpan.textContent;

    // Aquí iría la lógica para cambiar el modo
    autoModeSpan.textContent = currentMode === 'ON' ? 'OFF' : 'ON';
    showNotification('info', `Modo automático ${autoModeSpan.textContent}`);
}

function optimizeLoad() {
    showNotification('info', 'Optimizando distribución de carga...');
    // Implementar optimización de carga
}

function implementRecommendation(recId) {
    fetch('/api/recommendation-action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'implement', recommendation_id: recId })
    })
    .then(response => response.json())
    .then(data => {
        showNotification(data.success ? 'success' : 'error',
                       data.success ? 'Recomendación implementada' : 'Error implementando recomendación');
        if (data.success) {
            // Recargar recomendaciones
            dashboard.loadRecommendations();
        }
    })
    .catch(error => {
        console.error('Error:', error);
        showNotification('error', 'Error implementando recomendación');
    });
}

function dismissRecommendation(recId) {
    fetch('/api/recommendation-action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'dismiss', recommendation_id: recId })
    })
    .then(response => response.json())
    .then(data => {
        showNotification(data.success ? 'success' : 'error',
                       data.success ? 'Recomendación descartada' : 'Error descartando recomendación');
        if (data.success) {
            // Recargar recomendaciones
            dashboard.loadRecommendations();
        }
    })
    .catch(error => {
        console.error('Error:', error);
        showNotification('error', 'Error descartando recomendación');
    });
}

function showNotification(type, message) {
    // Crear notificación temporal
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible fade show notification`;
    notification.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;

    document.body.appendChild(notification);

    // Auto-remover después de 5 segundos
    setTimeout(() => {
        if (notification.parentNode) {
            notification.remove();
        }
    }, 5000);
}

// Inicializar dashboard cuando se carga la página
let dashboard;
document.addEventListener('DOMContentLoaded', function() {
    dashboard = new DashboardManager();
});