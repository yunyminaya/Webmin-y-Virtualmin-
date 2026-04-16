#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-php-lib.pl';
&ReadParse();

ovmphp_require_access();
my $versions = ovmphp_installed_versions();
my $d        = ovmphp_current_domain();
my $dom_args = $d ? '?dom='.&urlize($d->{'dom'}) : '';

&ui_print_header(undef, 'OpenVM PHP Manager', '', 'index');
print "<p>Gestión nativa de versiones PHP y configuración por directorio. Sin dependencia de licencias comerciales.</p>\n";

# Installed versions
print &ui_table_start('Versiones PHP instaladas', 'width=100%', 4);
print &ui_columns_start(['Versión', 'Binario', 'PHP-FPM', 'Estado']);
if (@$versions) {
	foreach my $v (@$versions) {
		my $bin_label  = $v->{'binary'}  ? &html_escape($v->{'binary'}) : '<span style="color:#999">no detectado</span>';
		my $fpm_label  = $v->{'fpm_active'}
			? '<span style="color:green">Activo</span>'
			: '<span style="color:#999">Inactivo</span>';
		print &ui_columns_row([
			'<strong>PHP '.$v->{'version'}.'</strong>',
			$bin_label,
			&html_escape($v->{'fpm_svc'}),
			$fpm_label,
		]);
	}
}
else {
	print &ui_columns_row(['No se detectaron versiones PHP instaladas', '', '', '']);
}
print &ui_columns_end();
print &ui_table_end();

# Domain context
if ($d) {
	my $dom_ver = ovmphp_domain_php_version($d);
	print &ui_table_start('PHP para '.&html_escape($d->{'dom'}), 'width=100%', 2);
	print &ui_table_row('Versión activa', $dom_ver ? "PHP $dom_ver" : 'No determinada');
	print &ui_table_end();
}

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row('versions.cgi',   'Versiones del sistema',    'Detalles de todas las versiones PHP disponibles.');
print &ui_buttons_row('directories.cgi'.$dom_args, 'Configuración por directorio', 'PHP distinto por subdirectorio del dominio.');
print &ui_buttons_row('ini.cgi'.$dom_args,         'PHP ini del dominio',          'Variables php.ini activas para el dominio.');
print &ui_buttons_end();

&ui_print_footer('/', $text{'index_return'} || 'Return');
