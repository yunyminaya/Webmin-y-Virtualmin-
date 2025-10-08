#!/usr/bin/perl
# ids_integration.pl - Integración completa con el sistema IDS/IPS

use strict;
use warnings;

require './intelligent-firewall-lib.pl';

# Configuración IDS/IPS
my $ids_config = {
    snort_log => '/var/log/snort/alert',
    suricata_log => '/var/log/suricata/fast.log',
    fail2ban_log => '/var/log/fail2ban.log',
    enabled => 1
};

# Procesar alertas de Snort
sub process_snort_alerts {
    my $log_file = $ids_config->{snort_log};

    return unless -f $log_file;

    open(my $fh, '<', $log_file) or return;

    my @new_alerts;
    while (<$fh>) {
        chomp;
        if (is_new_alert($_)) {
            push @new_alerts, parse_snort_alert($_);
        }
    }
    close($fh);

    # Procesar alertas nuevas
    foreach my $alert (@new_alerts) {
        handle_ids_alert($alert, 'snort');
    }

    return \@new_alerts;
}

# Procesar alertas de Suricata
sub process_suricata_alerts {
    my $log_file = $ids_config->{suricata_log};

    return unless -f $log_file;

    open(my $fh, '<', $log_file) or return;

    my @new_alerts;
    while (<$fh>) {
        chomp;
        if (is_new_alert($_)) {
            push @new_alerts, parse_suricata_alert($_);
        }
    }
    close($fh);

    foreach my $alert (@new_alerts) {
        handle_ids_alert($alert, 'suricata');
    }

    return \@new_alerts;
}

# Procesar logs de Fail2Ban
sub process_fail2ban_logs {
    my $log_file = $ids_config->{fail2ban_log};

    return unless -f $log_file;

    open(my $fh, '<', $log_file) or return;

    my @new_entries;
    while (<$fh>) {
        chomp;
        if (is_new_fail2ban_entry($_)) {
            push @new_entries, parse_fail2ban_entry($_);
        }
    }
    close($fh);

    foreach my $entry (@new_entries) {
        handle_fail2ban_entry($entry);
    }

    return \@new_entries;
}

# Verificar si es una alerta nueva (placeholder)
sub is_new_alert {
    my ($line) = @_;
    # Implementar lógica para evitar procesar alertas duplicadas
    return 1;
}

# Verificar si es una entrada nueva de Fail2Ban
sub is_new_fail2ban_entry {
    my ($line) = @_;
    return $line =~ /Ban|Unban/;
}

# Parsear alerta de Snort
sub parse_snort_alert {
    my ($line) = @_;
    # Formato típico: [timestamp] [clasificación] [prioridad] mensaje
    my %alert;
    if ($line =~ /\[(.+)\]\s+\[(.+)\]\s+\[(.+)\]\s+(.+)/) {
        $alert{timestamp} = $1;
        $alert{classification} = $2;
        $alert{priority} = $3;
        $alert{message} = $4;
    }
    # Extraer IP si está presente
    if ($line =~ /(\d+\.\d+\.\d+\.\d+)/) {
        $alert{ip} = $1;
    }
    return \%alert;
}

# Parsear alerta de Suricata
sub parse_suricata_alert {
    my ($line) = @_;
    # Formato similar a Snort
    return parse_snort_alert($line);
}

# Parsear entrada de Fail2Ban
sub parse_fail2ban_entry {
    my ($line) = @_;
    my %entry;
    if ($line =~ /(\d+-\d+-\d+\s+\d+:\d+:\d+),\d+\s+fail2ban\.(.+)\s+\[(.+)\]\s+(.+)/) {
        $entry{timestamp} = $1;
        $entry{jail} = $2;
        $entry{action} = $3;
        $entry{details} = $4;
    }
    if ($line =~ /(\d+\.\d+\.\d+\.\d+)/) {
        $entry{ip} = $1;
    }
    return \%entry;
}

# Manejar alerta IDS
sub handle_ids_alert {
    my ($alert, $source) = @_;

    return unless $alert->{ip};

    # Calcular puntuación de riesgo basada en la alerta
    my $risk_score = calculate_ids_risk_score($alert, $source);

    # Integrar con sistema de bloqueo adaptativo
    require './adaptive_blocker.pl';
    apply_adaptive_blocking($alert->{ip}, $risk_score);

    # Loggear
    log_ids_alert($alert, $source, $risk_score);
}

# Manejar entrada de Fail2Ban
sub handle_fail2ban_entry {
    my ($entry) = @_;

    return unless $entry->{ip};

    if ($entry->{action} =~ /Ban/) {
        # IP baneada por Fail2Ban, alta confianza
        require './smart_lists.pl';
        classify_ip($entry->{ip}, 0.9);
    }
}

# Calcular puntuación de riesgo desde alerta IDS
sub calculate_ids_risk_score {
    my ($alert, $source) = @_;

    my $score = 0.5;  # Base

    # Ajustar basado en prioridad/clasificación
    if ($alert->{priority}) {
        $score += ($alert->{priority} / 10);
    }

    # Ajustar basado en fuente
    if ($source eq 'snort') {
        $score += 0.1;
    } elsif ($source eq 'suricata') {
        $score += 0.15;
    }

    return $score > 1 ? 1 : $score;
}

# Loggear alerta IDS
sub log_ids_alert {
    my ($alert, $source, $score) = @_;

    my $config = read_config();
    my $log_file = $config->{traffic_log_path};

    return unless open(my $fh, '>>', $log_file);

    my $timestamp = localtime();
    print $fh "[$timestamp] IDS_ALERT [$source]: $alert->{message} IP:$alert->{ip} Score:$score\n";

    close($fh);
}

# Obtener estadísticas IDS
sub get_ids_stats {
    my $snort_count = process_snort_alerts() || 0;
    my $suricata_count = process_suricata_alerts() || 0;
    my $fail2ban_count = process_fail2ban_logs() || 0;

    return {
        snort_alerts => scalar @$snort_count,
        suricata_alerts => scalar @$suricata_count,
        fail2ban_entries => scalar @$fail2ban_count,
    };
}

# Ejecutar integración IDS si se llama directamente
if ($0 =~ /ids_integration\.pl$/) {
    my $stats = get_ids_stats();
    print "Estadísticas IDS:\n";
    print "Alertas Snort: $stats->{snort_alerts}\n";
    print "Alertas Suricata: $stats->{suricata_alerts}\n";
    print "Entradas Fail2Ban: $stats->{fail2ban_entries}\n";
}

1;