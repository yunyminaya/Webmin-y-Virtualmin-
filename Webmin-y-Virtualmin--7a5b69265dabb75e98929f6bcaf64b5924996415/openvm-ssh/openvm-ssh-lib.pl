#!/usr/bin/perl

use strict;
use warnings;
use File::Path qw(make_path);

our (%in, %text, $module_config_directory, $base_remote_user);
our $OPENVM_SSH_VIRTUALMIN_LOADED = 0;

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

sub ovmssh_text
{
my ($key, $fallback) = @_;
return exists($text{$key}) && defined($text{$key}) && $text{$key} ne ''
	? $text{$key}
	: $fallback;
}

sub ovmssh_module_config
{
my %config = (
	'feature_list_keys'     => 1,
	'feature_add_key'       => 1,
	'feature_delete_key'    => 1,
	'authorized_keys_file'  => '.ssh/authorized_keys',
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

sub ovmssh_load_virtualmin
{
return 1 if $OPENVM_SSH_VIRTUALMIN_LOADED;
&foreign_require("virtual-server", "virtual-server-lib.pl");
$OPENVM_SSH_VIRTUALMIN_LOADED = 1;
return 1;
}

sub ovmssh_require_access
{
ovmssh_load_virtualmin();
return 1 if defined(&master_admin) && &master_admin();
return 1 if defined(&can_edit_domain) && do {
	my $d = ovmssh_current_domain({});
	$d && &can_edit_domain($d);
	};
return 1 if defined(&can_edit_templates) && &can_edit_templates();
&error(ovmssh_text('ssh_ecannot', 'You cannot manage SSH keys from OpenVM SSH'));
}

sub ovmssh_current_domain
{
my ($hint) = @_;
$hint ||= {};
ovmssh_load_virtualmin();
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
# authorized_keys path for a user
# ---------------------------------------------------------------------------

sub ovmssh_authorized_keys_path
{
my ($unix_user) = @_;
my $cfg      = ovmssh_module_config();
my $ak_rel   = $cfg->{'authorized_keys_file'} || '.ssh/authorized_keys';
my @pwent    = getpwnam($unix_user);
my $home     = @pwent ? $pwent[7] : "/home/$unix_user";
return "$home/$ak_rel";
}

# ---------------------------------------------------------------------------
# Parse authorized_keys into structured records
# ---------------------------------------------------------------------------

sub ovmssh_parse_authorized_keys
{
my ($path) = @_;
return [] unless $path && -r $path;
my @keys;
open(my $fh, '<', $path) or return [];
my $idx = 0;
while (my $line = <$fh>) {
	chomp $line;
	$line =~ s/^\s+//;
	next if !$line || $line =~ /^#/;
	# authorized_keys line format: [options] keytype base64 [comment]
	my $comment = '';
	my $keytype  = '';
	my $key_data = '';
	if ($line =~ /^((?:sk-)?(?:ssh-\w+|ecdsa-sha2-\S+))\s+(\S+)(?:\s+(.*))?$/) {
		$keytype  = $1;
		$key_data = $2;
		$comment  = $3 // '';
		}
	elsif ($line =~ /\s+((?:sk-)?(?:ssh-\w+|ecdsa-sha2-\S+))\s+(\S+)(?:\s+(.*))?$/) {
		$keytype  = $1;
		$key_data = $2;
		$comment  = $3 // '';
		}
	else {
		$comment  = $line;
		$key_data = '';
		}
	push @keys, {
		'idx'      => $idx++,
		'type'     => $keytype || 'unknown',
		'key'      => $key_data ? substr($key_data, 0, 20).'...' : '',
		'key_full' => $key_data,
		'comment'  => $comment,
		'raw'      => $line,
		};
	}
close($fh);
return \@keys;
}

# ---------------------------------------------------------------------------
# List SSH keys for a domain's unix user
# ---------------------------------------------------------------------------

sub ovmssh_list_keys
{
my ($d) = @_;
return [] unless $d && $d->{'unix'};
ovmssh_load_virtualmin();

# Try GPL helper first
if (defined(&list_ssh_pubkeys)) {
	my @keys = eval { &list_ssh_pubkeys($d) };
	return \@keys if !$@ && @keys;
	}

my $path = ovmssh_authorized_keys_path($d->{'user'});
return ovmssh_parse_authorized_keys($path);
}

# ---------------------------------------------------------------------------
# Add an SSH public key — validates format, appends to authorized_keys
# ---------------------------------------------------------------------------

sub ovmssh_add_key
{
my ($d, $key_text, $comment) = @_;
return { 'ok' => 0, 'msg' => 'Dominio no seleccionado' } unless $d;

$key_text =~ s/^\s+//;
$key_text =~ s/\s+$//;
$key_text =~ s/\n.*//s;  # only first line

# Basic format validation
unless ($key_text =~ /^(?:sk-)?(?:ssh-\w+|ecdsa-sha2-\S+)\s+[A-Za-z0-9+\/=]{20,}/) {
	return { 'ok' => 0, 'msg' => 'Formato de clave SSH inválido. Usa el formato: ssh-rsa AAAA... o ssh-ed25519 AAAA...' };
	}

# Append comment if provided
$comment =~ s/[\r\n]//g if $comment;
$key_text .= " $comment" if $comment;

# Try GPL helper
if (defined(&add_ssh_pubkey)) {
	my $err = eval { &add_ssh_pubkey($d, $key_text) };
	return { 'ok' => 1, 'msg' => 'Clave añadida via Virtualmin GPL' } if !$@ && !$err;
	}

# Fallback: write directly
my $path = ovmssh_authorized_keys_path($d->{'user'});
my $dir  = $path; $dir =~ s/\/[^\/]+$//;

unless (-d $dir) {
	make_path($dir, { mode => 0700 }) or
		return { 'ok' => 0, 'msg' => "No se pudo crear el directorio $dir" };
	}

open(my $fh, '>>', $path) or
	return { 'ok' => 0, 'msg' => "No se pudo escribir en $path: $!" };
print $fh "$key_text\n";
close($fh);
chmod(0600, $path);

# Fix ownership
my @pwent = getpwnam($d->{'user'});
if (@pwent) {
	chown($pwent[2], $pwent[3], $path, $dir);
	}

return { 'ok' => 1, 'msg' => 'Clave SSH añadida correctamente' };
}

# ---------------------------------------------------------------------------
# Delete a key by index
# ---------------------------------------------------------------------------

sub ovmssh_delete_key
{
my ($d, $idx) = @_;
return { 'ok' => 0, 'msg' => 'Dominio no seleccionado' } unless $d;

my $path = ovmssh_authorized_keys_path($d->{'user'});
return { 'ok' => 0, 'msg' => 'No se encontró el archivo authorized_keys' } unless -r $path;

open(my $fh, '<', $path) or
	return { 'ok' => 0, 'msg' => "No se pudo leer $path: $!" };
my @lines = <$fh>;
close($fh);

my $i = 0;
my @new_lines;
foreach my $line (@lines) {
	my $trimmed = $line; $trimmed =~ s/^\s+//; $trimmed =~ s/\s+$//;
	if ($trimmed && $trimmed !~ /^#/) {
		push @new_lines, $line unless $i == $idx;
		$i++;
		}
	else {
		push @new_lines, $line;
		}
	}

open(my $out, '>', $path) or
	return { 'ok' => 0, 'msg' => "No se pudo escribir en $path: $!" };
print $out @new_lines;
close($out);
chmod(0600, $path);
return { 'ok' => 1, 'msg' => 'Clave eliminada correctamente' };
}

# ---------------------------------------------------------------------------
# Summary for a domain
# ---------------------------------------------------------------------------

sub ovmssh_domain_summary
{
my ($d) = @_;
return { 'keys' => 0 } unless $d;
my $keys = ovmssh_list_keys($d);
return { 'keys' => scalar @$keys };
}

1;
