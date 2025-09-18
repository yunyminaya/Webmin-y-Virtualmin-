#!/usr/local/bin/perl
# Save spam and virus delivery options for a virtual server

require './virtual-server-lib.pl';
&ReadParse();
&licence_status();
&error_setup($text{'spam_err'});
$d = &get_domain($in{'dom'});
&can_edit_domain($d) || &error($text{'edit_ecannot'});
&can_edit_spam($d) || &error($text{'spam_ecannot'});
&set_all_null_print();

# Work out what we can edit
if ($d->{'spam'}) {
	($smode, $sdest) = &get_domain_spam_delivery($d);
	if ($smode >= 0) {
		push(@what, [ 'spam', \&save_domain_spam_delivery ]);
		}
	}
if ($d->{'virus'}) {
	($vmode, $vdest) = &get_domain_virus_delivery($d);
	if ($vmode >= 0) {
		push(@what, [ 'virus', \&save_domain_virus_delivery ]);
		}
	}

# Validate spam and possibly virus inputs
foreach $w (@what) {
	($pfx, $func) = @$w;
	$mode = $in{$pfx."_mode"};
	$dest = undef;
	if ($mode == 1) {
		$dest = $in{$pfx."_file"};
		$dest =~ /\S/ && $dest !~ /\.\./ && $dest !~ /^\// ||
			&error($text{'spam_efile'});
		}
	elsif ($mode == 2) {
		$dest = $in{$pfx."_email"};
		$dest =~ /\@/ || &error($text{'spam_eemail'});
		}
	elsif ($mode == 3) {
		$dest = $in{$pfx."_dest"};
		$dest =~ /\S/ || &error($text{'spam_edest'});
		}
	@args = ( $d, $mode, $dest );
	if ($pfx eq "spam" && defined($in{'spamlevel_def'})) {
		# Spam deletion level
		if ($in{'spamlevel_def'}) {
			push(@args, 0);
			}
		else {
			$in{'spamlevel'} =~ /^[1-9]\d*$/ ||
				&error($text{'spam_elevel'});
			push(@args, $in{'spamlevel'});
			}
		}
	&$func(@args);
	}

&obtain_lock_spam($d);
&obtain_lock_cron($d);
&obtain_lock_mail($d);

if ($d->{'spam'} && &get_domain_spam_client($d) ne "spamc") {
	$d->{'spam_white'} = $in{'spam_white'};
	&update_spam_whitelist($d);
	&save_domain($d);
	}

# Save spam deletion field
$auto = { };
if ($in{'clear'} == 1) {
	$in{'days'} =~ /^\d+$/ && $in{'days'} > 0 ||
		&error($text{'spam_edays'});
	$auto->{'days'} = $in{'days'};
	}
elsif ($in{'clear'} == 2) {
	$in{'size'} =~ /^\d+$/ || &error($text{'spam_esize'});
	$auto->{'size'} = $in{'size'}*$in{'size_units'};
	}
if ($in{'trashclear'} == 1) {
	$in{'trashdays'} =~ /^\d+$/ && $in{'trashdays'} > 0 ||
		&error($text{'spam_etrashdays'});
	$auto->{'trashdays'} = $in{'trashdays'};
	}
elsif ($in{'trashclear'} == 2) {
	$in{'trashsize'} =~ /^\d+$/ || &error($text{'spam_etrashsize'});
	$auto->{'trashsize'} = $in{'trashsize'}*$in{'trashsize_units'};
	}
$auto->{'subfolders'} = $in{'subfolders'};
&save_domain_spam_autoclear($d, $auto);

# Save spamtrap setting
if (defined($in{'trap'})) {
	$st = &get_spamtrap_aliases($d);
	$err = undef;
	if ($st && !$in{'trap'}) {
		$err = &delete_spamtrap_aliases($d);
		}
	elsif (!$st && $in{'trap'}) {
		$err = &setup_spamtrap_aliases($d);
		}
	&error($err) if ($err);
	}

&release_lock_mail($d);
&release_lock_spam($d);
&release_lock_cron($d);

&run_post_actions();

# All done
&webmin_log("spam", "domain", $d->{'dom'});
&domain_redirect($d);

