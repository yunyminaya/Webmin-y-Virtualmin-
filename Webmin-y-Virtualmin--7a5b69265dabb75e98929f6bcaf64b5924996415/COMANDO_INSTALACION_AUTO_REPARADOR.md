# 🚀 COMANDO DE INSTALACIÓN Y FUNCIONES DE AUTO-REPARACIÓN

## 📋 RESUMEN EJECUTIVO

### 🎯 **COMANDO PRINCIPAL DE INSTALACIÓN**
```bash
./instalar_todo.sh
```
**¡Solo este comando! El sistema decide automáticamente qué hacer.**

---

## 🔍 **DECISIONES AUTOMÁTICAS DEL SISTEMA**

| Situación del Servidor | Acción Automática | Resultado |
|----------------------|-------------------|-----------|
| ❌ **Servidor Nuevo** | INSTALACIÓN COMPLETA | Instala Webmin + Virtualmin automáticamente |
| 🔧 **Servidor con Problemas** | REPARACIÓN AUTOMÁTICA | Detecta y repara problemas automáticamente |
| ✅ **Servidor Funcionando OK** | VERIFICACIÓN DE ESTADO | Muestra estado actual del sistema |

---

## 🔧 **FUNCIONES DEL AUTO-REPARADOR DE SERVIDOR**

### 🚀 **AUTO-REPARACIÓN PRINCIPAL** (`./auto_repair.sh`)
- ✅ **Servicios del Sistema**: Webmin, Apache/Nginx, MySQL/MariaDB
- ✅ **Configuraciones**: Archivos corruptos, permisos incorrectos
- ✅ **Dependencias**: Librerías y paquetes faltantes
- ✅ **Bases de Datos**: Conexiones y configuraciones rotas
- ✅ **Integridad**: Verificación de archivos del sistema

### 🚨 **REPARACIONES CRÍTICAS** (`./auto_repair_critical.sh`)
- ✅ **Memoria Crítica**: >95% uso o <100MB libres
- ✅ **Disco Crítico**: >98% uso del disco duro
- ✅ **CPU Crítico**: Load average >10
- ✅ **Procesos Críticos**: Zombies y procesos huérfanos
- ✅ **Red Crítica**: Problemas de conectividad

### 🛡️ **DEFENSA ANTI-ATAQUES** (`./auto_defense.sh`)
- ✅ **Ataques de Fuerza Bruta**: Intentos masivos de login
- ✅ **Conexiones Sospechosas**: netcat, ncat, socat, telnet
- ✅ **Procesos Maliciosos**: Detección y eliminación automática
- ✅ **Picos de Recursos**: CPU/Memoria anormales
- ✅ **Cambios en Archivos**: Modificaciones en archivos críticos
- ✅ **Servidores Virtuales**: Problemas en dominios y configuraciones

---

## 📊 **DASHBOARD PROFESIONAL** (`defense_dashboard.html`)
- ✅ **Diseño Webmin/Virtualmin**: Header azul gradiente, navegación gris
- ✅ **Controles Interactivos**: Botones de defensa, reparación, limpieza
- ✅ **Estado en Tiempo Real**: Monitoreo continuo del sistema
- ✅ **Logs Detallados**: Historial completo con scroll
- ✅ **Acceso Web**: Interfaz profesional en navegador

---

## 🎯 **USO PRÁCTICO**

### **Para Servidores Nuevos:**
```bash
ssh user@servidor-nuevo
./instalar_todo.sh
# ¡Instala todo automáticamente!
```

### **Para Servidores con Problemas:**
```bash
ssh user@servidor-problemas
./instalar_todo.sh
# ¡Detecta y repara automáticamente!
```

### **Para Monitoreo Continuo:**
```bash
./auto_defense.sh start    # Defensa 24/7
open defense_dashboard.html # Panel de control
```

---

## ✅ **RESULTADO FINAL**
- ✅ **Un solo comando** para instalación y reparación
- ✅ **Detección automática** del estado del servidor
- ✅ **Reparación completa** de todos los problemas
- ✅ **Protección 24/7** contra ataques
- ✅ **Dashboard profesional** con diseño Webmin
- ✅ **Documentación completa** en GitHub

**¡El sistema es completamente inteligente y se mantiene solo! 🤖✨**
