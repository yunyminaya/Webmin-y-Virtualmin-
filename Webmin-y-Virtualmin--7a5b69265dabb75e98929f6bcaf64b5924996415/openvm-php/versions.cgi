#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-php-lib.pl';
&ReadParse();

ovmphp_require_access();
my $versions = ovmphp_installed_versions();

&ui_print_header(undef, 'OpenVM PHP - Versiones', '', 'versions');
print "<p>Versiones PHP disponibles en el sistema (detectadas automáticamente).</p>\n";

if (@$versions) {
	print &ui_columns_start(['Versión', 'Binario', 'FPM Service', 'PID activo', 'dir ini']);
	foreach my $v (@$versions) {
		print &ui_columns_row([
			'PHP '.$v->{'version'},
			$v->{'binary'} ? &html_escape($v->{'binary'}) : '-',
			&html_escape($v->{'fpm_svc'}),
			$v->{'fpm_active'} ? '<span style="color:green">Sí</span>'
					   : '<span style="color:#999">No</span>',
			&html_escape($v->{'ini_dir'} || '-'),
		]);
	}
	print &ui_columns_end();
}
else {
	print defined(&ui_message)
		? &ui_message('No se detectaron versiones PHP instaladas en /etc/php/')
		: "<p>No se detectaron versiones PHP instaladas</p>\n";
}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
