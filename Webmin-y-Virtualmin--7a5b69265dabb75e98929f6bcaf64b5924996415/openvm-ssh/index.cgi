#!/usr/bin/perl

use strict;
use warnings;

require './openvm-ssh-lib.pl';

&require_acl();
&header('OpenVM SSH Keys', '');

&ovmssh_require_access();
&ovmssh_load_virtualmin();

my $d = &ovmssh_current_domain({});

print "<div style='max-width:960px;margin:0 auto;padding:20px;font-family:Arial,sans-serif'>\n";
print "<h2 style='color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:8px'>OpenVM SSH Keys</h2>\n";
print "<p style='color:#7f8c8d'>Gesti&oacute;n de claves SSH autorizadas por dominio / usuario.</p>\n";

# Domain selector
my @domains = &list_visible_domains();
print "<form method='get' action='index.cgi' style='margin-bottom:20px'>\n";
print "<label><strong>Dominio:</strong></label> ";
print "<select name='id' onchange='this.form.submit()' style='padding:6px;border-radius:4px;border:1px solid #ccc'>\n";
print "<option value=''>-- Seleccionar dominio --</option>\n";
foreach my $dom (@domains) {
	my $sel = ($d && $d->{'id'} eq $dom->{'id'}) ? " selected" : "";
	print "<option value='$dom->{'id'}'$sel>$dom->{'dom'}</option>\n";
	}
print "</select>&nbsp;<button type='submit' style='padding:6px 14px;background:#3498db;color:white;border:none;border-radius:4px;cursor:pointer'>Ver</button>\n";
print "</form>\n";

if ($d) {
	my $sum  = &ovmssh_domain_summary($d);
	my $keys = $sum->{'keys'};

	print "<div style='background:#eaf4fb;border:1px solid #3498db;border-radius:6px;padding:16px;margin-bottom:24px'>\n";
	print "<h3 style='margin:0 0 8px;color:#2980b9'>$d->{'dom'}</h3>\n";
	printf "<p style='margin:0;font-size:15px'>Claves SSH registradas: <strong>%d</strong></p>\n", $keys;
	print "</div>\n";

	print "<div style='display:flex;gap:12px;flex-wrap:wrap;margin-bottom:30px'>\n";

	my @actions = (
		{ 'url' => "keys.cgi?id=$d->{'id'}", 'label' => 'Ver Claves',    'color' => '#3498db' },
		{ 'url' => "add_key.cgi?id=$d->{'id'}", 'label' => 'Agregar Clave', 'color' => '#2ecc71' },
		);
	foreach my $act (@actions) {
		print "<a href='$act->{'url'}' style='display:block;padding:14px 22px;background:$act->{'color'};color:white;text-decoration:none;border-radius:6px;font-weight:bold;font-size:14px'>$act->{'label'}</a>\n";
		}
	print "</div>\n";
	}
else {
	print "<div style='background:#fef9e7;border:1px solid #f39c12;border-radius:6px;padding:16px;margin-bottom:24px'>\n";
	print "<p style='margin:0;color:#856404'>Selecciona un dominio para gestionar sus claves SSH.</p>\n";
	print "</div>\n";
	}

print "</div>\n";
&footer();
