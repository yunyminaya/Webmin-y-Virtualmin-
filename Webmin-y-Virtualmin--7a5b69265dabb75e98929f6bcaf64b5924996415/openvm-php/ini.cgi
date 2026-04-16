#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-php-lib.pl';
&ReadParse();

ovmphp_require_access();
my $d = ovmphp_current_domain();
$d || &error('Selecciona un dominio');
my $ini = ovmphp_get_ini_settings($d);

&ui_print_header(undef, 'OpenVM PHP - INI del dominio', '', 'ini');
print "<p>Variables PHP ini activas para <b>".&html_escape($d->{'dom'})."</b>.</p>\n";

if (%$ini) {
	print &ui_columns_start(['Variable', 'Valor']);
	foreach my $key (sort keys %$ini) {
		print &ui_columns_row([
			'<code>'.&html_escape($key).'</code>',
			&html_escape($ini->{$key}),
		]);
	}
	print &ui_columns_end();
}
else {
	print defined(&ui_message)
		? &ui_message('No se encontraron variables PHP ini personalizadas para este dominio')
		: "<p>No se encontraron variables PHP ini personalizadas</p>\n";
}

&ui_print_footer('index.cgi?dom='.&urlize($d->{'dom'}), $text{'index_return'} || 'Return');
