#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-monitoring-lib.pl';
&ReadParse();

ovmon_require_access();
my $bw = ovmon_bandwidth_per_domain();

&ui_print_header(undef, 'OpenVM Monitoring - Ancho de banda', '', 'bandwidth');
print "<p>Uso de ancho de banda por dominio (datos del runtime GPL).</p>\n";

if (@$bw) {
	print &ui_columns_start(['Dominio', 'Usado (MB)', 'Cuota (MB)', 'Uso %']);
	foreach my $b (@$bw) {
		my $col = $b->{'pct'} >= 90 ? 'red' : $b->{'pct'} >= 75 ? '#cc7700' : 'green';
		print &ui_columns_row([
			&html_escape($b->{'dom'}),
			$b->{'used_mb'},
			$b->{'quota_mb'} || 'Sin límite',
			$b->{'quota_mb'}
				? '<span style="color:'.$col.'">'.$b->{'pct'}.'%</span>'
				: '-',
		]);
	}
	print &ui_columns_end();
}
else {
	print defined(&ui_message)
		? &ui_message('No hay datos de ancho de banda disponibles')
		: "<p>No hay datos de ancho de banda disponibles</p>\n";
}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
