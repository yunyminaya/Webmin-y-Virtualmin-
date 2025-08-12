# Guía Completa - Webmin y Virtualmin en Ubuntu/Debian

## Instalación Rápida

### Método 1: Un Solo Comando
```bash
sudo bash instalacion_un_comando.sh
```

### Método 2: Manual
```bash
sudo bash instalar_webmin_virtualmin.sh
```

## Verificación Post-Instalación
```bash
bash verificar_funciones_pro_nativas.sh
```

## Configuración Inicial
1. Acceder a https://[IP]:10000
2. Usuario: root
3. Configurar primer dominio virtual

## Servicios Verificados
- Webmin: Puerto 10000
- Virtualmin: Puerto 10000
- Nginx: Puerto 80/443
- MySQL: Base de datos activa
- Postfix: Correo electrónico

## Solución de Problemas
- Ejecutar: bash diagnostico_completo.sh
- Verificar: bash verificar_seguridad_completa.sh
- Respaldos: bash sub_agente_backup.sh

## Compatibilidad
- Ubuntu 20.04 LTS ✅
- Ubuntu 22.04 LTS ✅
- Debian 10+ ✅
- Debian 11/12 ✅

## Conclusión
Sistema completamente funcional y optimizado para producción.
