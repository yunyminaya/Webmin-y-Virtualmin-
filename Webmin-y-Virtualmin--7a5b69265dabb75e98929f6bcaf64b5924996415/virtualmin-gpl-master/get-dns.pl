#!/usr/local/bin/perl

=head1 get-dns.pl

Output all DNS records for a domain.

For virtual servers with DNS enabled, this command provides an easy way to
see what DNS records currently exist. The server is specified with the 
C<--domain> flag, followed by a domain name.

By default, output is in a human-readable table format. However, you can
choose to a more easily parsed and complete format with the C<--multiline>
flag, or get a list of just record names with the C<--name-only> option.

Normally the command will output all the DNS records in the domain's zone file,
except those used for DNSSEC, but you can request to show only the DNSSEC DS
records that should be created in the registrar's zone with the
C<--ds-records> flag. Or you can choose to have DNSSEC records included in
the output with C<--dnssec-records>.

By default the command will list all records, but you can limit it to
records with a specific name via the C<--name> flag. Similarly you can limit
by type (A, CNAME, MX, etc) with the C<--type> flag.

=cut

package virtual_server;
if (!$module_name) {
	$main::no_acl_check++;
	$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
	$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
	if ($0 =~ /^(.*)\/[^\/]+$/) {
		chdir($pwd = $1);
		}
	else {
		chop($pwd = `pwd`);
		}
	$0 = "$pwd/get-dns.pl";
	require './virtual-server-lib.pl';
	$< == 0 || die "get-dns.pl must be run as root";
	}

# Parse command line
&parse_common_cli_flags(\@ARGV);
while(@ARGV > 0) {
	local $a = shift(@ARGV);
	if ($a eq "--domain") {
		$dname = shift(@ARGV);
		}
	elsif ($a eq "--name") {
		$rname = shift(@ARGV);
		}
	elsif ($a eq "--regexp") {
		$regexp = shift(@ARGV);
		}
	elsif ($a eq "--type") {
		$rtype = shift(@ARGV);
		}
	elsif ($a eq "--ds-records") {
		$dsmode = 1;
		}
	elsif ($a eq "--dnssec-records") {
		$dnssecmode = 1;
		}
	elsif ($a eq "--cloud-nameservers") {
		$cloudns = 1;
		}
	else {
		&usage("Unknown parameter $a");
		}
	}

# Validate inputs and get the domain
$dname || &usage("Missing --domain parameter");
$d = &get_domain_by("dom", $dname);
$d || &usage("Virtual server $dname does not exist");
$d->{'dns'} || &usage("Virtual server $dname does not have DNS enabled");
$cloud = &get_domain_dns_cloud($d);

if ($cloudns) {
	$cloud || &usage("--cloud-nameservers can only be used for domains ".
			 "hosted on a cloud DNS provider");
	$cnsrecs = &get_domain_cloud_ns_records($d);
	ref($cnsrecs) || &usage($cnsrecs);
	@$cnsrecs || &usage("Cloud DNS provider $cloud->{'name'} does not ".
			    "supply any nameservers");
	@recs = @$cnsrecs;
	}
elsif ($dsmode) {
	$dsrecs = &get_domain_dnssec_ds_records($d);
	ref($dsrecs) || &usage($dsrecs);
	@recs = @$dsrecs;
	}
else {
	my ($recs, $file) = &get_domain_dns_records_and_file($d);
	$file || &usage("Failed to read DNS records : $recs");
	@recs = grep { $_->{'type'} } @$recs;
	}
if (!$dnssecmode) {
	@recs = grep { !&is_dnssec_record($_) } @recs;
	}
@recs = @{&filter_domain_dns_records($d, \@recs)};

# Filter by name and type if requested
if ($rname) {
	$rname .= ".".$d->{'dom'} if ($rname !~ /\Q$d->{'dom'}\E$/i);
	$rname .= "." if ($rname !~ /\.$/);
	@recs = grep { lc($_->{'name'}) eq lc($rname) } @recs;
	}
if ($regexp) {
	@recs = grep { $_->{'name'} =~ /$regexp/i } @recs;
	}
if ($rtype) {
	@recs = grep { lc($_->{'type'}) eq lc($rtype) } @recs;
	}

if ($nameonly) {
	# Only record names
	foreach $r (@recs) {
		print $r->{'name'},"\n";
		}
	}
elsif ($multiline) {
	# Full details
	foreach $r (@recs) {
		print $r->{'name'},"\n";
		print "    Type: $r->{'type'}\n";
		print "    Class: $r->{'class'}\n";
		if ($r->{'ttl'}) {
			print "    TTL: $r->{'ttl'}\n";
			}
		foreach $v (@{$r->{'values'}}) {
			print "    Value: $v\n";
			}
		if ($cloud && $cloud->{'proxy'}) {
			print "    Proxied: ",
			      ($r->{'proxied'} ? "Yes" : "No"),"\n";
			}
                if ($r->{'file'} && !$d->{'dns_cloud'} &&
		    !$d->{'provision_dns'}) {
                        print "    File: $r->{'file'}\n";
                        }  
		}
	}
else {
	# Table format
	$fmt = "%-30.30s %-5.5s %-40.40s\n";
	printf $fmt, "Record", "Type", "Value";
	printf $fmt, ("-" x 30), ("-" x 5), ("-" x 40);
	foreach $r (@recs) {
		$r->{'name'} =~ s/\.\Q$d->{'dom'}\E\.//i;
		$r->{'name'} ||= '@';
		printf $fmt, $r->{'name'}, $r->{'type'}, 
			     join(" ", @{$r->{'values'}});
		}
	}

sub usage
{
print "$_[0]\n\n" if ($_[0]);
print "Lists the DNS records in some domain.\n";
print "\n";
print "virtualmin get-dns --domain name\n";
print "                  [--ds-records]\n";
print "                  [--dnssec-records]\n";
print "                  [--multiline | --name-only]\n";
print "                  [--name record-name | --regexp name-pattern]\n";
print "                  [--type A|AAAA|CNAME|MX|NS|TXT]\n";
exit(1);
}

