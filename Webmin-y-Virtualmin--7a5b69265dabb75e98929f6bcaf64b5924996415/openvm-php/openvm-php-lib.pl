#!/usr/bin/perl

use strict;
use warnings;

our (%in, %text, $module_config_directory, $base_remote_user);
our $OPENVM_PHP_VIRTUALMIN_LOADED = 0;

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

sub ovmphp_text
{
my ($key, $fallback) = @_;
return exists($text{$key}) && defined($text{$key}) && $text{$key} ne ''
	? $text{$key}
	: $fallback;
}

sub ovmphp_module_config
{
my %config = (
	'feature_versions' => 1,
	'feature_per_dir'  => 1,
	'feature_ini'      => 1,
	'php_versions_dir' => '/etc/php',
	);
my $config_file = $module_config_directory ? "$module_config_directory/config" : undef;
if ($config_file && -r $config_file) {
	open(my $fh, '<', $config_file) || die "Cannot read $config_file: $!";
	while (my $line = <$fh>) {
		chomp $line;
		next if $line =~ /^\s*#/ || $line !~ /=/;
		my ($k, $v) = split(/=/, $line, 2);
		next unless defined $k && $k ne '';
		$config{$k} = $v;
		}
	close($fh);
	}
return \%config;
}

sub ovmphp_load_virtualmin
{
return 1 if $OPENVM_PHP_VIRTUALMIN_LOADED;
&foreign_require("virtual-server", "virtual-server-lib.pl");
$OPENVM_PHP_VIRTUALMIN_LOADED = 1;
return 1;
}

sub ovmphp_require_access
{
ovmphp_load_virtualmin();
return 1 if defined(&master_admin) && &master_admin();
return 1 if defined(&can_edit_php_ini) && &can_edit_php_ini();
return 1 if defined(&can_edit_templates) && &can_edit_templates();
&error(ovmphp_text('php_ecannot', 'You cannot manage PHP from OpenVM PHP'));
}

sub ovmphp_current_domain
{
my ($hint) = @_;
$hint ||= {};
ovmphp_load_virtualmin();
my $id  = defined($hint->{'id'})   ? $hint->{'id'}   : $in{'id'};
my $dom = defined($hint->{'dom'})  ? $hint->{'dom'}   : $in{'dom'};
my $usr = defined($hint->{'user'}) ? $hint->{'user'}  : $base_remote_user;
my $d;
$d  = &get_domain($id)               if defined($id)  && $id ne '';
$d ||= &get_domain_by('dom', $dom)   if defined($dom) && $dom ne '';
$d ||= &get_domain_by('user', $usr)  if defined($usr) && $usr ne '';
return $d;
}

# ---------------------------------------------------------------------------
# Detect installed PHP versions
# ---------------------------------------------------------------------------

sub ovmphp_installed_versions
{
my $cfg     = ovmphp_module_config();
my $php_dir = $cfg->{'php_versions_dir'} || '/etc/php';
my @versions;

# /etc/php/<version>/ directories
if (-d $php_dir) {
	opendir(my $dh, $php_dir) or return \@versions;
	while (my $entry = readdir($dh)) {
		next if $entry =~ /^\./;
		next unless $entry =~ /^\d+\.\d+$/;
		my $fpm_bin = "/usr/bin/php$entry";
		my $fpm_svc = "php$entry-fpm";
		push @versions, {
			'version' => $entry,
			'binary'  => -x $fpm_bin ? $fpm_bin : undef,
			'fpm_svc' => $fpm_svc,
			'fpm_active' => -f "/run/php/php$entry-fpm.pid" ? 1 : 0,
			'ini_dir'    => "$php_dir/$entry/fpm/conf.d",
			};
		}
	closedir($dh);
	}

# Also check paths returned by GPL helpers
if (defined(&list_available_php_versions)) {
	my @gpl_ver = &list_available_php_versions();
	foreach my $v (@gpl_ver) {
		my $vname = ref($v) eq 'HASH' ? $v->{'version'} : $v;
		next unless $vname =~ /^\d/;
		next if grep { $_->{'version'} eq $vname } @versions;
		push @versions, {
			'version'    => $vname,
			'binary'     => undef,
			'fpm_svc'    => "php$vname-fpm",
			'fpm_active' => 0,
			'ini_dir'    => "/etc/php/$vname/fpm/conf.d",
			};
		}
	}

@versions = sort { $b->{'version'} cmp $a->{'version'} } @versions;
return \@versions;
}

# ---------------------------------------------------------------------------
# PHP version for a domain
# ---------------------------------------------------------------------------

sub ovmphp_domain_php_version
{
my ($d) = @_;
return undef unless $d;
ovmphp_load_virtualmin();

if (defined(&domain_php_version)) {
	my $ver = eval { &domain_php_version($d) };
	return $ver if $ver && !$@;
	}

# Fallback: read .htaccess or check php-fpm pool
my $phd = defined(&public_html_dir) ? &public_html_dir($d) : undef;
$phd ||= $d->{'home'} ? "$d->{'home'}/public_html" : undef;
if ($phd && -r "$phd/.htaccess") {
	open(my $fh, '<', "$phd/.htaccess") or return undef;
	while (<$fh>) {
		return $1 if /FCGIWrapper.*php(\d+\.\d+)/;
		return $1 if /AddHandler.*php(\d+\.\d+)/;
		}
	close($fh);
	}

return undef;
}

# ---------------------------------------------------------------------------
# Per-directory PHP config — list .htaccess overrides under public_html
# ---------------------------------------------------------------------------

sub ovmphp_per_dir_configs
{
my ($d) = @_;
ovmphp_load_virtualmin();
my @result;

if (defined(&list_domain_php_directories)) {
	my @dirs = eval { &list_domain_php_directories($d) };
	return \@dirs if !$@ && @dirs;
	}

# Fallback: scan .htaccess files
my $phd = defined(&public_html_dir) ? &public_html_dir($d) : undef;
$phd ||= $d->{'home'} ? "$d->{'home'}/public_html" : undef;
return \@result unless $phd && -d $phd;

my @htaccessfiles = `find \Q$phd\E -name '.htaccess' -maxdepth 5 2>/dev/null`;
foreach my $file (@htaccessfiles) {
	chomp $file;
	next unless -r $file;
	my $dir = $file; $dir =~ s/\/.htaccess$//;
	my $php_ver = undef;
	open(my $fh, '<', $file) or next;
	while (<$fh>) {
		$php_ver = $1 if /php(\d+\.\d+)/;
		}
	close($fh);
	push @result, {
		'dir'     => $dir,
		'php_ver' => $php_ver || 'heredado',
		'source'  => '.htaccess',
		} if $php_ver;
	}
return \@result;
}

# ---------------------------------------------------------------------------
# PHP ini key/value for a domain
# ---------------------------------------------------------------------------

sub ovmphp_get_ini_settings
{
my ($d) = @_;
ovmphp_load_virtualmin();
return {} unless $d;

if (defined(&get_domain_php_ini)) {
	my $ini = eval { &get_domain_php_ini($d) };
	return $ini if $ini && !$@;
	}

# Fallback: read pool ini file if it exists
my $ver = ovmphp_domain_php_version($d);
return {} unless $ver;
my $ini_file = "/etc/php/$ver/fpm/pool.d/$d->{'user'}.conf";
return {} unless -r $ini_file;

my %ini;
open(my $fh, '<', $ini_file) or return {};
while (<$fh>) {
	chomp;
	next if /^\s*[;\[#]/;
	if (/^php_admin_value\[(\S+)\]\s*=\s*(.+)$/ ||
	    /^php_value\[(\S+)\]\s*=\s*(.+)$/) {
		$ini{$1} = $2;
		}
	}
close($fh);
return \%ini;
}

1;
