#!/usr/bin/perl

use strict;
use warnings;
use POSIX qw(strftime);

our (%in, %text, $module_config_directory, $base_remote_user);
our $OPENVM_SSL_VIRTUALMIN_LOADED = 0;

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

sub ovmssl_text
{
my ($key, $fallback) = @_;
return exists($text{$key}) && defined($text{$key}) && $text{$key} ne ''
	? $text{$key}
	: $fallback;
}

sub ovmssl_module_config
{
my %config = (
	'feature_letsencrypt' => 1,
	'feature_zerossl'     => 1,
	'feature_buypass'     => 1,
	'feature_auto_renew'  => 1,
	'acme_binary'         => '',
	'zerossl_api_key'     => '',
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

sub ovmssl_load_virtualmin
{
return 1 if $OPENVM_SSL_VIRTUALMIN_LOADED;
&foreign_require("virtual-server", "virtual-server-lib.pl");
$OPENVM_SSL_VIRTUALMIN_LOADED = 1;
return 1;
}

sub ovmssl_require_access
{
ovmssl_load_virtualmin();
return 1 if defined(&master_admin) && &master_admin();
return 1 if defined(&can_generate_ssl) && &can_generate_ssl();
return 1 if defined(&can_edit_ssl) && &can_edit_ssl();
&error(ovmssl_text('ssl_ecannot', 'You cannot manage SSL from OpenVM SSL'));
}

sub ovmssl_current_domain
{
my ($hint) = @_;
$hint ||= {};
ovmssl_load_virtualmin();
my $id  = defined($hint->{'id'})   ? $hint->{'id'}   : $in{'id'};
my $dom = defined($hint->{'dom'})  ? $hint->{'dom'}   : $in{'dom'};
my $usr = defined($hint->{'user'}) ? $hint->{'user'}  : $base_remote_user;
my $d;
$d  = &get_domain($id)              if defined($id)  && $id ne '';
$d ||= &get_domain_by('dom', $dom) if defined($dom) && $dom ne '';
$d ||= &get_domain_by('user', $usr) if defined($usr) && $usr ne '';
return $d;
}

sub ovmssl_visible_domains
{
ovmssl_load_virtualmin();
my @doms = defined(&list_visible_domains) ? &list_visible_domains()
	 : defined(&list_domains)         ? &list_domains()
	 : ();
return \@doms;
}

# ---------------------------------------------------------------------------
# SSL providers catalog (no license gate)
# ---------------------------------------------------------------------------

sub ovmssl_providers
{
my $cfg = ovmssl_module_config();
my @providers;

push(@providers, {
	'id'       => 'letsencrypt',
	'name'     => "Let's Encrypt",
	'url'      => 'https://letsencrypt.org',
	'acme_dir' => 'https://acme-v02.api.letsencrypt.org/directory',
	'free'     => 1,
	'enabled'  => $cfg->{'feature_letsencrypt'} ? 1 : 0,
	'note'     => "Certificados DV gratuitos, renovación automática cada 90 días",
	}) if $cfg->{'feature_letsencrypt'};

push(@providers, {
	'id'       => 'zerossl',
	'name'     => 'ZeroSSL',
	'url'      => 'https://zerossl.com',
	'acme_dir' => 'https://acme.zerossl.com/v2/DV90',
	'free'     => 1,
	'enabled'  => $cfg->{'feature_zerossl'} ? 1 : 0,
	'note'     => "Alternativa a Let's Encrypt, panel propio en zerossl.com",
	}) if $cfg->{'feature_zerossl'};

push(@providers, {
	'id'       => 'buypass',
	'name'     => 'BuyPass Go SSL',
	'url'      => 'https://www.buypass.com/ssl/products/acme',
	'acme_dir' => 'https://api.buypass.com/acme/directory',
	'free'     => 1,
	'enabled'  => $cfg->{'feature_buypass'} ? 1 : 0,
	'note'     => "Certificados gratuitos con validez de 180 días (ACME nativo)",
	}) if $cfg->{'feature_buypass'};

return \@providers;
}

# ---------------------------------------------------------------------------
# Certificate inventory — wraps GPL helpers with open fallback
# ---------------------------------------------------------------------------

sub ovmssl_list_certs
{
ovmssl_load_virtualmin();
my @domains = @{ovmssl_visible_domains()};
my @certs;

foreach my $d (@domains) {
	next unless $d->{'ssl'};
	my %cert = (
		'dom'     => $d->{'dom'},
		'id'      => $d->{'id'},
		'enabled' => 1,
		'expiry'  => undef,
		'issuer'  => undef,
		'days'    => undef,
		'status'  => 'unknown',
		);

	# Try GPL cert helpers
	if (defined(&get_domain_ssl_cert)) {
		my $ci = eval { &get_domain_ssl_cert($d) };
		if ($ci && !$@) {
			$cert{'expiry'} = $ci->{'expiry'};
			$cert{'issuer'} = $ci->{'o'} || $ci->{'cn'};
			if ($cert{'expiry'}) {
				my $left = int(($cert{'expiry'} - time()) / 86400);
				$cert{'days'}   = $left;
				$cert{'status'} = $left < 0  ? 'expired'
						 : $left < 14 ? 'expiring'
						 :              'valid';
				}
			}
		}
	elsif ($d->{'ssl_cert'} && -r $d->{'ssl_cert'}) {
		# Fallback: read expiry via openssl CLI
		my $cert_file = $d->{'ssl_cert'};
		my $out = `openssl x509 -noout -enddate -issuer -in \Q$cert_file\E 2>/dev/null`;
		if ($out =~ /notAfter=(.+)/) {
			my $expiry_str = $1;
			my $ts = `date -d \Q$expiry_str\E +%s 2>/dev/null`;
			chomp $ts;
			if ($ts =~ /^\d+$/) {
				$cert{'expiry'} = int($ts);
				my $left = int(($ts - time()) / 86400);
				$cert{'days'}   = $left;
				$cert{'status'} = $left < 0  ? 'expired'
						 : $left < 14 ? 'expiring'
						 :              'valid';
				}
			}
		if ($out =~ /O=([^,\/\n]+)/) { $cert{'issuer'} = $1; }
		}

	push(@certs, \%cert);
	}

return \@certs;
}

# ---------------------------------------------------------------------------
# ACME binary detection (certbot / acme.sh / lego)
# ---------------------------------------------------------------------------

sub ovmssl_acme_binary
{
my $cfg = ovmssl_module_config();
return $cfg->{'acme_binary'} if $cfg->{'acme_binary'} && -x $cfg->{'acme_binary'};
for my $bin (qw(/usr/bin/certbot /usr/local/bin/certbot
		/root/.acme.sh/acme.sh /usr/local/bin/acme.sh
		/usr/local/bin/lego)) {
	return $bin if -x $bin;
	}
return undef;
}

# ---------------------------------------------------------------------------
# Renew via certbot / acme.sh using selected provider ACME dir
# ---------------------------------------------------------------------------

sub ovmssl_renew_domain
{
my ($d, $provider_id) = @_;
$provider_id ||= 'letsencrypt';
ovmssl_load_virtualmin();

# Prefer GPL native renewal
if (defined(&renew_domain_cert)) {
	my $err = eval { &renew_domain_cert($d) };
	return { 'ok' => 1, 'msg' => 'Renewed via Virtualmin GPL' } if !$@ && !$err;
	}

my %acme_dirs = (
	'letsencrypt' => 'https://acme-v02.api.letsencrypt.org/directory',
	'zerossl'     => 'https://acme.zerossl.com/v2/DV90',
	'buypass'     => 'https://api.buypass.com/acme/directory',
	);
my $acme_dir = $acme_dirs{$provider_id} || $acme_dirs{'letsencrypt'};
my $bin      = ovmssl_acme_binary();

return { 'ok' => 0, 'msg' => 'No ACME client found (install certbot or acme.sh)' }
	unless $bin;

my $dom   = $d->{'dom'};
my $email = $d->{'emailto'} || "admin\@$dom";
my $cmd;

if ($bin =~ /certbot/) {
	$cmd = "$bin certonly --non-interactive --agree-tos"
	     . " --email \Q$email\E"
	     . " --server \Q$acme_dir\E"
	     . " -d \Q$dom\E"
	     . " --webroot -w /var/www/html 2>&1";
	}
elsif ($bin =~ /acme\.sh/) {
	$cmd = "$bin --issue -d \Q$dom\E"
	     . " --server \Q$acme_dir\E"
	     . " --webroot /var/www/html 2>&1";
	}
else {
	$cmd = "$bin run --domains \Q$dom\E"
	     . " --server \Q$acme_dir\E"
	     . " --email \Q$email\E"
	     . " --accept-tos 2>&1";
	}

my $out = `$cmd`;
my $rc  = $? >> 8;
return { 'ok' => $rc == 0 ? 1 : 0, 'msg' => $out };
}

# ---------------------------------------------------------------------------
# Auto-renew check: return list of domains expiring within 30 days
# ---------------------------------------------------------------------------

sub ovmssl_domains_due_renewal
{
my ($threshold_days) = @_;
$threshold_days //= 30;
my $certs = ovmssl_list_certs();
return [ grep { defined($_->{'days'}) && $_->{'days'} <= $threshold_days } @$certs ];
}

1;
