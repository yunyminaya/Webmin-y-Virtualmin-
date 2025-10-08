#!/usr/bin/perl
# dashboard.cgi - Dashboard del firewall inteligente

require './intelligent-firewall-lib.pl';
require './smart_lists.pl';
require './ids_integration.pl';
&ui_print_header(undef, $text{'dashboard_title'}, "");

# Obtener datos
my $stats = get_threat_stats();
my $config = read_config();
my $lists_stats = get_lists_stats();
my $ids_stats = get_ids_stats();

print "<h2>$text{'dashboard_overview'}</h2>";

# Gráfico de amenazas (placeholder con HTML básico)
print "<div style='border:1px solid #ccc; padding:10px; margin:10px 0;'>";
print "<h3>$text{'dashboard_threats'}</h3>";
print "<canvas id='threatsChart' width='400' height='200'></canvas>";
print "</div>";

# Estadísticas principales
print &ui_table_start($text{'dashboard_main_stats'}, "width=100%", 4);
print &ui_table_header($text{'metric'}, $text{'value'}, $text{'metric'}, $text{'value'});

print &ui_table_row($text{'blocked_ips'}, $stats->{'blocked_ips'} || 0,
                   $text{'anomalies_detected'}, $stats->{'anomalies_detected'} || 0);

print &ui_table_row($text{'whitelist_count'}, $lists_stats->{'whitelist_count'} || 0,
                   $text{'blacklist_count'}, $lists_stats->{'blacklist_count'} || 0);

print &ui_table_row($text{'ids_alerts'}, ($ids_stats->{'snort_alerts'} + $ids_stats->{'suricata_alerts'}) || 0,
                   $text{'traffic_volume'}, $stats->{'traffic_volume'} || 0);

print &ui_table_end();

# Tabla de IPs bloqueadas recientes
print "<h2>$text{'dashboard_recent_blocks'}</h2>";
print &ui_table_start($text{'dashboard_blocked_ips'}, "width=100%", 4);
print &ui_table_header($text{'ip'}, $text{'risk_score'}, $text{'block_time'}, $text{'actions'});

# Leer logs recientes para mostrar bloqueos
my $log_file = $config->{traffic_log_path};
if (-f $log_file) {
    open(my $fh, '<', $log_file) or die "No se puede abrir $log_file";
    my @recent_blocks;
    while (<$fh>) {
        if (/BLOCKED:\s*(\d+\.\d+\.\d+\.\d+)\s*\(score:\s*([0-9.]+)\)/) {
            push @recent_blocks, [$1, $2, "Ahora"];
            last if @recent_blocks >= 10;
        }
    }
    close($fh);

    foreach my $block (@recent_blocks) {
        print &ui_table_row($block->[0], $block->[1], $block->[2],
                           &ui_link("unblock.cgi?ip=$block->[0]", $text{'unblock'}));
    }
}

print &ui_table_end();

# Estadísticas en tiempo real
print "<h2>$text{'dashboard_realtime'}</h2>";
print &ui_table_start($text{'dashboard_stats'}, "width=100%", 2);

# Obtener datos en tiempo real
my $realtime_stats = analyze_traffic();

print &ui_table_row($text{'packets_per_second'}, $realtime_stats->{'packets_per_second'} || "N/A");
print &ui_table_row($text{'active_connections'}, $realtime_stats->{'active_connections'} || "N/A");
print &ui_table_row($text{'cpu_usage'}, $realtime_stats->{'cpu_usage'} || "N/A");
print &ui_table_row($text{'memory_usage'}, $realtime_stats->{'memory_usage'} || "N/A");

print &ui_table_end();

# Estado del modelo ML
print "<h2>$text{'dashboard_ml_status'}</h2>";
my $model_exists = -f $config->{ml_model_path} ? $text{'yes'} : $text{'no'};
print &ui_table_start($text{'dashboard_ml_stats'}, "width=100%", 2);
print &ui_table_row($text{'model_trained'}, $model_exists);
print &ui_table_row($text{'last_training'}, "Hace 2 horas"); # Placeholder
print &ui_table_row($text{'accuracy'}, "95.2%"); # Placeholder
print &ui_table_end();

# Script para gráficos (usando Chart.js placeholder)
print "<script>
// Placeholder para gráficos con datos reales
const ctx = document.getElementById('threatsChart').getContext('2d');
const chart = new Chart(ctx, {
    type: 'line',
    data: {
        labels: ['Hace 1h', 'Hace 2h', 'Hace 3h', 'Hace 4h', 'Hace 5h', 'Hace 6h'],
        datasets: [{
            label: 'Amenazas Detectadas',
            data: [12, 19, 3, 5, 2, 3],
            borderColor: 'rgb(255, 99, 132)',
            tension: 0.1
        }]
    }
});
</script>";

&ui_print_footer("index.cgi", $text{'dashboard_return'});