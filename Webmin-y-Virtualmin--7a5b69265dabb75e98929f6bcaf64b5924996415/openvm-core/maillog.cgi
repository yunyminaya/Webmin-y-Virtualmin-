#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-lib.pl';
&ReadParse();

my $d = ovm_require_domain_access(ovm_current_domain(),
	'You cannot view mail logs with OpenVM Core for this virtual server');

my $limit = $in{'limit'} =~ /^\d+$/ ? $in{'limit'} : 200;
$limit = 1000 if ($limit > 1000);
$limit = 1 if ($limit < 1);

&ui_print_header(undef, 'OpenVM Mail Log Search', '', 'maillog');
print "<p>Search mail log entries for the current virtual server using an open implementation that does not depend on commercial licensing state.</p>\n";

print &ui_form_start('maillog.cgi', 'get');
print &ui_hidden('dom', $d->{'dom'}),"\n";
print &ui_table_start('Search conditions', undef, 2);
print &ui_table_row('Domain', &html_escape($d->{'dom'}));
print &ui_table_row('Start date / text',
	&ui_textbox('start', $in{'start'}, 30));
print &ui_table_row('End date / text',
	&ui_textbox('end', $in{'end'}, 30));
print &ui_table_row('Source address',
	&ui_textbox('source', $in{'source'}, 40));
print &ui_table_row('Destination address',
	&ui_textbox('dest', $in{'dest'}, 40));
print &ui_table_row('Max results',
	&ui_textbox('limit', $limit, 8));
print &ui_table_end();
print &ui_form_end([ [ 'search', $text{'search'} || 'Search' ] ]);

if ($in{'search'}) {
	my $results = ovm_mail_log_search($d, {
		'start' => $in{'start'},
		'end' => $in{'end'},
		'source' => $in{'source'},
		'dest' => $in{'dest'},
		'limit' => $limit,
		});

	print "<p><b>Search results</b></p>\n";
	if (@$results) {
		print &ui_columns_start([
			'File',
			'Log line'
		]);
		foreach my $entry (@$results) {
			print &ui_columns_row([
				&html_escape($entry->{'file'} || '-'),
				'<tt>'.&html_escape($entry->{'line'} || '').'</tt>'
			]);
		}
		print &ui_columns_end();
	}
	else {
		print defined(&ui_message)
			? &ui_message('No matching mail log entries were found')
			: "<p>No matching mail log entries were found</p>\n";
	}
}

&ui_print_footer('index.cgi?dom='.&urlize($d->{'dom'}), $text{'index_return'} || 'Return');
