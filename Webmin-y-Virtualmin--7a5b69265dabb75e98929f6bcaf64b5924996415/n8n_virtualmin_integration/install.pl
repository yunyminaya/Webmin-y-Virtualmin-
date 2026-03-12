#!/usr/bin/perl

# =============================================================================
# SCRIPT DE INSTALACIÓN DEL MÓDULO n8n PARA WEBMIN/VIRTUALMIN
# =============================================================================

use strict;
use warnings;
use File::Path;
use File::Copy;
use File::Basename;

# Obtener directorio del módulo
my $module_dir = $ARGV[0] || die "Uso: $0 <directorio_del_módulo>\n";
my $root_directory = $ARGV[1] || "/usr/share/webmin";

# Verificar que estamos como root
if ($< != 0) {
    die "Este script debe ejecutarse como root\n";
}

print "Instalando módulo n8n Automation Platform para Webmin/Virtualmin...\n";

# Directorios de instalación
my $webmin_modules_dir = "$root_directory/n8n";
my $config_dir = "/etc/webmin/n8n";
my $systemd_dir = "/etc/systemd/system";

# Crear directorios necesarios
print "Creando directorios de instalación...\n";
make_path($webmin_modules_dir, { mode => 0755 });
make_path($config_dir, { mode => 0755 });

# Copiar archivos del módulo
print "Copiando archivos del módulo...\n";

# Copiar archivos principales
copy_file("$module_dir/index.cgi", "$webmin_modules_dir/index.cgi");
copy_file("$module_dir/module.info", "$webmin_modules_dir/module.info");
copy_file("$module_dir/config", "$webmin_modules_dir/config");

# Copiar archivos de idioma
if (-d "$module_dir/lang") {
    make_path("$webmin_modules_dir/lang", { mode => 0755 });
    copy_file("$module_dir/lang/es", "$webmin_modules_dir/lang/es");
}

# Copiar scripts de instalación
if (-d "$module_dir/scripts") {
    make_path("$webmin_modules_dir/scripts", { mode => 0755 });
    opendir(my $dh, "$module_dir/scripts") or die "No puedo abrir directorio scripts: $!\n";
    while (my $file = readdir($dh)) {
        next if ($file =~ /^\./);
        copy_file("$module_dir/scripts/$file", "$webmin_modules_dir/scripts/$file");
    }
    closedir($dh);
}

# Copiar archivos de configuración
if (-d "$module_dir/configs") {
    make_path("$webmin_modules_dir/configs", { mode => 0755 });
    opendir(my $dh, "$module_dir/configs") or die "No puedo abrir directorio configs: $!\n";
    while (my $file = readdir($dh)) {
        next if ($file =~ /^\./);
        copy_file("$module_dir/configs/$file", "$webmin_modules_dir/configs/$file");
    }
    closedir($dh);
}

# Establecer permisos
print "Estableciendo permisos...\n";
chmod(0755, "$webmin_modules_dir/index.cgi");
chmod(0644, "$webmin_modules_dir/module.info");
chmod(0600, "$webmin_modules_dir/config");

# Copiar script de instalación principal
copy_file("$module_dir/../install_n8n_automation.sh", "/usr/local/bin/install_n8n_automation.sh");
chmod(0755, "/usr/local/bin/install_n8n_automation.sh");

# Crear enlaces simbólicos para scripts auxiliares
if (-f "$module_dir/../lib/common.sh") {
    make_path("/usr/local/lib/n8n", { mode => 0755 });
    copy_file("$module_dir/../lib/common.sh", "/usr/local/lib/n8n/common.sh");
    chmod(0644, "/usr/local/lib/n8n/common.sh");
}

# Crear directorios para n8n
print "Creando directorios para n8n...\n";
make_path("/var/lib/n8n", { mode => 0755 });
make_path("/etc/n8n", { mode => 0755 });
make_path("/var/log/n8n", { mode => 0755 });
make_path("/var/backups/n8n", { mode => 0755 });

# Crear usuario n8n si no existe
print "Creando usuario n8n...\n";
system("getent passwd n8n >/dev/null 2>&1 || useradd -r -s /bin/false -d /var/lib/n8n n8n");

# Establecer permisos de directorios
system("chown -R n8n:n8n /var/lib/n8n");
system("chown -R n8n:n8n /etc/n8n");
system("chown -R n8n:n8n /var/log/n8n");
system("chown -R n8n:n8n /var/backups/n8n");

# Configurar el módulo en Webmin
print "Configurando el módulo en Webmin...\n";

# Actualizar archivo de configuración de Webmin
my $webmin_config = "/etc/webmin/miniserv.conf";
if (-f $webmin_config) {
    # Agregar el módulo a la configuración de Webmin
    open(my $fh, '>>', $webmin_config) or die "No puedo abrir $webmin_config: $!\n";
    print $fh "n8n=n8n Automation Platform\n";
    close($fh);
}

# Crear archivo de configuración para el módulo
open(my $fh, '>', "$config_dir/config") or die "No puedo crear archivo de configuración: $!\n";
print $fh "n8n_port=5678\n";
print $fh "n8n_domain=\n";
print $fh "n8n_database_type=sqlite\n";
print $fh "n8n_enable_ssl=1\n";
print $fh "n8n_ssl_email=\n";
print $fh "n8n_admin_user=admin\n";
print $fh "n8n_admin_password=\n";
print $fh "n8n_data_dir=/var/lib/n8n\n";
print $fh "n8n_config_dir=/etc/n8n\n";
print $fh "n8n_backup_dir=/var/backups/n8n\n";
print $fh "n8n_log_level=info\n";
print $fh "n8n_max_instances=10\n";
close($fh);

chmod(0600, "$config_dir/config");

# Reiniciar Webmin para cargar el nuevo módulo
print "Reiniciando Webmin...\n";
system("systemctl restart webmin >/dev/null 2>&1 || /etc/init.d/webmin restart >/dev/null 2>&1");

# Verificar instalación
print "Verificando instalación...\n";

if (-f "$webmin_modules_dir/index.cgi" && -f "$webmin_modules_dir/module.info") {
    print "✓ Módulo n8n instalado correctamente\n";
} else {
    die "✗ Error en la instalación del módulo\n";
}

if (-f "/usr/local/bin/install_n8n_automation.sh") {
    print "✓ Script de instalación automática disponible\n";
} else {
    print "✗ Script de instalación automática no encontrado\n";
}

if (system("getent passwd n8n >/dev/null 2>&1") == 0) {
    print "✓ Usuario n8n creado\n";
} else {
    print "✗ Error al crear usuario n8n\n";
}

# Mostrar información de acceso
print "\n" . "="x60 . "\n";
print "INSTALACIÓN COMPLETADA\n";
print "="x60 . "\n";
print "Módulo n8n Automation Platform instalado exitosamente\n";
print "\nAcceso al módulo:\n";
print "- URL: https://tu-servidor:10000/n8n/\n";
print "- Usuario: root (o tu usuario de Webmin)\n";
print "- Contraseña: tu contraseña de Webmin\n";
print "\nScript de instalación automática:\n";
print "- Comando: /usr/local/bin/install_n8n_automation.sh\n";
print "\nDirectorios creados:\n";
print "- Datos: /var/lib/n8n\n";
print "- Configuración: /etc/n8n\n";
print "- Logs: /var/log/n8n\n";
print "- Respaldos: /var/backups/n8n\n";
print "="x60 . "\n";

# Función auxiliar para copiar archivos
sub copy_file {
    my ($src, $dst) = @_;
    
    unless (-f $src) {
        print "ADVERTENCIA: Archivo $src no encontrado\n";
        return;
    }
    
    copy($src, $dst) or die "No puedo copiar $src a $dst: $!\n";
    print "Copiado: $src -> $dst\n";
}

print "Instalación completada exitosamente.\n";