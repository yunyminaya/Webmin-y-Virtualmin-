#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-mail-lib.pl';
&ReadParse();

ovmm_require_access();
my $d = ovmm_current_domain();
$d || &error('Selecciona un dominio con correo habilitado');
my $quotas = ovmm_mailbox_quotas($d);

&ui_print_header(undef, 'OpenVM Mail - Cuotas', '', 'quotas');
print "<p>Uso de cuota de buzones en <b>".&html_escape($d->{'dom'})."</b>.</p>\n";

if (@$quotas) {
	print &ui_columns_start(['Usuario', 'Email', 'Usado (KB)', 'Cuota (KB)', 'Uso %', 'Estado']);
	foreach my $q (@$quotas) {
		my $st = $q->{'warning'}
			? '<span style="color:#cc7700">Alerta</span>'
			: '<span style="color:green">Normal</span>';
		my $bar = $q->{'quota_kb'}
			? $q->{'pct'}.'%'
			: 'Sin límite';
		print &ui_columns_row([
			&html_escape($q->{'user'}),
			&html_escape($q->{'email'}),
			$q->{'used_kb'},
			$q->{'quota_kb'} || 'Sin límite',
			$bar,
			$st,
		]);
	}
	print &ui_columns_end();
}
else {
	print defined(&ui_message)
		? &ui_message('No se encontraron buzones con información de cuota')
		: "<p>No se encontraron buzones</p>\n";
}

&ui_print_footer('index.cgi?dom='.&urlize($d->{'dom'}), $text{'index_return'} || 'Return');
