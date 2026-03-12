#!/usr/bin/perl
# adaptive_blocker.pl - Bloqueo adaptativo de amenazas basado en puntuaciones de riesgo

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

# Sistema de puntuación de riesgo
my %risk_scores;

# Calcular puntuación de riesgo para una IP
sub calculate_risk_score {
    my ($ip, $traffic_data) = @_;

    my $score = 0;

    # Factores de riesgo
    $score += 0.3 if is_suspicious_ip($ip);
    $score += 0.2 if has_high_connection_rate($ip, $traffic_data);
    $score += 0.25 if matches_attack_pattern($ip, $traffic_data);
    $score += 0.25 if is_from_blacklisted_country($ip);

    # Normalizar a 0-1
    $score = 1 if $score > 1;

    $risk_scores{$ip} = $score;
    return $score;
}

# Verificar si IP es sospechosa
sub is_suspicious_ip {
    my ($ip) = @_;

    # Lista negra básica
    my @blacklist = qw(192.168.1.100 10.0.0.50);

    return grep { $_ eq $ip } @blacklist;
}

# Verificar tasa alta de conexiones
sub has_high_connection_rate {
    my ($ip, $traffic_data) = @_;

    # Placeholder: implementar lógica real
    return 0;
}

# Verificar patrones de ataque
sub matches_attack_pattern {
    my ($ip, $traffic_data) = @_;

    # Placeholder: implementar detección de patrones
    return 0;
}

# Verificar país de origen
sub is_from_blacklisted_country {
    my ($ip) = @_;

    # Placeholder: implementar geolocalización
    return 0;
}

# Aplicar bloqueo adaptativo
sub apply_adaptive_blocking {
    my ($ip, $score) = @_;

    my $config = read_config();
    my $chain = $config->{iptables_chain};

    if (validate_input($ip, 'ip') && validate_input($chain, 'chain')) {
        if ($score >= $config->{block_threshold}) {
            # Bloqueo permanente con sanitización
            my $safe_ip = quotemeta($ip);
            my $safe_chain = quotemeta($chain);
            system("iptables -A $safe_chain -s $safe_ip -j DROP");
            print "Bloqueo permanente aplicado a $ip (score: $score)\n";
        } elsif ($score >= 0.5) {
            # Bloqueo temporal (placeholder)
            print "Bloqueo temporal aplicado a $ip (score: $score)\n";
        }
    } else {
        print "Error: IP o cadena inválida: $ip / $chain\n";
    }
}

# Obtener estadísticas de bloqueo
sub get_blocking_stats {
    my $config = read_config();
    my $chain = $config->{iptables_chain};

    my $blocked_count = 0;
    if (validate_input($chain, 'chain')) {
        my $safe_chain = quotemeta($chain);
        $blocked_count = `iptables -L $safe_chain | grep DROP | wc -l`;
        chomp($blocked_count);
    } else {
        print "Error: Cadena inválida: $chain\n";
    }

    return {
        blocked_ips => $blocked_count,
        risk_scores => \%risk_scores
    };
}

# Ejecutar bloqueo adaptativo si se llama directamente
if ($0 =~ /adaptive_blocker\.pl$/) {
    my $test_ip = '192.168.1.100';
    my $score = calculate_risk_score($test_ip, {});
    apply_adaptive_blocking($test_ip, $score);

    print "Puntuación de riesgo para $test_ip: $score\n";
}

1;