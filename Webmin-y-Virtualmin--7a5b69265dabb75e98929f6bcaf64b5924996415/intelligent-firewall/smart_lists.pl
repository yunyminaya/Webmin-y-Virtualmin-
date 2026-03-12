#!/usr/bin/perl
# smart_lists.pl - Whitelist/blacklist inteligente con aprendizaje automático

use strict;
use warnings;

require './intelligent-firewall-lib.pl';

# Listas inteligentes
my %whitelist;
my %blacklist;
my %graylist;  # IPs en observación

# Archivo de listas
my $lists_file = '/etc/webmin/intelligent-firewall/smart_lists.db';

# Cargar listas desde archivo
sub load_smart_lists {
    return unless -f $lists_file;

    open(my $fh, '<', $lists_file) or return;
    while (<$fh>) {
        chomp;
        my ($ip, $type, $score, $last_seen) = split(/\t/, $_);
        if ($type eq 'white') {
            $whitelist{$ip} = {score => $score, last_seen => $last_seen};
        } elsif ($type eq 'black') {
            $blacklist{$ip} = {score => $score, last_seen => $last_seen};
        } elsif ($type eq 'gray') {
            $graylist{$ip} = {score => $score, last_seen => $last_seen};
        }
    }
    close($fh);
}

# Guardar listas a archivo
sub save_smart_lists {
    open(my $fh, '>', $lists_file) or return;

    foreach my $ip (keys %whitelist) {
        print $fh "$ip\twhite\t$whitelist{$ip}{score}\t$whitelist{$ip}{last_seen}\n";
    }
    foreach my $ip (keys %blacklist) {
        print $fh "$ip\tblack\t$blacklist{$ip}{score}\t$blacklist{$ip}{last_seen}\n";
    }
    foreach my $ip (keys %graylist) {
        print $fh "$ip\tgray\t$graylist{$ip}{score}\t$graylist{$ip}{last_seen}\n";
    }

    close($fh);
}

# Clasificar IP automáticamente
sub classify_ip {
    my ($ip, $behavior_score) = @_;

    my $current_time = time();

    if ($behavior_score >= 0.8) {
        # Alta confianza de ser maliciosa
        $blacklist{$ip} = {score => $behavior_score, last_seen => $current_time};
        delete $whitelist{$ip};
        delete $graylist{$ip};
        print "IP $ip agregada a blacklist\n";
    } elsif ($behavior_score <= 0.2) {
        # Alta confianza de ser legítima
        $whitelist{$ip} = {score => $behavior_score, last_seen => $current_time};
        delete $blacklist{$ip};
        delete $graylist{$ip};
        print "IP $ip agregada a whitelist\n";
    } else {
        # Observación
        $graylist{$ip} = {score => $behavior_score, last_seen => $current_time};
        print "IP $ip en observación (graylist)\n";
    }

    save_smart_lists();
}

# Verificar si IP está en whitelist
sub is_whitelisted {
    my ($ip) = @_;
    return exists $whitelist{$ip};
}

# Verificar si IP está en blacklist
sub is_blacklisted {
    my ($ip) = @_;
    return exists $blacklist{$ip};
}

# Obtener estadísticas de listas
sub get_lists_stats {
    return {
        whitelist_count => scalar keys %whitelist,
        blacklist_count => scalar keys %blacklist,
        graylist_count => scalar keys %graylist,
    };
}

# Limpiar listas antiguas
sub cleanup_old_entries {
    my $max_age = 30 * 24 * 60 * 60;  # 30 días
    my $current_time = time();

    foreach my $list (\%whitelist, \%blacklist, \%graylist) {
        foreach my $ip (keys %$list) {
            if ($current_time - $list->{$ip}{last_seen} > $max_age) {
                delete $list->{$ip};
            }
        }
    }

    save_smart_lists();
}

# Inicializar listas
load_smart_lists();

# Ejecutar clasificación si se llama directamente
if ($0 =~ /smart_lists\.pl$/) {
    classify_ip('192.168.1.1', 0.9);  # Test blacklist
    classify_ip('10.0.0.1', 0.1);    # Test whitelist
    classify_ip('172.16.0.1', 0.5);  # Test graylist

    my $stats = get_lists_stats();
    print "Estadísticas de listas:\n";
    print "Whitelist: $stats->{whitelist_count}\n";
    print "Blacklist: $stats->{blacklist_count}\n";
    print "Graylist: $stats->{graylist_count}\n";
}

1;