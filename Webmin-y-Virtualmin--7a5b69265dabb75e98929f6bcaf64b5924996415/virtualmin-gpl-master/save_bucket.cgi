#!/usr/local/bin/perl
# Create, update or delete an S3 bucket

require './virtual-server-lib.pl';
&ReadParse();
&licence_status();
&can_backup_buckets() || &error($text{'buckets_ecannot'});

# Get the account
@accounts = &list_all_s3_accounts();
($account) = grep { $_->[0] eq $in{'account'} } @accounts;
$account || &error($text{'bucket_eagone'});

# Get the bucket(s)
$buckets = &s3_list_buckets($account->[0], $account->[1]);
ref($buckets) || &error(&text('bucket_elist', $buckets));
if (!$in{'new'}) {
	($bucket) = grep { $_->{'Name'} eq $in{'name'} } @$buckets;
	$bucket || &error($text{'bucket_egone'});
	}

if ($in{'delete'}) {
	# Just delete it
	&error_setup($text{'bucket_derr'});
	if ($in{'confirm'}) {
		# Just do it
		$err = &s3_delete_bucket(
			$account->[0], $account->[1], $in{'name'}, 0);
		&error($err) if ($err);
		&webmin_log("delete", "bucket", $in{'name'});
		&redirect("list_buckets.cgi");
		}
	else {
		# Ask first
		&ui_print_header(undef, $text{'bucket_title3'}, "");

		# Get size of all files
		$files = &s3_list_files($account->[0], $account->[1], $in{'name'});
		ref($files) || &error($files);
		$size = 0;
		foreach my $f (@$files) {
			$size += $f->{'Size'};
			}

		# Show confirm form
		$ttname = "<tt>".&html_escape($in{'name'})."</tt>";
		print &ui_confirmation_form(
			"save_bucket.cgi",
			@$files ? &text('bucket_drusure', $ttname,
					scalar(@$files), &nice_size($size))
				: &text('bucket_drusure2', $ttname),
			[ [ "account", $in{'account'} ],
			  [ "name", $in{'name'} ],
			  [ "delete", 1 ] ],
			[ [ "confirm", $text{'bucket_dok'} ] ],
			);

		&ui_print_footer("list_buckets.cgi", $text{'buckets_return'});
		}
	}
else {
	&error_setup($text{'bucket_err'});

	# Get current bucket ACL
	$acl = { 'Grants' => [ ] };
	if (!$in{'new'}) {
		$oldinfo = &s3_get_bucket($account->[0], $account->[1], $in{'name'});
		ref($oldinfo) || &error(&text('bucket_einfo', $oldinfo));
		$oldacl = $oldinfo->{'acl'};
		foreach my $g (@{$oldacl->{'Grants'}}) {
			$grantee = $g->{'Grantee'};
			if ($grantee->{'Type'} eq 'CanonicalUser') {
				$useridmap{$grantee->{'DisplayName'}} =
					$grantee->{'ID'};
				}
			}
		$acl->{'Owner'} = $oldacl->{'Owner'};
		}

	# Validate and parse permissions
	for(my $i=0; defined($in{"type_$i"}); $i++) {
		next if (!$in{"type_$i"});
		$in{"grantee_$i"} =~ /^\S+$/ ||
			&error(&text('bucket_egrantee', $i+1));
		$obj = { 'Permission' => $in{"perm_$i"},
			 'Grantee' => { },
		       };
		if ($in{"type_$i"} eq "CanonicalUser") {
			# Granting to a user
			if ($useridmap{$in{"grantee_$i"}}) {
				# We have the ID already
				$obj->{'Grantee'}->{'Type'} =
					'CanonicalUser';
				$obj->{'Grantee'}->{'ID'} = 
					$useridmap{$in{"grantee_$i"}};
				$obj->{'Grantee'}->{'DisplayName'} = 
					$in{"grantee_$i"};
				}
			else {
				# Grant by email
				$obj->{'Grantee'}->{'Type'} =
					'AmazonCustomerByEmail';
				$obj->{'Grantee'}->{'EmailAddress'} = 
					$in{"grantee_$i"};
				}
			}
		else {
			# Granting to a group
			$obj->{'Grantee'}->{'Type'} = 'Group';
			$uri = $in{"grantee_$i"};
			if ($uri !~ /^(http|https):/) {
				$uri = $s3_groups_uri.$uri;
				}
			$obj->{'Grantee'}->{'URI'} = $uri;
			}
		push(@{$acl->{'Grants'}}, $obj);
		}
	$in{'new'} || @{$acl->{'Grants'}} || &error($text{'bucket_enogrants'});

	# Validate expiry policy
	$lifecycle = { 'Rules' => [ ] };
	if (!$in{'new'}) {
		@oldrules = @{$oldinfo->{'lifecycle'}->{'Rules'}};
		}
	for(my $i=0; defined($in{"lprefix_def_$i"}); $i++) {
		next if ($in{"lprefix_def_$i"} == 2);
		$obj = { };
		if ($in{'new'} || $i >= @oldrules) {
			# Generate a new ID
			$obj->{'ID'} = &domain_id();
			}
		else {
			# Use old ID for this row
			$obj->{'ID'} = $oldrules[$i]->{'ID'};
			}
		if (!$in{"lprefix_${i}_def"}) {
			$obj->{'Filter'}->{'Prefix'} = $in{"lprefix_$i"};
			}
		$obj->{'Status'} = $in{"lstatus_$i"} ? "Enabled" : "Disabled";
		if ($trans = &days_date_parse("lglacier_$i", $obj)) {
			$trans->{'StorageClass'} = $in{"class_$i"};
			$obj->{'Transitions'} = [ $trans ];
			}
		if ($exp = &days_date_parse("ldelete_$i", $obj)) {
			$obj->{'Expiration'} = $exp;
			}
		push(@{$lifecycle->{'Rules'}}, $obj);
		}

	# Validate logging settings
	my $logging;
	if (!$in{'logging_def'}) {
		$logging = $oldinfo ? $oldinfo->{'logging'} : undef;
		$logging ||= { 'TargetObjectKeyFormat' => {
					'SimplePrefix' => { }
				}
			     };
		$in{'ltarget'} =~ /^[a-z0-9\-\_\-]+$/i ||
                        &error($text{'bucket_eltarget'});
		$in{'lprefix'} =~ /^\S+$/i ||
                        &error($text{'bucket_elprefix'});
		$logging->{'TargetBucket'} = $in{'ltarget'};
		$logging->{'TargetPrefix'} = $in{'lprefix'};
		}

	if ($in{'new'}) {
		# Validate inputs
		$in{'name'} =~ /^[a-z0-9\-\_\-]+$/i ||
			&error($text{'bucket_ename'});
		($clash) = grep { $_->{'Name'} eq $in{'name'} } @$buckets;
		$clash && &error($text{'bucket_eeclash'});

		# Create the bucket
		$err = &init_s3_bucket($account->[0], $account->[1],
				       $in{'name'}, 1, $in{'location'});
		&error($err) if ($err);
		}

	# Apply permisisons
	if ($in{'new'}) {
		$oldinfo = &s3_get_bucket(
			$account->[0], $account->[1], $in{'name'});
		$oldacl = $oldinfo->{'acl'};
		$acl->{'Owner'} = $oldacl->{'Owner'};
		if (@{$acl->{'Grants'}}) {
			$err = &s3_put_bucket_acl(
			    $account->[0], $account->[1], $in{'name'}, $acl);
			}
		}
	else {
		$err = &s3_put_bucket_acl(
			$account->[0], $account->[1], $in{'name'}, $acl);
		}
	if ($err) {
		&error($err." ".$text{'bucket_eacls'});
		}

	# Apply expiry policy
	$err = &s3_put_bucket_lifecycle($account->[0], $account->[1],
					$in{'name'}, $lifecycle);
	&error($err) if ($err);

	# Apply logging
	$err = &s3_put_bucket_logging($account->[0], $account->[1],
					$in{'name'}, $logging);
	&error($err) if ($err);

	&webmin_log($in{'new'} ? "create" : "modify", "bucket", $in{'name'});
	&redirect("list_buckets.cgi");
	}

sub days_date_parse
{
my ($name, $obj, $section) = @_;
my $rv;
if ($in{$name} == 1) {
	# Parse days field
	$in{$name."_days"} =~ /^\d+$/ || &error(&text('bucket_eldays', $i+1));
	$rv->{'Days'} = int($in{$name."_days"});
	}
elsif ($in{$name} == 2) {
	# Parse date field
	$in{$name."_year"} =~ /^[0-9]{4}$/ ||
		&error(&text('bucket_elyear', $i+1));
	$in{$name."_month"} =~ /^[0-9]{1,2}$/ ||
		&error(&text('bucket_elmonth', $i+1));
	$in{$name."_day"} =~ /^[0-9]{1,2}$/ ||
		&error(&text('bucket_elday', $i+1));
	$rv->{'Date'} = sprintf("%4.4d-%2.2d-%2.2dT00:00:00.000Z",
				$in{$name."_year"},
				$in{$name."_month"},
				$in{$name."_day"});
	}
return $rv;
}
