#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-php-lib.pl';
&ReadParse();

ovmphp_require_access();
my $d = ovmphp_current_domain();
$d || &error('Selecciona un dominio para ver configuración por directorio');
my $dirs = ovmphp_per_dir_configs($d);

&ui_print_header(undef, 'OpenVM PHP - Por directorio', '', 'directories');
print "<p>Configuración PHP por directorio en <b>".&html_escape($d->{'dom'})."</b>.</p>\n";

if (@$dirs) {
	print &ui_columns_start(['Directorio', 'Versión PHP', 'Fuente']);
	foreach my $dir (@$dirs) {
		print &ui_columns_row([
			&html_escape($dir->{'dir'}    || $dir->{'directory'} || '-'),
			&html_escape($dir->{'php_ver'} || $dir->{'version'}  || '-'),
			&html_escape($dir->{'source'} || 'Virtualmin'),
		]);
	}
	print &ui_columns_end();
}
else {
	print defined(&ui_message)
		? &ui_message('No se encontraron configuraciones PHP por directorio para este dominio')
		: "<p>No se encontraron configuraciones PHP por directorio</p>\n";
}

&ui_print_footer('index.cgi?dom='.&urlize($d->{'dom'}), $text{'index_return'} || 'Return');
