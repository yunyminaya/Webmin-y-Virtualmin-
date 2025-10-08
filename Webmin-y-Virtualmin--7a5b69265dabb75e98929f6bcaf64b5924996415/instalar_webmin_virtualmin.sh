#!/bin/bash
set -e

# Verificar privilegios de root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecute como root (sudo)"
  exit 1
fi

echo "Instalando dependencias necesarias..."
apt-get update
apt-get install -y wget curl software-properties-common apt-transport-https gnupg

echo "Agregando repositorios de Webmin y Virtualmin..."
wget -qO - http://software.virtualmin.com/lib/RPM-GPG-KEY-virtualmin | apt-key add -
wget -qO - http://software.virtualmin.com/lib/RPM-GPG-KEY-webmin | apt-key add -
add-apt-repository "deb http://software.virtualmin.com/gpl/ubuntu virtualmin-universal main"
add-apt-repository "deb http://download.webmin.com/download/repository sarge contrib"

echo "Actualizando repositorios..."
apt-get update

echo "Instalando Webmin y Virtualmin..."
apt-get install -y webmin virtualmin

echo "Activando sistema de reparación automática..."
if [ -f ./install_auto_repair_system.sh ]; then
  bash ./install_auto_repair_system.sh auto
fi

echo "Activando sistema de monitoreo continuo..."
if [ -f ./continuous_monitoring.sh ]; then
  bash ./continuous_monitoring.sh auto
fi

echo "Instalación completada. Acceda a Webmin en https://<su-ip>:10000/"