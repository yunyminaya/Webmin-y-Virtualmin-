#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-scripts-lib.pl';
&ReadParse();

ovmsc_require_access();
my $tools  = ovmsc_tool_status();
my $apps   = ovmsc_apps_catalog();
my $d      = ovmsc_current_domain();
my $dom_args = $d ? '?dom='.&urlize($d->{'dom'}) : '';

&ui_print_header(undef, 'OpenVM Script Installer', '', 'index');
print "<p>Instalador nativo de aplicaciones web. Usa WP-CLI, Composer, Drush y otras herramientas open source sin dependencia de licencias comerciales.</p>\n";

# Tool status table
print &ui_table_start('Herramientas detectadas', 'width=100%', 2);
foreach my $tool (sort keys %$tools) {
	my $path = $tools->{$tool};
	my $val  = $path
		? '<span style="color:green">'.&html_escape($path).'</span>'
		: '<span style="color:#999">No instalado</span>';
	print &ui_table_row(&html_escape($tool), $val);
}
print &ui_table_end();

# Domain context
if ($d) {
	my $installed = ovmsc_installed_apps($d);
	print &ui_table_start('Apps instaladas en '.&html_escape($d->{'dom'}), 'width=100%', 2);
	if (@$installed) {
		foreach my $app (@$installed) {
			print &ui_table_row(
				&html_escape($app->{'name'} || $app->{'script'} || '-'),
				&html_escape($app->{'version'} || '-')
			);
		}
	}
	else {
		print &ui_table_row('Estado', 'No se detectaron aplicaciones instaladas');
	}
	print &ui_table_end();
}

# Apps catalog
print &ui_table_start('Catálogo de aplicaciones disponibles', 'width=100%', 4);
print &ui_columns_start(['App', 'Categoría', 'Herramienta', 'Descripción']);
foreach my $app (@$apps) {
	my $tool_ok = $app->{'tool_bin'} ? 1 : 0;
	my $avail   = $app->{'available'} && $tool_ok;
	my $name_cell = $avail
		? &ui_link('install.cgi?app='.&urlize($app->{'id'}).$dom_args,
			&html_escape($app->{'name'}))
		: &html_escape($app->{'name'});
	my $tool_cell = &html_escape($app->{'tool'}).
		($tool_ok
			? ' <span style="color:green">✓</span>'
			: ' <span style="color:#cc7700">(no instalado)</span>');
	print &ui_columns_row([
		$name_cell,
		&html_escape($app->{'category'}),
		$tool_cell,
		&html_escape($app->{'description'}),
	]);
}
print &ui_columns_end();
print &ui_table_end();

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row('installed.cgi'.$dom_args, 'Apps instaladas', 'Ver aplicaciones detectadas en el dominio seleccionado.');
print &ui_buttons_end();

&ui_print_footer('/', $text{'index_return'} || 'Return');
