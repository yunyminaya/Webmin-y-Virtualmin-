#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-batch-lib.pl';
&ReadParse();

ovmbatch_require_access();
my $cfg = ovmbatch_module_config();

&ui_print_header(undef, 'OpenVM Batch Domain Manager', '', 'index');
print "<p>Creación masiva de dominios virtuales desde CSV. Sin dependencia de licencias comerciales.</p>\n";

print &ui_table_start('Configuración', 'width=100%', 2);
print &ui_table_row('Límite por lote',    $cfg->{'max_batch_size'} || 500);
print &ui_table_row('Dry-run por defecto', $cfg->{'dry_run_default'} ? 'Sí' : 'No');
print &ui_table_end();

print &ui_table_start('Formato CSV esperado', 'width=100%', 2);
print &ui_table_row('Columnas', '<code>domain, user, password, plan, email</code>');
print &ui_table_row('Mínimo requerido', '<code>domain, user</code>');
print &ui_table_row('Ejemplo',
	'<pre>domain,user,password,plan,email'."\n".
	'ejemplo.com,ejemplo,Secret123,default,admin@ejemplo.com'."\n".
	'otro.com,otro,Pass456,,admin@otro.com</pre>');
print &ui_table_end();

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row('create.cgi', 'Iniciar creación masiva', 'Pegar o cargar CSV y crear dominios en lote.');
print &ui_buttons_end();

&ui_print_footer('/', $text{'index_return'} || 'Return');
