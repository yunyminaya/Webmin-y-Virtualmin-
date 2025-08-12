# Instalación de un Solo Comando desde GitHub

## Comando Único para Instalación Completa

```bash
curl -sSL https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main/instalacion_github_unico.sh | sudo bash
```

## Que Incluye la Instalación

### Webmin Pro Nativo 100% Funcional

- Administrador de archivos avanzado
- Configuración de respaldos PRO
- Gestor de rotación de logs
- Administrador de procesos en tiempo real
- Programador de tareas avanzado
- Administración completa de usuarios/grupos

### Virtualmin Pro Nativo 100% Funcional

- Hosting virtual completo con múltiples dominios
- Gestión completa de servidores virtuales
- Certificados SSL Let's Encrypt automáticos
- Servidor de correo Postfix + Dovecot configurado
- MySQL/MariaDB + PostgreSQL completos
- Apache + Nginx optimizados

## Requisitos del Sistema

- Ubuntu 18.04+ o Debian 10+
- Root access (sudo)
- Conexión a internet

## Verificación Post-Instalación

```bash
bash verificar_funciones_pro_nativas.sh
```

## Acceso al Panel

- URL: https://[TU_IP]:10000
- Usuario: root
- Contraseña: [Contraseña de root del sistema]

## Soporte

- Logs: /var/log/webmin-virtualmin-install.log
- Repositorio: [GitHub Repository](https://github.com/yunyminaya/Webmin-y-Virtualmin-)
