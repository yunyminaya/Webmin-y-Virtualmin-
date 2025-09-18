#!/usr/local/bin/perl
# Migrate some virtual server backup file

require './virtual-server-lib.pl';
$can = &can_migrate_servers();
$can || &error($text{'migrate_ecannot'});
&error_setup($text{'migrate_err'});
&ReadParseMime();
&require_migration();

# Parse source file input
$src = &parse_backup_destination("src", \%in, $can > 1, undef, undef);
($mode) = &parse_backup_url($src);
if ($mode == 0) {
	-r $src || &error($text{'migrate_efile'});
	}

if ($can < 3) {
	if (!$in{'user_def'}) {
		$in{'user'} =~ /^[a-z0-9\.\-\_]+$/i ||
			&error($text{'migrate_euser'});
		$user = $in{'user'};
		defined(getpwnam($in{'user'})) &&
			&error($text{'migrate_euserclash'});
		}
	if (!$in{'pass_def'}) {
		$pass = $in{'pass'};
		}
	}
$tmpl = &get_template($in{'template'});
&can_use_template($tmpl) || &error($text{'setup_etmpl'});
$plan = &get_plan($in{'plan'});
&can_use_plan($plan) || &error($text{'setup_eplan'});
if ($can < 3) {
	# Parent can be chosen
	if (!$in{'parent_def'}) {
		$parent = &get_domain_by("user", $in{'parent'}, "parent", "");
		&can_config_domain($parent) || &error($text{'edit_ecannot'});
		}
	}
else {
	# This user's master domain
	$parent = &get_domain_by_user($base_remote_user);
	$parent && &can_edit_domain($parent) || &error($text{'edit_ecannot'});
	}
if ($parent && !$tmpl->{'for_sub'}) {
	&error($text{'migrate_etmplsub'});
	}
elsif (!$parent && !$tmpl->{'for_parent'}) {
	&error($text{'migrate_etmplparent'});
	}
$ipinfo = { };
($ipinfo->{'ip'}, $ipinfo->{'virt'}, $ipinfo->{'virtalready'}, $ipinfo->{'netmask'}) =
	&parse_virtual_ip($tmpl, $parent ? $parent->{'reseller'} :
				 &reseller_admin() ? $base_remote_user : undef);
if (&supports_ip6()) {
	($ipinfo->{'ip6'}, $ipinfo->{'virt6'}, $ipinfo->{'virt6already'},
	 $ipinfo->{'netmask6'}) =
		&parse_virtual_ip6($tmpl, $parent ? $parent->{'reseller'} :
					 &reseller_admin() ? $base_remote_user : undef);
	}
if (!$in{'prefix_def'}) {
	$in{'prefix'} =~ /^[a-z0-9\.\-]+$/i ||
		&error($text{'setup_eprefix'});
	$prefix = $in{'prefix'};
	}
$in{'email_def'} || $in{'email'} =~ /\S/ || &error($text{'setup_eemail'});

my @footer_action = &vui_footer_history_back();

&ui_print_unbuffered_header(undef, $text{'migrate_title'}, "");
# Download the file
$oldsrc = $src;
$nice = &nice_backup_url($oldsrc);
if ($mode == 5) {
	# Uploaded data .. save to temp file
	&$first_print(&text('migrate_uploading', $in{'src_file'}));
	$src = &transname();
	&open_tempfile(SRC, ">$src", 0, 1);
	&print_tempfile(SRC, $in{'src_upload'});
	&close_tempfile(SRC);
	@st = stat($src);
	&$second_print(&text('migrate_uploaded', &nice_size($st[7])));
	}
elsif ($mode > 0) {
	# Fetch from some server
	&$first_print(&text('migrate_downloading', $nice));
	$temp = &transname();
	$err = &download_backup($src, $temp);
	if ($err) {
		&$second_print(&text('migrate_edownload', $err));
		goto DONE;
		}
	$src = $temp;
	@st = stat($src);
	&$second_print(&text('migrate_downloaded', &nice_size($st[7])));
	}

# Validate the file
&$first_print($text{'migrate_validating'});
$vfunc = "migration_$in{'type'}_validate";
($err, $domain, $user, $pass) =
	&$vfunc($src, undef, $user, $parent, $prefix, $pass);
if ($err) {
	&$second_print(&text('migrate_evalidate', $err));
	goto DONE;
	}
elsif (&domain_name_clash($domain)) {
	&$second_print($text{'migrate_eclash'});
	goto DONE;
	}

@footer_action = ("", $text{'index_return'});
&$second_print($text{'setup_done'});

# Call the migration function
&lock_domain_name($domain);
&$first_print(&text('migrate_doing1', "<tt>$domain</tt>", $nice));
&$indent_print();
$mfunc = "migration_$in{'type'}_migrate";
@doms = &$mfunc($src, $domain, $user, $in{'webmin'}, $in{'template'},
		$ipinfo, $pass, $parent, $prefix,
		$in{'email_def'} ? undef : $in{'email'}, $plan);
&unlock_domain_name($domain);
&run_post_actions();
&$outdent_print();

# Fix htaccess files
foreach my $d (@doms) {
	&fix_script_htaccess_files($d, &public_html_dir($d));
	}

# Detect migrated scripts
foreach my $d (@doms) {
	foreach my $sinfo (&detect_installed_scripts($d)) {
		&add_domain_script($d, $sinfo->{'name'}, $sinfo->{'version'},
				   $sinfo->{'opts'}, $sinfo->{'desc'},
				   $sinfo->{'url'}, $sinfo->{'user'},
				   $sinfo->{'pass'});
		}
	}

# If this user is a reseller, grant any new domains to him
if (&reseller_admin()) {
	foreach my $d (@doms) {
		$d->{'reseller'} = $base_remote_user;
		&save_domain($d);
		}
	}

if (@doms) {
	$d = $doms[0];
	&$second_print(&text('migrate_ok', "edit_domain.cgi?dom=$d->{'id'}",
	                                   "<tt>".&html_escape($in->{'dom'} || $d->{'dom'})."</tt>"));

	# Call any theme post command
	if (defined(&theme_post_save_domain)) {
		&theme_post_save_domain($d, 'create');
		}
	}
else {
	@footer_action = &vui_footer_history_back();
	&$second_print(&text('migrate_failed'));
	}

DONE:
&ui_print_footer(@footer_action);

