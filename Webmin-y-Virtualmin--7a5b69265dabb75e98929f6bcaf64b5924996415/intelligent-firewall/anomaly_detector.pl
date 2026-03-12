#!/usr/bin/perl
# anomaly_detector.pl - Detección automática de anomalías

use strict;
use warnings;

require './intelligent-firewall-lib.pl';

# Detectar anomalías en datos de tráfico
sub detect_anomalies {
    my ($traffic_data) = @_;

    # Preparar datos para el motor ML
    my $data_string = prepare_data_for_ml($traffic_data);

    # Llamar al motor ML
    my $result = `python3 $module_root_directory/ml_engine.py detect "$data_string" 2>/dev/null`;

    # Parsear resultado
    my $anomalies = {};
    if ($result =~ /\{(.+)\}/) {
        my $json_like = $1;
        # Simple parsing (mejorar con JSON module)
        while ($json_like =~ /'([^']+)':\s*([0-9.]+)/g) {
            $anomalies->{$1} = $2;
        }
    }

    return $anomalies;
}

# Preparar datos para el motor ML
sub prepare_data_for_ml {
    my ($traffic_data) = @_;

    # Convertir hash a string para pasar a Python
    my $data_str = "";
    foreach my $key (keys %$traffic_data) {
        if (ref($traffic_data->{$key}) eq 'ARRAY') {
            $data_str .= "$key: " . join(',', @{$traffic_data->{$key}}) . "\n";
        } else {
            $data_str .= "$key: $traffic_data->{$key}\n";
        }
    }

    return $data_str;
}

# Ejecutar detección si se llama directamente
if ($0 =~ /anomaly_detector\.pl$/) {
    my $test_data = {
        active_connections => 150,
        packets_total => 50000,
        cpu_usage => 25,
        top_ips => ['192.168.1.1', '10.0.0.1']
    };

    my $anomalies = detect_anomalies($test_data);
    print "Anomalías detectadas:\n";
    foreach my $ip (keys %$anomalies) {
        print "$ip: $anomalies->{$ip}\n";
    }
}

1;