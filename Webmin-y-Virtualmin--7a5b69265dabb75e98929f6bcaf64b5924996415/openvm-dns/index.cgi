#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-dns-lib.pl';
&ReadParse();

ovmd_require_access();
my $clouds = ovmd_dns_clouds();
my $remote = ovmd_remote_dns();

&ui_print_header(undef, 'OpenVM DNS Operations', '', 'index');
print "<p>Panel abierto para inventario de proveedores DNS cloud y servidores DNS remotos usando el runtime GPL disponible.</p>\n";

print &ui_table_start('DNS cloud providers', 'width=100%', 2);
if (@$clouds) {
	foreach my $cloud (@$clouds) {
		my $status = $cloud->{'state_ok'} ? '<span style="color: green">READY</span>' : '<span style="color: #cc6600">UNCONFIGURED</span>';
		my $domains = @{$cloud->{'users'} || []} ? join(', ', @{$cloud->{'users'}}) : '-';
		my $label = $cloud->{'desc'} || $cloud->{'name'};
		my $title = &html_escape($label);
		if ($cloud->{'url'}) {
			$title = &ui_link($cloud->{'url'}, $title, undef, 'target=_blank');
			}
		print &ui_table_row($title, $status."<br>".&html_escape($cloud->{'state_desc'} || '')."<br>Domains: ".&html_escape($domains));
		}
	}
else {
	print &ui_table_row('Providers', 'No cloud DNS providers detected');
	}
print &ui_table_end();

print &ui_hr();
print &ui_table_start('Remote DNS servers', 'width=100%', 2);
if (@$remote) {
	foreach my $server (@$remote) {
		my $domains = @{$server->{'domains'} || []} ? join(', ', @{$server->{'domains'}}) : '-';
		print &ui_table_row(
			&html_escape($server->{'host'} || '-'),
			&html_escape($server->{'type'} || 'Remote')."<br>Domains: ".&html_escape($domains)."<br>Count: ".($server->{'domain_count'} || 0)
		);
		}
	}
else {
	print &ui_table_row('Servers', 'No remote DNS servers detected');
	}
print &ui_table_end();

&ui_print_footer('/', $text{'index_return'} || 'Return');
