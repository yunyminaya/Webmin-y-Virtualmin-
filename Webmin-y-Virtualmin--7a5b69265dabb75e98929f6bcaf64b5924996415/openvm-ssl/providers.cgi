#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-ssl-lib.pl';
&ReadParse();

ovmssl_require_access();
my $providers = ovmssl_providers();

&ui_print_header(undef, 'OpenVM SSL - Proveedores', '', 'providers');
print "<p>Proveedores ACME soportados nativamente. No se requiere licencia comercial para ninguno de ellos.</p>\n";

print &ui_table_start('Proveedores ACME', 'width=100%', 2);
foreach my $p (@$providers) {
	print &ui_table_row('Proveedor', &html_escape($p->{'name'}));
	print &ui_table_row('URL',       &ui_link($p->{'url'}, &html_escape($p->{'url'}), undef, 'target=_blank'));
	print &ui_table_row('Directorio ACME', &html_escape($p->{'acme_dir'}));
	print &ui_table_row('Coste',     $p->{'free'} ? 'Gratuito' : 'De pago');
	print &ui_table_row('Estado',
		$p->{'enabled'}
			? '<span style="color:green">Habilitado</span>'
			: '<span style="color:#999">Deshabilitado</span>');
	print &ui_table_row('Nota', &html_escape($p->{'note'}));
	print &ui_table_row('', &ui_hr());
}
print &ui_table_end();

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
