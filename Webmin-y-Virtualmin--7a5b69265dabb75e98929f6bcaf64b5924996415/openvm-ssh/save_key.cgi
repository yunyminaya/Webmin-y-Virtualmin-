#!/usr/bin/perl

use strict;
use warnings;

require './openvm-ssh-lib.pl';
&ReadParse();
&require_acl();

&ovmssh_require_access();
&ovmssh_load_virtualmin();

my $d        = &ovmssh_current_domain({});
my $key_text = $in{'key_text'} || '';
my $comment  = $in{'comment'}  || '';

unless ($d) {
	&header('Guardar clave SSH', '');
	print "<p style='color:red;font-family:Arial,sans-serif;padding:20px'>Dominio no encontrado. <a href='index.cgi'>Volver</a></p>\n";
	&footer(); exit 0;
	}

my $result = &ovmssh_add_key($d, $key_text, $comment);

&header('Resultado - Clave SSH', '');
print "<div style='max-width:760px;margin:0 auto;padding:20px;font-family:Arial,sans-serif'>\n";

if ($result->{'ok'}) {
	print "<div style='background:#d4edda;border:1px solid #c3e6cb;border-radius:6px;padding:16px;margin-bottom:20px'>\n";
	print "<h3 style='margin:0 0 8px;color:#155724'>&#10003; Clave a&ntilde;adida correctamente</h3>\n";
	print "<p style='margin:0;color:#155724'>$result->{'msg'}</p>\n";
	print "</div>\n";
	print "<p><a href='keys.cgi?id=$d->{'id'}' style='display:inline-block;padding:8px 18px;background:#3498db;color:white;text-decoration:none;border-radius:4px'>Ver claves del dominio</a></p>\n";
	}
else {
	print "<div style='background:#f8d7da;border:1px solid #f5c6cb;border-radius:6px;padding:16px;margin-bottom:20px'>\n";
	print "<h3 style='margin:0 0 8px;color:#721c24'>&#10008; Error al a&ntilde;adir la clave</h3>\n";
	print "<p style='margin:0;color:#721c24'>$result->{'msg'}</p>\n";
	print "</div>\n";
	print "<p><a href='add_key.cgi?id=$d->{'id'}' style='display:inline-block;padding:8px 18px;background:#2ecc71;color:white;text-decoration:none;border-radius:4px'>Reintentar</a></p>\n";
	}

print "</div>\n";
&footer();
