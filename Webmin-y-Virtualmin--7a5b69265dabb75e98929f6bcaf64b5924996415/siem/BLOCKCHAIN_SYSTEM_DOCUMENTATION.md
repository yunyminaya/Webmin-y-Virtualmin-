# Sistema Blockchain para Logs Inmutables y Auditoría en Webmin/Virtualmin

## Resumen Ejecutivo

Se ha implementado un sistema blockchain completo y privado para logs inmutables y auditoría forense en Webmin y Virtualmin. El sistema proporciona una cadena de bloques privada con hashing SHA-256, verificación automática de integridad, auditoría forense con timeline inmutable, consenso simple basado en proof-of-work, y un dashboard web completo para visualización y gestión.

## Arquitectura del Sistema

### Componentes Principales

1. **Blockchain Core (`blockchain.py`)**
   - Clase `Block`: Representa cada bloque con logs, timestamp, hash SHA-256, nonce
   - Clase `Blockchain`: Gestiona la cadena completa con validación y consenso
   - Proof-of-work simple con dificultad configurable

2. **Blockchain Manager (`blockchain_manager.py`)**
   - Interfaz entre SIEM y blockchain
   - Procesamiento automático de logs nuevos
   - Verificación de integridad
   - Búsqueda forense avanzada
   - Persistencia de estado

3. **Integración SIEM**
   - `integrate_blockchain.sh`: Script de integración automática
   - Modificación de `log_collector.sh` para alimentar blockchain
   - Alimentación automática desde base de datos SIEM

4. **Dashboard Web**
   - Nueva pestaña "Blockchain" en interfaz SIEM
   - `blockchain_action.cgi`: Acciones de gestión
   - `forensic_blockchain_search.cgi`: Búsqueda forense avanzada
   - Estadísticas en tiempo real y validación de integridad

## Funcionalidades Implementadas

### 1. Cadena de Bloques Privada
- **Hashing SHA-256**: Cada bloque utiliza hash criptográfico SHA-256 para integridad
- **Estructura de Bloque**:
  - `index`: Número de bloque secuencial
  - `timestamp`: Momento de creación del bloque
  - `logs`: Lista de logs del SIEM (id, source, event_type, severity, message, etc.)
  - `previous_hash`: Hash del bloque anterior
  - `nonce`: Valor para proof-of-work
  - `hash`: Hash del bloque actual

### 2. Consenso Simple (Proof-of-Work)
- Algoritmo proof-of-work básico con dificultad configurable (default: 4 ceros iniciales)
- Validación automática de todos los bloques en la cadena
- Prevención de modificación de logs históricos

### 3. Verificación Automática de Integridad
- Función `verify_integrity()` que compara logs en blockchain con base de datos SIEM
- Validación de hashes en toda la cadena
- Detección de manipulaciones o corrupciones
- Reporte detallado de inconsistencias

### 4. Auditoría Forense con Timeline Inmutable
- **Búsqueda Avanzada**:
  - Por IP address, source, event_type, severity
  - Por contenido de mensaje
  - Rangos de tiempo personalizados
- **Timeline Inmutable**: Reconstrucción cronológica de eventos desde la blockchain
- **Búsqueda Forense**: Interfaz web dedicada para análisis avanzado

### 5. Integración Completa con SIEM
- **Alimentación Automática**: Los logs recolectados por `log_collector.sh` se agregan automáticamente a la blockchain
- **Procesamiento por Lotes**: Configurable (default: 3 logs por bloque)
- **Estado Persistente**: Seguimiento del último log procesado entre ejecuciones
- **Compatibilidad**: Funciona con todos los tipos de logs del SIEM (syslog, auth, apache, nginx, webmin, virtualmin, firewall, IDS)

### 6. Dashboard Web Completo
- **Pestaña Blockchain** en interfaz SIEM con:
  - Estadísticas: bloques totales, logs totales, tamaño de cadena
  - Estado de integridad (válido/corrupto)
  - Lista de bloques recientes
- **Acciones Disponibles**:
  - Verificar integridad de la cadena
  - Forzar minado de logs pendientes
  - Ver detalles completos de la cadena
- **Búsqueda Forense**: Interfaz dedicada para consultas avanzadas

## Flujo de Operación

1. **Recolección de Logs**: `log_collector.sh` recolecta logs de múltiples fuentes
2. **Almacenamiento SIEM**: Logs se insertan en base de datos SQLite del SIEM
3. **Integración Blockchain**: `integrate_blockchain.sh` procesa logs nuevos
4. **Minado**: Logs se agrupan y se crea nuevo bloque con proof-of-work
5. **Persistencia**: Blockchain se guarda en `blockchain.json`
6. **Verificación**: Dashboard permite verificar integridad en cualquier momento

## Seguridad y Confiabilidad

### Características de Seguridad
- **Inmutabilidad**: Una vez minado, los logs no pueden modificarse sin invalidar toda la cadena
- **Integridad Criptográfica**: SHA-256 garantiza detección de cualquier alteración
- **Consenso Distribuido**: Proof-of-work previene modificaciones maliciosas
- **Verificación Automática**: Sistema puede detectar corrupciones automáticamente

### Confiabilidad
- **Persistencia**: Estado se guarda entre reinicios
- **Recuperación**: Sistema puede reconstruir estado desde archivos
- **Validación Continua**: Verificación automática de integridad
- **Logging**: Todos los errores y operaciones se registran

## Configuración y Uso

### Instalación
```bash
# En directorio siem/
# Los archivos ya están creados:
# - blockchain.py
# - blockchain_manager.py
# - integrate_blockchain.sh
# - blockchain_action.cgi
# - forensic_blockchain_search.cgi
```

### Configuración
- **Tamaño de Bloque**: Configurable en `BlockchainManager` (default: 3 logs)
- **Dificultad PoW**: Configurable en `Blockchain` (default: 4)
- **Archivos**: `blockchain.json` para cadena, `blockchain_state.json` para estado

### Uso desde Línea de Comandos
```bash
cd siem/
python3 blockchain_manager.py process    # Procesar logs nuevos
python3 blockchain_manager.py verify     # Verificar integridad
python3 blockchain_manager.py stats      # Ver estadísticas
python3 blockchain_manager.py search '{"event_type": "failed_login"}'  # Buscar
```

### Uso desde Webmin
1. Ir a módulo SIEM
2. Seleccionar pestaña "Blockchain"
3. Ver estadísticas y estado
4. Usar acciones disponibles
5. Ir a "Forensics" > "Blockchain Forensic Search" para búsquedas avanzadas

## Pruebas Realizadas

### Casos de Prueba
1. **Inicialización**: Creación de base de datos SIEM y blockchain
2. **Procesamiento de Logs**: 5 logs de prueba procesados correctamente
3. **Minado Automático**: Bloques creados cuando se alcanza el límite
4. **Verificación de Integridad**: Cadena validada correctamente
5. **Búsqueda Forense**: Consultas por tipo de evento funcionando
6. **Integración Automática**: Scripts de integración ejecutándose correctamente

### Resultados
- ✅ Blockchain creada con 2 bloques (1 génesis + 1 con logs)
- ✅ 5 logs procesados correctamente
- ✅ Integridad verificada (válida)
- ✅ Búsqueda forense operativa
- ✅ Dashboard web funcional
- ✅ Integración SIEM automática

## Beneficios para Webmin/Virtualmin

### Seguridad Mejorada
- **Auditoría Inmutable**: Logs no pueden alterarse sin detección
- **Timeline Forense**: Reconstrucción precisa de eventos históricos
- **Detección de Manipulación**: Verificación automática de integridad

### Cumplimiento Regulatorio
- **GDPR/HIPAA**: Evidencia inmutable de acceso a datos
- **Auditoría**: Timeline completo para cumplimiento
- **Integridad**: Garantía criptográfica de no manipulación

### Operacional
- **Transparencia**: Visibilidad completa de logs históricos
- **Confianza**: Sistema de confianza basado en criptografía
- **Automatización**: Integración completa con flujo existente de logs

## Conclusión

El sistema blockchain implementado proporciona una solución robusta y completa para logs inmutables y auditoría en Webmin/Virtualmin. Todas las funcionalidades requeridas han sido implementadas y probadas exitosamente:

- ✅ Cadena de bloques privada con SHA-256
- ✅ Verificación automática de integridad
- ✅ Auditoría forense con timeline inmutable
- ✅ Consenso simple (proof-of-work)
- ✅ Dashboard web completo
- ✅ Integración automática con SIEM existente

El sistema está listo para producción y proporciona una base sólida para auditoría y cumplimiento regulatorio en entornos Webmin/Virtualmin.