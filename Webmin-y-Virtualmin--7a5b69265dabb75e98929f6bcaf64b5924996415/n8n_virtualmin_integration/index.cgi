#!/usr/bin/perl

# =============================================================================
# MÓDULO VIRTUALMIN PARA n8n AUTOMATION PLATFORM
# =============================================================================

use strict;
use warnings;
use WebminCore;
use POSIX qw(strftime);
use JSON;
use File::Path qw(make_path);
use File::Copy;

# Configuración del módulo
&init_config();
&ReadParse();

# Variables globales
our %in;
our $module_config_directory;
our $text;

# Encabezado de la página
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

# Determinar acción
my $action = $in{'action'} || 'dashboard';

# Ejecutar acción correspondiente
if ($action eq 'dashboard') {
    show_dashboard();
} elsif ($action eq 'install') {
    show_install_form();
} elsif ($action eq 'do_install') {
    do_install();
} elsif ($action eq 'manage') {
    show_manage();
} elsif ($action eq 'delete') {
    do_delete();
} elsif ($action eq 'backup') {
    do_backup();
} elsif ($action eq 'restore') {
    show_restore_form();
} elsif ($action eq 'do_restore') {
    do_restore();
} else {
    show_dashboard();
}

&ui_print_footer("/", $text{'index'});

# =============================================================================
# FUNCIONES PRINCIPALES
# =============================================================================

sub show_dashboard {
    print &ui_subheading($text{'dashboard_title'});
    
    # Verificar instalación de n8n
    my $n8n_status = check_n8n_status();
    
    if ($n8n_status->{'installed'}) {
        show_installed_dashboard($n8n_status);
    } else {
        show_not_installed_dashboard();
    }
}

sub show_not_installed_dashboard {
    print &ui_table_start($text{'not_installed'}, "width=100%", 2);
    
    print &ui_table_row($text{'status'}, 
        &ui_link("index.cgi?action=install", &ui_button($text{'install_n8n'}, "primary")));
    
    print &ui_table_row($text{'description'}, $text{'n8n_description'});
    
    print &ui_table_end();
    
    # Mostrar características
    print &ui_subheading($text{'features'});
    print &ui_columns_start([$text{'feature'}, $text{'description'}], 100);
    
    my @features = (
        [$text{'workflow_automation'}, $text{'workflow_desc'}],
        [$text{'visual_editor'}, $text{'visual_editor_desc'}],
        [$text{'integrations'}, $text{'integrations_desc'}],
        [$text{'self_hosted'}, $text{'self_hosted_desc'}],
        [$text{'api_access'}, $text{'api_access_desc'}],
        [$text{'multi_user'}, $text{'multi_user_desc'}],
    );
    
    foreach my $feature (@features) {
        print &ui_columns_row($feature);
    }
    
    print &ui_columns_end();
}

sub show_installed_dashboard {
    my $status = shift;
    
    print &ui_table_start($text{'installed_info'}, "width=100%", 2);
    
    print &ui_table_row($text{'version'}, $status->{'version'});
    print &ui_table_row($text{'status'}, get_status_badge($status->{'running'}));
    print &ui_table_row($text{'url'}, &ui_link($status->{'url'}, $status->{'url'}));
    print &ui_table_row($text{'port'}, $status->{'port'});
    print &ui_table_row($text{'database'}, $status->{'database'});
    print &ui_table_row($text{'memory_usage'}, $status->{'memory'});
    print &ui_table_row($text{'uptime'}, $status->{'uptime'});
    
    print &ui_table_end();
    
    # Acciones
    print &ui_subheading($text{'actions'});
    print &ui_buttons_start();
    
    print &ui_buttons_row("index.cgi?action=manage", $text{'manage_instance'});
    print &ui_buttons_row("index.cgi?action=backup", $text{'backup_instance'});
    print &ui_buttons_row("index.cgi?action=restore", $text{'restore_instance'});
    
    if ($status->{'running'}) {
        print &ui_buttons_row("index.cgi?action=stop", $text{'stop_service'});
    } else {
        print &ui_buttons_row("index.cgi?action=start", $text{'start_service'});
    }
    
    print &ui_buttons_row("index.cgi?action=restart", $text{'restart_service'});
    
    print &ui_buttons_end();
    
    # Estadísticas
    show_statistics($status);
}

sub show_install_form {
    print &ui_subheading($text{'install_title'});
    
    print &ui_form_start("index.cgi", "post");
    print &ui_hidden("action", "do_install");
    
    print &ui_table_start($text{'installation_config'}, "width=100%", 2);
    
    # Dominio
    print &ui_table_row($text{'domain'},
        &ui_textbox("domain", get_default_domain(), 40));
    
    # Puerto
    print &ui_table_row($text{'port'},
        &ui_textbox("port", "5678", 6));
    
    # Base de datos
    my @db_options = ("sqlite", "mysql", "postgresql");
    print &ui_table_row($text{'database_type'},
        &ui_select("database_type", "sqlite", \@db_options));
    
    # SSL
    print &ui_table_row($text{'enable_ssl'},
        &ui_yesno_radio("enable_ssl", 1));
    
    # Email para SSL
    print &ui_table_row($text{'ssl_email'},
        &ui_textbox("ssl_email", "", 40));
    
    # Usuario admin
    print &ui_table_row($text{'admin_user'},
        &ui_textbox("admin_user", "admin", 20));
    
    # Contraseña admin
    print &ui_table_row($text{'admin_password'},
        &ui_password("admin_password", "", 20));
    
    print &ui_table_end();
    
    print &ui_form_end([["install", $text{'install_button'}]]);
}

sub do_install {
    my $domain = $in{'domain'};
    my $port = $in{'port'};
    my $database_type = $in{'database_type'};
    my $enable_ssl = $in{'enable_ssl'};
    my $ssl_email = $in{'ssl_email'};
    my $admin_user = $in{'admin_user'};
    my $admin_password = $in{'admin_password'};
    
    # Validación
    if (!$domain || !$port || !$admin_user) {
        error($text{'missing_fields'});
    }
    
    # Ejecutar instalación
    my $result = install_n8n_instance({
        domain => $domain,
        port => $port,
        database_type => $database_type,
        enable_ssl => $enable_ssl,
        ssl_email => $ssl_email,
        admin_user => $admin_user,
        admin_password => $admin_password
    });
    
    if ($result->{'success'}) {
        redirect("index.cgi?action=manage&instance=$domain");
    } else {
        error($result->{'error'});
    }
}

sub show_manage {
    my $domain = $in{'instance'} || get_default_instance();
    
    print &ui_subheading(&text('manage_instance_title', $domain));
    
    my $status = get_instance_status($domain);
    
    # Información del estado
    print &ui_table_start($text{'instance_info'}, "width=100%", 2);
    
    foreach my $key (sort keys %$status) {
        next if $key eq 'actions';
        print &ui_table_row($text{$key} || $key, $status->{$key});
    }
    
    print &ui_table_end();
    
    # Acciones de gestión
    print &ui_subheading($text{'management_actions'});
    print &ui_buttons_start();
    
    foreach my $action (@{$status->{'actions'}}) {
        print &ui_buttons_row($action->{'url'}, $action->{'text'});
    }
    
    print &ui_buttons_end();
}

# =============================================================================
# FUNCIONES AUXILIARES
# =============================================================================

sub check_n8n_status {
    my $status = {
        installed => 0,
        running => 0,
        version => "",
        url => "",
        port => "",
        database => "",
        memory => "",
        uptime => ""
    };
    
    # Verificar si n8n está instalado
    if (command_exists("n8n")) {
        $status->{'installed'} = 1;
        $status->{'version'} = `n8n --version 2>/dev/null | tr -d '\n'`;
        
        # Verificar si está corriendo
        my $process = `ps aux | grep n8n | grep -v grep`;
        if ($process) {
            $status->{'running'} = 1;
            
            # Obtener información del proceso
            if ($process =~ /n8n start --port (\d+)/) {
                $status->{'port'} = $1;
                $status->{'url'} = "http://localhost:$1";
            }
            
            # Obtener uso de memoria
            if ($process =~ /\s+(\d+)\s+/) {
                $status->{'memory'} = format_bytes($1 * 1024);
            }
        }
        
        # Obtener configuración
        my $config_file = "/etc/n8n/n8n.env";
        if (-f $config_file) {
            my $config = read_config_file($config_file);
            $status->{'database'} = $config->{'DB_TYPE'} || "sqlite";
            $status->{'url'} = $config->{'N8N_HOST'} ? 
                "http://$config->{'N8N_HOST'}:$config->{'N8N_PORT'}" : $status->{'url'};
        }
    }
    
    return $status;
}

sub get_status_badge {
    my $running = shift;
    
    if ($running) {
        return "<span class='badge badge-success'>$text{'running'}</span>";
    } else {
        return "<span class='badge badge-danger'>$text{'stopped'}</span>";
    }
}

sub install_n8n_instance {
    my $config = shift;
    
    my $result = {
        success => 0,
        error => ""
    };
    
    # Validar configuración
    if (!$config->{'domain'} || !$config->{'port'}) {
        $result->{'error'} = $text{'missing_config'};
        return $result;
    }
    
    # Ejecutar script de instalación
    my $cmd = "./install_n8n_automation.sh";
    my @args = (
        "--domain", $config->{'domain'},
        "--port", $config->{'port'},
        "--database", $config->{'database_type'},
        "--admin-user", $config->{'admin_user'}
    );
    
    if ($config->{'enable_ssl'}) {
        push @args, "--enable-ssl";
        if ($config->{'ssl_email'}) {
            push @args, "--ssl-email", $config->{'ssl_email'};
        }
    }
    
    if ($config->{'admin_password'}) {
        push @args, "--admin-password", $config->{'admin_password'};
    }
    
    my $output = backquote_command("$cmd " . join(" ", @args) . " 2>&1");
    
    if ($? == 0) {
        $result->{'success'} = 1;
        $result->{'output'} = $output;
    } else {
        $result->{'error'} = $output;
    }
    
    return $result;
}

sub get_instance_status {
    my $domain = shift;
    
    my $status = {
        domain => $domain,
        status => "unknown",
        version => "",
        url => "",
        port => "",
        database => "",
        memory => "",
        uptime => "",
        actions => []
    };
    
    # Obtener información del servicio systemd
    my $service_name = "n8n";
    my $service_status = `systemctl status $service_name 2>/dev/null`;
    
    if ($service_status =~ /active \(running\)/) {
        $status->{'status'} = "running";
    } elsif ($service_status =~ /inactive \(dead\)/) {
        $status->{'status'} = "stopped";
    }
    
    # Configurar acciones
    push @{$status->{'actions'}}, {
        text => $text{'restart_service'},
        url => "index.cgi?action=restart&instance=$domain"
    };
    
    if ($status->{'status'} eq "running") {
        push @{$status->{'actions'}}, {
            text => $text{'stop_service'},
            url => "index.cgi?action=stop&instance=$domain"
        };
    } else {
        push @{$status->{'actions'}}, {
            text => $text{'start_service'},
            url => "index.cgi?action=start&instance=$domain"
        };
    }
    
    push @{$status->{'actions'}}, {
        text => $text{'backup_instance'},
        url => "index.cgi?action=backup&instance=$domain"
    };
    
    push @{$status->{'actions'}}, {
        text => $text{'delete_instance'},
        url => "index.cgi?action=delete&instance=$domain"
    };
    
    return $status;
}

sub show_statistics {
    my $status = shift;
    
    print &ui_subheading($text{'statistics'});
    
    # Obtener estadísticas del sistema
    my $stats = get_system_stats();
    
    print &ui_table_start($text{'system_stats'}, "width=100%", 2);
    
    print &ui_table_row($text{'cpu_usage'}, $stats->{'cpu'});
    print &ui_table_row($text{'memory_usage'}, $stats->{'memory'});
    print &ui_table_row($text{'disk_usage'}, $stats->{'disk'});
    print &ui_table_row($text{'network_io'}, $stats->{'network'});
    
    print &ui_table_end();
}

sub get_system_stats {
    my $stats = {
        cpu => "0%",
        memory => "0%",
        disk => "0%",
        network => "0 B/s"
    };
    
    # Uso de CPU
    my $cpu_usage = `top -bn1 | grep "Cpu(s)" | awk '{print \$2}' | cut -d'%' -f1`;
    $stats->{'cpu'} = sprintf("%.1f%%", $cpu_usage) if $cpu_usage;
    
    # Uso de memoria
    my $mem_info = `free -m | grep Mem`;
    if ($mem_info =~ /(\d+)\s+(\d+)\s+(\d+)/) {
        my $total = $1;
        my $used = $2;
        my $percentage = ($used / $total) * 100;
        $stats->{'memory'} = sprintf("%.1f%%", $percentage);
    }
    
    # Uso de disco
    my $disk_usage = `df -h / | tail -1`;
    if ($disk_usage =~ /\s+(\d+)%/) {
        $stats->{'disk'} = "$1%";
    }
    
    return $stats;
}

# =============================================================================
# FUNCIONES DE UTILIDAD
# =============================================================================

sub command_exists {
    my $cmd = shift;
    return system("which $cmd >/dev/null 2>&1") == 0;
}

sub format_bytes {
    my $bytes = shift;
    
    my @units = ('B', 'KB', 'MB', 'GB', 'TB');
    my $unit = 0;
    
    while ($bytes >= 1024 && $unit < @units - 1) {
        $bytes /= 1024;
        $unit++;
    }
    
    return sprintf("%.1f %s", $bytes, $units[$unit]);
}

sub read_config_file {
    my $file = shift;
    my $config = {};
    
    if (open(my $fh, '<', $file)) {
        while (my $line = <$fh>) {
            chomp $line;
            if ($line =~ /^(.+?)=(.*)$/) {
                my $key = $1;
                my $value = $2;
                $config->{$key} = $value;
            }
        }
        close($fh);
    }
    
    return $config;
}

sub get_default_domain {
    my $hostname = `hostname -f`;
    chomp $hostname;
    return "n8n.$hostname";
}

sub get_default_instance {
    # Lógica para obtener la instancia por defecto
    return get_default_domain();
}

sub error {
    my $message = shift;
    print &ui_error($message);
    &ui_print_footer("/", $text{'index'});
    exit;
}

sub redirect {
    my $url = shift;
    print "Location: $url\n\n";
    exit;
}