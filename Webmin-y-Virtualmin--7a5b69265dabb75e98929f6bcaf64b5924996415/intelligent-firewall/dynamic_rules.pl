#!/usr/bin/perl
# dynamic_rules.pl - Reglas dinámicas que se adaptan al comportamiento normal

use strict;
use warnings;

require './intelligent-firewall-lib.pl';

# Función de validación de seguridad
sub validate_input {
    my ($input, $type) = @_;
    if ($type eq 'ip') {
        # Validar formato de IP (IPv4 simple)
        return $input =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ &&
               $input !~ /\.\./ && # Evitar .. en IP
               $input !~ /[^0-9.]/; # Solo números y puntos
    } elsif ($type eq 'chain') {
        # Validar nombre de cadena iptables (solo alfanumérico y guiones)
        return $input =~ /^[a-zA-Z0-9_-]+$/ && length($input) <= 30;
    }
    return 0;
}

# Actualizar reglas dinámicas basadas en anomalías
sub update_dynamic_rules {
    my ($anomalies) = @_;

    my $config = read_config();
    my $chain = $config->{iptables_chain};

    foreach my $ip (keys %$anomalies) {
        my $score = $anomalies->{$ip};

        if ($score > $config->{block_threshold} && validate_input($ip, 'ip') && validate_input($chain, 'chain')) {
            # Bloquear IP con sanitización
            my $safe_ip = quotemeta($ip);
            my $safe_chain = quotemeta($chain);
            system("iptables -A $safe_chain -s $safe_ip -j DROP");

            # Loggear bloqueo
            log_blocked_ip($ip, $score);

            print "IP $ip bloqueada (puntuación: $score)\n";
        } else {
            print "Advertencia: IP o cadena inválida detectada: $ip / $chain\n";
        }
    }

    # Limpiar reglas expiradas (placeholder)
    cleanup_expired_rules();
}

# Loggear IP bloqueada
sub log_blocked_ip {
    my ($ip, $score) = @_;

    my $config = read_config();
    my $log_file = $config->{traffic_log_path};

    return unless open(my $fh, '>>', $log_file);

    my $timestamp = localtime();
    print $fh "[$timestamp] BLOCKED: $ip (score: $score)\n";

    close($fh);
}

# Limpiar reglas expiradas
sub cleanup_expired_rules {
    # Placeholder: implementar lógica para expirar reglas antiguas
    # Por ejemplo, reglas que llevan más de 24 horas
}

# Obtener reglas actuales
sub get_current_rules {
    my $config = read_config();
    my $chain = $config->{iptables_chain};

    if (validate_input($chain, 'chain')) {
        my $safe_chain = quotemeta($chain);
        my @rules = `iptables -L $safe_chain -n`;
        return \@rules;
    } else {
        print "Error: Cadena inválida: $chain\n";
        return [];
    }
}

# Remover regla específica
sub remove_rule {
    my ($ip) = @_;

    my $config = read_config();
    my $chain = $config->{iptables_chain};

    if (validate_input($ip, 'ip') && validate_input($chain, 'chain')) {
        my $safe_ip = quotemeta($ip);
        my $safe_chain = quotemeta($chain);
        system("iptables -D $safe_chain -s $safe_ip -j DROP");
        print "Regla removida para IP: $ip\n";
    } else {
        print "Error: IP o cadena inválida: $ip / $chain\n";
    }
}

# Ejecutar actualización si se llama directamente
if ($0 =~ /dynamic_rules\.pl$/) {
    my $test_anomalies = {
        '192.168.1.100' => 0.95,
        '10.0.0.50' => 0.85
    };

    update_dynamic_rules($test_anomalies);
}

1;