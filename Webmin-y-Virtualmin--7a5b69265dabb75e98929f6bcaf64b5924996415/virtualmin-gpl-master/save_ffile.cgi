#!/usr/local/bin/perl
# save_ffile.cgi
# Save a filter file

require './virtual-server-lib.pl';
&ReadParseMime();
&licence_status();
$d = &get_domain($in{'dom'});
&can_edit_domain($d) || &error($text{'aliases_ecannot'});
&can_edit_afiles() || &error($text{'ffile_ecannot'});
&error_setup($text{'ffile_err'});

for($i=0; defined($in{"field_$i"}); $i++) {
	next if (!$in{"field_$i"});
	$in{"match_$i"} || &error($text{'ffile_ematch'});
	$in{"action_$i"} || &error($text{'ffile_eaction'});
	push(@filter, $in{"what_$i"}." ".$in{"action_$i"}." ".
		      $in{"field_$i"}." ".$in{"match_$i"}."\n");
	}
push(@filter, "2 ".$in{'other'}."\n") if ($in{'other'});

&lock_file($in{'file'});
&open_tempfile_as_domain_user($d, FILE, ">$in{'file'}", 1) ||
	&error(&text('ffile_ewrite', $in{'file'}, $d->{'user'}, $!));
&print_tempfile(FILE, @filter);
&close_tempfile_as_domain_user($d, FILE);
&unlock_file($in{'file'});
&run_post_actions_silently();
&webmin_log("save", "ffile", $in{'file'});

$what = $in{'alias'} ? 'alias' : 'user';
&redirect("edit_$what.cgi?$what=$in{$what}&dom=$in{'dom'}&unix=1");

