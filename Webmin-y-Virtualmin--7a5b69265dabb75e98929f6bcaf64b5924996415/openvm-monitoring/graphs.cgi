#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-monitoring-lib.pl';
&ReadParse();

ovmon_require_access();
my $rrd = ovmon_rrd_available();

&ui_print_header(undef, 'OpenVM Monitoring - Gráficos', '', 'graphs');
print "<p>Gráficos de uso de recursos via RRDtool y collectd.</p>\n";

if ($rrd) {
	my $cfg = ovmon_module_config();
	my $rrd_dir = $cfg->{'rrd_dir'};
	print &ui_table_start('RRD disponible', 'width=100%', 2);
	print &ui_table_row('RRDtool', '<span style="color:green">Disponible</span>');
	print &ui_table_row('Directorio RRD', &html_escape($rrd_dir));
	print &ui_table_end();
	print "<p>Los gráficos RRD pueden generarse con: <code>rrdtool graph /tmp/cpu.png --start -86400 DEF:load=$rrd_dir/localhost/load/load.rrd:shortterm:AVERAGE LINE1:load#ff0000:CPU</code></p>\n";
}
else {
	print defined(&ui_message)
		? &ui_message('RRDtool / collectd no detectados. Instala con: <code>apt install rrdtool collectd</code> para activar gráficos históricos.')
		: "<p>RRDtool / collectd no detectados. Instala con: <code>apt install rrdtool collectd</code></p>\n";
}

print &ui_hr();
my $cpu = ovmon_cpu_info();
my $mem = ovmon_memory_info();

# Simple ASCII-style bar representation
sub pct_bar {
	my ($pct) = @_;
	$pct = 0 unless defined $pct;
	$pct = 100 if $pct > 100;
	my $filled = int($pct / 5);
	my $empty  = 20 - $filled;
	my $col    = $pct >= 90 ? 'red' : $pct >= 70 ? '#cc7700' : 'green';
	return '<code style="color:'.$col.'">['
		. ('█' x $filled)
		. ('░' x $empty)
		. '] '.$pct.'%</code>';
}

print &ui_table_start('Estado actual (tiempo real)', 'width=100%', 2);
print &ui_table_row('CPU', pct_bar($cpu->{'usage_pct'} // 0));
print &ui_table_row('RAM', pct_bar($mem->{'usage_pct'} // 0));
my $swap_pct = $mem->{'swap_total_kb'}
	? int(($mem->{'swap_used_kb'} || 0) * 100 / $mem->{'swap_total_kb'})
	: 0;
print &ui_table_row('Swap', pct_bar($swap_pct));
print &ui_table_end();

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
