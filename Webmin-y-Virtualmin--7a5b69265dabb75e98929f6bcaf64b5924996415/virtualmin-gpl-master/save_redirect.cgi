#!/usr/local/bin/perl
# Create, update or delete a website redirect

require './virtual-server-lib.pl';
&ReadParse();
&licence_status();
$d = &get_domain($in{'dom'});
&can_edit_domain($d) && &can_edit_redirect() ||
	&error($text{'redirects_ecannot'});
&has_web_redirects($d) || &error($text{'redirects_eweb'});
&error_setup($text{'redirect_err'});
&obtain_lock_web($d);
if (!$in{'new'}) {
	($r) = grep { $_->{'id'} eq $in{'old'} } &list_redirects($d);
	$r || &error($text{'redirect_egone'});
	$oldr = { %$r };
	}

if ($in{'delete'}) {
	# Just delete it
	$err = &delete_redirect($d, $r);
	&error($err) if ($err);
	}
else {
	# Validate inputs
	if ($in{'path'} =~ /^(http|https):\/\/([^\/]+)(\/\S*)$/) {
		# URL, check the domain and save the path
		lc($2) eq $d->{'dom'} ||
		   lc($2) eq "www.".$d->{'dom'} ||
		     &error(&text('redirect_epath2', $d->{'dom'}));
		$r->{'path'} = $3;
		}
	elsif ($in{'path'} =~ /^\/\S*$/ || $in{'path'} =~ /^\^\S*/) {
		# Just a path or a regexp
		$r->{'path'} = $in{'path'};
		}
	else {
		&error($text{'redirect_epath'});
		}
	if ($in{'mode'} == 0) {
		# Redirect to a URL on another host
		$in{'url'} =~ /^(http|https):\/\/\S+$/ ||
			&error($text{'redirect_eurl'});
		$r->{'dest'} = $in{'url'};
		$r->{'alias'} = 0;
		}
	elsif ($in{'mode'} == 3) {
		# Redirect to a URL path on this host
		$in{'urlpath'} =~ /^\/\S*$/ ||
			&error($text{'redirect_eurlpath'});
		$r->{'dest'} = $in{'urlpath'};
		$r->{'alias'} = 0;
		if ($in{'path'} eq '/' && $in{'regexp'} != 2 &&
		    $in{'http'} && $in{'https'}) {
			&error($text{'redirect_eurlpath2'});
			}
		}
	elsif ($in{'mode'} == 2) {
		# Redirect to a URL on this host
		$in{'dpath'} =~ /^\/\S*$/ || &error($text{'redirect_eurl'});
		$r->{'dest'} = $in{'dproto'}.'://%{HTTP_HOST}'.$in{'dpath'};
		$r->{'alias'} = 0;
		}
	else {
		# Alias to a directory
		$in{'dir'} =~ /^\/\S+$/ ||
			&error($text{'redirect_edir'});
		$actualdir = $in{'dir'};
		if ($actualdir =~ s/\$.*$//) {
			# If path contains $1, reduce to parent dir
			$actualdir =~ s/\/[^\/]*$//;
			}
		!$actualdir || -d $actualdir ||
			&error(&text('redirect_edir3', $actualdir));
		if ($in{'new'} || $r->{'dest'} ne $in{'dir'}) {
			$rroot = &get_redirect_root($d);
			&is_under_directory($rroot, $in{'dir'}) ||
				&error(&text('redirect_edir2', $rroot));
			}
		$r->{'dest'} = $in{'dir'};
		$r->{'alias'} = 1;
		}
	if ($in{'mode'} == 0 || $in{'mode'} == 2) {
		# Save redirect code
		$r->{'code'} = $in{'code'};
		$in{'code'} eq '' || $in{'code'} =~ /^\d{3}$/ &&
		    $in{'code'} >= 300 && $in{'code'} < 400 ||
			&error($text{'redirect_ecode'});
		}
	$r->{'regexp'} = $in{'regexp'} == 1 ? 1 : 0;
	$r->{'exact'} = $in{'regexp'} == 2 ? 1 : 0;
	$r->{'http'} = $in{'http'};
	$r->{'https'} = $in{'https'};
	if (&has_web_host_redirects($d)) {
		if ($in{'host_def'}) {
			delete($r->{'host'});
			}
		else {
			if ($in{'hostregexp'}) {
				$in{'host'} =~ /^\S+$/ ||
					&error($text{'redirect_ehost2'});
				}
			else {
				$in{'host'} =~ /^[a-z0-9\.\_\-]+$/i ||
					&error($text{'redirect_ehost'});
				}
			$r->{'host'} = $in{'host'};
			$r->{'hostregexp'} = $in{'hostregexp'};
			}
		}
	$r = &add_wellknown_redirect($r);

	# Create or update
	if ($in{'new'}) {
		$err = &create_redirect($d, $r);
		}
	else {
		$err = &modify_redirect($d, $r, $oldr);
		}
	&error($err) if ($err);
	}

# Restart Apache and log
&release_lock_web($d);
&set_all_null_print();
&run_post_actions();
&webmin_log($in{'new'} ? 'create' : $in{'delete'} ? 'delete' : 'modify',
	    "redirect", $r->{'path'}, { 'dom' => $d->{'dom'} });

&redirect("list_redirects.cgi?dom=$in{'dom'}");

