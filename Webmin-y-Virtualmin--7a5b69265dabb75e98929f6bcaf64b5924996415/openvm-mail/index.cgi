#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-mail-lib.pl';
&ReadParse();

ovmm_require_access();
my $d        = ovmm_current_domain();
my $dom_args = $d ? '?dom='.&urlize($d->{'dom'}) : '';
my $summary  = $d ? ovmm_domain_summary($d) : {};

&ui_print_header(undef, 'OpenVM Mail Manager', '', 'index');
print "<p>Gestión nativa de filtros de correo, cuotas y limpieza de buzones. Sin dependencia de licencias comerciales.</p>\n";

if ($d) {
	print &ui_table_start('Resumen de correo: '.&html_escape($d->{'dom'}), 'width=100%', 2);
	print &ui_table_row('Filtros activos',  $summary->{'filters'}   // 0);
	print &ui_table_row('Buzones',          $summary->{'mailboxes'} // 0);
	print &ui_table_row('Alertas de cuota', $summary->{'warnings'}  // 0);
	print &ui_table_end();
}
else {
	print defined(&ui_message)
		? &ui_message('Selecciona un dominio con correo habilitado para ver detalles')
		: "<p>Selecciona un dominio con correo habilitado</p>\n";
}

my $policy = ovmm_cleanup_policy();
print &ui_table_start('Política de limpieza', 'width=100%', 2);
print &ui_table_row('Mensajes antiguos', $policy->{'old_messages_days'}.' días');
print &ui_table_row('Vaciado de Trash',  $policy->{'trash_days'}.' días');
print &ui_table_row('Alerta de cuota',   $policy->{'quota_warning_pct'}.'%');
print &ui_table_row('Descripción',       &html_escape($policy->{'description'}));
print &ui_table_end();

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row('filters.cgi'.$dom_args,  'Filtros de correo', 'Ver y gestionar filtros Procmail/Sieve del dominio.');
print &ui_buttons_row('quotas.cgi'.$dom_args,   'Cuotas de buzones', 'Ver uso y alertas de cuota por buzón.');
print &ui_buttons_row('cleanup.cgi'.$dom_args,  'Política de limpieza', 'Revisar y ajustar las reglas de limpieza automática.');
print &ui_buttons_end();

&ui_print_footer('/', $text{'index_return'} || 'Return');
