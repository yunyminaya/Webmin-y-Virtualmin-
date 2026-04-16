#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-mail-lib.pl';
&ReadParse();

ovmm_require_access();
my $policy = ovmm_cleanup_policy();

&ui_print_header(undef, 'OpenVM Mail - Política de limpieza', '', 'cleanup');
print "<p>Reglas de limpieza automática de buzones. Se aplican globalmente a todos los dominios con correo habilitado.</p>\n";

print &ui_table_start('Política activa', 'width=100%', 2);
print &ui_table_row('Mensajes más antiguos de (días)',  $policy->{'old_messages_days'});
print &ui_table_row('Vaciado automático de Trash (días)', $policy->{'trash_days'});
print &ui_table_row('Umbral de alerta de cuota (%)',    $policy->{'quota_warning_pct'});
print &ui_table_row('Descripción',                      &html_escape($policy->{'description'}));
print &ui_table_end();

print "<p>Para modificar la política, edita los valores en la configuración del módulo (<code>config</code>).</p>\n";
print "<p>La limpieza automática puede activarse con un cron que ejecute:<br><code>find /var/mail -name '*.msg' -mtime +".$policy->{'old_messages_days'}." -delete</code></p>\n";

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
