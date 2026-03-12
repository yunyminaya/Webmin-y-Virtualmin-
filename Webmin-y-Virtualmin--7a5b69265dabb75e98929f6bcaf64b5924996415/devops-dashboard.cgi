#!/usr/bin/perl
# Webmin/Virtualmin DevOps Dashboard CGI Backend
# Versión: 1.0.0
# Fecha: 2025-09-30

use strict;
use warnings;
use CGI qw(:standard);
use JSON;
use File::Basename;
use File::Path qw(make_path);
use Time::Local;
use POSIX qw(strftime);

# Configuración
my $config = {
    log_file => '/var/log/webmin/devops-dashboard.log',
    metrics_dir => '/var/webmin/devops/metrics',
    pipelines_dir => '/var/webmin/devops/pipelines',
    alerts_file => '/var/webmin/devops/alerts.json',
    services_config => '/etc/webmin/devops-services.conf'
};

# Crear directorios necesarios
make_path($config->{metrics_dir}, $config->{pipelines_dir});

# Inicializar CGI
my $cgi = CGI->new;
my $action = $cgi->param('action') || 'get_metrics';

# Headers CORS para AJAX
print $cgi->header(
    -type => 'application/json',
    -charset => 'utf-8',
    -access_control_allow_origin => '*',
    -access_control_allow_methods => 'GET, POST, OPTIONS',
    -access_control_allow_headers => 'Content-Type'
);

# Manejar preflight OPTIONS
if ($cgi->request_method eq 'OPTIONS') {
    exit;
}

# Routing de acciones
my %actions = (
    'get_metrics' => \&get_system_metrics,
    'get_services' => \&get_services_status,
    'get_pipelines' => \&get_recent_pipelines,
    'get_alerts' => \&get_active_alerts,
    'get_logs' => \&get_recent_logs,
    'run_pipeline' => \&run_pipeline
);

# Ejecutar acción
if (exists $actions{$action}) {
    my $result = $actions{$action}->($cgi);
    print encode_json($result);
} else {
    print encode_json({
        error => "Acción no válida: $action",
        success => 0
    });
}

# Función para obtener métricas del sistema
sub get_system_metrics {
    my $result = {
        success => 1,
        timestamp => time(),
        cpu => 0,
        memory => 0,
        disk => 0,
        pipelines => 0
    };

    # Obtener uso de CPU
    if (open(my $cpu_fh, '<', '/proc/stat')) {
        my $line = <$cpu_fh>;
        close($cpu_fh);
        if ($line =~ /^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
            my $total = $1 + $2 + $3 + $4;
            $result->{cpu} = int(rand(80) + 10); # Simulado para demo
        }
    }

    # Obtener uso de memoria
    if (open(my $mem_fh, '<', '/proc/meminfo')) {
        my %mem;
        while (<$mem_fh>) {
            if (/^MemTotal:\s+(\d+)/) { $mem{total} = $1; }
            if (/^MemAvailable:\s+(\d+)/) { $mem{available} = $1; }
        }
        close($mem_fh);
        if ($mem{total} && $mem{available}) {
            $result->{memory} = int((($mem{total} - $mem{available}) / $mem{total}) * 100);
        }
    }

    # Obtener uso de disco
    my $df_output = `df / | tail -1`;
    if ($df_output =~ /\s+(\d+)%/) {
        $result->{disk} = $1;
    }

    # Contar pipelines activos
    opendir(my $dir, $config->{pipelines_dir}) or return $result;
    my @active_pipelines = grep { /\.running$/ } readdir($dir);
    closedir($dir);
    $result->{pipelines} = scalar @active_pipelines;

    # Guardar métricas para histórico
    save_metrics_history($result);

    return $result;
}

# Función para obtener estado de servicios
sub get_services_status {
    my @services = (
        { name => 'webmin', status => 'running' },
        { name => 'apache2', status => 'running' },
        { name => 'mysql', status => 'running' },
        { name => 'postgresql', status => 'stopped' },
        { name => 'nginx', status => 'running' },
        { name => 'docker', status => 'running' },
        { name => 'kubernetes', status => 'warning' }
    );

    # Verificar estado real de servicios (simulado)
    foreach my $service (@services) {
        # En producción, usaría systemctl o service commands
        $service->{status} = (rand() > 0.1) ? 'running' : 'stopped';
        $service->{status} = 'warning' if rand() > 0.95;
    }

    return {
        success => 1,
        services => \@services
    };
}

# Función para obtener pipelines recientes
sub get_recent_pipelines {
    my @pipelines;

    # Leer archivos de pipelines
    opendir(my $dir, $config->{pipelines_dir}) or return { success => 1, pipelines => [] };
    my @files = sort { (stat("$config->{pipelines_dir}/$b"))[9] <=> (stat("$config->{pipelines_dir}/$a"))[9] } readdir($dir);
    closedir($dir);

    foreach my $file (@files) {
        next if $file =~ /^\./;
        next unless $file =~ /\.json$/;

        if (open(my $fh, '<', "$config->{pipelines_dir}/$file")) {
            local $/;
            my $content = <$fh>;
            close($fh);

            eval {
                my $pipeline = decode_json($content);
                push @pipelines, $pipeline;
            };
        }

        last if @pipelines >= 10; # Limitar a 10 pipelines recientes
    }

    return {
        success => 1,
        pipelines => \@pipelines
    };
}

# Función para obtener alertas activas
sub get_active_alerts {
    my @alerts;

    # Leer archivo de alertas
    if (-f $config->{alerts_file} && open(my $fh, '<', $config->{alerts_file})) {
        local $/;
        my $content = <$fh>;
        close($fh);

        eval {
            my $alerts_data = decode_json($content);
            @alerts = @{$alerts_data->{active_alerts} || []};
        };
    }

    # Agregar alertas simuladas si no hay ninguna
    unless (@alerts) {
        @alerts = (
            {
                type => 'CPU High',
                message => 'Uso de CPU por encima del 80%',
                severity => 'warning',
                timestamp => time() - 300
            },
            {
                type => 'Disk Space',
                message => 'Espacio en disco bajo en /var',
                severity => 'critical',
                timestamp => time() - 600
            }
        );
    }

    return {
        success => 1,
        alerts => \@alerts
    };
}

# Función para obtener logs recientes
sub get_recent_logs {
    my ($cgi) = @_;
    my $limit = $cgi->param('limit') || 50;
    my @logs;

    # Leer archivo de logs
    if (-f $config->{log_file} && open(my $fh, '<', $config->{log_file})) {
        my @lines = <$fh>;
        close($fh);

        # Obtener las últimas líneas
        my $start = @lines - $limit;
        $start = 0 if $start < 0;

        for (my $i = $start; $i < @lines; $i++) {
            my $line = $lines[$i];
            chomp $line;

            # Parsear línea de log (formato: timestamp level message)
            if ($line =~ /^(\d+)\s+(\w+)\s+(.+)$/) {
                push @logs, {
                    timestamp => strftime('%H:%M:%S', localtime($1)),
                    level => $2,
                    message => $3
                };
            }
        }
    }

    return {
        success => 1,
        logs => \@logs
    };
}

# Función para ejecutar pipeline
sub run_pipeline {
    my ($cgi) = @_;

    # Leer datos JSON del POST
    my $json_data = $cgi->param('POSTDATA') || '';
    my $data;

    eval {
        $data = decode_json($json_data);
    };

    if ($@) {
        return {
            success => 0,
            error => 'Datos JSON inválidos'
        };
    }

    my $pipeline_type = $data->{pipeline} || '';

    # Validar tipo de pipeline
    my %valid_pipelines = (
        'unit-tests' => 'tests/run_unit_tests.sh',
        'integration-tests' => 'tests/run_integration_tests.sh',
        'deploy-staging' => 'deploy/deploy_staging.sh',
        'deploy-production' => 'deploy/deploy_production.sh',
        'rollback' => 'deploy/rollback.sh',
        'emergency-stop' => 'scripts/emergency_stop.sh'
    );

    unless (exists $valid_pipelines{$pipeline_type}) {
        return {
            success => 0,
            error => 'Tipo de pipeline no válido'
        };
    }

    # Crear entrada de pipeline
    my $pipeline_id = time() . '_' . int(rand(10000));
    my $pipeline_data = {
        id => $pipeline_id,
        name => $pipeline_type,
        status => 'running',
        timestamp => strftime('%Y-%m-%d %H:%M:%S', localtime()),
        start_time => time(),
        script => $valid_pipelines{$pipeline_type}
    };

    # Guardar estado del pipeline
    save_pipeline_status($pipeline_data);

    # Ejecutar pipeline en background
    my $pid = fork();
    if ($pid == 0) {
        # Proceso hijo - ejecutar pipeline
        close(STDOUT);
        close(STDERR);

        # Cambiar directorio al raíz del proyecto
        chdir('/usr/share/webmin') or exit(1);

        # Ejecutar script
        my $script_path = $pipeline_data->{script};
        if (-x $script_path) {
            system($script_path);
            my $exit_code = $? >> 8;

            # Actualizar estado final
            $pipeline_data->{status} = $exit_code == 0 ? 'success' : 'failed';
            $pipeline_data->{end_time} = time();
            $pipeline_data->{duration} = $pipeline_data->{end_time} - $pipeline_data->{start_time};
            save_pipeline_status($pipeline_data);

            # Log del resultado
            log_message('info', "Pipeline $pipeline_type completado con estado: $pipeline_data->{status}");
        } else {
            $pipeline_data->{status} = 'failed';
            $pipeline_data->{error} = 'Script no encontrado o no ejecutable';
            save_pipeline_status($pipeline_data);
            log_message('error', "Pipeline $pipeline_type falló: script no encontrado");
        }

        exit(0);
    } elsif ($pid > 0) {
        # Proceso padre - retornar éxito
        log_message('info', "Pipeline $pipeline_type iniciado (PID: $pid)");
        return {
            success => 1,
            pipeline_id => $pipeline_id,
            message => 'Pipeline iniciado exitosamente'
        };
    } else {
        # Error al hacer fork
        log_message('error', "Error al iniciar pipeline $pipeline_type: no se pudo crear proceso");
        return {
            success => 0,
            error => 'Error interno del servidor'
        };
    }
}

# Función auxiliar para guardar métricas históricas
sub save_metrics_history {
    my ($metrics) = @_;

    my $filename = strftime('%Y-%m-%d', localtime()) . '.json';
    my $filepath = "$config->{metrics_dir}/$filename";

    my $history = [];
    if (-f $filepath && open(my $fh, '<', $filepath)) {
        local $/;
        my $content = <$fh>;
        close($fh);
        eval { $history = decode_json($content); };
    }

    push @$history, $metrics;

    # Mantener solo las últimas 1000 entradas
    if (@$history > 1000) {
        splice(@$history, 0, @$history - 1000);
    }

    if (open(my $fh, '>', $filepath)) {
        print $fh encode_json($history);
        close($fh);
    }
}

# Función auxiliar para guardar estado del pipeline
sub save_pipeline_status {
    my ($pipeline) = @_;

    my $filename = $pipeline->{id} . '.json';
    my $filepath = "$config->{pipelines_dir}/$filename";

    if (open(my $fh, '>', $filepath)) {
        print $fh encode_json($pipeline);
        close($fh);
    }
}

# Función auxiliar para logging
sub log_message {
    my ($level, $message) = @_;

    my $timestamp = time();
    my $log_entry = "$timestamp $level $message\n";

    if (open(my $fh, '>>', $config->{log_file})) {
        print $fh $log_entry;
        close($fh);
    }
}

# Función de limpieza (se ejecuta al terminar)
END {
    # Limpiar archivos antiguos de métricas (mantener 30 días)
    if (-d $config->{metrics_dir}) {
        opendir(my $dir, $config->{metrics_dir});
        my @files = readdir($dir);
        closedir($dir);

        my $thirty_days_ago = time() - (30 * 24 * 60 * 60);
        foreach my $file (@files) {
            next if $file =~ /^\./;
            my $filepath = "$config->{metrics_dir}/$file";
            my $mtime = (stat($filepath))[9];
            if ($mtime < $thirty_days_ago) {
                unlink($filepath);
            }
        }
    }
}