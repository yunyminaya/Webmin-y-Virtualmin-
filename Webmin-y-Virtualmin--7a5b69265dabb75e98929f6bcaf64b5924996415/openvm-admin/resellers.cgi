#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-admin-lib.pl';
&ReadParse();

ovma_require_module_access();
my $resellers = ovma_list_resellers();

&ui_print_header(undef, 'OpenVM Resellers', '', 'resellers');
print "<p>Open inventory of reseller accounts exposed by the current runtime.</p>\n";

if (@$resellers) {
	print &ui_columns_start([
		'Name',
		'Password state',
		'Default IPv4',
		'ACL summary'
	]);
	foreach my $reseller (@$resellers) {
		my $acl = $reseller->{'acl'} || {};
		my @acl_keys = grep { defined($acl->{$_}) && $acl->{$_} ne '' } sort keys %$acl;
		my $acl_summary = @acl_keys ? join(', ', @acl_keys[0 .. (@acl_keys > 5 ? 4 : $#acl_keys)]) : '-';
		print &ui_columns_row([
			&html_escape($reseller->{'name'} || '-'),
			($reseller->{'pass'} && $reseller->{'pass'} =~ /^!/) ? 'Locked' : 'Active',
			&html_escape($acl->{'defip'} || '-'),
			&html_escape($acl_summary)
		]);
	}
	print &ui_columns_end();
	}
else {
	print defined(&ui_message)
		? &ui_message('No reseller inventory is available from the current runtime')
		: "<p>No reseller inventory is available from the current runtime</p>\n";
	}

ovma_log_action('view', 'openvm-admin', 'Viewed reseller inventory');
&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
