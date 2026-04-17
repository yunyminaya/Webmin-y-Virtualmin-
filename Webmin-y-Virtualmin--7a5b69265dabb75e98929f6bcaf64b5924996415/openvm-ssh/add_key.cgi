#!/usr/bin/perl

use strict;
use warnings;

require './openvm-ssh-lib.pl';

&require_acl();
&header('Agregar clave SSH', '');

&ovmssh_require_access();
&ovmssh_load_virtualmin();

my $d = &ovmssh_current_domain({});

print "<div style='max-width:760px;margin:0 auto;padding:20px;font-family:Arial,sans-serif'>\n";
print "<h2 style='color:#2c3e50;border-bottom:2px solid #2ecc71;padding-bottom:8px'>Agregar clave SSH p&uacute;blica</h2>\n";
print "<p><a href='keys.cgi?id=" . ($d ? $d->{'id'} : '') . "' style='color:#3498db'>&larr; Volver a claves</a></p>\n";

unless ($d) {
	print "<div style='background:#f8d7da;border:1px solid #f5c6cb;border-radius:6px;padding:16px'>\n";
	print "<p style='margin:0;color:#721c24'>Dominio no encontrado.</p>\n";
	print "</div>\n";
	&footer(); exit 0;
	}

print "<div style='background:#eaf4fb;border:1px solid #3498db;border-radius:6px;padding:12px;margin-bottom:20px'>\n";
print "<p style='margin:0'><strong>Dominio:</strong> $d->{'dom'} &mdash; usuario Unix: <code>$d->{'user'}</code></p>\n";
print "</div>\n";

print "<form method='post' action='save_key.cgi'>\n";
print "<input type='hidden' name='id' value='$d->{'id'}'>\n";

print "<div style='margin-bottom:16px'>\n";
print "<label style='display:block;font-weight:bold;margin-bottom:6px'>Clave p&uacute;blica SSH <span style='color:red'>*</span></label>\n";
print "<textarea name='key_text' rows='6' style='width:100%;padding:10px;font-family:monospace;font-size:13px;border:1px solid #ccc;border-radius:4px;box-sizing:border-box' placeholder='Pega aqu&iacute; tu clave p&uacute;blica. Ejemplo:\nssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... usuario\@host\nssh-rsa AAAAB3Nza... usuario\@host'></textarea>\n";
print "<small style='color:#7f8c8d'>Formatos soportados: ssh-ed25519, ssh-rsa, ssh-ecdsa, ecdsa-sha2-nistp256, sk-*</small>\n";
print "</div>\n";

print "<div style='margin-bottom:20px'>\n";
print "<label style='display:block;font-weight:bold;margin-bottom:6px'>Comentario (opcional)</label>\n";
print "<input type='text' name='comment' style='width:100%;padding:8px;border:1px solid #ccc;border-radius:4px;box-sizing:border-box' placeholder='p.ej. laptop personal, servidor CI/CD'>\n";
print "</div>\n";

print "<div style='background:#d4edda;border:1px solid #c3e6cb;border-radius:6px;padding:12px;margin-bottom:20px'>\n";
print "<strong style='color:#155724'>Instrucciones:</strong>\n";
print "<ol style='margin:6px 0 0 18px;padding:0;color:#155724;font-size:14px'>\n";
print "<li>Genera tu par de claves: <code>ssh-keygen -t ed25519 -C \"mi\@email.com\"</code></li>\n";
print "<li>Copia la clave p&uacute;blica: <code>cat ~/.ssh/id_ed25519.pub</code></li>\n";
print "<li>P&eacute;gala en el campo de arriba y haz clic en Guardar.</li>\n";
print "</ol>\n";
print "</div>\n";

print "<button type='submit' style='padding:10px 28px;background:#2ecc71;color:white;border:none;border-radius:4px;cursor:pointer;font-size:15px;font-weight:bold'>Guardar clave</button>\n";
print "&nbsp;<a href='keys.cgi?id=$d->{'id'}' style='padding:10px 18px;background:#95a5a6;color:white;text-decoration:none;border-radius:4px;font-size:14px'>Cancelar</a>\n";
print "</form>\n";

print "</div>\n";
&footer();
