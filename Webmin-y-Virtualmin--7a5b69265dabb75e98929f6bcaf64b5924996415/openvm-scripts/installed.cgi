#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-scripts-lib.pl';
&ReadParse();

ovmsc_require_access();
my $d = ovmsc_current_domain();
my $installed = $d ? ovmsc_installed_apps($d) : [];

&ui_print_header(undef, 'OpenVM Scripts - Apps instaladas', '', 'installed');
print $d
	? "<p>Apps detectadas en el dominio <b>".&html_escape($d->{'dom'})."</b>.</p>\n"
	: "<p>Selecciona un dominio para ver las apps instaladas.</p>\n";

if (@$installed) {
	print &ui_columns_start(['App / Script', 'Versión', 'Ruta']);
	foreach my $app (@$installed) {
		print &ui_columns_row([
			&html_escape($app->{'name'} || $app->{'script'} || '-'),
			&html_escape($app->{'version'} || '-'),
			&html_escape($app->{'dir'} || '-'),
		]);
	}
	print &ui_columns_end();
}
else {
	print defined(&ui_message)
		? &ui_message('No se detectaron aplicaciones instaladas')
		: "<p>No se detectaron aplicaciones instaladas</p>\n";
}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
