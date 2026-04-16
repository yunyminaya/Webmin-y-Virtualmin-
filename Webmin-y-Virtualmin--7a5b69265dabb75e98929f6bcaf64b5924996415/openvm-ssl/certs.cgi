#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-ssl-lib.pl';
&ReadParse();

ovmssl_require_access();
my $certs = ovmssl_list_certs();

&ui_print_header(undef, 'OpenVM SSL - Certificados', '', 'certs');
print "<p>Inventario completo de certificados SSL en todos los dominios visibles.</p>\n";

if (@$certs) {
	print &ui_columns_start(['Dominio', 'Estado', 'Días restantes', 'Emisor', 'Renovar']);
	foreach my $c (@$certs) {
		my $st_color = $c->{'status'} eq 'expired'  ? 'red'
			     : $c->{'status'} eq 'expiring' ? '#cc7700'
			     :                                 'green';
		my $st_label = $c->{'status'} eq 'expired'  ? 'Expirado'
			     : $c->{'status'} eq 'expiring' ? 'Por vencer'
			     : $c->{'status'} eq 'valid'    ? 'Válido'
			     :                                 'Desconocido';
		print &ui_columns_row([
			&html_escape($c->{'dom'}),
			'<span style="color:'.$st_color.'">'.$st_label.'</span>',
			defined($c->{'days'}) ? $c->{'days'} : '-',
			&html_escape($c->{'issuer'} || '-'),
			&ui_link('renew.cgi?id='.&urlize($c->{'id'}).'&provider=letsencrypt', 'Renovar'),
		]);
	}
	print &ui_columns_end();
}
else {
	print defined(&ui_message)
		? &ui_message('No se encontraron certificados SSL activos')
		: "<p>No se encontraron certificados SSL activos</p>\n";
}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
