#!/usr/bin/perl

use strict;
use warnings;

our (%in, %text, $module_config_directory, $config_directory);
our $OPENVM_DNS_VIRTUALMIN_LOADED = 0;

###############################################################################
# Existing helper functions (preserved from original)
###############################################################################

sub ovmd_text
{
my ($key, $fallback) = @_;
return exists($text{$key}) && defined($text{$key}) && $text{$key} ne ''
	? $text{$key}
	: $fallback;
}

sub ovmd_module_config
{
my %config = (
	'feature_dns_clouds' => 1,
	'feature_remote_dns' => 1,
	'show_provider_links' => 1,
	'max_domain_links' => 100,
	);
my $config_file = $module_config_directory ? "$module_config_directory/config" : undef;
if ($config_file && -r $config_file) {
	open(my $fh, '<', $config_file) || die "Failed to read $config_file : $!";
	while(my $line = <$fh>) {
		chomp($line);
		next if ($line =~ /^\s*#/ || $line !~ /=/);
		my ($key, $value) = split(/=/, $line, 2);
		next if (!defined($key) || $key eq '');
		$config{$key} = $value;
		}
	close($fh);
	}
return \%config;
}

sub ovmd_load_virtualmin
{
return 1 if ($OPENVM_DNS_VIRTUALMIN_LOADED);
if (defined(&foreign_require)) {
	&foreign_require("virtual-server", "virtual-server-lib.pl");
	}
$OPENVM_DNS_VIRTUALMIN_LOADED = 1;
return 1;
}

sub ovmd_require_access
{
ovmd_load_virtualmin();
return 1 if (defined(&master_admin) && &master_admin());
return 1 if (defined(&can_cloud_providers) && &can_cloud_providers());
return 1 if (defined(&can_edit_templates) && &can_edit_templates());
&error(ovmd_text('dnsclouds_ecannot', 'You cannot manage DNS cloud settings'));
}

sub ovmd_dns_clouds
{
ovmd_load_virtualmin();
my @doms = defined(&list_domains) ? &list_domains() : ();
my @clouds = defined(&list_dns_clouds) ? &list_dns_clouds() : ();
my @result;

foreach my $cloud (@clouds) {
	my $state_func = "dnscloud_".$cloud->{'name'}."_get_state";
	my $state = defined(&$state_func) ? &$state_func($cloud) : { 'ok' => 0, 'desc' => 'Unavailable' };
	my @users = grep { defined(&dns_uses_cloud) ? &dns_uses_cloud($_, $cloud) : 0 } @doms;
	push(@result, {
		'name' => $cloud->{'name'},
		'desc' => $cloud->{'desc'},
		'url' => $cloud->{'url'},
		'state_ok' => $state->{'ok'} ? 1 : 0,
		'state_desc' => $state->{'desc'} || '',
		'users' => [ map { $_->{'dom'} } @users ],
		'user_count' => scalar(@users),
		});
	}

return \@result;
}

sub ovmd_remote_dns
{
ovmd_load_virtualmin();
return [] if (!defined(&list_remote_dns));
my @remote = &list_remote_dns();
my @doms = defined(&list_domains) ? &list_domains() : ();
my @result;

foreach my $r (@remote) {
	my @uses = grep { $_->{'dns_remote'} && $_->{'dns_remote'} eq $r->{'host'} } @doms;
	push(@result, {
		'host' => $r->{'host'},
		'type' => $r->{'slave'} ? 'Slave' : 'Master',
		'domains' => [ map { $_->{'dom'} } @uses ],
		'domain_count' => scalar(@uses),
		});
	}

return \@result;
}

###############################################################################
# NEW ovmns_* functions - Enhanced DNS management
###############################################################################

# ovmns_init() - Module initialization
sub ovmns_init
{
ovmd_load_virtualmin();
my $config = ovmd_module_config();
return {
	'version' => '1.0.0',
	'config' => $config,
	'bind_available' => ovmns_check_bind(),
	'dig_available' => ovmns_check_dig(),
	'opendkim_available' => ovmns_check_opendkim(),
	'dnssec_tools' => ovmns_check_dnssec_tools(),
	};
}

# ovmns_check_bind() - Check if BIND/named is available
sub ovmns_check_bind
{
my $found = 0;
$found = 1 if (-x '/usr/sbin/named');
$found = 1 if (-x '/usr/local/sbin/named');
if (!$found && defined(&foreign_check)) {
	$found = 1 if (&foreign_check("bind8") || &foreign_check("bind9"));
	}
return $found;
}

# ovmns_check_dig() - Check if dig command is available
sub ovmns_check_dig
{
my $out = `which dig 2>/dev/null`;
chomp($out);
return (-x $out) ? 1 : 0;
}

# ovmns_check_opendkim() - Check if OpenDKIM tools are available
sub ovmns_check_opendkim
{
my $found = 0;
$found = 1 if (-x '/usr/sbin/opendkim-genkey');
$found = 1 if (-x '/usr/bin/opendkim-genkey');
$found = 1 if (-x '/usr/local/sbin/opendkim-genkey');
return $found;
}

# ovmns_check_dnssec_tools() - Check if DNSSEC tools are available
sub ovmns_check_dnssec_tools
{
my $tools = {
	'dnssec-keygen' => 0,
	'dnssec-signzone' => 0,
	'dnssec-dsfromkey' => 0,
	};
foreach my $tool (keys %$tools) {
	my $path = `which $tool 2>/dev/null`;
	chomp($path);
	$tools->{$tool} = (-x $path) ? 1 : 0;
	}
return $tools;
}

# ovmns_get_zone_file($domain) - Get zone file path for a domain
sub ovmns_get_zone_file
{
my ($domain) = @_;
return undef unless ($domain && $domain =~ /\./);

# Try Virtualmin API first
if (defined(&get_domain)) {
	my $d = &get_domain($domain);
	if ($d && $d->{'dns_domain'}) {
		# Try to get zone file from BIND module
		if (defined(&foreign_require)) {
			&foreign_require("bind8", "bind8-lib.pl");
			if (defined(&get_zone_file)) {
				my $zone = &get_zone_file($d->{'dns_domain'}, $d->{'dns_master'});
				return $zone if ($zone);
				}
			}
		}
	}

# Common zone file locations
my @paths = (
	"/var/named/$domain.hosts",
	"/var/named/data/$domain.hosts",
	"/etc/bind/db.$domain",
	"/var/lib/named/$domain.zone",
	"/var/lib/named/master/$domain.zone",
	"/var/named/$domain.zone",
	);
foreach my $p (@paths) {
	return $p if (-r $p);
	}
return undef;
}

# ovmns_list_domains_with_dns() - List all domains with DNS zones
sub ovmns_list_domains_with_dns
{
ovmd_load_virtualmin();
my @domains;

if (defined(&list_domains)) {
	my @doms = &list_domains();
	foreach my $d (@doms) {
		next unless ($d->{'dns_domain'});
		my $dom = $d->{'dom'};
		my $spf = ovmns_get_spf($dom);
		my $dkim = ovmns_check_dkim($dom);
		my $dmarc = ovmns_get_dmarc($dom);
		my $dnssec = ovmns_check_dnssec($dom);
		push(@domains, {
			'domain' => $dom,
			'dns_domain' => $d->{'dns_domain'},
			'dns_master' => $d->{'dns_master'},
			'dns_slave' => $d->{'dns_slave'},
			'spf_status' => $spf ? 'ok' : 'missing',
			'spf_record' => $spf,
			'dkim_status' => $dkim->{'status'},
			'dkim_selector' => $dkim->{'selector'},
			'dmarc_status' => $dmarc ? 'ok' : 'missing',
			'dmarc_record' => $dmarc,
			'dnssec_status' => $dnssec->{'status'},
			'records_count' => scalar(ovmns_list_records($dom)),
			});
		}
	}
return @domains;
}

# ovmns_list_records($domain) - List DNS records for a domain
sub ovmns_list_records
{
my ($domain) = @_;
return () unless ($domain && $domain =~ /\./);

my @records;

# Try Virtualmin/BIND API first
if (defined(&foreign_require)) {
	&foreign_require("bind8", "bind8-lib.pl");
	if (defined(&get_zone_records)) {
		my @recs = &get_zone_records($domain);
		foreach my $r (@recs) {
			push(@records, {
				'type' => $r->{'type'} || 'A',
				'name' => $r->{'name'} || $domain,
				'value' => $r->{'values'} || $r->{'value'} || '',
				'ttl' => $r->{'ttl'} || 86400,
				});
			}
		return @records if (@records);
		}
	}

# Fallback: parse zone file
my $zone_file = ovmns_get_zone_file($domain);
if ($zone_file && -r $zone_file) {
	open(my $fh, '<', $zone_file) || return @records;
	while (my $line = <$fh>) {
		chomp($line);
		$line =~ s/;.*$//;  # Remove comments
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		next if ($line eq '' || $line =~ /^\$/);

		# Parse: name TTL class type value
		my @parts = split(/\s+/, $line);
		next if (scalar(@parts) < 4);

		my $name = shift(@parts);
		my $ttl = ($parts[0] =~ /^\d+$/) ? shift(@parts) : 86400;
		my $class = ($parts[0] =~ /^(IN|CH|HS)$/i) ? shift(@parts) : 'IN';
		my $type = shift(@parts) || 'A';
		my $value = join(' ', @parts);

		$name = $domain if ($name eq '@');
		$name =~ s/\.$//;
		$value =~ s/\.$// if ($value !~ /".*"$/);

		push(@records, {
			'type' => uc($type),
			'name' => $name,
			'value' => $value,
			'ttl' => $ttl,
			});
		}
	close($fh);
	}

# Fallback: use dig
if (!@records && ovmns_check_dig()) {
	my @types = ('A', 'AAAA', 'MX', 'NS', 'TXT', 'CNAME', 'SRV', 'CAA', 'SOA');
	foreach my $type (@types) {
		my $cmd = "dig +short $domain $type 2>/dev/null";
		my $out = `$cmd`;
		foreach my $line (split(/\n/, $out)) {
			chomp($line);
			next if ($line eq '');
			push(@records, {
				'type' => $type,
				'name' => $domain,
				'value' => $line,
				'ttl' => 86400,
				});
			}
		}
	}

return @records;
}

# ovmns_add_record($domain, $type, $name, $value, $ttl) - Add a DNS record
sub ovmns_add_record
{
my ($domain, $type, $name, $value, $ttl) = @_;
return { 'ok' => 0, 'error' => 'Domain is required' } unless ($domain);
return { 'ok' => 0, 'error' => 'Record type is required' } unless ($type);
return { 'ok' => 0, 'error' => 'Record value is required' } unless (defined($value));

$ttl ||= 86400;
$type = uc($type);
$name ||= $domain;
$name = $domain if ($name eq '@');

# Validate record format
my $validation = ovmns_validate_record($type, $value);
return $validation unless ($validation->{'ok'});

# Try Virtualmin API first
if (defined(&foreign_require)) {
	&foreign_require("bind8", "bind8-lib.pl");
	if (defined(&create_zone_record)) {
		my $rv = &create_zone_record($domain, $name, $type, $value, $ttl);
		if ($rv) {
			ovmns_reload_bind();
			return { 'ok' => 1, 'message' => 'Record added successfully' };
			}
		}
	}

# Fallback: edit zone file directly
my $zone_file = ovmns_get_zone_file($domain);
if ($zone_file && -w $zone_file) {
	my $record_line = "$name $ttl IN $type $value\n";
	open(my $fh, '>>', $zone_file) || return { 'ok' => 0, 'error' => "Cannot write zone file: $!" };
	print $fh $record_line;
	close($fh);
	ovmns_reload_bind();
	return { 'ok' => 1, 'message' => 'Record added to zone file' };
	}

return { 'ok' => 0, 'error' => 'No method available to add DNS record' };
}

# ovmns_delete_record($domain, $type, $name) - Delete a DNS record
sub ovmns_delete_record
{
my ($domain, $type, $name) = @_;
return { 'ok' => 0, 'error' => 'Domain is required' } unless ($domain);
return { 'ok' => 0, 'error' => 'Record type is required' } unless ($type);

$type = uc($type);
$name ||= $domain;
$name = $domain if ($name eq '@');

# Try Virtualmin API first
if (defined(&foreign_require)) {
	&foreign_require("bind8", "bind8-lib.pl");
	if (defined(&delete_zone_record)) {
		my $rv = &delete_zone_record($domain, $name, $type);
		if ($rv) {
			ovmns_reload_bind();
			return { 'ok' => 1, 'message' => 'Record deleted successfully' };
			}
		}
	}

# Fallback: edit zone file directly
my $zone_file = ovmns_get_zone_file($domain);
if ($zone_file && -w $zone_file) {
	my @lines;
	open(my $fh, '<', $zone_file) || return { 'ok' => 0, 'error' => "Cannot read zone file: $!" };
	while (my $line = <$fh>) {
		chomp($line);
		my $orig = $line;
		$line =~ s/;.*$//;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		if ($line ne '') {
			my @parts = split(/\s+/, $line);
			next if ($line =~ /^\$/);
			my $rname = shift(@parts) || '';
			my $ttl = (@parts && $parts[0] =~ /^\d+$/) ? shift(@parts) : undef;
			my $class = (@parts && $parts[0] =~ /^(IN|CH|HS)$/i) ? shift(@parts) : undef;
			my $rtype = shift(@parts) || '';
			$rname =~ s/\.$//;
			$rname = $domain if ($rname eq '@' || $rname eq '');
			if (uc($rtype) eq $type && ($rname eq $name || $rname eq "$name.$domain")) {
				next;  # Skip this record (delete it)
				}
			}
		push(@lines, $orig."\n");
		}
	close($fh);
	open(my $wfh, '>', $zone_file) || return { 'ok' => 0, 'error' => "Cannot write zone file: $!" };
	print $wfh @lines;
	close($wfh);
	ovmns_reload_bind();
	return { 'ok' => 1, 'message' => 'Record deleted from zone file' };
	}

return { 'ok' => 0, 'error' => 'No method available to delete DNS record' };
}

# ovmns_edit_record($domain, $type, $old_name, $new_name, $new_value, $new_ttl)
sub ovmns_edit_record
{
my ($domain, $type, $old_name, $new_name, $new_value, $new_ttl) = @_;
return { 'ok' => 0, 'error' => 'Domain is required' } unless ($domain);
return { 'ok' => 0, 'error' => 'Record type is required' } unless ($type);

$type = uc($type);
$new_name ||= $old_name;
$new_ttl ||= 86400;

# Validate new value
my $validation = ovmns_validate_record($type, $new_value);
return $validation unless ($validation->{'ok'});

# Delete old record, add new one
my $del = ovmns_delete_record($domain, $type, $old_name);
if ($del->{'ok'}) {
	my $add = ovmns_add_record($domain, $type, $new_name, $new_value, $new_ttl);
	return $add;
	}

return $del;
}

# ovmns_get_spf($domain) - Get SPF record for a domain
sub ovmns_get_spf
{
my ($domain) = @_;
return undef unless ($domain && $domain =~ /\./);

if (ovmns_check_dig()) {
	my $cmd = "dig +short TXT $domain 2>/dev/null";
	my $out = `$cmd`;
	foreach my $line (split(/\n/, $out)) {
		chomp($line);
		$line =~ s/^"//;
		$line =~ s/"$//;
		return $line if ($line =~ /^v=spf1/);
		}
	}
return undef;
}

# ovmns_set_spf($domain, $spf_text) - Set SPF record for a domain
sub ovmns_set_spf
{
my ($domain, $spf_text) = @_;
return { 'ok' => 0, 'error' => 'Domain is required' } unless ($domain);
return { 'ok' => 0, 'error' => 'SPF text is required' } unless ($spf_text);

# Remove existing SPF record
my $existing = ovmns_get_spf($domain);
if ($existing) {
	ovmns_delete_record($domain, 'TXT', $domain);
	}

# Add new SPF record
my $result = ovmns_add_record($domain, 'TXT', $domain, "\"$spf_text\"", 3600);
return $result;
}

# ovmns_check_dkim($domain) - Check DKIM configuration for a domain
sub ovmns_check_dkim
{
my ($domain) = @_;
my $result = {
	'status' => 'missing',
	'selector' => 'default',
	'key_found' => 0,
	'dns_record' => undef,
	'key_size' => 0,
	};

return $result unless ($domain && $domain =~ /\./);

# Check for DKIM key files
my @selectors = ('default', 'selector1', 'selector2', 'mail');
foreach my $sel (@selectors) {
	my @key_paths = (
		"/etc/opendkim/keys/$domain/$sel.private",
		"/etc/opendkim/keys/$domain/$sel.txt",
		"/var/db/dkim/$domain.$sel.key",
		);
	foreach my $kp (@key_paths) {
		if (-r $kp) {
			$result->{'key_found'} = 1;
			$result->{'selector'} = $sel;
			$result->{'key_path'} = $kp;
			last;
			}
		}
	last if ($result->{'key_found'});
	}

# Check DNS for DKIM record
if (ovmns_check_dig()) {
	foreach my $sel (@selectors) {
		my $dkim_name = "$sel._domainkey.$domain";
		my $cmd = "dig +short TXT $dkim_name 2>/dev/null";
		my $out = `$cmd`;
		foreach my $line (split(/\n/, $out)) {
			chomp($line);
			$line =~ s/^"//;
			$line =~ s/"$//;
			if ($line =~ /v=DKIM1/) {
				$result->{'status'} = 'ok';
				$result->{'selector'} = $sel;
				$result->{'dns_record'} = $line;
				if ($line =~ /p=([A-Za-z0-9+\/]+)/) {
					my $key_data = $1;
					$result->{'key_size'} = length($key_data) * 6;  # Approximate bits
					}
				return $result;
				}
			}
		}
	}

# If key file exists but no DNS record
if ($result->{'key_found'}) {
	$result->{'status'} = 'warning';
	}

return $result;
}

# ovmns_enable_dkim($domain) - Enable DKIM for a domain
sub ovmns_enable_dkim
{
my ($domain) = @_;
return { 'ok' => 0, 'error' => 'Domain is required' } unless ($domain);

my $selector = 'default';
my $bits = 2048;
my $key_dir = "/etc/opendkim/keys/$domain";

# Create key directory
if (!-d $key_dir) {
	my $mkdir_result = `mkdir -p $key_dir 2>&1`;
	if ($? != 0) {
		return { 'ok' => 0, 'error' => "Cannot create key directory: $mkdir_result" };
		}
	}

# Generate DKIM key
my $genkey_cmd = "opendkim-genkey -b $bits -d $domain -D $key_dir -s $selector -v 2>&1";
my $genkey_out = `$genkey_cmd`;
if ($? != 0) {
	# Try alternate path
	$genkey_cmd = "/usr/sbin/opendkim-genkey -b $bits -d $domain -D $key_dir -s $selector -v 2>&1";
	$genkey_out = `$genkey_cmd`;
	}

# Read the generated TXT record
my $txt_file = "$key_dir/$selector.txt";
my $dns_record = '';
if (-r $txt_file) {
	open(my $fh, '<', $txt_file) || return { 'ok' => 0, 'error' => "Cannot read generated key file: $!" };
	while (my $line = <$fh>) {
		chomp($line);
		$dns_record .= $line;
		}
	close($fh);
	$dns_record =~ s/\s+/ /g;
	$dns_record =~ s/\s*;\s*$//;
	}

# Set proper permissions
`chmod 700 $key_dir 2>/dev/null`;
`chmod 600 $key_dir/$selector.private 2>/dev/null`;
`chown -R opendkim:opendkim $key_dir 2>/dev/null`;

return {
	'ok' => 1,
	'message' => 'DKIM key generated successfully',
	'selector' => $selector,
	'key_size' => $bits,
	'dns_record' => $dns_record,
	'key_file' => "$key_dir/$selector.private",
	'txt_file' => $txt_file,
	'dns_name' => "$selector._domainkey.$domain",
	};
}

# ovmns_get_dmarc($domain) - Get DMARC record for a domain
sub ovmns_get_dmarc
{
my ($domain) = @_;
return undef unless ($domain && $domain =~ /\./);

if (ovmns_check_dig()) {
	my $dmarc_name = "_dmarc.$domain";
	my $cmd = "dig +short TXT $dmarc_name 2>/dev/null";
	my $out = `$cmd`;
	foreach my $line (split(/\n/, $out)) {
		chomp($line);
		$line =~ s/^"//;
		$line =~ s/"$//;
		return $line if ($line =~ /^v=DMARC1/);
		}
	}
return undef;
}

# ovmns_set_dmarc($domain, $policy, $pct, $rua) - Set DMARC record
sub ovmns_set_dmarc
{
my ($domain, $policy, $pct, $rua) = @_;
return { 'ok' => 0, 'error' => 'Domain is required' } unless ($domain);

$policy ||= 'none';
$pct ||= 100;
$policy = lc($policy);

# Validate policy
unless ($policy =~ /^(none|quarantine|reject)$/) {
	return { 'ok' => 0, 'error' => 'Invalid DMARC policy. Use: none, quarantine, or reject' };
	}

# Build DMARC record
my $dmarc = "v=DMARC1; p=$policy; pct=$pct";
if ($rua && $rua =~ /\@/) {
	$dmarc .= "; rua=mailto:$rua";
	}

# Remove existing DMARC record
my $existing = ovmns_get_dmarc($domain);
if ($existing) {
	ovmns_delete_record($domain, 'TXT', "_dmarc.$domain");
	}

# Add new DMARC record
my $result = ovmns_add_record($domain, 'TXT', "_dmarc.$domain", "\"$dmarc\"", 3600);
return $result;
}

# ovmns_check_dnssec($domain) - Check DNSSEC status for a domain
sub ovmns_check_dnssec
{
my ($domain) = @_;
my $result = {
	'status' => 'disabled',
	'ksk_found' => 0,
	'zsk_found' => 0,
	'ds_records' => [],
	'key_tags' => [],
	};

return $result unless ($domain && $domain =~ /\./);

# Check for DNSSEC key files
my @key_dirs = (
	"/var/named/K$domain.*",
	"/etc/bind/K$domain.*",
	"/var/lib/named/K$domain.*",
	"/var/named/data/K$domain.*",
	);

my @key_files;
foreach my $pattern (@key_dirs) {
	my @found = glob($pattern);
	push(@key_files, @found);
	}

foreach my $kf (@key_files) {
	if ($kf =~ /\.key$/) {
		if ($kf =~ /KSK/i || $kf =~ /\+013\+/) {
			$result->{'ksk_found'} = 1;
			}
		else {
			$result->{'zsk_found'} = 1;
			}
		# Extract key tag
		if ($kf =~ /\+(\d+)\+/) {
			push(@{$result->{'key_tags'}}, $1);
			}
		}
	}

# Check DS record at parent
if (ovmns_check_dig()) {
	my $cmd = "dig +short DS $domain 2>/dev/null";
	my $out = `$cmd`;
	if ($out && $out =~ /\d+/) {
		$result->{'status'} = 'active';
		foreach my $line (split(/\n/, $out)) {
			chomp($line);
			push(@{$result->{'ds_records'}}, $line) if ($line =~ /\d+/);
			}
		}
	elsif ($result->{'ksk_found'} || $result->{'zsk_found'}) {
		$result->{'status'} = 'signed';
		}
	}
elsif ($result->{'ksk_found'} || $result->{'zsk_found'}) {
	$result->{'status'} = 'signed';
	}

return $result;
}

# ovmns_enable_dnssec($domain) - Enable DNSSEC for a domain
sub ovmns_enable_dnssec
{
my ($domain) = @_;
return { 'ok' => 0, 'error' => 'Domain is required' } unless ($domain);

my $tools = ovmns_check_dnssec_tools();
unless ($tools->{'dnssec-keygen'}) {
	return { 'ok' => 0, 'error' => 'dnssec-keygen tool not found. Install bind9utils.' };
	}

my $zone_file = ovmns_get_zone_file($domain);
unless ($zone_file && -r $zone_file) {
	return { 'ok' => 0, 'error' => 'Zone file not found for domain' };
	}

my $zone_dir = $zone_file;
$zone_dir =~ s/\/[^\/]+$//;

# Generate ZSK (Zone Signing Key)
my $zsk_cmd = "cd $zone_dir && dnssec-keygen -a RSASHA256 -b 2048 -n ZONE $domain 2>&1";
my $zsk_out = `$zsk_cmd`;
return { 'ok' => 0, 'error' => "ZSK generation failed: $zsk_out" } if ($? != 0);

# Generate KSK (Key Signing Key)
my $ksk_cmd = "cd $zone_dir && dnssec-keygen -a RSASHA256 -b 4096 -n ZONE -f KSK $domain 2>&1";
my $ksk_out = `$ksk_cmd`;
return { 'ok' => 0, 'error' => "KSK generation failed: $ksk_out" } if ($? != 0);

# Sign the zone
my $sign_cmd = "cd $zone_dir && dnssec-signzone -A -3 \$(head -c 1000 /dev/urandom | sha1sum | cut -b 1-16) -N INCREMENT -o $domain -t $zone_file 2>&1";
my $sign_out = `$sign_cmd`;
return { 'ok' => 0, 'error' => "Zone signing failed: $sign_out" } if ($? != 0);

# Get DS records
my @ds_records;
my $ds_cmd = "cd $zone_dir && dnssec-dsfromkey K${domain}.*.key 2>&1";
my $ds_out = `$ds_cmd`;
foreach my $line (split(/\n/, $ds_out)) {
	chomp($line);
	push(@ds_records, $line) if ($line =~ /DS\s+/ || $line =~ /^\S+\s+IN\s+DS\s+/);
	}

ovmns_reload_bind();

return {
	'ok' => 1,
	'message' => 'DNSSEC enabled successfully',
	'ds_records' => \@ds_records,
	'zsk_output' => $zsk_out,
	'ksk_output' => $ksk_out,
	'sign_output' => $sign_out,
	};
}

# ovmns_check_propagation($domain, $type) - Check DNS propagation
sub ovmns_check_propagation
{
my ($domain, $type) = @_;
return { 'ok' => 0, 'error' => 'Domain is required' } unless ($domain);

$type ||= 'A';
$type = uc($type);

my @servers = (
	{ 'name' => 'Google', 'ip' => '8.8.8.8' },
	{ 'name' => 'Google Secondary', 'ip' => '8.8.4.4' },
	{ 'name' => 'Cloudflare', 'ip' => '1.1.1.1' },
	{ 'name' => 'Cloudflare Secondary', 'ip' => '1.0.0.1' },
	{ 'name' => 'OpenDNS', 'ip' => '208.67.222.222' },
	{ 'name' => 'OpenDNS Secondary', 'ip' => '208.67.220.220' },
	{ 'name' => 'Quad9', 'ip' => '9.9.9.9' },
	);

my @results;
my $local_value = '';

# Get local value first
if (ovmns_check_dig()) {
	my $local_cmd = "dig +short $domain $type \@localhost 2>/dev/null";
	$local_value = `$local_cmd`;
	chomp($local_value);
	$local_value =~ s/\s+$//;
	}

foreach my $srv (@servers) {
	my $result = {
		'name' => $srv->{'name'},
		'ip' => $srv->{'ip'},
		'value' => '',
		'match' => 0,
		'time_ms' => 0,
		};

	if (ovmns_check_dig()) {
		my $cmd = "dig +short +time=5 $domain $type \@$srv->{'ip'} 2>/dev/null";
		my $start = time();
		my $out = `$cmd`;
		my $elapsed = (time() - $start) * 1000;
		chomp($out);
		$out =~ s/\s+$//;
		$result->{'value'} = $out;
		$result->{'time_ms'} = $elapsed;
		$result->{'match'} = ($local_value && $out && $out eq $local_value) ? 1 : 0;
		}
	push(@results, $result);
	}

my $propagation_pct = 0;
if (@results) {
	my $matching = grep { $_->{'match'} } @results;
	$propagation_pct = int(($matching / scalar(@results)) * 100);
	}

return {
	'ok' => 1,
	'domain' => $domain,
	'type' => $type,
	'local_value' => $local_value,
	'servers' => \@results,
	'propagation_pct' => $propagation_pct,
	'total_servers' => scalar(@results),
	'matching_servers' => scalar(grep { $_->{'match'} } @results),
	};
}

# ovmns_validate_record($type, $value) - Validate DNS record format
sub ovmns_validate_record
{
my ($type, $value) = @_;
return { 'ok' => 0, 'error' => 'Record type is required' } unless ($type);
return { 'ok' => 0, 'error' => 'Record value is required' } unless (defined($value) && $value ne '');

$type = uc($type);

# IP-based records
if ($type eq 'A') {
	unless ($value =~ /^(\d{1,3}\.){3}\d{1,3}$/) {
		return { 'ok' => 0, 'error' => 'Invalid IPv4 address format' };
		}
	my @octets = split(/\./, $value);
	foreach my $o (@octets) {
		return { 'ok' => 0, 'error' => 'IPv4 octet must be 0-255' } if ($o > 255);
		}
	}
elsif ($type eq 'AAAA') {
	unless ($value =~ /^[0-9a-fA-F:]+$/) {
		return { 'ok' => 0, 'error' => 'Invalid IPv6 address format' };
		}
	}
elsif ($type eq 'MX') {
	unless ($value =~ /^\d+\s+\S+/) {
		return { 'ok' => 0, 'error' => 'MX record must be: priority hostname (e.g., 10 mail.example.com)' };
		}
	}
elsif ($type eq 'CNAME') {
	unless ($value =~ /^[a-zA-Z0-9]([a-zA-Z0-9\-]*\.)+[a-zA-Z]{2,}\.?$/) {
		return { 'ok' => 0, 'error' => 'CNAME must be a valid hostname' };
		}
	}
elsif ($type eq 'NS') {
	unless ($value =~ /^[a-zA-Z0-9]([a-zA-Z0-9\-]*\.)+[a-zA-Z]{2,}\.?$/) {
		return { 'ok' => 0, 'error' => 'NS must be a valid hostname' };
		}
	}
elsif ($type eq 'TXT') {
	# TXT records are flexible, minimal validation
	if (length($value) > 255) {
		return { 'ok' => 0, 'error' => 'TXT record too long (max 255 chars per string)' };
		}
	}
elsif ($type eq 'SRV') {
	unless ($value =~ /^\d+\s+\d+\s+\d+\s+\S+/) {
		return { 'ok' => 0, 'error' => 'SRV record must be: priority weight port target' };
		}
	}
elsif ($type eq 'CAA') {
	unless ($value =~ /^\d+\s+(issue|issuewild|iodef)\s+\S+/i) {
		return { 'ok' => 0, 'error' => 'CAA record must be: flags tag value (e.g., 0 issue "letsencrypt.org")' };
		}
	}

return { 'ok' => 1, 'message' => 'Record format is valid' };
}

# ovmns_get_soa($domain) - Get SOA record for a domain
sub ovmns_get_soa
{
my ($domain) = @_;
return undef unless ($domain && $domain =~ /\./);

if (ovmns_check_dig()) {
	my $cmd = "dig SOA $domain +noall +answer 2>/dev/null";
	my $out = `$cmd`;
	if ($out =~ /SOA\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
		return {
			'mname' => $1,
			'rname' => $2,
			'serial' => $3,
			'refresh' => $4,
			'retry' => $5,
			'expire' => $6,
			'minimum' => $7,
			};
		}
	}
return undef;
}

# ovmns_update_soa($domain, %soa) - Update SOA record
sub ovmns_update_soa
{
my ($domain, %soa) = @_;
return { 'ok' => 0, 'error' => 'Domain is required' } unless ($domain);

my $zone_file = ovmns_get_zone_file($domain);
if ($zone_file && -w $zone_file) {
	my @lines;
	open(my $fh, '<', $zone_file) || return { 'ok' => 0, 'error' => "Cannot read zone file: $!" };
	while (my $line = <$fh>) {
		chomp($line);
		if ($line =~ /SOA\s+/) {
			# Update SOA serial
			if ($soa{'serial'}) {
				$line =~ s/(\d+)\s*;?\s*Serial/$soa{'serial'} ; Serial/i;
				}
			elsif ($line =~ /(\d{10})\s*;?\s*Serial/i) {
				my $old_serial = $1;
				my $today = `date +%Y%m%d`;
				chomp($today);
				my $new_serial = $today . "01";
				$new_serial = $old_serial + 1 if ($new_serial <= $old_serial);
				$line =~ s/$old_serial/$new_serial/;
				}
			}
		push(@lines, $line."\n");
		}
	close($fh);
	open(my $wfh, '>', $zone_file) || return { 'ok' => 0, 'error' => "Cannot write zone file: $!" };
	print $wfh @lines;
	close($wfh);
	ovmns_reload_bind();
	return { 'ok' => 1, 'message' => 'SOA record updated' };
	}

return { 'ok' => 0, 'error' => 'Zone file not found or not writable' };
}

# ovmns_batch_update($domain, @records) - Batch update DNS records
sub ovmns_batch_update
{
my ($domain, @records) = @_;
return { 'ok' => 0, 'error' => 'Domain is required' } unless ($domain);
return { 'ok' => 0, 'error' => 'No records provided' } unless (@records);

my $success = 0;
my $failed = 0;
my @errors;

foreach my $rec (@records) {
	next unless (ref($rec) eq 'HASH');
	my $action = $rec->{'action'} || 'add';

	if ($action eq 'add') {
		my $result = ovmns_add_record($domain, $rec->{'type'}, $rec->{'name'}, $rec->{'value'}, $rec->{'ttl'});
		if ($result->{'ok'}) { $success++; }
		else { $failed++; push(@errors, "Add $rec->{'type'} $rec->{'name'}: $result->{'error'}"); }
		}
	elsif ($action eq 'delete') {
		my $result = ovmns_delete_record($domain, $rec->{'type'}, $rec->{'name'});
		if ($result->{'ok'}) { $success++; }
		else { $failed++; push(@errors, "Delete $rec->{'type'} $rec->{'name'}: $result->{'error'}"); }
		}
	elsif ($action eq 'edit') {
		my $result = ovmns_edit_record($domain, $rec->{'type'}, $rec->{'old_name'}, $rec->{'name'}, $rec->{'value'}, $rec->{'ttl'});
		if ($result->{'ok'}) { $success++; }
		else { $failed++; push(@errors, "Edit $rec->{'type'} $rec->{'name'}: $result->{'error'}"); }
		}
	}

return {
	'ok' => ($failed == 0) ? 1 : 0,
	'message' => "Batch update: $success succeeded, $failed failed",
	'success' => $success,
	'failed' => $failed,
	'errors' => \@errors,
	};
}

# ovmns_reload_bind() - Reload BIND/named configuration
sub ovmns_reload_bind
{
if (defined(&foreign_require)) {
	&foreign_require("bind8", "bind8-lib.pl");
	if (defined(&reload_bind)) {
		&reload_bind();
		return 1;
		}
	}

# Try system commands
if (-x '/usr/sbin/rndc') {
	system("/usr/sbin/rndc reload 2>/dev/null");
	return 1;
	}
elsif (-x '/usr/sbin/named') {
	system("/usr/sbin/named -s reload 2>/dev/null");
	return 1;
	}
elsif (-x '/usr/bin/systemctl') {
	system("/usr/bin/systemctl reload named 2>/dev/null || /usr/bin/systemctl reload bind9 2>/dev/null");
	return 1;
	}

return 0;
}

# ovmns_increment_serial($domain) - Increment SOA serial
sub ovmns_increment_serial
{
my ($domain) = @_;
return ovmns_update_soa($domain);
}

1;
