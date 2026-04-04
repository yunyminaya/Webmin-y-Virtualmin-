#!/usr/bin/perl

use strict;
use warnings;

our (%in, %text, $module_config_directory);
our $OPENVM_DNS_VIRTUALMIN_LOADED = 0;

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
&foreign_require("virtual-server", "virtual-server-lib.pl");
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
my @doms = &list_domains();
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
my @doms = &list_domains();
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

1;
