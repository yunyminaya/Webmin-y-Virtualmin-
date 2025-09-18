#!/usr/local/bin/perl
# edit_newbw.cgi
# Display current bandwidth usage graphs, and allow enabling of scheduled
# checking

require './virtual-server-lib.pl';
&can_edit_templates() || &error($text{'newbw_ecannot'});
&ui_print_header(undef, $text{'newbw_title'}, "", "bandwidth");

$job = &find_bandwidth_job();
@tds = ( "width=30% ");
print "$text{'newbw_desc'}<p>\n";
print &ui_form_start("save_newbw.cgi", "post");
print &ui_hidden_table_start($text{'newbw_header1'}, "width=100%", 2, "table1",
			     1, \@tds);

# Show active field
print &ui_table_row(&hlink($text{'newbw_active'}, "bandwidth_bw_active"),
		    &ui_radio("bw_active", $job && $config{'bw_active'} ? 1 : 0,
			      [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

# Show interval between scans
print &ui_table_row(&hlink($text{'newbw_step'}, "bandwidth_bw_step"),
		    &ui_textbox("bw_step", $config{'bw_step'} || 1, 3));

# Show field for monitoring period
print &ui_table_row(&hlink($text{'newbw_period'}, "bandwidth_bw_past"),
		    &ui_select("bw_past", $config{'bw_past'},
			[ [ 'week', $text{'newbw_past_week'} ],
			  [ 'month', $text{'newbw_past_month'} ],
			  [ 'year', $text{'newbw_past_year'} ],
			  [ '', $text{'newbw_past_'} ] ])."\n".
		    &ui_textbox("bw_period",
		      $config{'bw_past'} ? undef : $config{'bw_period'}, 4)." ".
		    $text{'newbw_days'});

# Show field for max days to keep
print &ui_table_row(&hlink($text{'newbw_maxdays'}, "bandwidth_maxdays"),
		    &ui_opt_textbox("bw_maxdays", $config{'bw_maxdays'},
				    10, $text{'newbw_maxdaysdef'}));

# Show email to owner field
print &ui_table_row(&hlink($text{'newbw_owner'}, "bandwidth_bw_owner"),
		    &ui_yesno_radio("bw_owner", $config{'bw_owner'}));

# Show email to other address
print &ui_table_row(&hlink($text{'newbw_email'}, "bandwidth_bw_email"),
		    &ui_textbox("bw_email",
		      $config{'bw_email'} || $gconfig{'webmin_email_to'}, 30));

# Show field for notification period
print &ui_table_row(&hlink($text{'newbw_notify'}, "bandwidth_bw_notify"),
		    &ui_textbox("bw_notify", $config{'bw_notify'}, 5)."\n".
		    $text{'newbw_hours'});

# Show field for disable option
print &ui_table_row(&hlink($text{'newbw_disable'}, "bandwidth_bw_disable"),
		    &ui_radio("bw_disable", $config{'bw_disable'} ? 1 : 0,
			      [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

# Show field for re-enable option
print &ui_table_row(&hlink($text{'newbw_enable'}, "bandwidth_bw_enable"),
		    &ui_yesno_radio("bw_enable", $config{'bw_enable'}));

# Include FTP and SSH transfers for backups?
print &ui_table_row(&hlink($text{'newbw_backup'}, "bandwidth_bw_backup"),
		    &ui_yesno_radio("bw_backup", $config{'bw_backup'}));

print &ui_hidden_table_end("table1");

print &ui_hidden_table_start($text{'newbw_header2'}, "width=100%", 2, "table2",
			     0, \@tds);

# Show email for domains over limit
$file = $config{'bw_template'};
$file = "$module_config_directory/bw-template" if ($file eq "default");
print &ui_table_row(&hlink($text{'newbw_template'}, "bandwidth_bw_template"),
		    &ui_textarea("bw_template", &cat_file($file),
				5, 70));

# Show field for warning percentage
print &ui_table_row(&hlink($text{'newbw_warn'}, "bandwidth_bw_warn"),
    &ui_radio("bw_warn", $config{'bw_warn'} ? 1 : 0,
	      [ [ 1, &text('newbw_warnyes',
			   &ui_textbox("bw_warnlevel", $config{'bw_warn'},4)) ],
		[ 0, $text{'no'} ] ]));

# Show email for domains over limit
$file = $config{'warnbw_template'};
$file = "$module_config_directory/warnbw-template" if ($file eq "default");
print &ui_table_row(&hlink($text{'newbw_warntemplate'},
			   "bandwidth_warnbw_template"),
		    &ui_textarea("warnbw_template", &cat_file($file),
				5, 70));

print &ui_hidden_table_end("table2");

print &ui_hidden_table_start($text{'newbw_header3'}, "width=100%", 2, "table3",
			     0, \@tds);

# Servers to check or exclude
if ($config{'bw_servers'} eq "") {
	$serversmode = 0;
	}
elsif ($config{'bw_servers'} =~ /^\!(.*)$/) {
	$serversmode = 2;
	@servers = split(/\s+/, $1);
	}
else {
	$serversmode = 1;
	@servers = split(/\s+/, $config{'bw_servers'});
	}
print &ui_table_row(&hlink($text{'newbw_servers'}, "bandwidth_serversmode"),
		    &ui_radio("serversmode", $serversmode,
			      [ [ 0, $text{'newbw_servers0'} ],
			        [ 1, $text{'newbw_servers1'} ],
			        [ 2, $text{'newbw_servers2'} ] ])."<br>\n".
		    &servers_input("servers", \@servers,
				   [ &list_visible_domains() ]));

# Log files for FTP and mail
$defftplog = $config{'ftp'} ? &get_proftpd_log() : undef;
print &ui_table_row(&hlink($text{'newbw_ftplog'}, "bandwidth_ftplog_def"),
	&ui_opt_textbox("ftplog", $config{'bw_ftplog'}, 40,
	  $defftplog ? &text('newbw_ftplogdef', "<tt>$defftplog</tt>")."<br>"
		     : $text{'newbw_ftplognone'},
	$text{'newbw_ftplogfile'})."<br>".
	&ui_checkbox("ftplog_rotated", 1, &hlink($text{'newbw_rotated'},
						 "bandwidth_ftplog_rotated"),
		     $config{'bw_ftplog_rotated'}));

$mode = $config{'bw_maillog'} eq "auto" ? 2 : $config{'bw_maillog'} ? 0 : 1;
$defmaillog = $config{'mail'} ? &get_mail_log() : undef;
print &ui_table_row(&hlink($text{'newbw_maillog'}, "bandwidth_maillog_def"),
	&ui_radio("maillog_def", $mode,
	  [ [ 1, $text{'newbw_ftplognone'}."<br>" ],
	    [ 2, &text('newbw_maillogdef', $defmaillog ?
		   "<tt>$defmaillog</tt>" : $text{'newbw_unknown'})."<br>" ],
	    [ 0, $text{'newbw_maillogfile'}." ".
		 &ui_textbox("maillog", $mode ? undef : $config{'bw_maillog'},
			     40) ] ])."<br>".
	&ui_checkbox("maillog_rotated", 1, &hlink($text{'newbw_rotated'},
						  "bandwidth_maillog_rotated"),
		     $config{'bw_maillog_rotated'}));

# Include outgoing email
print &ui_table_row(&hlink($text{'newbw_mailout'}, "bandwidth_mailout"),
	&ui_radio("nomailout", int($config{'bw_nomailout'}),
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

# Include relayed email
print &ui_table_row(&hlink($text{'newbw_mailall'}, "bandwidth_mailall"),
	&ui_radio("mailall", int($config{'bw_mail_all'}),
		  [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_hidden_table_end("table3");
print &ui_form_end([ [ "save", $text{'save'} ] ]);

# Button to show graph
print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("bwgraph.cgi", $text{'newbw_graphbutton'},
				     $text{'newbw_graphdesc'});
if ($config{'bw_active'} && $virtualmin_pro) {
	print &ui_buttons_row("bwreset_form.cgi", $text{'newbw_resetbutton'},
						  $text{'newbw_resetdesc'});
	}
print &ui_buttons_end();

&ui_print_footer("", $text{'index_return'});

