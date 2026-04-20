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
	# Core
	'show_openvm_core'        => 1,
	'show_openvm_admin'       => 1,
	'show_openvm_suite'       => 1,
	# Servicios Web
	'show_openvm_dns'         => 1,
	'show_openvm_ssl'         => 1,
	'show_openvm_php'         => 1,
	'show_openvm_scripts'     => 1,
	'show_openvm_ssh'         => 1,
	# Infraestructura
	'show_openvm_backup'      => 1,
	'show_openvm_monitoring'  => 1,
	'show_openvm_dashboard'   => 1,
	'show_openvm_api'         => 1,
	# Base de Datos
	'show_openvm_db'          => 1,
	# Email
	'show_openvm_mail'        => 1,
	'show_openvm_notifications' => 1,
	# Automatizacion
	'show_openvm_cron'        => 1,
	'show_openvm_batch'       => 1,
	# Negocio
	'show_openvm_billing'     => 1,
	# Security / Infra (legacy)
	'show_security_modules'   => 1,
	'show_infra_modules'      => 1,
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

# ── Core ──────────────────────────────────────────────────────────
if ($config->{'show_openvm_core'}) {
	push(@modules,
		{
			'id'          => 'openvm-core',
			'name'        => 'OpenVM Core',
			'path'        => '../openvm-core/index.cgi',
			'icon'        => '⚙️',
			'description' => 'HTML editor, connectivity checks, mail log search, backup keys and remote DNS inventory.',
			'category'    => 'Core',
			'version'     => '1.0.0',
		});
	}

if ($config->{'show_openvm_admin'}) {
	push(@modules,
		{
			'id'          => 'openvm-admin',
			'name'        => 'OpenVM Administration',
			'path'        => '../openvm-admin/index.cgi',
			'icon'        => '👤',
			'description' => 'Delegated administration, extra admins, reseller inventory and operational audit.',
			'category'    => 'Core',
			'version'     => '1.0.0',
		});
	}

if ($config->{'show_openvm_suite'}) {
	push(@modules,
		{
			'id'          => 'openvm-suite',
			'name'        => 'OpenVM Suite',
			'path'        => '../openvm-suite/index.cgi',
			'icon'        => '📦',
			'description' => 'Unified entry point for all OpenVM modules. Navigate and manage every component from one dashboard.',
			'category'    => 'Core',
			'version'     => '2.0.0',
		});
	}

# ── Servicios Web ─────────────────────────────────────────────────
if ($config->{'show_openvm_dns'}) {
	push(@modules,
		{
			'id'          => 'openvm-dns',
			'name'        => 'OpenVM DNS',
			'path'        => '../openvm-dns/index.cgi',
			'icon'        => '🌐',
			'description' => 'Visual DNS zone editor with SPF/DKIM/DMARC wizard, DNSSEC management and propagation checker.',
			'category'    => 'Servicios Web',
			'version'     => '2.0.0',
		});
	}

if ($config->{'show_openvm_ssl'}) {
	push(@modules,
		{
			'id'          => 'openvm-ssl',
			'name'        => 'OpenVM SSL Manager',
			'path'        => '../openvm-ssl/index.cgi',
			'icon'        => '🔒',
			'description' => 'Gestión avanzada de certificados SSL: Let\'s Encrypt, ZeroSSL y BuyPass con renovación automática vía ACME.',
			'category'    => 'Servicios Web',
			'version'     => '1.0.0',
		});
	}

if ($config->{'show_openvm_php'}) {
	push(@modules,
		{
			'id'          => 'openvm-php',
			'name'        => 'OpenVM PHP Manager',
			'path'        => '../openvm-php/index.cgi',
			'icon'        => '🐘',
			'description' => 'Gestión de múltiples versiones PHP, configuración por directorio y ajuste de ini por dominio.',
			'category'    => 'Servicios Web',
			'version'     => '1.0.0',
		});
	}

if ($config->{'show_openvm_scripts'}) {
	push(@modules,
		{
			'id'          => 'openvm-scripts',
			'name'        => 'OpenVM Script Installer',
			'path'        => '../openvm-scripts/index.cgi',
			'icon'        => '📥',
			'description' => 'Instalador nativo de aplicaciones web: WordPress, Drupal, Joomla, Laravel, Nextcloud, Ghost y más.',
			'category'    => 'Servicios Web',
			'version'     => '1.0.0',
		});
	}

if ($config->{'show_openvm_ssh'}) {
	push(@modules,
		{
			'id'          => 'openvm-ssh',
			'name'        => 'OpenVM SSH Keys',
			'path'        => '../openvm-ssh/index.cgi',
			'icon'        => '🔑',
			'description' => 'Gestión de claves SSH autorizadas por dominio: agregar, listar y eliminar claves públicas.',
			'category'    => 'Servicios Web',
			'version'     => '1.0.0',
		});
	}

# ── Infraestructura ───────────────────────────────────────────────
if ($config->{'show_openvm_backup'}) {
	push(@modules,
		{
			'id'          => 'openvm-backup',
			'name'        => 'OpenVM Backup',
			'path'        => '../openvm-backup/index.cgi',
			'icon'        => '💾',
			'description' => 'Backup schedules, encryption key inventory and restore preparation over the GPL runtime.',
			'category'    => 'Infraestructura',
			'version'     => '1.0.0',
		});
	}

if ($config->{'show_openvm_monitoring'}) {
	push(@modules,
		{
			'id'          => 'openvm-monitoring',
			'name'        => 'OpenVM Monitoring',
			'path'        => '../openvm-monitoring/index.cgi',
			'icon'        => '📊',
			'description' => 'Monitoreo nativo de CPU, RAM, disco, ancho de banda y procesos con gráficas en tiempo real.',
			'category'    => 'Infraestructura',
			'version'     => '1.0.0',
		});
	}

if ($config->{'show_openvm_dashboard'}) {
	push(@modules,
		{
			'id'          => 'openvm-dashboard',
			'name'        => 'OpenVM Dashboard',
			'path'        => '../openvm-dashboard/index.cgi',
			'icon'        => '📈',
			'description' => 'Real-time SPA dashboard with server metrics, domain overview, service status and quick actions.',
			'category'    => 'Infraestructura',
			'version'     => '1.0.0',
		});
	}

if ($config->{'show_openvm_api'}) {
	push(@modules,
		{
			'id'          => 'openvm-api',
			'name'        => 'OpenVM API',
			'path'        => '../openvm-api/index.cgi',
			'icon'        => '🔌',
			'description' => 'REST API with JWT authentication, rate limiting, OpenAPI/Swagger docs and full CRUD for all modules.',
			'category'    => 'Infraestructura',
			'version'     => '1.0.0',
		});
	}

# ── Base de Datos ─────────────────────────────────────────────────
if ($config->{'show_openvm_db'}) {
	push(@modules,
		{
			'id'          => 'openvm-db',
			'name'        => 'OpenVM Database Manager',
			'path'        => '../openvm-db/index.cgi',
			'icon'        => '🗄️',
			'description' => 'MySQL and PostgreSQL database manager: create, edit, query, backup, user management and SQL console.',
			'category'    => 'Base de Datos',
			'version'     => '1.0.0',
		});
	}

# ── Email ─────────────────────────────────────────────────────────
if ($config->{'show_openvm_mail'}) {
	push(@modules,
		{
			'id'          => 'openvm-mail',
			'name'        => 'OpenVM Mail Manager',
			'path'        => '../openvm-mail/index.cgi',
			'icon'        => '✉️',
			'description' => 'Complete email management: mailboxes, aliases, queue control, autoresponders, filters and quotas per domain.',
			'category'    => 'Email',
			'version'     => '2.0.0',
		});
	}

if ($config->{'show_openvm_notifications'}) {
	push(@modules,
		{
			'id'          => 'openvm-notifications',
			'name'        => 'OpenVM Notifications',
			'path'        => '../openvm-notifications/index.cgi',
			'icon'        => '🔔',
			'description' => 'Multi-channel notification system: email, SMS, Slack, webhook with templates and delivery history.',
			'category'    => 'Email',
			'version'     => '1.0.0',
		});
	}

# ── Automatizacion ────────────────────────────────────────────────
if ($config->{'show_openvm_cron'}) {
	push(@modules,
		{
			'id'          => 'openvm-cron',
			'name'        => 'OpenVM Cron Manager',
			'path'        => '../openvm-cron/index.cgi',
			'icon'        => '⏰',
			'description' => 'Cron job manager with visual scheduling, pre-built templates, execution logs and syntax validation.',
			'category'    => 'Automatización',
			'version'     => '1.0.0',
		});
	}

if ($config->{'show_openvm_batch'}) {
	push(@modules,
		{
			'id'          => 'openvm-batch',
			'name'        => 'OpenVM Batch Manager',
			'path'        => '../openvm-batch/index.cgi',
			'icon'        => '📋',
			'description' => 'Creación masiva de dominios desde CSV con modo dry-run y confirmación previa.',
			'category'    => 'Automatización',
			'version'     => '1.0.0',
		});
	}

# ── Negocio ───────────────────────────────────────────────────────
if ($config->{'show_openvm_billing'}) {
	push(@modules,
		{
			'id'          => 'openvm-billing',
			'name'        => 'OpenVM Billing',
			'path'        => '../openvm-billing/index.cgi',
			'icon'        => '💳',
			'description' => 'Billing management: hosting plans, client accounts, invoice generation, payment tracking and financial reports.',
			'category'    => 'Negocio',
			'version'     => '1.0.0',
		});
	}

# ── Security (legacy) ─────────────────────────────────────────────
if ($config->{'show_security_modules'}) {
	push(@modules,
		{
			'id'          => 'intelligent-firewall',
			'name'        => 'Intelligent Firewall',
			'path'        => '../intelligent-firewall/index.cgi',
			'icon'        => '🛡️',
			'description' => 'Adaptive security module with ML-based threat detection, dynamic rules and anomaly detection.',
			'category'    => 'Seguridad',
			'version'     => '1.0.0',
		},
		{
			'id'          => 'zero-trust',
			'name'        => 'Zero Trust',
			'path'        => '../zero-trust/index.cgi',
			'icon'        => '🔐',
			'description' => 'Zero-trust orchestration, contextual access control and continuous monitoring.',
			'category'    => 'Seguridad',
			'version'     => '1.0.0',
		},
		{
			'id'          => 'siem',
			'name'        => 'SIEM',
			'path'        => '../siem/index.cgi',
			'icon'        => '🔍',
			'description' => 'Event correlation, forensic workflows, blockchain audit trails and compliance reporting.',
			'category'    => 'Seguridad',
			'version'     => '1.0.0',
		});
	}

# ── Infrastructure (legacy) ───────────────────────────────────────
if ($config->{'show_infra_modules'}) {
	push(@modules,
		{
			'id'          => 'multi-cloud',
			'name'        => 'Multi-cloud Integration',
			'path'        => '../multi_cloud_integration/webmin_integration.cgi',
			'icon'        => '☁️',
			'description' => 'Unified multi-cloud integration: AWS, GCP, Azure with cost optimization and migration tools.',
			'category'    => 'Infraestructura',
			'version'     => '1.0.0',
		});
	}

return \@modules;
}

sub ovms_grouped_catalog
{
my $modules = ovms_modules_catalog();
my %grouped;
foreach my $module (@$modules) {
	push(@{$grouped{$module->{'category'}}}, $module);
	}
return \%grouped;
}

sub ovms_category_order
{
my @order = (
	'Core',
	'Servicios Web',
	'Infraestructura',
	'Base de Datos',
	'Email',
	'Automatización',
	'Negocio',
	'Seguridad',
	);
return \@order;
}

sub ovms_category_icon
{
my ($category) = @_;
my %icons = (
	'Core'            => '⭐',
	'Servicios Web'   => '🌍',
	'Infraestructura' => '🏗️',
	'Base de Datos'   => '🗄️',
	'Email'           => '📧',
	'Automatización'  => '🤖',
	'Negocio'         => '💰',
	'Seguridad'       => '🛡️',
	);
return $icons{$category} || '📁';
}

sub ovms_count_modules
{
my $modules = ovms_modules_catalog();
return scalar(@$modules);
}

1;
