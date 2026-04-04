#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-suite-lib.pl';
&ReadParse();

my $grouped = ovms_grouped_catalog();

&ui_print_header(undef, 'OpenVM Unified Suite', '', 'index');
print "<p>Unified entrypoint for the OpenVM open-source modules and the security/infrastructure modules already available in this repository.</p>\n";

foreach my $group (sort keys %$grouped) {
	print &ui_table_start($group, 'width=100%', 2);
	foreach my $module (@{$grouped->{$group}}) {
		print &ui_table_row(
			&html_escape($module->{'name'}),
			&ui_link($module->{'path'}, &html_escape($module->{'name'})).
			"<br>".&html_escape($module->{'description'})
		);
	}
	print &ui_table_end();
	print &ui_hr();
	}

&ui_print_footer('/', $text{'index_return'} || 'Return');
