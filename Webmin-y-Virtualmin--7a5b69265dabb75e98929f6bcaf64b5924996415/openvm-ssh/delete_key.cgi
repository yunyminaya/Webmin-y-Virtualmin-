#!/usr/bin/perl

use strict;
use warnings;

our %in;

require './openvm-ssh-lib.pl';
&ReadParse();
&require_acl();

&ovmssh_require_access();
&ovmssh_load_virtualmin();

my $d   = &ovmssh_current_domain({});
my $idx = defined($in{'idx'}) ? int($in{'idx'}) : -1;

&header('Eliminar clave SSH', '');
print "<div style='max-width:760px;margin:0 auto;padding:20px;font-family:Arial,sans-serif'>\n";

unless ($d && $idx >= 0) {
	print "<div style='background:#f8d7da;border:1px solid #f5c6cb;border-radius:6px;padding:16px'>\n";
	print "<p style='margin:0;color:#721c24'>Par&aacute;metros inválidos. <a href='index.cgi'>Volver</a></p>\n";
	print "</div>\n";
	&footer(); exit 0;
	}

my $result = &ovmssh_delete_key($d, $idx);

if ($result->{'ok'}) {
	print "<div style='background:#d4edda;border:1px solid #c3e6cb;border-radius:6px;padding:16px;margin-bottom:20px'>\n";
	print "<h3 style='margin:0 0 8px;color:#155724'>&#10003; Clave eliminada</h3>\n";
	print "<p style='margin:0;color:#155724'>$result->{'msg'}</p>\n";
	print "</div>\n";
	}
else {
	print "<div style='background:#f8d7da;border:1px solid #f5c6cb;border-radius:6px;padding:16px;margin-bottom:20px'>\n";
	print "<h3 style='margin:0 0 8px;color:#721c24'>&#10008; Error al eliminar</h3>\n";
	print "<p style='margin:0;color:#721c24'>$result->{'msg'}</p>\n";
	print "</div>\n";
	}

print "<p><a href='keys.cgi?id=$d->{'id'}' style='display:inline-block;padding:8px 18px;background:#3498db;color:white;text-decoration:none;border-radius:4px'>Ver claves del dominio</a></p>\n";
print "</div>\n";
&footer();
