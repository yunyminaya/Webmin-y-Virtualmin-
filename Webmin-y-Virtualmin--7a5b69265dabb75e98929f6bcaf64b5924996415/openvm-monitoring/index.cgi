#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-monitoring-lib.pl';
&ReadParse();

ovmon_require_access();
my $cpu   = ovmon_cpu_info();
my $mem   = ovmon_memory_info();
my $disks = ovmon_disk_info();

&ui_print_header(undef, 'OpenVM Resource Monitoring', '', 'index');
print "<p>Monitoreo nativo de recursos del sistema: CPU, memoria, disco, ancho de banda y procesos. Sin dependencia de licencias comerciales.</p>\n";

# CPU
print &ui_table_start('CPU', 'width=100%', 2);
print &ui_table_row('Cores detectados', $cpu->{'cores'} || 1);
print &ui_table_row('Uso actual',       ($cpu->{'usage_pct'} // '?').'%');
print &ui_table_row('Load avg (1/5/15m)', $cpu->{'load1'}.'  /  '.$cpu->{'load5'}.'  /  '.$cpu->{'load15'});
print &ui_table_end();

# Memory
my $mem_bar = $mem->{'total_kb'}
	? int($mem->{'used_kb'} / 1024).' MB de '.int($mem->{'total_kb'} / 1024).' MB ('.$mem->{'usage_pct'}.'%)'
	: 'No disponible';
print &ui_table_start('Memoria RAM', 'width=100%', 2);
print &ui_table_row('Uso actual',   $mem_bar);
print &ui_table_row('Disponible',   int(($mem->{'available_kb'} || 0) / 1024).' MB');
print &ui_table_row('Swap total',   int(($mem->{'swap_total_kb'} || 0) / 1024).' MB');
print &ui_table_row('Swap usado',   int(($mem->{'swap_used_kb'}  || 0) / 1024).' MB');
print &ui_table_end();

# Disk
print &ui_table_start('Disco', 'width=100%', 5);
print &ui_columns_start(['Dispositivo', 'Tamaño (GB)', 'Usado (GB)', 'Libre (GB)', 'Uso %']);
foreach my $d (@$disks) {
	my $col = $d->{'pct'} >= 90 ? 'red' : $d->{'pct'} >= 75 ? '#cc7700' : 'green';
	print &ui_columns_row([
		&html_escape($d->{'source'}).' ('.$d->{'mount'}.')',
		int($d->{'size_kb'}  / (1024*1024) * 10 + 0.5) / 10,
		int($d->{'used_kb'}  / (1024*1024) * 10 + 0.5) / 10,
		int($d->{'avail_kb'} / (1024*1024) * 10 + 0.5) / 10,
		'<span style="color:'.$col.'">'.$d->{'pct'}.'%</span>',
	]);
}
print &ui_columns_end();
print &ui_table_end();

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row('graphs.cgi',    'Gráficos de uso',      'Historial gráfico de CPU, memoria y disco via RRDtool/collectd.');
print &ui_buttons_row('bandwidth.cgi', 'Ancho de banda',       'Uso de ancho de banda por dominio.');
print &ui_buttons_row('processes.cgi', 'Procesos del sistema', 'Top procesos por consumo de CPU y memoria.');
print &ui_buttons_end();

&ui_print_footer('/', $text{'index_return'} || 'Return');
