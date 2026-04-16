#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-scripts-lib.pl';
&ReadParse();

ovmsc_require_access();
my $app_id   = $in{'app'} || '';
my $d        = ovmsc_current_domain();
my $catalog  = ovmsc_apps_catalog();
my ($app)    = grep { $_->{'id'} eq $app_id } @$catalog;

&ui_print_header(undef, 'OpenVM Scripts - Instalar app', '', 'install');

if (!$app) {
	print defined(&ui_message)
		? &ui_message('App no encontrada en el catálogo: '.&html_escape($app_id))
		: "<p>App no encontrada: ".&html_escape($app_id)."</p>\n";
	print &ui_buttons_start();
	print &ui_buttons_row('index.cgi', 'Volver al catálogo', '');
	print &ui_buttons_end();
	&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
	exit;
}

if (!$d) {
	print defined(&ui_message)
		? &ui_message('Selecciona un dominio antes de instalar')
		: "<p>Selecciona un dominio antes de instalar</p>\n";
	&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
	exit;
}

print &ui_table_start('Instalar '.&html_escape($app->{'name'}), 'width=100%', 2);
print &ui_table_row('App',      &html_escape($app->{'name'}));
print &ui_table_row('Dominio',  &html_escape($d->{'dom'}));
print &ui_table_row('Categoría', &html_escape($app->{'category'}));
print &ui_table_row('Herramienta', &html_escape($app->{'tool'}));
print &ui_table_row('Comando base', '<code>'.&html_escape($app->{'install_cmd'}).'</code>');
print &ui_table_row('Descripción', &html_escape($app->{'description'}));
print &ui_table_end();

print "<p><strong>Nota:</strong> La instalación se ejecuta en el directorio público del dominio usando las herramientas detectadas en el servidor.</p>\n";
print "<p>Para instalar, ejecuta el comando base desde el directorio público del dominio via SSH o terminal.</p>\n";

print &ui_buttons_start();
print &ui_buttons_row('index.cgi', 'Volver al catálogo', '');
print &ui_buttons_end();

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
