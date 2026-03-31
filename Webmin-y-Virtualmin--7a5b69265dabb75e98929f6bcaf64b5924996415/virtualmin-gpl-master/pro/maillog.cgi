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
$d || &error($text{'maillog_ecannot'} || 'No virtual server selected');
my $can_view = defined(&can_view_maillog) ? &can_view_maillog($d)
	:	&can_edit_domain($d);
$can_view || &error($text{'maillog_ecannot'} || 'You cannot view mail logs for this virtual server');

&ui_print_header(undef, $text{'maillog_title'} || 'Search Mail Logs', '', 'maillog');
print ($text{'maillog_desc'} || 'Search mail log lines for the current virtual server using optional filters.'),"<p>\n";

print &ui_form_start('maillog.cgi', 'get');
print &ui_hidden('dom', $d->{'dom'}),"\n";
print &ui_table_start($text{'maillog_header'} || 'Search conditions', undef, 2);
print &ui_table_row($text{'maillog_start'} || 'Start date / text',
	&ui_textbox('start', $in{'start'}, 30));
print &ui_table_row($text{'maillog_end'} || 'End date / text',
	&ui_textbox('end', $in{'end'}, 30));
print &ui_table_row($text{'maillog_source'} || 'Source address',
	&ui_textbox('source', $in{'source'}, 40));
print &ui_table_row($text{'maillog_to'} || 'Destination address',
	&ui_textbox('dest', $in{'dest'}, 40));
print &ui_table_end();
print &ui_form_end([ [ 'search', $text{'search'} || 'Search' ] ]);

if ($in{'search'}) {
	my @files = grep { $_ && -r $_ }
		($config{'maillog_file'}, '/var/log/mail.log', '/var/log/maillog',
		 '/var/log/mail.log.1', '/var/log/maillog.1');
	my @results;
	my $limit = 200;
	foreach my $file (@files) {
		open(my $fh, '<', $file) || next;
		while(my $line = <$fh>) {
			chomp($line);
			next if ($in{'start'} && index(lc($line), lc($in{'start'})) < 0);
			next if ($in{'end'} && index(lc($line), lc($in{'end'})) < 0);
			next if ($in{'source'} && $line !~ /\Q$in{'source'}\E/i);
			next if ($in{'dest'} && $line !~ /\Q$in{'dest'}\E/i);
			if (!$in{'source'} && !$in{'dest'}) {
				next if ($line !~ /\Q$d->{'dom'}\E/i &&
				         (!$d->{'emailto'} || $line !~ /\Q$d->{'emailto'}\E/i));
			}
			push(@results, $line);
			last if (@results >= $limit);
		}
		close($fh);
		last if (@results >= $limit);
	}

	print "<p><b>",($text{'maillog_title'} || 'Search Mail Logs'),"</b></p>\n";
	if (@results) {
		print "<pre style='white-space: pre-wrap'>";
		foreach my $line (@results) {
			print &html_escape($line),"\n";
		}
		print "</pre>\n";
	}
	else {
		print &ui_message($text{'viewmaillog_egone'} || 'No matching log entries found');
	}
}

&ui_print_footer('', $text{'index_return'} || 'Return');
