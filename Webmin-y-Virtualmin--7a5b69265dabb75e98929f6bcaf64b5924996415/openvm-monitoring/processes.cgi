#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-monitoring-lib.pl';
&ReadParse();

ovmon_require_access();
my $procs = ovmon_top_processes(20);

&ui_print_header(undef, 'OpenVM Monitoring - Procesos', '', 'processes');
print "<p>Top procesos del sistema ordenados por uso de CPU.</p>\n";

if (@$procs) {
	print &ui_columns_start(['PID', 'Usuario', 'CPU %', 'MEM %', 'Comando']);
	foreach my $p (@$procs) {
		my $col = $p->{'cpu_pct'} >= 80 ? 'red'
			: $p->{'cpu_pct'} >= 40 ? '#cc7700'
			: 'inherit';
		print &ui_columns_row([
			$p->{'pid'},
			&html_escape($p->{'user'}),
			'<span style="color:'.$col.'">'.$p->{'cpu_pct'}.'</span>',
			$p->{'mem_pct'},
			'<code>'.&html_escape(substr($p->{'command'}, 0, 80)).'</code>',
		]);
	}
	print &ui_columns_end();
}
else {
	print defined(&ui_message)
		? &ui_message('No se pudo obtener información de procesos')
		: "<p>No se pudo obtener información de procesos</p>\n";
}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
