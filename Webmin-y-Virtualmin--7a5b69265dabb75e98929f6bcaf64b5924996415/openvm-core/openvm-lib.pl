#!/usr/bin/perl

use strict;
use warnings;
use File::Path qw(make_path);

our (%in, %text, %config, $base_remote_user, $module_config_directory, $module_root_directory);
our $OPENVM_VIRTUAL_SERVER_LOADED = 0;

sub ovm_text
{
my ($key, $fallback) = @_;
return exists($text{$key}) && defined($text{$key}) && $text{$key} ne ''
       ? $text{$key}
       : $fallback;
}

sub ovm_module_config
{
my %config = (
	'feature_html_editor' => 1,
	'feature_connectivity' => 1,
	'feature_safe_write' => 1,
	'default_edit_file' => 'index.html',
	'max_preview_bytes' => 262144,
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

sub ovm_load_virtualmin
{
return 1 if ($OPENVM_VIRTUAL_SERVER_LOADED);
&foreign_require("virtual-server", "virtual-server-lib.pl");
$OPENVM_VIRTUAL_SERVER_LOADED = 1;
return 1;
}

sub ovm_current_domain
{
my ($hint) = @_;
$hint ||= {};
ovm_load_virtualmin();
my $id = defined($hint->{'id'}) ? $hint->{'id'} : $in{'id'};
my $dom = defined($hint->{'dom'}) ? $hint->{'dom'} : $in{'dom'};
my $user = defined($hint->{'user'}) ? $hint->{'user'} : $base_remote_user;
my $d;
$d = &get_domain($id) if (defined($id) && $id ne '');
$d ||= &get_domain_by('dom', $dom) if (defined($dom) && $dom ne '');
$d ||= &get_domain_by('user', $user) if (defined($user) && $user ne '');
return $d;
}

sub ovm_require_domain_access
{
my ($d, $deny_message) = @_;
$d ||= ovm_current_domain();
$d || &error(ovm_text('edit_html', 'No virtual server selected'));
&can_edit_domain($d) || &error($deny_message || ovm_text('edit_html', 'You cannot edit this virtual server'));
return $d;
}

sub ovm_safe_relative_path
{
my ($path) = @_;
my $default = ovm_module_config()->{'default_edit_file'} || 'index.html';
$path = defined($path) ? $path : $default;
$path =~ s/^\s+//;
$path =~ s/\s+$//;
$path =~ s/\\/\//g;
$path =~ s/^\/+//;
$path =~ s/\.\.//g;
$path =~ s/\/{2,}/\//g;
$path =~ s/[^A-Za-z0-9_\.\-\/]//g;
$path =~ s/\/$// if ($path ne '/');
$path ||= $default;
return $path;
}

sub ovm_public_html_dir
{
my ($d) = @_;
ovm_load_virtualmin();
my $phd = &public_html_dir($d);
if (!$phd && $d->{'home'}) {
	foreach my $candidate ("$d->{'home'}/public_html",
				       "$d->{'home'}/www",
				       "$d->{'home'}/htdocs") {
		if (-d $candidate || !-e $candidate) {
			$phd = $candidate;
			last;
			}
		}
	}
return $phd;
}

sub ovm_read_text_file
{
my ($file) = @_;
return '' if (!$file || !-r $file);
if (defined(&cat_file)) {
	my $rv = &cat_file($file);
	return defined($rv) ? $rv : '';
	}
open(my $fh, '<', $file) || die "Failed to read $file : $!";
local $/ = undef;
my $data = <$fh>;
close($fh);
return defined($data) ? $data : '';
}

sub ovm_write_text_file
{
my ($file, $content) = @_;
$content = '' if (!defined($content));
my $dir = $file;
$dir =~ s/\/[^\/]+$//;
if ($dir && !-d $dir) {
	if (defined(&make_dir)) {
		eval { &make_dir($dir, 0755); };
		}
	make_path($dir, { 'mode' => 0755 }) if (!-d $dir);
	}
if (defined(&uncat_file)) {
	&uncat_file($file, $content);
	return 1;
	}
open(my $fh, '>', $file) || die "Failed to write $file : $!";
print $fh $content;
close($fh);
return 1;
}

sub ovm_preview_url
{
my ($d, $rel) = @_;
my $proto = $d->{'ssl'} ? 'https' : 'http';
my $domain = $d->{'dom'} || 'localhost';
my $suffix = '';
if (defined($rel) && $rel ne '') {
	$suffix = '/'.ovm_safe_relative_path($rel);
	}
return "$proto://$domain$suffix";
}

sub ovm_default_html
{
my ($d, $rel) = @_;
my $domain = $d->{'dom'} || 'example.test';
my $path = $rel || 'index.html';
return <<"EOF";
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$domain</title>
</head>
<body>
  <main style="max-width: 720px; margin: 40px auto; font-family: Arial, sans-serif; line-height: 1.5;">
    <h1>$domain</h1>
    <p>Archivo inicial generado por OpenVM Core.</p>
    <p>Ruta actual: <strong>$path</strong></p>
  </main>
</body>
</html>
EOF
}

sub ovm_connectivity_checks
{
my ($d) = @_;
ovm_load_virtualmin();
my @checks;
if (defined(&check_domain_connectivity)) {
	my @errs = &check_domain_connectivity($d, { 'mail' => 1, 'ssl' => 1 });
	if (@errs) {
		foreach my $e (@errs) {
			push(@checks, { 'name' => ovm_text('edit_connect', 'Connectivity'),
					'ok' => 0,
					'message' => $e });
			}
		}
	else {
		push(@checks, { 'name' => ovm_text('edit_connect', 'Connectivity'),
				'ok' => 1,
				'message' => ovm_text('edit_connectdesc', 'Connectivity checks completed successfully') });
		}
	return \@checks;
	}
my $resolved = gethostbyname($d->{'dom'}) ? 1 : 0;
push(@checks, {
	'name' => 'DNS',
	'ok' => $resolved,
	'message' => $resolved ? 'Domain resolves via the local resolver' : 'Domain does not resolve from this host',
	});
push(@checks, {
	'name' => 'Website',
	'ok' => $d->{'web'} ? 1 : 0,
	'message' => $d->{'web'} ? 'Website feature is enabled for this virtual server' : 'Website feature is disabled for this virtual server',
	});
push(@checks, {
	'name' => 'Mail',
	'ok' => $d->{'mail'} ? 1 : 0,
	'message' => $d->{'mail'} ? 'Mail feature is enabled for this virtual server' : 'Mail feature is disabled for this virtual server',
	});
push(@checks, {
	'name' => 'SSL',
	'ok' => $d->{'ssl'} ? 1 : 0,
	'message' => $d->{'ssl'} ? 'SSL is enabled for this virtual server' : 'SSL is not enabled for this virtual server',
	});
my $public_html = ovm_public_html_dir($d);
push(@checks, {
	'name' => 'Public HTML',
	'ok' => $public_html && (-d $public_html || !-e $public_html) ? 1 : 0,
	'message' => $public_html ? "Public web root: $public_html" : 'Public HTML directory could not be determined',
	});
return \@checks;
}

sub ovm_feature_matrix
{
my $config = ovm_module_config();
return [
	{
	'name' => 'HTML editor',
	'enabled' => $config->{'feature_html_editor'} ? 1 : 0,
	'note' => 'Edición de archivos del sitio usando APIs GPL y escritura segura propia',
	},
	{
	'name' => 'Connectivity diagnostics',
	'enabled' => $config->{'feature_connectivity'} ? 1 : 0,
	'note' => 'Validación de conectividad con helper GPL o fallback abierto local',
	},
	{
	'name' => 'Mail log search',
	'enabled' => 1,
	'note' => 'Consulta abierta de logs de correo con filtros por dominio, origen y destino',
	},
	{
	'name' => 'Backup key inventory',
	'enabled' => 1,
	'note' => 'Listado abierto de claves de cifrado de backup desde helpers GPL o GPG local',
	},
	{
	'name' => 'Remote DNS inventory',
	'enabled' => 1,
	'note' => 'Inventario abierto de servidores DNS remotos y dominios asociados',
	},
	{
	'name' => 'License independence',
	'enabled' => 1,
	'note' => 'El módulo no escribe ni modifica archivos de licencia oficiales',
	},
	];
}

sub ovm_trim
{
my ($value) = @_;
$value = '' if (!defined($value));
$value =~ s/^\s+//;
$value =~ s/\s+$//;
return $value;
}

sub ovm_mail_log_candidates
{
ovm_load_virtualmin();
my @files = grep { $_ && -r $_ } (
	$config{'maillog_file'},
	'/var/log/mail.log',
	'/var/log/maillog',
	'/var/log/mail.log.1',
	'/var/log/maillog.1',
	);
my %seen;
@files = grep { !$seen{$_}++ } @files;
return \@files;
}

sub ovm_mail_log_search
{
my ($d, $filters) = @_;
$filters ||= {};
my $limit = $filters->{'limit'} || 200;
my $needle_start = ovm_trim($filters->{'start'});
my $needle_end = ovm_trim($filters->{'end'});
my $needle_source = ovm_trim($filters->{'source'});
my $needle_dest = ovm_trim($filters->{'dest'});
my $needle_domain = $d->{'dom'} || '';
my $needle_email = $d->{'emailto'} || '';
my @results;

foreach my $file (@{ovm_mail_log_candidates()}) {
	open(my $fh, '<', $file) || next;
	while(my $line = <$fh>) {
		chomp($line);
		next if ($needle_start && index(lc($line), lc($needle_start)) < 0);
		next if ($needle_end && index(lc($line), lc($needle_end)) < 0);
		next if ($needle_source && $line !~ /\Q$needle_source\E/i);
		next if ($needle_dest && $line !~ /\Q$needle_dest\E/i);
		if (!$needle_source && !$needle_dest) {
			next if ($needle_domain && $line !~ /\Q$needle_domain\E/i &&
			         (!$needle_email || $line !~ /\Q$needle_email\E/i));
			}
		push(@results, {
			'file' => $file,
			'line' => $line,
			});
		last if (@results >= $limit);
		}
	close($fh);
	last if (@results >= $limit);
	}

return \@results;
}

sub ovm_backup_keys
{
ovm_load_virtualmin();
my @keys;
if (defined(&list_backup_keys)) {
	@keys = &list_backup_keys();
	}
else {
	my $keyring = '/etc/webmin/virtual-server/bkeys';
	if (-d $keyring) {
		my $out = `gpg --homedir $keyring --list-keys --with-colons 2>/dev/null`;
		foreach my $line (split(/\n/, $out)) {
			my @f = split(/:/, $line);
			next if ($f[0] ne 'pub');
			push(@keys, {
				'id' => $f[4] || 'unknown',
				'desc' => 'GPG backup key',
				'owner' => 'root',
				'created' => $f[5] || undef,
				});
			}
		}
	}
return \@keys;
}

sub ovm_remote_dns_inventory
{
ovm_load_virtualmin();
my @inventory;

if (defined(&list_remote_dns)) {
	my @remote = &list_remote_dns();
	my @doms = &list_domains();
	foreach my $r (@remote) {
		my @uses = grep { $_->{'dns_remote'} && $_->{'dns_remote'} eq $r->{'host'} } @doms;
		push(@inventory, {
			'host' => $r->{'host'},
			'type' => $r->{'slave'} ? 'Slave' : 'Master',
			'domains' => [ map { $_->{'dom'} } @uses ],
			'domain_count' => scalar(@uses),
			});
		}
	}
else {
	my @doms = grep { $_->{'dns_remote'} } &list_domains();
	my %by_host;
	foreach my $d (@doms) {
		push(@{$by_host{$d->{'dns_remote'}}}, $d->{'dom'});
		}
	foreach my $host (sort keys %by_host) {
		push(@inventory, {
			'host' => $host,
			'type' => 'Remote',
			'domains' => $by_host{$host},
			'domain_count' => scalar(@{$by_host{$host}}),
			});
		}
	}

return \@inventory;
}

1;
