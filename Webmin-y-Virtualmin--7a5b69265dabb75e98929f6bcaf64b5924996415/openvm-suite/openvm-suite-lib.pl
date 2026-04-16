#!/usr/bin/perl

use strict;
use warnings;

our (%text, $module_config_directory);

sub ovms_text
{
my ($key, $fallback) = @_;
return exists($text{$key}) && defined($text{$key}) && $text{$key} ne ''
	? $text{$key}
	: $fallback;
}

sub ovms_module_config
{
my %config = (
	'show_openvm_core' => 1,
	'show_openvm_admin' => 1,
	'show_openvm_ssl' => 1,
	'show_openvm_scripts' => 1,
	'show_openvm_mail' => 1,
	'show_openvm_monitoring' => 1,
	'show_openvm_batch' => 1,
	'show_openvm_php' => 1,
	'show_openvm_ssh' => 1,
	'show_security_modules' => 1,
	'show_infra_modules' => 1,
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

sub ovms_modules_catalog
{
my $config = ovms_module_config();
my @modules;

if ($config->{'show_openvm_core'}) {
	push(@modules,
		{
			'name' => 'OpenVM Core',
			'path' => '../openvm-core/index.cgi',
			'description' => 'HTML editor, connectivity checks, mail log search, backup keys and remote DNS inventory.',
			'group' => 'OpenVM'
			});
	}

if ($config->{'show_openvm_admin'}) {
	push(@modules,
		{
			'name' => 'OpenVM Administration',
			'path' => '../openvm-admin/index.cgi',
			'description' => 'Delegated administration, extra admins, reseller inventory and operational audit.',
			'group' => 'OpenVM'
			});
	push(@modules,
		{
			'name' => 'OpenVM DNS',
			'path' => '../openvm-dns/index.cgi',
			'description' => 'Cloud DNS inventory and remote DNS operations over the GPL runtime.',
			'group' => 'OpenVM'
			});
	push(@modules,
		{
			'name' => 'OpenVM Backup',
			'path' => '../openvm-backup/index.cgi',
			'description' => 'Backup schedules, key inventory and restore preparation over the GPL runtime.',
			'group' => 'OpenVM'
			});
	}

if ($config->{'show_openvm_ssl'}) {
	push(@modules,
		{
			'name' => 'OpenVM SSL Manager',
			'path' => '../openvm-ssl/index.cgi',
			'description' => 'Gestión avanzada de certificados SSL: Let\'s Encrypt, ZeroSSL y BuyPass con renovación automática vía ACME.',
			'group' => 'OpenVM'
			});
	}

if ($config->{'show_openvm_scripts'}) {
	push(@modules,
		{
			'name' => 'OpenVM Script Installer',
			'path' => '../openvm-scripts/index.cgi',
			'description' => 'Instalador nativo de aplicaciones web: WordPress, Drupal, Joomla, Laravel, Nextcloud, Ghost y más.',
			'group' => 'OpenVM'
			});
	}

if ($config->{'show_openvm_mail'}) {
	push(@modules,
		{
			'name' => 'OpenVM Mail Manager',
			'path' => '../openvm-mail/index.cgi',
			'description' => 'Filtros de correo, cuotas de buzones y políticas de limpieza automática por dominio.',
			'group' => 'OpenVM'
			});
	}

if ($config->{'show_openvm_monitoring'}) {
	push(@modules,
		{
			'name' => 'OpenVM Monitoring',
			'path' => '../openvm-monitoring/index.cgi',
			'description' => 'Monitoreo nativo de CPU, RAM, disco, ancho de banda y procesos con gráficas en tiempo real.',
			'group' => 'OpenVM'
			});
	}

if ($config->{'show_openvm_batch'}) {
	push(@modules,
		{
			'name' => 'OpenVM Batch Manager',
			'path' => '../openvm-batch/index.cgi',
			'description' => 'Creación masiva de dominios desde CSV con modo dry-run y confirmación previa.',
			'group' => 'OpenVM'
			});
	}

if ($config->{'show_openvm_php'}) {
	push(@modules,
		{
			'name' => 'OpenVM PHP Manager',
			'path' => '../openvm-php/index.cgi',
			'description' => 'Gestión de múltiples versiones PHP, configuración por directorio y ajuste de ini por dominio.',
			'group' => 'OpenVM'
			});
	}

if ($config->{'show_openvm_ssh'}) {
	push(@modules,
		{
			'name' => 'OpenVM SSH Keys',
			'path' => '../openvm-ssh/index.cgi',
			'description' => 'Gestión de claves SSH autorizadas por dominio: agregar, listar y eliminar claves públicas.',
			'group' => 'OpenVM'
			});
	}

if ($config->{'show_security_modules'}) {
	push(@modules,
		{
			'name' => 'Intelligent Firewall',
			'path' => '../intelligent-firewall/index.cgi',
			'description' => 'Adaptive security module already present in the repository.',
			'group' => 'Security'
			},
		{
			'name' => 'Zero Trust',
			'path' => '../zero-trust/index.cgi',
			'description' => 'Zero-trust orchestration and contextual control.',
			'group' => 'Security'
			},
		{
			'name' => 'SIEM',
			'path' => '../siem/index.cgi',
			'description' => 'Event correlation, forensic workflows and audit consolidation.',
			'group' => 'Security'
			});
	}

if ($config->{'show_infra_modules'}) {
	push(@modules,
		{
			'name' => 'Multi-cloud Integration',
			'path' => '../multi_cloud_integration/webmin_integration.cgi',
			'description' => 'Unified cloud integration already available in the workspace.',
			'group' => 'Infrastructure'
			});
	}

return \@modules;
}

sub ovms_grouped_catalog
{
my $modules = ovms_modules_catalog();
my %grouped;
foreach my $module (@$modules) {
	push(@{$grouped{$module->{'group'}}}, $module);
	}
return \%grouped;
}

1;
