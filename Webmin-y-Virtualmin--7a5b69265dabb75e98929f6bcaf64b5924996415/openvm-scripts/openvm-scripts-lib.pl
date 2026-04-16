#!/usr/bin/perl

use strict;
use warnings;

our (%in, %text, $module_config_directory, $base_remote_user);
our $OPENVM_SCRIPTS_VIRTUALMIN_LOADED = 0;

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

sub ovmsc_text
{
my ($key, $fallback) = @_;
return exists($text{$key}) && defined($text{$key}) && $text{$key} ne ''
	? $text{$key}
	: $fallback;
}

sub ovmsc_module_config
{
my %config = (
	'feature_wordpress' => 1,
	'feature_drupal'    => 1,
	'feature_joomla'    => 1,
	'feature_laravel'   => 1,
	'feature_composer'  => 1,
	'wpcli_path'        => '',
	'composer_path'     => '',
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

sub ovmsc_load_virtualmin
{
return 1 if $OPENVM_SCRIPTS_VIRTUALMIN_LOADED;
&foreign_require("virtual-server", "virtual-server-lib.pl");
$OPENVM_SCRIPTS_VIRTUALMIN_LOADED = 1;
return 1;
}

sub ovmsc_require_access
{
ovmsc_load_virtualmin();
return 1 if defined(&master_admin) && &master_admin();
return 1 if defined(&can_install_scripts) && &can_install_scripts();
return 1 if defined(&can_edit_templates) && &can_edit_templates();
&error(ovmsc_text('scripts_ecannot', 'You cannot manage script installs from OpenVM Scripts'));
}

sub ovmsc_current_domain
{
my ($hint) = @_;
$hint ||= {};
ovmsc_load_virtualmin();
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
# Tool detection
# ---------------------------------------------------------------------------

sub ovmsc_find_binary
{
my ($names_ref) = @_;
for my $name (@$names_ref) {
	for my $dir (qw(/usr/local/bin /usr/bin /root/.composer/vendor/bin
			/root/.config/composer/vendor/bin)) {
		return "$dir/$name" if -x "$dir/$name";
		}
	my $which = `which \Q$name\E 2>/dev/null`;
	chomp $which;
	return $which if $which && -x $which;
	}
return undef;
}

sub ovmsc_tool_status
{
my $cfg = ovmsc_module_config();

my $wpcli    = $cfg->{'wpcli_path'} && -x $cfg->{'wpcli_path'}
		? $cfg->{'wpcli_path'}
		: ovmsc_find_binary(['wp', 'wp-cli']);
my $composer = $cfg->{'composer_path'} && -x $cfg->{'composer_path'}
		? $cfg->{'composer_path'}
		: ovmsc_find_binary(['composer', 'composer.phar']);
my $drush    = ovmsc_find_binary(['drush']);
my $node     = ovmsc_find_binary(['node', 'nodejs']);
my $npm      = ovmsc_find_binary(['npm']);
my $php      = ovmsc_find_binary(['php']);
my $git      = ovmsc_find_binary(['git']);

return {
	'wp-cli'   => $wpcli,
	'composer' => $composer,
	'drush'    => $drush,
	'node'     => $node,
	'npm'      => $npm,
	'php'      => $php,
	'git'      => $git,
	};
}

# ---------------------------------------------------------------------------
# Apps catalog (native, no license gate)
# ---------------------------------------------------------------------------

sub ovmsc_apps_catalog
{
my $cfg    = ovmsc_module_config();
my $tools  = ovmsc_tool_status();
my @apps;

push(@apps, {
	'id'          => 'wordpress',
	'name'        => 'WordPress',
	'category'    => 'CMS',
	'tool'        => 'wp-cli',
	'tool_bin'    => $tools->{'wp-cli'},
	'available'   => $cfg->{'feature_wordpress'} ? 1 : 0,
	'description' => 'CMS más popular del mundo, instalación via WP-CLI',
	'install_cmd' => 'wp core download --allow-root && wp config create --allow-root && wp core install --allow-root',
	});

push(@apps, {
	'id'          => 'drupal',
	'name'        => 'Drupal',
	'category'    => 'CMS',
	'tool'        => 'composer+drush',
	'tool_bin'    => $tools->{'composer'},
	'available'   => $cfg->{'feature_drupal'} ? 1 : 0,
	'description' => 'CMS empresarial, instalación via Composer + Drush',
	'install_cmd' => 'composer create-project drupal/recommended-project .',
	});

push(@apps, {
	'id'          => 'joomla',
	'name'        => 'Joomla',
	'category'    => 'CMS',
	'tool'        => 'composer',
	'tool_bin'    => $tools->{'composer'},
	'available'   => $cfg->{'feature_joomla'} ? 1 : 0,
	'description' => 'CMS multipropósito, instalación via Composer',
	'install_cmd' => 'composer create-project joomla/joomla-cms .',
	});

push(@apps, {
	'id'          => 'laravel',
	'name'        => 'Laravel',
	'category'    => 'Framework PHP',
	'tool'        => 'composer',
	'tool_bin'    => $tools->{'composer'},
	'available'   => $cfg->{'feature_laravel'} ? 1 : 0,
	'description' => 'Framework PHP moderno, instalación via Composer',
	'install_cmd' => 'composer create-project laravel/laravel .',
	});

push(@apps, {
	'id'          => 'nextcloud',
	'name'        => 'Nextcloud',
	'category'    => 'Colaboración',
	'tool'        => 'php',
	'tool_bin'    => $tools->{'php'},
	'available'   => 1,
	'description' => 'Plataforma de colaboración y almacenamiento en la nube (auto-hosted)',
	'install_cmd' => 'php occ maintenance:install',
	});

push(@apps, {
	'id'          => 'matomo',
	'name'        => 'Matomo Analytics',
	'category'    => 'Analytics',
	'tool'        => 'php',
	'tool_bin'    => $tools->{'php'},
	'available'   => 1,
	'description' => 'Analytics open source alternativo a Google Analytics',
	'install_cmd' => 'php console install',
	});

push(@apps, {
	'id'          => 'moodle',
	'name'        => 'Moodle',
	'category'    => 'E-learning',
	'tool'        => 'php',
	'tool_bin'    => $tools->{'php'},
	'available'   => 1,
	'description' => 'Plataforma e-learning open source',
	'install_cmd' => 'php admin/cli/install.php',
	});

push(@apps, {
	'id'          => 'ghost',
	'name'        => 'Ghost',
	'category'    => 'Blogging',
	'tool'        => 'npm',
	'tool_bin'    => $tools->{'npm'},
	'available'   => $tools->{'npm'} ? 1 : 0,
	'description' => 'Plataforma de publicación moderna basada en Node.js',
	'install_cmd' => 'npm install ghost-cli -g && ghost install',
	});

return \@apps;
}

# ---------------------------------------------------------------------------
# List installed apps for a domain via GPL scripts-lib
# ---------------------------------------------------------------------------

sub ovmsc_installed_apps
{
my ($d) = @_;
ovmsc_load_virtualmin();
return [] unless $d;

if (defined(&list_domain_scripts)) {
	my @scripts = &list_domain_scripts($d);
	return \@scripts;
	}

# Fallback: scan public_html for known app markers
my $phd = defined(&public_html_dir) ? &public_html_dir($d) : undef;
$phd ||= $d->{'home'} ? "$d->{'home'}/public_html" : undef;
return [] unless $phd && -d $phd;

my @found;
if (-f "$phd/wp-config.php")  { push @found, { 'name' => 'WordPress', 'version' => '' }; }
if (-f "$phd/sites/default/settings.php") { push @found, { 'name' => 'Drupal', 'version' => '' }; }
if (-f "$phd/configuration.php" && -d "$phd/components") { push @found, { 'name' => 'Joomla', 'version' => '' }; }
if (-f "$phd/artisan")        { push @found, { 'name' => 'Laravel', 'version' => '' }; }
if (-f "$phd/config/config.php" && -d "$phd/apps") { push @found, { 'name' => 'Nextcloud', 'version' => '' }; }

return \@found;
}

1;
