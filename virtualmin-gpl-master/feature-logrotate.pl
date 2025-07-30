# Functions for managing logrotate

sub require_logrotate
{
return if ($require_logrotate++);
&foreign_require("logrotate");
}

sub check_depends_logrotate
{
my ($d) = @_;
if (!&domain_has_website($d)) {
	return $text{'setup_edeplogrotate'};
	}
return undef;
}

# setup_logrotate(&domain)
# Create logrotate entries for the server's access and error logs
sub setup_logrotate
{
my ($d) = @_;
&$first_print($text{'setup_logrotate'});
&require_logrotate();
&require_apache();
&obtain_lock_logrotate($d);
my $tmpl = &get_template($d->{'template'});

# Work out the log files we are rotating
my @logs = &get_all_domain_logs($d, 0);
my @tmpllogs = &get_domain_template_logs($d);
if (@logs) {
	# If in single config mode, check if there is a block for Virtualmin
	# already (either under /var/log/virtualmin, or in a domain's home)
	my $parent = &logrotate::get_config_parent();
	my $logdir = $logs[0];
	$logdir =~ s/\/[^\/]+$//;
	my $already;
	if ($tmpl->{'logrotate_shared'} eq 'yes') {
		LOGROTATE: foreach my $c (@{$parent->{'members'}}) {
			foreach my $n (@{$c->{'name'}}) {
				if ($n =~ /^\Q$logdir\E\/[^\/]+$/ ||
				    $n =~ /^\Q$home_base\E\//) {
					$already = $c;
					last LOGROTATE;
					}
				}
			}
		}

	# Check if any are already rotated
	my @addlogs = @logs;
	foreach my $c (@{$parent->{'members'}}) {
		foreach my $n (map { glob($_) } @{$c->{'name'}}) {
			if (&indexof($n, @addlogs) >= 0) {
				if ($already) {
					# Already rotated in a block that
					# includes multiple domains logs
					@addlogs = grep { $_ ne $n } @addlogs;
					}
				else {
					# A block for just this domain exists!
					&error(&text('setup_clashlogrotate',
						     "<tt>$n</tt>"));
					}
				}
			}
		}

	if (!$already) {
		# Add the new section
		my $file = &logrotate::get_add_file(
			$tmpl->{'logrotate_shared'} eq 'yes' ?
			    'virtualmin' : $d->{'dom'});
		my $lconf = { 'file' => $file,
			      'name' => \@logs };
		my $newfile = !-r $lconf->{'file'};
		if ($tmpl->{'logrotate'} eq 'none') {
			# Use automatic configuration
			my $script = &get_postrotate_script($d);
			$lconf->{'members'} = [
				{ 'name' => 'rotate',
				  'value' => $config{'logrotate_num'} || 5 },
				{ 'name' => 'weekly' },
				{ 'name' => 'compress' },
				{ 'name' => 'postrotate',
				  'script' => $script },
				{ 'name' => 'sharedscripts' },
				{ 'name' => 'missingok' },
				];
			}
		else {
			# Use manually defined directives
			my $temp = &transname();
			my $txt = $tmpl->{'logrotate'};
			$txt =~ s/\t/\n/g;
			&open_tempfile(TEMP, ">$temp");
			&print_tempfile(TEMP, "/dev/null {\n");
			&print_tempfile(TEMP,
				&substitute_domain_template($txt, $d)."\n");
			&print_tempfile(TEMP, "}\n");
			&close_tempfile(TEMP);
			my $tconf = &logrotate::get_config($temp);
			$lconf->{'members'} = $tconf->[0]->{'members'};
			unlink($temp);
			$d->{'logrotate_shared'} = 1;
			}
		&logrotate::save_directive($parent, undef, $lconf);
		&flush_file_lines($lconf->{'file'});
		if ($newfile) {
			&set_ownership_permissions(undef, undef, 0644,
						   $lconf->{'file'});
			}
		}
	elsif (@addlogs) {
		# Add to existing section
		push(@{$already->{'name'}}, @addlogs);
		&logrotate::save_directive($parent, $already, $already);
		&flush_file_lines($already->{'file'});
		}

	# Make sure extra log files actually exist
	foreach my $lt (@tmpllogs) {
		if (!-e $lt) {
			&open_tempfile_as_domain_user($d, TOUCHLOG,
						      ">$lt", 1, 1);
			&close_tempfile_as_domain_user($d, TOUCHLOG);
			&set_permissions_as_domain_user(
				$d, 0777, $lt);
			}
		}

	&$second_print($text{'setup_done'});
	}
else {
	&$second_print($text{'setup_nolog'});
	}
&release_lock_logrotate($d);
return 1;
}

# modify_logrotate(&domain, &olddomain)
# Adjust path if home directory has changed
sub modify_logrotate
{
my ($d, $oldd) = @_;

# Work out old and new Apache logs
my $alog = &get_website_log($d, 0);
my $oldalog = &get_old_website_log($alog, $d, $oldd);
my $elog = &get_website_log($d, 1);
my $oldelog = &get_old_website_log($elog, $d, $oldd);
my $plog = &get_domain_php_error_log($d);
my $oldplog = defined($oldd->{'php_error_log'}) ?
		$oldd->{'php_error_log'} :
		&get_old_website_log($plog, $d, $oldd);
my @logmap = ( [ $alog, $oldalog ],
	       [ $elog, $oldelog ],
	       [ $plog, $oldplog ] );
@logmap = grep { $_->[0] ne $_->[1] } @logmap;

# Stop here if nothing to do
return if (!@logmap &&
	   $d->{'user'} eq $oldd->{'user'} &&
	   $d->{'group'} eq $oldd->{'group'});
&require_logrotate();
&obtain_lock_logrotate($d);

# Change log paths if needed
if (@logmap) {
	&$first_print($text{'save_logrotate'});

	# Fix up the logrotate section for the old file
	my $lconf = &get_logrotate_section($oldalog);
	if ($lconf) {
		my $parent = &logrotate::get_config_parent();
		my @n = @{$lconf->{'name'}};
		foreach my $lm (@logmap) {
			if ($lm->[1]) {
				# We know what the old log file was
				my $idx = &indexof($lm->[1], @n);
				if ($idx >= 0 && $lm->[0]) {
					# Found it, and there's a replacement
					$n[$idx] = $lm->[0];
					}
				elsif ($idx >= 0) {
					# Found it, no replacement so remove it
					splice(@n, $idx, 1);
					}
				}
			elsif ($lm->[0]) {
				# Only new log exists, so add if missing
				my $idx = &indexof($lm->[0], @n);
				if ($idx < 0) {
					push(@n, $lm->[0]);
					}
				}
			}
		$lconf->{'name'} = \@n;
		&logrotate::save_directive($parent, $lconf, $lconf);
		&flush_file_lines($lconf->{'file'});
		&$second_print($text{'setup_done'});
		}
	else {
		&$second_print(&text('setup_nologrotate', $oldalog));
		}
	}

# Change references to home dir
if ($d->{'home'} ne $oldd->{'home'}) {
	&$first_print($text{'save_logrotatehome'});
	my $lconf = &get_logrotate_section($alog);
	if ($lconf) {
                my $parent = &logrotate::get_config_parent();
		foreach my $n (@{$lconf->{'name'}}) {
			$n =~ s/\Q$oldd->{'home'}\E\//$d->{'home'}\//;
			}
		&logrotate::save_directive($parent, $lconf, $lconf);
		&flush_file_lines($lconf->{'file'});
		&$second_print($text{'setup_done'});
		}
	else {
		&$second_print($text{'setup_nologrotate2'});
		}
	}

# Change references to user or group
if ($d->{'user'} ne $oldd->{'user'} ||
    $d->{'group'} ne $oldd->{'group'}) {
	&$first_print($text{'save_logrotateuser'});
	my $lconf = &get_logrotate_section($alog);
	if ($lconf) {
		&modify_user_logrotate($d, $oldd, $lconf);
		&$second_print($text{'setup_done'});
		}
	else {
		&$second_print($text{'setup_nologrotate2'});
		}
	}

&release_lock_logrotate($d);
}

# delete_logrotate(&domain)
# Remove logrotate section for this domain
sub delete_logrotate
{
my ($d) = @_;
&require_logrotate();
&$first_print($text{'delete_logrotate'});
&obtain_lock_logrotate($d);
my $lconf = &get_logrotate_section($d);
my $parent = &logrotate::get_config_parent();
if ($lconf) {
	# Check if all log files in the section are related to the domain
	my %logs = map { $_, 1 } &get_all_domain_logs($d, 1);
	my @leftover = grep { !$logs{$_} } @{$lconf->{'name'}};
	if (@leftover) {
		# Just remove some log files, but leave the block
		$lconf->{'name'} = \@leftover;
		&logrotate::save_directive($parent, $lconf, $lconf);
		&flush_file_lines($lconf->{'file'});
		}
	else {
		# Remove the whole logrotate block
		&logrotate::save_directive($parent, $lconf, undef);
		&flush_file_lines($lconf->{'file'});
		&clear_logrotate_caches();
		&logrotate::delete_if_empty($lconf->{'file'});
		}
	&$second_print($text{'setup_done'});
	}
else {
	&$second_print($text{'setup_nologrotate2'});
	}
delete($d->{'logrotate_shared'});
&release_lock_logrotate($d);
return 1;
}

# clear_logrotate_caches()
# Clear any in-memory caches of the logrotate config
sub clear_logrotate_caches
{
undef($logrotate::get_config_parent_cache);
undef(%logrotate::get_config_cache);
undef(%logrotate::get_config_lnum_cache);
undef(%logrotate::get_config_files_cache);
}

# clone_logrotate(&domain, &old-domain)
# Copy logrotate directives to a new domain
sub clone_logrotate
{
my ($d, $oldd) = @_;
&obtain_lock_logrotate($d);
&$first_print($text{'clone_logrotate'});
my $lconf = &get_logrotate_section($d);
my $olconf = &get_logrotate_section($oldd);
if (!$olconf) {
	&$second_print($text{'clone_logrotateold'});
	return 0;
	}
if (!$lconf) {
	&$second_print($text{'clone_logrotatenew'});
	return 0;
	}
&require_logrotate();

# Splice across the lines
my $lref = &read_file_lines($lconf->{'file'});
my $olref = &read_file_lines($olconf->{'file'});
my @lines = @$olref[$olconf->{'line'}+1 .. $olconf->{'eline'}-1];
splice(@$lref, $lconf->{'line'}+1,
       $lconf->{'eline'}-$lconf->{'line'}-1, @lines);
&flush_file_lines($lconf->{'file'});
&clear_logrotate_caches();

# Fix username if changed
if ($d->{'user'} ne $oldd->{'user'}) {
	my $lconf = &get_logrotate_section($d);
	&modify_user_logrotate($d, $oldd, $lconf);
	}

&release_lock_logrotate($d);
&$second_print($text{'setup_done'});
return 1;
}

# validate_logrotate(&domain)
# Returns an error message if a domain's logrotate section is not found
sub validate_logrotate
{
my ($d) = @_;
my $log = &get_website_log($d);
return &text('validate_elogfile', "<tt>$d->{'dom'}</tt>") if (!$log);
my @val = ( &get_website_log($d, 0), &get_website_log($d, 1) );
my $plog = &get_domain_php_error_log($d);
push(@val, $plog) if ($plog);
foreach my $v (@val) {
	my $lconf = &get_logrotate_section($v);
	return &text('validate_elogrotate', "<tt>$v</tt>") if (!$lconf);
	}
return undef;
}

# get_logrotate_section(&domain|log-file)
# Returns the Logrotate configuration block for some domain or log file
sub get_logrotate_section
{
my ($d) = @_;
&require_logrotate();
&require_apache();
my $alog = ref($d) ? &get_website_log($d, 0) : $d;
if (!$alog && ref($d)) {
	# Website may have been already deleted, so we don't know the log
	# file path! Try the template default.
	$alog = &get_apache_template_log($d, 0);
	}
my $elog;
if (ref($d)) {
	$elog = &get_website_log($d, 1) ||
		&get_apache_template_log($d, 1);
	}
my $conf = &logrotate::get_config();
my ($c, $n);
foreach $c (@$conf) {
	foreach $n (@{$c->{'name'}}) {
		return $c if ($n eq $alog);
		return $c if ($elog && $n eq $elog);
		}
	}
return undef;
}

# check_logrotate_clash()
# No need to check for clashes ..
sub check_logrotate_clash
{
return 0;
}

# backup_logrotate(&domain, file)
# Saves the log rotation section for this domain to a file
sub backup_logrotate
{
my ($d, $file) = @_;
&$first_print($text{'backup_logrotatecp'});
my $lconf = &get_logrotate_section($d);
if ($lconf) {
	my $lref = &read_file_lines($lconf->{'file'});
	&open_tempfile_as_domain_user($d, FILE, ">$file");
	foreach my $l (@$lref[$lconf->{'line'} .. $lconf->{'eline'}]) {
		&print_tempfile(FILE, "$l\n");
		}
	&close_tempfile_as_domain_user($d, FILE);
	&$second_print($text{'setup_done'});
	return 1;
	}
else {
	my $alog = &get_website_log($d, 0);
	&$second_print(&text('setup_nologrotate', $alog));
	return 0;
	}
}

# restore_logrotate(&domain, file, &options, &all-options, home-format,
#		    &olddomain)
sub restore_logrotate
{
&$first_print($text{'restore_logrotatecp'});
my $tmpl = &get_template($_[0]->{'template'});
if ($d->{'logrotate_shared'}) {
	&$second_print($text{'restore_logrotatecpshared'});
	return 1;
	}
&obtain_lock_logrotate($_[0]);
my $lconf = &get_logrotate_section($_[0]);
my $rv;
if ($lconf) {
	my $srclref = &read_file_lines($_[1]);
	my $dstlref = &read_file_lines($lconf->{'file'});
	splice(@$dstlref, $lconf->{'line'}+1,
	       $lconf->{'eline'}-$lconf->{'line'}-1,
	       @$srclref[1 .. @$srclref-2]);
	my @range = ($lconf->{'line'} .. $lconf->{'line'}+scalar(@$srclref)-1);
	if ($_[5]->{'home'} && $_[5]->{'home'} ne $_[0]->{'home'}) {
		# Fix up any references to old home dir
		foreach my $i (@range) {
			$dstlref->[$i] =~ s/(^|\s)$_[5]->{'home'}/$1$_[0]->{'home'}/g;
			}
		}

	# Replace the old postrotate block with the config from this system
	foreach my $i (@range) {
		if ($dstlref->[$i] =~ /^\s*postrotate/) {
			$dstlref->[$i+1] = "\t".&get_postrotate_script($_[0]);
			last;
			}
		}

	&flush_file_lines($lconf->{'file'});
	&clear_logrotate_caches();
	&$second_print($text{'setup_done'});
	$rv = 1;
	}
else {
	&$second_print($text{'setup_nologrotate2'});
	$rv = 0;
	}
&release_lock_logrotate($_[0]);
return $rv;
}

# sysinfo_logrotate()
# Returns the Logrotate version
sub sysinfo_logrotate
{
&require_logrotate();
$logrotate::logrotate_version ||= &logrotate::get_logrotate_version();
return ( [ $text{'sysinfo_logrotate'}, $logrotate::logrotate_version ] );
}

# check_logrotate_template([directives])
# Returns an error message if the default Logrotate directives don't look valid
sub check_logrotate_template
{
my ($d, $gotpostrotate);
my @dirs = split(/\t+/, $_[0]);
foreach $d (@dirs) {
	if ($d =~ /\s*postrotate/) {
		$gotpostrotate = 1;
		}
	}
$gotpostrotate || return $text{'lcheck_epost'};
return undef;
}

# show_template_logrotate(&tmpl)
# Outputs HTML for editing Logrotate related template options
sub show_template_logrotate
{
my ($tmpl) = @_;

# Use shared logrotate config
print &ui_table_row(
	&hlink($text{'tmpl_logrotate_shared'}, "template_logrotate_shared"),
	&ui_radio("logrotate_shared", $tmpl->{'logrotate_shared'},
	  [ $tmpl->{'default'} ? ( ) : ( [ "", $text{'tmpl_default'} ] ),
	    [ "no", $text{'tmpl_logrotate_shared0'} ],
	    [ "yes", $text{'tmpl_logrotate_shared1'} ] ]));

# Logrotate directives
print &ui_table_row(
	&hlink($text{'tmpl_logrotate'}, "template_logrotate"),
	&none_def_input("logrotate", $tmpl->{'logrotate'},
			$text{'tmpl_ftpbelow'}, 0, 0,
			$text{'tmpl_logrotatenone'},
			[ "logrotate" ])."<br>\n".
	&ui_textarea("logrotate",
		$tmpl->{'logrotate'} eq "none" ? undef :
		  join("\n", split(/\t/, $tmpl->{'logrotate'})),
		5, 60));

# Additional files to rotate
print &ui_table_row(
        &hlink($text{'tmpl_logrotate_files'}, "template_logrotatefiles"),
	&none_def_input("logrotate_files", $tmpl->{'logrotate_files'},
			$text{'tmpl_ftpbelow2'}, 0, 0,
                        $text{'tmpl_logrotatenone2'},
			[ "logrotate_files" ])."<br>\n".
	&ui_textarea("logrotate_files",
		     $tmpl->{'logrotate_files'} eq 'none' ? '' :
		       join("\n", split(/\t+/, $tmpl->{'logrotate_files'})),
		     5, 60));
}

# parse_template_logrotate(&tmpl)
# Updates Logrotate related template options from %in
sub parse_template_logrotate
{
my ($tmpl) = @_;

# Save logrotate settings
$tmpl->{'logrotate_shared'} = $in{'logrotate_shared'};
$tmpl->{'logrotate'} = &parse_none_def("logrotate");
if ($in{"logrotate_mode"} == 2) {
	my $err = &check_logrotate_template($in{'logrotate'});
	&error($err) if ($err);
	}

$tmpl->{'logrotate_files'} = &parse_none_def("logrotate_files");
}

# chained_logrotate(&domain, [&old-domain])
# Logrotate is automatically enabled when a website is, if set to always mode
# and if the website is just being turned on now.
sub chained_logrotate
{
my ($d, $oldd) = @_;
if ($config{'logrotate'} != 3) {
	# Not in auto mode, so don't touch
	return undef;
	}
elsif ($d->{'alias'} || $d->{'subdom'}) {
	# These types never have logs
	return 0;
	}
elsif (&domain_has_website($d)) {
	if (!$oldd || !&domain_has_website($oldd)) {
		# Turning on web, so turn on logrotate
		return 1;
		}
	else {
		# Don't do anything
		return undef;
		}
	}
else {
	# Always off when web is
	return 0;
	}
}

# can_chained_logrotate()
# Returns 'web' because the logrotate feature will be enabled if a website is
sub can_chained_logrotate
{
my $f = &domain_has_website();
return ($f);
}

# modify_user_logrotate(&domain, &old-domain, &logrotate-config)
# Change the user and group names in a logrotate config
sub modify_user_logrotate
{
my ($d, $oldd, $lconf) = @_;
my $create = &logrotate::find_value("create", $lconf->{'members'});
if ($create =~ /^(\d+)\s+(\S+)\s+(\S+)$/) {
	my ($p, $u, $g) = ($1, $2, $3);
	$u = $d->{'user'} if ($u eq $oldd->{'user'});
	$g = $d->{'group'} if ($g eq $oldd->{'group'});
	&logrotate::save_directive($lconf, "create",
		{ 'name' => 'create',
		  'value' => join(" ", $p, $u, $g) }, "\t");
	&flush_file_lines($lconf->{'file'});
	}
}

# Lock the logrotate config files
sub obtain_lock_logrotate
{
return if (!$config{'logrotate'});
&obtain_lock_anything();
if ($main::got_lock_logrotate == 0) {
	&require_logrotate();
	&lock_file($logrotate::config{'add_file'})
		if ($logrotate::config{'add_file'});
	&lock_file($logrotate::config{'logrotate_conf'});
	}
$main::got_lock_logrotate++;
}

# Unlock all logrotate config files
sub release_lock_logrotate
{
return if (!$config{'logrotate'});
if ($main::got_lock_logrotate == 1) {
	&require_logrotate();
	&unlock_file($logrotate::config{'add_file'})
		if ($logrotate::config{'add_file'});
	&unlock_file($logrotate::config{'logrotate_conf'});
	}
$main::got_lock_logrotate-- if ($main::got_lock_logrotate);
&release_lock_anything();
}

# get_postrotate_script(&domain)
# Returns the script (as a string) for running after rotation
sub get_postrotate_script
{
my ($d) = @_;
my $p = &domain_has_website($d);
return undef if (!$p);
my $script;
my $mode = &get_domain_php_mode($d);
my $fpmcmd = undef;
if ($mode eq "fpm" && $d->{'php_error_log'}) {
	# Also needs to restart the FPM server
	my $conf = &get_php_fpm_config($d);
	if ($conf && $conf->{'init'}) {
		$fpmcmd = "virtualmin restart-server --server fpm --domain $d->{'id'} ".
			  "--quiet --reload";
		}
	}
if ($p eq 'web') {
	# Get restart command from Apache
	my $apachectl = $apache::config{'apachectl_path'} ||
			   &has_command("apachectl") ||
			   &has_command("apache2ctl") ||
			   "apachectl";
	my $apply_cmd = $apache::config{'apply_cmd'};
	$apply_cmd = undef if ($apply_cmd eq 'restart');
	$script = $apache::config{'graceful_cmd'} ||
		  $apply_cmd ||
		  "$apachectl graceful";
	$script .= " ; $fpmcmd" if ($fpmcmd);
	$script .= " ; sleep 5";
	}
else {
	# Ask plugin
	$script = &plugin_call($p, "feature_restart_web_command", $d);
	$script .= " ; $fpmcmd" if ($fpmcmd);
	}
return $script;
}

# get_all_domain_logs(&domain, [include-template])
# Returns all logs that should be rotated for a domain
sub get_all_domain_logs
{
my ($d, $tmpl) = @_;
my $alog = &get_website_log($d, 0);
my $elog = &get_website_log($d, 1);
my @logs = ( $alog, $elog );
if ($d->{'ftp'}) {
	push(@logs, &get_proftpd_log($d));
	}
push(@logs, $d->{'php_error_log'} || &get_domain_php_error_log($d));
if ($tmpl) {
	push(@logs, &get_domain_template_logs($d));
	push(@logs, &get_apache_template_log($d, 0));
	push(@logs, &get_apache_template_log($d, 1));
	push(@logs, &get_default_php_error_log($d));
	}
return &unique(grep { $_ } @logs);
}

# get_domain_template_logs(&domain)
# Returns extra logs from a domain's template 
sub get_domain_template_logs
{
my ($d) = @_;
my $tmpl = &get_template($d->{'template'});
my @tmpllogs;
foreach my $lt (split(/\t+/, $tmpl->{'logrotate_files'})) {
	if ($lt && $lt ne "none") {
		push(@tmpllogs, &substitute_domain_template($lt, $d));
		}
	}
return @tmpllogs;
}

$done_feature_script{'logrotate'} = 1;

1;

