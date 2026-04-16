#!/usr/bin/perl

use strict;
use warnings;

require './openvm-ssh-lib.pl';

&require_acl();
&header('Claves SSH del dominio', '');

&ovmssh_require_access();
&ovmssh_load_virtualmin();

my $d = &ovmssh_current_domain({});

print "<div style='max-width:960px;margin:0 auto;padding:20px;font-family:Arial,sans-serif'>\n";
print "<h2 style='color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:8px'>Claves SSH</h2>\n";
print "<p><a href='index.cgi' style='color:#3498db'>&larr; Volver</a></p>\n";

unless ($d) {
	print "<div style='background:#f8d7da;border:1px solid #f5c6cb;border-radius:6px;padding:16px'>\n";
	print "<p style='margin:0;color:#721c24'>Dominio no encontrado. <a href='index.cgi?$ENV{QUERY_STRING}' style='color:#721c24'>Reintentar</a></p>\n";
	print "</div>\n";
	&footer();
	exit 0;
	}

my $keys = &ovmssh_list_keys($d);

print "<div style='background:#eaf4fb;border:1px solid #3498db;border-radius:6px;padding:12px;margin-bottom:20px'>\n";
printf "<p style='margin:0'><strong>Dominio:</strong> %s &mdash; <strong>%d</strong> clave(s) configurada(s).</p>\n",
	$d->{'dom'}, scalar @$keys;
print "</div>\n";

print "<p><a href='add_key.cgi?id=$d->{'id'}' style='display:inline-block;padding:8px 18px;background:#2ecc71;color:white;text-decoration:none;border-radius:4px;font-weight:bold'>+ Agregar clave</a></p>\n";

if (@$keys) {
	print "<table style='width:100%;border-collapse:collapse;background:white;box-shadow:0 1px 3px rgba(0,0,0,.1);border-radius:6px;overflow:hidden'>\n";
	print "<thead><tr style='background:#2c3e50;color:white'>\n";
	print "<th style='padding:10px 14px;text-align:left'>#</th>\n";
	print "<th style='padding:10px 14px;text-align:left'>Tipo</th>\n";
	print "<th style='padding:10px 14px;text-align:left'>Comentario</th>\n";
	print "<th style='padding:10px 14px;text-align:left'>Vista previa</th>\n";
	print "<th style='padding:10px 14px;text-align:left'>Acciones</th>\n";
	print "</tr></thead><tbody>\n";

	my $row = 0;
	foreach my $k (@$keys) {
		my $bg     = $row++ % 2 ? '#f9f9f9' : 'white';
		my $idx    = $k->{'idx'};
		my $type   = &html_escape($k->{'type'});
		my $comm   = &html_escape($k->{'comment'});
		my $prev   = &html_escape($k->{'key'});

		print "<tr style='background:$bg'>\n";
		print "<td style='padding:9px 14px;color:#555'>${\($idx+1)}</td>\n";
		print "<td style='padding:9px 14px;font-family:monospace;font-size:13px;color:#2980b9'>$type</td>\n";
		print "<td style='padding:9px 14px;color:#333'>$comm</td>\n";
		print "<td style='padding:9px 14px;font-family:monospace;font-size:12px;color:#7f8c8d'>$prev</td>\n";
		print "<td style='padding:9px 14px'>\n";
		print "<form method='post' action='delete_key.cgi' style='display:inline'\n";
		print "  onsubmit='return confirm(\"¿Eliminar esta clave SSH?\")'>\n";
		print "<input type='hidden' name='id'  value='$d->{'id'}'>\n";
		print "<input type='hidden' name='idx' value='$idx'>\n";
		print "<button type='submit' style='padding:4px 12px;background:#e74c3c;color:white;border:none;border-radius:4px;cursor:pointer;font-size:13px'>Eliminar</button>\n";
		print "</form>\n";
		print "</td></tr>\n";
		}
	print "</tbody></table>\n";
	}
else {
	print "<div style='background:#fef9e7;border:1px solid #f39c12;border-radius:6px;padding:16px;margin-top:16px'>\n";
	print "<p style='margin:0;color:#856404'>No hay claves SSH registradas para este dominio. Usa <a href='add_key.cgi?id=$d->{'id'}' style='color:#856404'>+ Agregar clave</a>.</p>\n";
	print "</div>\n";
	}

print "</div>\n";
&footer();
