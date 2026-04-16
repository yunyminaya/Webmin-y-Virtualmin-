#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-ssl-lib.pl';
&ReadParse();

ovmssl_require_access();
my $providers = ovmssl_providers();
my $certs     = ovmssl_list_certs();
my $acme_bin  = ovmssl_acme_binary();
my $due       = ovmssl_domains_due_renewal(30);

&ui_print_header(undef, 'OpenVM SSL Manager', '', 'index');
print "<p>Gestión avanzada de certificados SSL con soporte nativo para Let's Encrypt, ZeroSSL y BuyPass. Sin dependencia de licencias comerciales.</p>\n";

# ACME client status
my $bin_status = $acme_bin
	? '<span style="color:green">Detectado: '.&html_escape($acme_bin).'</span>'
	: '<span style="color:#cc7700">No detectado — instala certbot o acme.sh para renovación automática</span>';

print &ui_table_start('Estado del cliente ACME', 'width=100%', 2);
print &ui_table_row('Cliente ACME', $bin_status);
print &ui_table_row('Dominios próximos a vencer (30 días)', scalar(@$due) || '0');
print &ui_table_end();

# Providers
print &ui_table_start('Proveedores SSL disponibles', 'width=100%', 4);
print &ui_columns_start(['Proveedor', 'Estado', 'Validez', 'Nota']);
foreach my $p (@$providers) {
	my $st = $p->{'enabled'}
		? '<span style="color:green">Habilitado</span>'
		: '<span style="color:#999">Deshabilitado</span>';
	print &ui_columns_row([
		&ui_link($p->{'url'}, &html_escape($p->{'name'}), undef, 'target=_blank'),
		$st,
		$p->{'id'} eq 'buypass' ? '180 días' : '90 días',
		&html_escape($p->{'note'}),
	]);
}
print &ui_columns_end();
print &ui_table_end();

# Certificate inventory
print &ui_table_start('Inventario de certificados', 'width=100%', 5);
print &ui_columns_start(['Dominio', 'Estado', 'Vence en (días)', 'Emisor', 'Acción']);
if (@$certs) {
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
			&ui_link('renew.cgi?id='.&urlize($c->{'id'}).'&provider=letsencrypt',
				'Renovar', undef, ''),
		]);
	}
}
else {
	print &ui_columns_row(['Sin certificados SSL activos', '', '', '', '']);
}
print &ui_columns_end();
print &ui_table_end();

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row('providers.cgi', 'Configurar proveedores', 'Ver y configurar los proveedores ACME disponibles.');
print &ui_buttons_row('certs.cgi', 'Ver todos los certificados', 'Inventario completo de certificados en todos los dominios.');
print &ui_buttons_end();

&ui_print_footer('/', $text{'index_return'} || 'Return');
