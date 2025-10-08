#!/usr/bin/perl
# index.cgi - Página principal del firewall inteligente

require './intelligent-firewall-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "");

# Verificar permisos
&foreign_require("virtual-server", "virtual-server-lib.pl");
&master_admin() || &error($text{'index_ecannot'});

# Inicializar si no está
init_firewall();

# Mostrar estado
my $config = read_config();
my $stats = get_threat_stats();

print &ui_table_start($text{'index_status'}, "width=100%", 2);

print &ui_table_row($text{'index_enabled'},
                   $config->{'enabled'} ? $text{'yes'} : $text{'no'});

print &ui_table_row($text{'index_blocked_ips'},
                   $stats->{'blocked_ips'});

print &ui_table_row($text{'index_anomalies'},
                   $stats->{'anomalies_detected'});

print &ui_table_row($text{'index_traffic'},
                   $stats->{'traffic_volume'});

print &ui_table_end();

# Enlaces a funciones
print &ui_hr();
print &ui_buttons_start();

print &ui_buttons_row("dashboard.cgi", $text{'index_dashboard'},
                      $text{'index_dashboard_desc'});

print &ui_buttons_row("config.cgi", $text{'index_config'},
                      $text{'index_config_desc'});

print &ui_buttons_end();

&ui_print_footer("/", $text{'index_return'});