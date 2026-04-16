#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-ssl-lib.pl';
&ReadParse();

ovmssl_require_access();

my $id       = $in{'id'}       || '';
my $provider = $in{'provider'} || 'letsencrypt';

ovmssl_load_virtualmin();
my $d = $id ? &get_domain($id) : ovmssl_current_domain();
$d || &error('Dominio no encontrado');

my $result = ovmssl_renew_domain($d, $provider);

&ui_print_header(undef, 'OpenVM SSL - Renovar certificado', '', 'renew');

if ($result->{'ok'}) {
	print defined(&ui_message)
		? &ui_message('Certificado renovado correctamente para <b>'.&html_escape($d->{'dom'}).'</b>')
		: "<p>Certificado renovado correctamente para <b>".&html_escape($d->{'dom'})."</b></p>\n";
}
else {
	print defined(&ui_message)
		? &ui_message('Error al renovar el certificado: <pre>'.&html_escape($result->{'msg'}).'</pre>')
		: "<p>Error: <pre>".&html_escape($result->{'msg'} || 'Sin detalle')."</pre></p>\n";
}

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row('certs.cgi', 'Volver a certificados', '');
print &ui_buttons_end();

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
