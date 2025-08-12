#!/bin/bash

# Script para activar SSH en macOS
# En macOS, SSH se llama "Remote Login"

echo "🔐 ACTIVADOR DE SSH PARA macOS"
echo "================================"
echo ""

# Verificar estado actual
echo "📊 Verificando estado actual del SSH..."

# Verificar si ssh-agent está corriendo
if launchctl list | grep -q "ssh-agent"; then
    echo "✅ SSH Agent está corriendo"
else
    echo "❌ SSH Agent no está corriendo"
fi

# Verificar si sshd está corriendo
if ps aux | grep -q "[s]shd"; then
    echo "✅ SSH Daemon (sshd) está corriendo"
    echo "🎉 SSH ya está ACTIVO en tu sistema"
else
    echo "❌ SSH Daemon (sshd) no está corriendo"
    echo "🔧 SSH necesita ser activado"
fi

# Verificar puerto 22
if netstat -an | grep -q ":22.*LISTEN"; then
    echo "✅ Puerto 22 está en escucha"
    ssh_active=true
else
    echo "❌ Puerto 22 no está en escucha"
    ssh_active=false
fi

echo ""
echo "🛠️ OPCIONES PARA ACTIVAR SSH EN macOS:"
echo ""

if [[ "$ssh_active" == "true" ]]; then
    echo "🎉 ¡SSH YA ESTÁ ACTIVO!"
    echo ""
    echo "Para conectarte desde otro equipo:"
    echo "ssh $(whoami)@$(hostname)"
    echo ""
    echo "Tu dirección IP local:"
    ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print "  " $2}'
else
    echo "Para activar SSH, tienes estas opciones:"
    echo ""
    echo "📋 OPCIÓN 1: Interfaz gráfica (RECOMENDADO)"
    echo "  1. Ir a: Preferencias del Sistema → Compartir"
    echo "  2. Activar: 'Acceso remoto' o 'Remote Login'"
    echo "  3. Configurar usuarios que pueden conectarse"
    echo ""
    echo "📋 OPCIÓN 2: Terminal (necesita contraseña de administrador)"
    echo "  sudo systemsetup -setremotelogin on"
    echo ""
    echo "📋 OPCIÓN 3: Usando launchctl"
    echo "  sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist"
fi

echo ""
echo "🔒 CONFIGURACIÓN DE SEGURIDAD SSH:"
echo ""
echo "Archivo de configuración SSH: /etc/ssh/sshd_config"
echo ""
echo "Configuraciones recomendadas:"
echo "  PermitRootLogin no"
echo "  PasswordAuthentication yes (o no si usas llaves)"
echo "  Port 22 (o cambiar por seguridad)"
echo ""

echo "🧪 VERIFICAR CONEXIÓN SSH:"
echo ""
echo "Desde el mismo equipo:"
echo "  ssh $(whoami)@localhost"
echo ""
echo "Desde otro equipo en la red:"
echo "  ssh $(whoami)@TU_IP_LOCAL"
echo ""

echo "📝 LOGS DE SSH:"
echo "  /var/log/system.log (buscar 'sshd')"
echo "  log show --predicate 'process == \"sshd\"' --last 1h"
echo ""

echo "🔧 TROUBLESHOOTING:"
echo ""
echo "Si SSH no funciona después de activarlo:"
echo "  1. Verificar firewall de macOS"
echo "  2. Reiniciar servicio: sudo launchctl kickstart -k system/com.openssh.sshd"
echo "  3. Verificar configuración: sudo sshd -T"
echo "  4. Ver logs: log show --predicate 'process == \"sshd\"' --last 10m"
echo ""

# Función para probar SSH
test_ssh() {
    echo "🧪 PROBANDO CONEXIÓN SSH LOCAL..."
    
    if command -v ssh >/dev/null 2>&1; then
        echo "Intentando conexión SSH local..."
        
        # Probar conexión SSH local (sin contraseña, solo verificar que responde)
        timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no $(whoami)@localhost "echo 'SSH funciona'" 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            echo "✅ SSH está funcionando correctamente"
        else
            echo "❌ SSH no responde o necesita configuración"
        fi
    else
        echo "❌ Cliente SSH no encontrado"
    fi
}

# Ejecutar prueba
test_ssh

echo ""
echo "🎯 RESUMEN:"
if [[ "$ssh_active" == "true" ]]; then
    echo "✅ SSH está ACTIVO y funcionando"
else
    echo "❌ SSH está INACTIVO - usar las opciones arriba para activarlo"
fi

echo ""
echo "Para activar SSH de forma permanente y segura:"
echo "👉 Ir a Preferencias del Sistema → Compartir → Acceso remoto"