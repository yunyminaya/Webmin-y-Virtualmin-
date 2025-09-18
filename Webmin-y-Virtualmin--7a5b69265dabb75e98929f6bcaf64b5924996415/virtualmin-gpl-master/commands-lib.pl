# Functions for use by the command-line API

our ($convert_multiline, $convert_idonly, $convert_nameonly, $convert_emailonly,
     $convert_format);

sub list_api_categories
{
return ([ "Backup and restore", "backup-domain.pl", "*-scheduled-backup*.pl",
				"restore-domain.pl", "list-backup-keys.pl",
				"delete-backup.pl", "list-backup-logs.pl" ],
	[ "Virtual servers", "*-domain.pl", "*-domains.pl",
			     "enable-feature.pl", "disable-feature.pl",
			     "get-dns.pl", "modify-dns.pl", "modify-spam.pl",
			     "modify-web.pl", "modify-mail.pl", "resend-email.pl",
			     "fix-domain-quota.pl", "fix-domain-permissions.pl",
			     "list-ports.pl", "list-virtual-servers.pl",
			     "list-redirects.pl", "list-shared-addresses.pl",
			     "reset-feature.pl", "list-bandwidth.pl",
			     "list-features.pl", "check-connectivity.pl" ],
	[ "Mail and FTP users", "*-user.pl", "*-users.pl",
				"list-available-shells.pl",
				"list-mailbox.pl", "reset-pass.pl",
				"search-maillogs.pl", "copy-mailbox.pl",
				"set-spam.pl", "test-imap.pl",
				"test-pop3.pl", "test-smtp.pl",],
	[ "Mail aliases", "*-alias.pl", "*-aliases.pl" ],
	[ "Server owner limits", "*-limit.pl", "*-limits.pl",
				 "modify-resources.pl" ],
	[ "Extra administrators", "*-admin.pl", "*-admins.pl" ],
	[ "Custom fields", "*-custom.pl" ],
	[ "Databases", "*-database.pl", "*-databases.pl",
		       "modify-database-hosts.pl", "modify-database-pass.pl",
		       "set-mysql-pass.pl", "list-mysql-servers.pl" ],
	[ "Reseller accounts", "*-reseller.pl", "*-resellers.pl" ],
	[ "Script installers (web apps)",
			       "install-script.pl", "delete-script.pl",
			       "list-scripts.pl", "list-available-scripts.pl",
			       "detect-scripts.pl", "start-stop-script.pl",
			       "configure-script.pl",
			       "configure-all-scripts.pl" ],
	[ "Proxies and balancers", "*-proxy.pl", "*-proxies.pl" ],
	[ "PHP versions", "*-php-directory.pl", "*-php-directories.pl",
			  "list-php-versions.pl", "list-php-ini.pl",
			  "modify-php-ini.pl" ],
	[ "SSL certificates", "list-certs.pl", "*-cert.pl",
			      "list-certs-expiry.pl", "list-service-certs.pl",
			      "get-ssl.pl", "list-acme-providers.pl" ],
	[ "Virtual server templates", "*-template.pl", "*-templates.pl" ],
	[ "Account plans", "*-plan.pl", "*-plans.pl" ],
	[ "SVN repositories", "*-svn-repositor*.pl" ],
	[ "Amazon S3", "*-s3-*.pl" ],
	[ "Rackspace Cloud Files", "*-rs-*.pl" ],
	$virtualmin_pro ? [ "Dropbox", "*-dropbox-file*.pl" ] : (),
	$virtualmin_pro ? [ "Google Cloud Storage", "*-gcs-*.pl" ] : (),
	[ "License", "*license*" ],
	[ "Repository", "*setup-repos*" ],
	[ "Configuration backups", "list-config-backups.pl",
				   "restore-config-backups.pl" ],
	[ "Other scripts", "*.pl" ],
	);
}

sub list_api_category_descs
{
return (
"Virtual servers",
"Probably the most important programs are those for creating, listing,
modifying and deleting virtual servers. Because these actions may involve
several steps, all of these programs output messages as the proceed, showing
the success or failure of each step. These programs and their options are
documented below.",

"Backup and restore",
"Virtualmin has the ability to backup and restore virtual servers either
manually or on a set schedule, using the web interface. However, you can also
use the command line programs listed below to make backups. This can be used
for doing your own migration to other systems or products, or manually setting
up custom backup schedules for different servers.",

"Mail and FTP users",
"Each Virtualmin virtual server can have users associated with it, each of
which can be a mailbox, an FTP login, or a database user. Users can be created a
ny managed from the command line, using the programs described below.",

"Mail aliases",
"Virtual servers with email enabled can have mail aliases associated with them,
to forward email either to users within the server, or to addresses at some
other domain. Aliases can also be set up to deliver mail to files, or feed
them to programs as input. The programs in this section allow you to manage
mail aliases from the command line.",

"Custom fields",
"If your Virtualmin install has been configured to allow additional custom
fields to be stored for each virtual server, the programs listed in this
section can also be used to manage those fields.",

"Databases",
"All Virtualmin virtual servers with database features enabled can have several
MySQL and PostgreSQL databases associated with them. These can be created and
deleted from the web interface, or using the following programs.",

"Extra administrators",
"All Virtualmin virtual servers can have additional administration accounts
created, which are similar to the server administrator Webmin login, but
possibly with limited capabilities. These extra admin accounts can be
created and managed using the following programs.",

"Reseller accounts",
"If your Virtualmin site uses resellers, they can also be managed using the
command-line programs documented in this section. All of the reseller options
that can be set through the web interface can also be controlled from the
Unix shell prompt.",

"Script installers",
"Virtualmin allows scripts created by other developers to be easily installed
into the virtual servers that it manages. These are typically programs like
Wikis, Blogs and web-based mail readers, often written in PHP. Normally these
are setup through the web interface, but they can be managed by the following
command-line programs as well.",

"Proxies and balancers",
"A proxy maps some URL on a virtual server to another webserver. This means
that requests for any page under that URL path will be forwarded to the
other site, which could be a separate machine or another webserver process
on the same system (such as Tomcat for Java or Mongrel for Ruby on Rails).",

"PHP versions",
"If more than one version of PHP is installed on your system and either CGI
or fCGId is used to run PHP scripts in some virtual server, it can be configured
to run a different PHP version on a per-directory basis. This is most useful
when running PHP applications that only support specific versions, like an
old script that only runs under version 4.",

"SSL certificates",
"Commands in this section can be used to list SSL certificates, generate
new certs, keys and signing requests, and install a signed cert from a CA.",

"Virtual server templates",
"These commands can be list to list, create and modify Virtualmin templates,
which in turn define the initial configuration for virtual servers.",

"Account plans",
"Plans define the quota, allowed functions and other limits on virtual server
owners. These commands can be used to list existing plans, modify their
limits, create new plans, and delete them.",

"SVN repositories",
"For virtual serves with the SVN plugin enabled, these commands can be used
to list, create and delete SVN repositories.",

"Amazon S3",
"These commands can be used to upload files to, download files from and
manage files on Amazon's S3 cloud storage service.",

"License",
"These commands are used to list Virtualmin license info, change license or
downgrade to GPL.",

"Other scripts",
"Programs in this section don't fall into any of the other categories.",
	);
}

sub list_api_skip_scripts
{
return ( "upload-api-docs.pl",
	 "functional-test.pl",
	 "generate-script-sites.pl",
	 "check-scripts.pl",
	 "fetch-script-files.pl",
	 "postinstall.pl",
	 );
}

# list_api_directories(pwd)
# Returns a list of directories to check for API scripts
sub list_api_directories
{
local ($pwd) = @_;
local $par = $pwd;
$par =~ s/\/([^\/]+)$//;
return ( $pwd, glob("$par/virtualmin-*") );
}

# get_api_helper_command()
# Returns the path to the API wrapper command
sub get_api_helper_command
{
if ($config{'api_helper'}) {
	return $config{'api_helper'};
	}
else {
	# Try some directories for writing
	foreach my $dir ("/usr/sbin", "/usr/local/sbin", "/opt/csw/bin") {
		-d $dir || next;
		open(APIWRAPPERTEST, ">$dir/.virtualmin-test") || next;
		close(APIWRAPPERTEST);
		unlink("$dir/.virtualmin-test");
		return "$dir/virtualmin";
		}
	return undef;
	}
}

# create_api_helper_command([&extra-dirs])
# Creates the API helper command. Returns either 1 and the path, or 0 and
# an error message.
sub create_api_helper_command
{
local ($extradirs) = @_;
local @dirs = ( $module_root_directory );
push(@dirs, @$extradirs) if ($extradirs);
local $dirstr = join(" ", @dirs);
local $api_helper_command = &get_api_helper_command();
if (!$api_helper_command) {
	return (0, "No writable path configured or auto-detected");
	}
local $bash = &has_command("bash") || &has_command("sh");
if ($bash) {
	&open_tempfile(HELPER, ">$api_helper_command", 1, 0) ||
		return (0, "Failed to write to $api_helper_command : $!");
	&print_tempfile(HELPER, <<EOF);
#!$bash
WEBMIN_CONFIG=$config_directory
WEBMIN_VAR=$var_directory
PERLLIB=${root_directory}:${root_directory}/vendor_perl
WRAPPER_ORIGINAL_PWD=`pwd`
unset SCRIPT_NAME
unset FOREIGN_MODULE_NAME
unset SERVER_ROOT
unset SCRIPT_FILENAME
export WEBMIN_CONFIG WEBMIN_VAR PERLLIB SCRIPT_NAME FOREIGN_MODULE_NAME SERVER_ROOT SCRIPT_FILENAME WRAPPER_ORIGINAL_PWD
cd $module_root_directory
id -a | grep -i uid=0 >/dev/null
if [ "\$?" != 0 ]; then
	echo "$api_helper_command must be run as root"
	exit 2
fi
if [ "\$1" = "" -o "\$1" = "help" -a "\$2" = "" -o "\$1" = "--help" -a "\$2" = "" -o "\$1" = "-help" -a "\$2" = "" ]; then
	echo "usage: $api_helper_command <command> [args..]"
	echo "   or: $api_helper_command help <command>"
	echo ""
	echo "Available commands :"
	echo ""
	COMMAND=list-commands
else
	COMMAND=\$1
	COMMANDINITIAL=\$COMMAND
fi
shift
if [ "\$COMMAND" = "help" ]; then
	help=1
	COMMAND=\$1
	shift
fi
echo \$COMMAND | grep '\\.pl' > /dev/null
if [ "\$?" != "0" ]; then
	COMMAND="\$COMMAND.pl"
fi
for dir in $dirstr; do
	if [ -x "\$dir/\$COMMAND" ]; then
		if [ "\$help" = "1" ]; then
			exec perldoc \$dir/\$COMMAND
		else
			if [[ "\$@" == "--help" ]]; then
				echo "See \\`virtualmin help \$COMMANDINITIAL\\` for more details and examples"
				echo ""
			fi
			exec \$dir/\$COMMAND "\$@"
		fi
	fi
done
echo Command \$COMMAND was not found
exit 1
EOF
	&close_tempfile(HELPER);
	&set_ownership_permissions(undef, undef, 0755, $api_helper_command);
	return (1, $api_helper_command);
	}
else {
	return (0, "bash was not found");
	}
}

# parse_common_cli_flags(&argv)
# Parses and updates the provided argv, and sets global variables $multiline,
# $idonly, $nameonly. May also start capturing output for XML and JSON.
sub parse_common_cli_flags
{
my ($argv) = @_;
my $i = 0;
while($i < @$argv) {
	if ($argv->[$i] eq "--multiline") {
		$convert_multiline = $multiline = 1;
		splice(@$argv, $i, 1);
		}
	elsif ($argv->[$i] eq "--simple-multiline") {
		$convert_multiline = $multiline = 2;
		splice(@$argv, $i, 1);
		}
	elsif ($argv->[$i] eq "--id-only") {
		$convert_idonly = $idonly = 1;
		splice(@$argv, $i, 1);
		}
	elsif ($argv->[$i] eq "--name-only") {
		$convert_nameonly = $nameonly = 1;
		splice(@$argv, $i, 1);
		}
	elsif ($argv->[$i] eq "--email-only") {
		$convert_emailonly = $emailonly = 1;
		splice(@$argv, $i, 1);
		}
	elsif ($argv->[$i] =~ /^--(xml|json)$/) {
		&cli_convert_remote_format($1);
		$convert_format = $1;
		splice(@$argv, $i, 1);
		if (!$multiline && !$idonly && !$nameonly && !$emailonly) {
			$convert_multiline = $multiline = 1;
			}
		}
	elsif ($argv->[$i] eq "--help") {
		&usage();
		}
	else {
		$i++;
		}
	}
}

# cli_convert_remote_format(format)
# Catches and displays Virtualmin CLI standard listing
# commands in JSON or XML format. Returns 1 if the output
# should be multiline, 0 if not.
sub cli_convert_remote_format
{
my ($format) = @_;
return 0 if ($convert_remote_format_pid);

my ($lines, $fh, $ofh);
# Redirect STDOUT to a variable
open ($fh, '>', \$lines) || return;
# Save the original STDOUT
$ofh = select($fh);
$convert_remote_format_pid = $$;

# Setup end handler to convert saved output
END {
	return if ($$ != $convert_remote_format_pid);
	no warnings 'closure';
	# Restore the original STDOUT
	select($ofh);

	# Convert output to XML or JSON
	my $program = $0;
	$program =~ s/^.*\///;
	my %fakein = ( 'multiline' => $convert_multiline,
		       'id-only' => $convert_idonly,
		       'name-only' => $convert_nameonly,
		       'email-only' => $convert_emailonly );
	print &convert_remote_format($lines, $?, $program,
				     \%fakein, $convert_format);
	}
return 1;
}

# can_remote(program-name)
# Returns 1 if the current user can execute remote commands
sub can_remote
{
my ($program) = @_;
return &master_admin() || &can_remote_as_user($program);
}

# can_remote_as_user(program-name)
# Returns 1 if given API supports remote commands
# as the current user (not root)
sub can_remote_as_user
{
my ($program) = @_;
if ($program eq "configure-script" ||
    $program eq "configure-all-scripts") {
	return 1;
	}
return 0;
}

1;

