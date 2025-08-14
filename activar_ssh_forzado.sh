#!/bin/bash

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

echo "🔧 ACTIVANDO SSH EN macOS DE FORMA FORZADA"
echo "=========================================="
echo ""

echo "📊 Estado inicial:"
echo "SSH Agent: $(launchctl list | grep ssh-agent | wc -l) procesos"
echo "SSH Daemon: $(ps aux | grep -c [s]shd) procesos"
echo "Puerto 22: $(netstat -an | grep -c :22.*LISTEN) en escucha"
echo ""

echo "🚀 Intentando activar SSH..."
echo ""

# Método 1: systemsetup (el más común)
echo "1️⃣ Usando systemsetup..."
echo "Comando: sudo systemsetup -setremotelogin on"
echo "(Necesitarás ingresar tu contraseña de administrador)"
echo ""

# Método 2: launchctl para el servicio SSH
echo "2️⃣ Verificando servicios de SSH disponibles..."
ls -la /System/Library/LaunchDaemons/ | grep ssh

echo ""
echo "3️⃣ Intentando cargar servicio SSH manualmente..."

# Verificar si existe el archivo del servicio SSH
if [[ -f "/System/Library/LaunchDaemons/ssh.plist" ]]; then
    echo "✅ Archivo ssh.plist encontrado"
    echo "Comando: sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist"
else
    echo "❌ Archivo ssh.plist no encontrado en ubicación estándar"
fi

# Buscar archivos relacionados con SSH
echo ""
echo "4️⃣ Buscando archivos de configuración SSH..."
find /System/Library/LaunchDaemons/ -name "*ssh*" 2>/dev/null
find /Library/LaunchDaemons/ -name "*ssh*" 2>/dev/null

echo ""
echo "5️⃣ Verificando configuración actual del sistema..."
echo "Configuraciones de compartir:"
echo "Comando para verificar: systemsetup -getremotelogin"

echo ""
echo "🔧 PASOS MANUALES PARA ACTIVAR SSH:"
echo ""
echo "OPCIÓN A: Interfaz gráfica (MÁS FÁCIL)"
echo "  1. Abrir 'Preferencias del Sistema'"
echo "  2. Ir a 'Compartir'"
echo "  3. Activar 'Acceso remoto' o 'Remote Login'"
echo "  4. Seleccionar usuarios que pueden acceder"
echo ""
echo "OPCIÓN B: Terminal"
echo "  sudo systemsetup -setremotelogin on"
echo ""
echo "OPCIÓN C: Comando alternativo"
echo "  sudo launchctl enable system/com.openssh.sshd"
echo "  sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist"
echo ""

echo "📋 DESPUÉS DE ACTIVAR, VERIFICAR:"
echo "  netstat -an | grep :22"
echo "  ps aux | grep sshd"
echo "  ssh $(whoami)@localhost"
echo ""

echo "🔒 OBTENER TU IP PARA CONEXIONES REMOTAS:"
ifconfig | grep "inet " | grep -v 127.0.0.1 | head -3

echo ""
echo "⚠️  IMPORTANTE:"
echo "- SSH en macOS requiere permisos de administrador"
echo "- El firewall de macOS puede bloquear conexiones"
echo "- Algunos comandos necesitan ejecutarse como root (sudo)"
echo ""

echo "🧪 PROBANDO CONEXIÓN DESPUÉS DE ACTIVAR:"
echo "ssh $(whoami)@localhost"
echo "ssh $(whoami)@$(hostname)"
echo ""

echo "📖 LOGS PARA DEBUGGING:"
echo "sudo log show --predicate 'process == \"sshd\"' --last 30m"
echo ""
