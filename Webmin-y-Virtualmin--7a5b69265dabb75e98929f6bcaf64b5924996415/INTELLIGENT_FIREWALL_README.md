# Firewall Inteligente con Aprendizaje Automático

## Descripción

Este módulo implementa un firewall inteligente para Webmin y Virtualmin que utiliza algoritmos de aprendizaje automático para detectar y bloquear amenazas en tiempo real.

## Funcionalidades Implementadas

### 1. Análisis de Patrones de Tráfico en Tiempo Real
- Monitoreo continuo del tráfico de red
- Extracción de características del tráfico (paquetes/segundo, conexiones, etc.)
- Logging estructurado para análisis posterior

### 2. Detección Automática de Anomalías usando Algoritmos ML
- Motor de ML basado en Python con scikit-learn
- Algoritmo Isolation Forest para detección de anomalías
- Entrenamiento automático con datos históricos

### 3. Reglas Dinámicas que se Adaptan al Comportamiento Normal
- Actualización automática de reglas de iptables
- Adaptación basada en patrones aprendidos
- Reglas temporales que expiran automáticamente

### 4. Bloqueo Adaptativo de Amenazas basado en Puntuaciones de Riesgo
- Sistema de puntuación de riesgo para IPs
- Bloqueo automático cuando se supera el umbral
- Escalado de bloqueo basado en severidad

### 5. Whitelist/Blacklist Inteligente con Aprendizaje Automático
- Clasificación automática de IPs confiables/sospechosas
- Aprendizaje de patrones de comportamiento legítimo
- Actualización dinámica de listas

### 6. Integración Completa con Sistema IDS/IPS
- Compatibilidad con Snort/Suricata
- Procesamiento de alertas IDS
- Correlación de eventos

### 7. Dashboard Web para Visualización de Amenazas y Métricas
- Interfaz web integrada en Webmin
- Gráficos en tiempo real de amenazas
- Estadísticas de rendimiento del firewall

### 8. Aprendizaje Continuo basado en Datos Históricos
- Entrenamiento periódico del modelo ML
- Recopilación automática de datos de tráfico
- Mejora continua de la precisión de detección

### 9. Integración con iptables/ufw
- Gestión automática de reglas de iptables
- Cadena dedicada para reglas dinámicas
- Persistencia de reglas

### 10. Integración con Servicios Existentes
- Compatibilidad con Virtualmin
- Integración con logs del sistema
- API para integración con otros módulos

## Arquitectura

```
intelligent-firewall/
├── module.info              # Metadatos del módulo
├── config                   # Configuración por defecto
├── config_info.pl          # Información de configuración
├── intelligent-firewall-lib.pl  # Librería principal
├── ml_engine.py            # Motor de ML en Python
├── index.cgi               # Página principal
├── dashboard.cgi           # Dashboard web
├── init_firewall.pl        # Inicialización
├── train_model.pl          # Entrenamiento ML
└── ...
```

## Instalación

1. Ejecutar el script de instalación:
   ```bash
   ./install_intelligent_firewall.sh
   ```

2. Acceder desde Webmin > Firewall Inteligente

## Configuración

- **Habilitar firewall inteligente**: Activa/desactiva el módulo
- **Ruta al modelo ML**: Ubicación del archivo del modelo entrenado
- **Ruta a logs de tráfico**: Archivo de logs para análisis
- **Umbral de bloqueo**: Puntuación mínima para bloqueo automático
- **Intervalo de aprendizaje**: Horas entre re-entrenamientos del modelo
- **Cadena de iptables**: Nombre de la cadena de reglas

## Uso

### Dashboard
- Visualiza estadísticas en tiempo real
- Monitorea IPs bloqueadas
- Revisa métricas de rendimiento

### Gestión de Amenazas
- Lista de IPs bloqueadas con puntuaciones
- Opción para desbloquear manualmente
- Historial de detecciones

### Configuración Avanzada
- Ajuste de parámetros ML
- Configuración de umbrales
- Gestión de listas blancas/negras

## Algoritmos ML Utilizados

- **Isolation Forest**: Para detección de anomalías en tráfico
- **Standard Scaler**: Para normalización de características
- **Entrenamiento supervisado**: Basado en datos históricos etiquetados

## Integraciones

- **Webmin**: Interfaz de administración
- **Virtualmin**: Gestión de servidores virtuales
- **iptables**: Reglas de firewall
- **Python/scikit-learn**: Motor de ML
- **Cron**: Entrenamiento automático

## Seguridad

- Ejecuta con privilegios mínimos necesarios
- Logs auditados
- Validación de entrada
- Protección contra inyección

## Rendimiento

- Procesamiento en tiempo real
- Optimización de recursos
- Escalabilidad horizontal
- Monitoreo de uso de CPU/memoria

## Soporte

Para soporte técnico, consulte la documentación de Webmin/Virtualmin o contacte al desarrollador.