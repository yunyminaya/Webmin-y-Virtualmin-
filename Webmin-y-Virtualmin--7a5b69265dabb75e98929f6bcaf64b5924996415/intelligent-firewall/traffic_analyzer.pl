#!/usr/bin/perl
# traffic_analyzer.pl - Análisis de patrones de tráfico en tiempo real

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);

require './intelligent-firewall-lib.pl';

# Configuración
my $config = read_config();
my $log_file = $config->{traffic_log_path} || '/var/log/intelligent-firewall/traffic.log';
my $data_file = '/var/log/intelligent-firewall/traffic_data.csv';

# Función principal de análisis
sub analyze_traffic_realtime {
    my $interval = 60;  # segundos

    while (1) {
        my $start_time = time();

        # Recopilar estadísticas de tráfico
        my $stats = collect_traffic_stats();

        # Detectar anomalías
        my $anomalies = detect_anomalies($stats);

        # Actualizar reglas dinámicas
        update_dynamic_rules($anomalies);

        # Loggear datos para ML
        log_traffic_data($stats);

        # Esperar hasta el próximo intervalo
        my $elapsed = time() - $start_time;
        sleep($interval - $elapsed) if $elapsed < $interval;
    }
}

# Recopilar estadísticas de tráfico
sub collect_traffic_stats {
    my %stats;

    # Obtener conexiones activas
    my $netstat = `netstat -ant | grep ESTABLISHED | wc -l`;
    chomp($netstat);
    $stats{active_connections} = $netstat;

    # Obtener paquetes por segundo (aproximado)
    my $packets = `iptables -L -v -n | grep -E "(ACCEPT|DROP)" | awk '{sum += \$1} END {print sum}'`;
    chomp($packets);
    $stats{packets_total} = $packets || 0;

    # Obtener uso de CPU (placeholder)
    $stats{cpu_usage} = 0;  # Implementar medición real

    # Obtener IPs más activas
    my @top_ips = `iptables -L -v -n | grep DROP | head -10 | awk '{print \$8}'`;
    $stats{top_ips} = \@top_ips;

    return \%stats;
}

# Loggear datos para entrenamiento ML
sub log_traffic_data {
    my ($stats) = @_;

    return unless open(my $fh, '>>', $data_file);

    my $timestamp = time();
    my $line = join(',', $timestamp, $stats->{active_connections},
                   $stats->{packets_total}, $stats->{cpu_usage});

    print $fh "$line\n";
    close($fh);
}

# Ejecutar análisis si se llama directamente
if ($0 =~ /traffic_analyzer\.pl$/) {
    analyze_traffic_realtime();
}

1;