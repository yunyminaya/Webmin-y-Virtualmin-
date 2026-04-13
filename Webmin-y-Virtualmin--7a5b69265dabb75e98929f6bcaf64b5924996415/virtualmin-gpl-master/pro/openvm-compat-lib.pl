#!/usr/bin/perl

use strict;
use warnings;

our (%in, %text, %config, $base_remote_user, $module_name);

require './virtual-server-lib.pl';

sub compat_trim
{
my ($value) = @_;
$value = '' if (!defined($value));
$value =~ s/^\s+//;
$value =~ s/\s+$//;
return $value;
}

sub compat_current_domain
{
my $d;
$d = &get_domain($in{'id'}) if ($in{'id'});
$d ||= &get_domain($in{'dom'}) if ($in{'dom'} && $in{'dom'} =~ /^\d+$/);
$d ||= &get_domain_by('dom', $in{'dom'}) if ($in{'dom'} && $in{'dom'} !~ /^\d+$/);
$d ||= &get_domain_by('user', $base_remote_user) if ($base_remote_user);
return $d;
}

sub compat_selected_domains
{
my %seen;
my @rv;
foreach my $id (split(/\0/, $in{'d'} || '')) {
	next if (!$id || $seen{$id}++);
	my $d = &get_domain($id);
	push(@rv, $d) if ($d);
	}
if (!@rv) {
	my $d = compat_current_domain();
	push(@rv, $d) if ($d);
	}
return @rv;
}

sub compat_user_name
{
my ($short, $d) = @_;
$short = compat_trim($short);
$short = lc($short) if (!$config{'allow_upper'});
return undef if (!$short);
return $d ? &userdom_name($short, $d) : $short;
}

sub compat_limits_to_text
{
my ($limits) = @_;
return '' if (ref($limits) ne 'HASH');
return join("\n", map { $_."=".$limits->{$_} } sort keys %{$limits});
}

sub compat_text_to_limits
{
my ($text) = @_;
my %limits;
foreach my $line (split(/\r?\n/, $text || '')) {
	$line = compat_trim($line);
	next if (!$line || $line =~ /^\#/);
	$line =~ /^([^=]+)=(.*)$/ || &error("Invalid resource limit line: $line");
	my ($key, $value) = (compat_trim($1), compat_trim($2));
	$key ne '' || &error("Invalid empty resource limit name");
	$limits{$key} = $value;
	}
return \%limits;
}

1;
