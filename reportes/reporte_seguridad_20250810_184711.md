# Reporte de Seguridad de Webmin/Virtualmin
Fecha: Sun Aug 10 18:47:11 UTC 2025

## Sistema Operativo
- **Tipo**: debian
- **Fecha de verificación**: Sun Aug 10 18:47:11 UTC 2025

## Puertos Abiertos
### Puertos críticos detectados:
- ✅ Puerto Webmin (10000) está abierto
- ✅ Puerto SSH (22/2222) está abierto
- ✅ Puerto HTTP (80) está abierto
- ✅ Puerto HTTPS (443) está abierto
- ✅ Puerto MySQL (3306) está abierto
### Puertos no estándar detectados:
```
tcp        0      0 127.0.0.1:6379          0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:465             0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:8891          0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:783           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:11000         0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:11211         0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:20000         0.0.0.0:*               LISTEN     
tcp6       0      0 :::2222                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 :::465                  :::*                    LISTEN     
tcp6       0      0 :::21                   :::*                    LISTEN     
tcp6       0      0 ::1:6379                :::*                    LISTEN     
```

## Configuración de Webmin/Virtualmin
- ℹ️ Versión de Webmin: 2.402
- ✅ Virtualmin está instalado
- ⚠️ No se pudo determinar la versión de Virtualmin
- ℹ️ Virtualmin GPL está instalado
- ✅ SSL está habilitado en Webmin
- ℹ️ Puerto de Webmin: 10000
- ℹ️ Webmin usa el puerto predeterminado
- ✅ Protección contra fuerza bruta habilitada (5 intentos, 60 segundos)

## Configuración de Seguridad de Virtualmin
- ✅ Virtualmin está instalado
- ℹ️     theme version: 24.02
- ✅ Archivo de configuración de Virtualmin encontrado
- ⚠️ DKIM no está habilitado en Virtualmin
- ⚠️ SPF no está habilitado en Virtualmin
- ⚠️ SSL no está habilitado por defecto en Virtualmin

## Configuración del Servidor Web
- ✅ Apache está instalado
### Módulos de seguridad de Apache:
- ⚠️ Módulo mod_ssl no está habilitado
- ⚠️ Módulo mod_security no está habilitado
- ⚠️ Módulo mod_evasive no está habilitado
- ⚠️ No se encontró configuración SSL para Apache
- ✅ Cabeceras de seguridad configuradas

## Configuración de Bases de Datos
### MySQL/MariaDB
- ✅ MySQL/MariaDB está instalado
- ℹ️ Versión: 15.1
- ✅ Servicio activo
