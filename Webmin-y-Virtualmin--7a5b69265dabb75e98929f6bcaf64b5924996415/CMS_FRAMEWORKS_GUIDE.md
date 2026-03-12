# Guía de Instalación de CMS y Frameworks

## Descripción General

Este sistema incluye instalación automática de **WordPress** y **Laravel** desde sus fuentes oficiales, junto con herramientas esenciales para el desarrollo web seguro en servidores virtuales.

## Características Incluidas

### WordPress
- ✅ Instalación desde `wordpress.org` (última versión)
- ✅ Configuración automática de `wp-config.php` con salts seguros
- ✅ Configuraciones de seguridad avanzadas
- ✅ Headers de seguridad HTTP
- ✅ Protección contra ataques comunes
- ✅ Permisos seguros para hosting compartido

### Laravel
- ✅ Instalación desde repositorio oficial de Laravel
- ✅ Configuración automática de `.env` con APP_KEY
- ✅ Configuraciones de seguridad para producción
- ✅ Virtual hosts optimizados para Laravel
- ✅ Migraciones de base de datos automáticas
- ✅ Storage link configurado

### Herramientas Adicionales
- ✅ **Composer**: Gestor de dependencias PHP
- ✅ **WP-CLI**: Herramientas de línea de comandos para WordPress
- ✅ **Drush**: Herramientas para Drupal

## Instalación Automática

El sistema se instala automáticamente durante la instalación unificada:

```bash
sudo ./instalacion_unificada.sh
```

## Instalación Manual de Sitios Específicos

Si necesitas instalar WordPress o Laravel en dominios específicos:

### Instalar WordPress

```bash
# Sintaxis
./install_cms_frameworks.sh
# Luego usar las funciones manualmente:
install_wordpress "midominio.com" "mi_base_datos" "usuario_db" "password_db"
```

### Instalar Laravel

```bash
# Sintaxis
./install_cms_frameworks.sh
# Luego usar las funciones manualmente:
install_laravel "midominio.com" "mi_base_datos" "usuario_db" "password_db"
```

## Configuraciones de Seguridad Implementadas

### WordPress
- `DISALLOW_FILE_EDIT = true` - Deshabilita edición de archivos desde admin
- `FORCE_SSL_ADMIN = true` - Fuerza HTTPS en administración
- Headers de seguridad: X-Frame-Options, X-XSS-Protection, CSP
- Protección de archivos sensibles (.htaccess, wp-config.php)
- Rate limiting básico

### Laravel
- `APP_DEBUG = false` - Debug deshabilitado en producción
- `APP_ENV = production` - Entorno de producción
- Sesiones seguras con HTTP Only y SameSite
- Headers de seguridad avanzados
- Configuración SSL automática

## Estructura de Directorios

```
/var/www/html/
├── midominio.com/          # Sitio WordPress/Laravel
│   ├── wp-config.php       # Config WordPress (permisos 600)
│   ├── .env               # Config Laravel
│   ├── wp-content/        # Contenido WordPress
│   ├── storage/           # Storage Laravel
│   └── public/            # Document root
```

## Virtual Hosts Configurados

### Para WordPress
- DocumentRoot: `/var/www/html/midominio.com`
- Permite overrides para .htaccess
- Configuraciones PHP optimizadas

### Para Laravel
- DocumentRoot: `/var/www/html/midominio.com/public`
- Configuraciones específicas para Laravel
- Headers de seguridad SSL

## Base de Datos

El sistema crea automáticamente:
- Base de datos dedicada por sitio
- Usuario de base de datos con permisos limitados
- Prefijos de tabla seguros (wp_, lara_)

## Permisos de Archivos

- **Archivos**: 644 (lectura para todos, escritura para owner)
- **Directorios**: 755 (ejecución para todos, escritura para owner)
- **Configuraciones críticas**: 600 (solo owner)
- **Uploads**: 775 (permite escritura para web server)

## Actualizaciones de Seguridad

### WordPress
- Actualizaciones automáticas menores habilitadas
- Actualizaciones principales manuales (para testing)
- WP-CLI disponible para actualizaciones

### Laravel
- Composer para gestión de dependencias
- Artisan para tareas de mantenimiento
- Actualizaciones manuales recomendadas

## Monitoreo y Mantenimiento

### Logs
- `/var/log/apache2/*_access.log` - Accesos web
- `/var/log/apache2/*_error.log` - Errores web
- `/var/log/mysql/mysql.log` - Logs de base de datos

### Comandos Útiles

```bash
# Verificar estado de servicios
sudo systemctl status apache2
sudo systemctl status mysql

# Ver logs en tiempo real
sudo tail -f /var/log/apache2/midominio_access.log

# Gestionar WordPress con WP-CLI
cd /var/www/html/midominio.com
wp core update
wp plugin update --all

# Gestionar Laravel con Artisan
cd /var/www/html/midominio.com
php artisan migrate
php artisan config:cache
```

## Solución de Problemas

### Problemas Comunes

1. **Error 500 en WordPress**
   - Verificar permisos de archivos
   - Revisar configuración de PHP-FPM
   - Verificar logs de error

2. **Error en Laravel**
   - Verificar APP_KEY en .env
   - Ejecutar `php artisan config:clear`
   - Verificar permisos de storage/

3. **Problemas de Base de Datos**
   - Verificar credenciales en configuración
   - Revisar permisos de usuario MySQL
   - Verificar conectividad a MySQL

### Comandos de Diagnóstico

```bash
# Verificar PHP
php -v
php -m

# Verificar Composer
composer --version

# Verificar WP-CLI
wp --version

# Verificar conectividad DB
mysql -u usuario_db -p -e "SELECT 1"
```

## Mejores Prácticas

1. **Siempre usar HTTPS** - Configurado automáticamente
2. **Actualizaciones regulares** - Monitorear y aplicar
3. **Backups automáticos** - Configurar con Virtualmin
4. **Monitoreo de logs** - Revisar periódicamente
5. **Configuraciones específicas** - Ajustar según necesidades

## Soporte

Para soporte técnico:
- Revisar logs del sistema
- Verificar documentación de Virtualmin
- Consultar foros oficiales de WordPress/Laravel
- Revisar configuración de Apache/Nginx

---

*Esta documentación se actualiza automáticamente con cada nueva versión del sistema.*