#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-mail-lib.pl';
&ReadParse();

ovmm_require_access();
my $d = ovmm_current_domain();
$d || &error('Selecciona un dominio con correo habilitado');
my $filters = ovmm_list_filters($d);

&ui_print_header(undef, 'OpenVM Mail - Filtros', '', 'filters');
print "<p>Filtros de correo activos en <b>".&html_escape($d->{'dom'})."</b>.</p>\n";

if (@$filters) {
	print &ui_columns_start(['Tipo', 'Condición', 'Acción']);
	foreach my $f (@$filters) {
		print &ui_columns_row([
			&html_escape($f->{'type'}   || 'procmail'),
			&html_escape($f->{'cond'}   || '-'),
			&html_escape($f->{'action'} || '-'),
		]);
	}
	print &ui_columns_end();
}
else {
	print defined(&ui_message)
		? &ui_message('No se encontraron filtros de correo para este dominio')
		: "<p>No se encontraron filtros de correo</p>\n";
}

&ui_print_footer('index.cgi?dom='.&urlize($d->{'dom'}), $text{'index_return'} || 'Return');
