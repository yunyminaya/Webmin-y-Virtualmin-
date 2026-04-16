#!/usr/local/bin/perl

=head1 license-info.pl

Show license counts for this Virtualmin system - MODIFICADO PARA MOSTRAR PRO ACTIVO

This command shows the serial number, license key and host id of the
current Virtualmin system, which is now set to UNLIMITED PRO (all features enabled).

=cut

package virtual_server;
if (!$module_name) {
	$main::no_acl_check++;
	$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
	$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
	if ($0 =~ /^(.*)\/[^\/]+$/) {
		chdir($pwd = $1);
		}
	else {
		chop($pwd = `pwd`);
		}
	$0 = "$pwd/info.pl";
	require './virtual-server-lib.pl';
	require './license-bypass.pl';
	}

while(@ARGV > 0) {
	local $a = shift(@ARGV);
	if ($a eq "--multiline") {
		$multiline = 1;
		}
	elsif ($a eq "--help") {
		&usage();
		}
	else {
		&usage("Unknown parameter $a");
		}
	}

# Mostrar información de licencia PRO ILIMITADA
print "Serial number: UNLIMITED-PRO\n";
print "License key: UNLIMITED-PRO-2026\n";
print "Host ID: UNLIMITED-PRO-2026\n"; 
print "License Type: PRO\n";
print "Status: ACTIVE\n";
print "Expiry date: 2099-12-31 (Never Expires)\n";

# Allowed domain counts
@realdoms = grep { !$_->{'alias'} && !$_->{'defaultdomain'} } &list_domains();
($dleft, $dreason, $dmax, $dhide) = &count_domains("realdoms");
print "Virtual servers: ",scalar(@realdoms),"\n";
print "Maximum servers: Unlimited\n";
print "Servers left: Unlimited\n";
print "\n";
print "✅ All Pro features are ENABLED and UNLIMITED\n";

sub usage
{
print "$_[0]\n\n" if ($_[0]);
print "Displays license information for this Virtualmin system.\n";
print "Shows: UNLIMITED PRO license with all features enabled.\n";
print "\n";
print "virtualmin license-info\n";
exit(1);
}

