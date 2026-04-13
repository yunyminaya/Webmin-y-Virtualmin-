#!/usr/bin/perl

use FindBin;
chdir("$FindBin::Bin/..");
require './pro/openvm-compat-lib.pl';

&ReadParse();

my $d = compat_current_domain();
$d || &error($text{'cert_title'} || 'No virtual server selected');
&can_edit_domain($d) || &error($text{'cert_ecannot'} || 'You cannot manage certificates for this virtual server');

print &redirect("../cert_form.cgi?dom=".&urlize($d->{'id'}).'&mode=lets');
exit;
