#!/usr/bin/perl

use FindBin;
chdir("$FindBin::Bin/..");
require './virtual-server-lib.pl';
&ReadParse();

sub current_domain
{
my $d;
$d = &get_domain($in{'id'}) if ($in{'id'});
$d ||= &get_domain_by('dom', $in{'dom'}) if ($in{'dom'});
$d ||= &get_domain_by('user', $base_remote_user);
return $d;
}

my $d = &current_domain();
$d || &error($text{'edit_connect'} || 'No virtual server selected');
&can_edit_domain($d) || &error($text{'edit_connect'} || 'You cannot validate this virtual server');

&ui_print_header(undef, $text{'edit_connect'} || 'Check connectivity', '', 'connectivity');
print ($text{'edit_connectdesc'} || 'Verify that this virtual server can be reached from the Internet.'),"<p>\n";

my @checks;
if (defined(&check_domain_connectivity)) {
	my @errs = &check_domain_connectivity($d, { 'mail' => 1, 'ssl' => 1 });
	if (@errs) {
		foreach my $e (@errs) {
			push(@checks, [ $text{'error'} || 'Error', 0, $e ]);
		}
	}
	else {
		push(@checks, [ $text{'setup_done'} || 'OK', 1,
			$text{'edit_connectdesc'} || 'Connectivity checks completed successfully' ]);
	}
}
else {
	my $resolved = gethostbyname($d->{'dom'}) ? 1 : 0;
	my $web_enabled = $d->{'web'} ? 1 : 0;
	my $mail_enabled = $d->{'mail'} ? 1 : 0;
	my $ssl_enabled = $d->{'ssl'} ? 1 : 0;
	push(@checks, [ 'DNS', $resolved,
		$resolved ? 'Domain resolves via system resolver' : 'Domain does not resolve from this host' ]);
	push(@checks, [ 'Website', $web_enabled,
		$web_enabled ? 'Website feature is enabled for this virtual server' : 'Website feature is disabled for this virtual server' ]);
	push(@checks, [ 'Mail', $mail_enabled,
		$mail_enabled ? 'Mail feature is enabled for this virtual server' : 'Mail feature is disabled for this virtual server' ]);
	push(@checks, [ 'SSL', $ssl_enabled,
		$ssl_enabled ? 'SSL is enabled for this virtual server' : 'SSL is not enabled for this virtual server' ]);
}

print &ui_table_start($text{'edit_connect'} || 'Check connectivity', undef, 3);
foreach my $c (@checks) {
	print &ui_table_row($c->[0],
		($c->[1] ? '<span style="color: green">OK</span>' : '<span style="color: red">FAIL</span>').
		"<br>".&html_escape($c->[2]));
}
print &ui_table_end();

&ui_print_footer('', $text{'index_return'} || 'Return');
