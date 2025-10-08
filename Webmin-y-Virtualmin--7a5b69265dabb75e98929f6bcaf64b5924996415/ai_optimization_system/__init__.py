"""
🤖 AI Optimizer Pro - Sistema de Optimización Automática con IA para Webmin/Virtualmin

Sistema completo que incluye:
- Análisis predictivo de rendimiento usando Machine Learning
- Optimización automática de configuraciones (Apache, MySQL, PHP, sistema)
- Balanceo de carga inteligente basado en patrones de uso
- Gestión automática de recursos (CPU, memoria, disco)
- Recomendaciones proactivas con implementación automática
- Dashboard de optimización con métricas y tendencias

Integración completa con el sistema de monitoreo avanzado existente.

Autor: AI Optimizer Pro Team
Versión: 1.0.0
"""

__version__ = "1.0.0"
__author__ = "AI Optimizer Pro Team"
__description__ = "Sistema de Optimización Automática con IA para Webmin/Virtualmin"

# Importaciones principales
from .core.ai_optimizer_core import AIOptimizerCore
from .ml_models.predictive_analyzer import PredictiveAnalyzer
from .config_manager.auto_config_optimizer import AutoConfigOptimizer
from .resource_manager.intelligent_resource_manager import IntelligentResourceManager
from .load_balancer.smart_load_balancer import SmartLoadBalancer
from .recommendations.proactive_recommendation_engine import ProactiveRecommendationEngine
from .dashboard.ai_optimization_dashboard import AIOptimizationDashboard

__all__ = [
    'AIOptimizerCore',
    'PredictiveAnalyzer',
    'AutoConfigOptimizer',
    'IntelligentResourceManager',
    'SmartLoadBalancer',
    'ProactiveRecommendationEngine',
    'AIOptimizationDashboard'
]

# Función de inicio rápido
def start_ai_optimizer(config_file=None):
    """
    Función de inicio rápido del sistema de optimización con IA

    Args:
        config_file (str, optional): Ruta al archivo de configuración personalizado

    Returns:
        AIOptimizerCore: Instancia del sistema inicializado
    """
    optimizer = AIOptimizerCore(config_file)
    optimizer.initialize_components()
    optimizer.start()
    return optimizer

# Función para iniciar dashboard
def start_dashboard(optimizer, host="localhost", port=8888):
    """
    Función para iniciar el dashboard del sistema

    Args:
        optimizer (AIOptimizerCore): Instancia del optimizador
        host (str): Host para el dashboard
        port (int): Puerto para el dashboard

    Returns:
        AIOptimizationDashboard: Instancia del dashboard
    """
    dashboard = AIOptimizationDashboard(optimizer, host, port)
    dashboard.start()
    return dashboard