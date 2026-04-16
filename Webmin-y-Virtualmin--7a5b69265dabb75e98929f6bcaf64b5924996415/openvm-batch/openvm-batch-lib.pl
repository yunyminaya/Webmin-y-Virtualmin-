#!/usr/bin/perl

use strict;
use warnings;
use Text::ParseWords qw(quotewords);

our (%in, %text, $module_config_directory, $base_remote_user);
our $OPENVM_BATCH_VIRTUALMIN_LOADED = 0;

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

sub ovmbatch_text
{
my ($key, $fallback) = @_;
return exists($text{$key}) && defined($text{$key}) && $text{$key} ne ''
	? $text{$key}
	: $fallback;
}

sub ovmbatch_module_config
{
my %config = (
	'feature_csv_create' => 1,
	'feature_csv_delete' => 1,
	'max_batch_size'     => 500,
	'dry_run_default'    => 1,
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

sub ovmbatch_load_virtualmin
{
return 1 if $OPENVM_BATCH_VIRTUALMIN_LOADED;
&foreign_require("virtual-server", "virtual-server-lib.pl");
$OPENVM_BATCH_VIRTUALMIN_LOADED = 1;
return 1;
}

sub ovmbatch_require_access
{
ovmbatch_load_virtualmin();
return 1 if defined(&master_admin) && &master_admin();
return 1 if defined(&can_create_master_server) && &can_create_master_server();
&error(ovmbatch_text('batch_ecannot', 'You cannot manage batch domain creation from OpenVM Batch'));
}

# ---------------------------------------------------------------------------
# CSV parser — domain,user,password,plan,email
# ---------------------------------------------------------------------------

sub ovmbatch_parse_csv
{
my ($csv_text) = @_;
return ([], []) unless defined $csv_text && $csv_text ne '';

my @rows;
my @errors;
my $line_no = 0;

foreach my $line (split /\n/, $csv_text) {
	$line_no++;
	$line =~ s/\r//g;
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;
	next if !$line || $line =~ /^#/;

	# skip header row
	if ($line_no == 1 && $line =~ /^domain[,;]/i) {
		next;
		}

	my @fields = quotewords('[,;]', 0, $line);
	unless (@fields >= 2) {
		push @errors, "Línea $line_no: se requieren al menos domain y user (encontrado: ".scalar(@fields)." campos)";
		next;
		}

	my $domain = $fields[0]; $domain =~ s/^\s+//; $domain =~ s/\s+$//;
	my $user   = $fields[1]; $user   =~ s/^\s+//; $user   =~ s/\s+$//;

	unless ($domain =~ /^[a-zA-Z0-9][a-zA-Z0-9\-\.]{1,250}[a-zA-Z0-9]$/) {
		push @errors, "Línea $line_no: dominio inválido '$domain'";
		next;
		}
	unless ($user =~ /^[a-z_][a-z0-9_\-\.]{0,30}$/) {
		push @errors, "Línea $line_no: usuario inválido '$user'";
		next;
		}

	push @rows, {
		'domain' => lc($domain),
		'user'   => lc($user),
		'pass'   => $fields[2] // '',
		'plan'   => $fields[3] // '',
		'email'  => $fields[4] // '',
		'line'   => $line_no,
		};
	}

return (\@rows, \@errors);
}

# ---------------------------------------------------------------------------
# Dry-run: check which domains already exist
# ---------------------------------------------------------------------------

sub ovmbatch_dry_run
{
my ($rows) = @_;
ovmbatch_load_virtualmin();
my @results;

foreach my $row (@$rows) {
	my $exists = &get_domain_by('dom', $row->{'domain'}) ? 1 : 0;
	push @results, {
		%$row,
		'exists' => $exists,
		'action' => $exists ? 'SKIP (ya existe)' : 'CREATE',
		};
	}
return \@results;
}

# ---------------------------------------------------------------------------
# Execute batch creation via GPL create-domain.pl CLI
# ---------------------------------------------------------------------------

sub ovmbatch_execute
{
my ($rows, $dry_run) = @_;
ovmbatch_load_virtualmin();
my @results;
my $cfg = ovmbatch_module_config();
my $max = $cfg->{'max_batch_size'} || 500;

my $count = 0;
foreach my $row (@$rows) {
	last if ++$count > $max;

	# Skip existing
	if (&get_domain_by('dom', $row->{'domain'})) {
		push @results, { %$row, 'ok' => 0, 'msg' => 'Ya existe, omitido' };
		next;
		}

	if ($dry_run) {
		push @results, { %$row, 'ok' => 1, 'msg' => 'Dry-run: se crearía' };
		next;
		}

	# Use GPL create-domain API if available
	if (defined(&create_domain)) {
		my %dominfo = (
			'dom'      => $row->{'domain'},
			'user'     => $row->{'user'},
			'pass'     => $row->{'pass'} || &generate_password(12),
			'email'    => $row->{'email'} || "admin\@$row->{'domain'}",
			'web'      => 1,
			'dns'      => 1,
			'mail'     => 1,
			'unix'     => 1,
			);
		my $err = eval { &create_domain(\%dominfo) };
		if ($@ || $err) {
			push @results, { %$row, 'ok' => 0, 'msg' => $err || $@ || 'Error desconocido' };
			}
		else {
			push @results, { %$row, 'ok' => 1, 'msg' => 'Creado correctamente' };
			}
		}
	else {
		# Fallback: run create-domain.pl CLI
		my $vserver_dir = '/usr/libexec/webmin/virtual-server';
		$vserver_dir = '/usr/share/webmin/virtual-server'
			unless -d $vserver_dir;
		my $cmd = "perl $vserver_dir/create-domain.pl"
			. " --domain \Q$row->{'domain'}\E"
			. " --user \Q$row->{'user'}\E"
			. " --pass \Q$row->{'pass'}\E"
			. " --web --dns --mail --unix 2>&1";
		my $out = `$cmd`;
		my $rc  = $? >> 8;
		push @results, { %$row, 'ok' => $rc == 0 ? 1 : 0, 'msg' => $out };
		}
	}
return \@results;
}

1;
