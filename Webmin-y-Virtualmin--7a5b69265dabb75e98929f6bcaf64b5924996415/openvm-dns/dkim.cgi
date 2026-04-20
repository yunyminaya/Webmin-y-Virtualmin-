#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
chdir($FindBin::Bin);
require './openvm-dns-lib.pl';
&ReadParse();

ovmd_require_access();

my $domain = $in{'domain'};
my $action = $in{'action'} || '';

&error("Domain parameter is required") unless ($domain);

# Handle actions
if ($action eq 'generate_dkim') {
	my $selector = $in{'selector'} || 'default';
	my $bits = $in{'key_size'} || 2048;
	my $result = ovmns_enable_dkim($domain);
	if ($result->{'ok'}) {
		&redirect("dkim.cgi?domain=".&urlize($domain)."&msg=".&urlize($result->{'message'}));
		exit;
		}
	else {
		&error($result->{'error'});
		}
	}
elsif ($action eq 'verify_dkim') {
	&redirect("dkim.cgi?domain=".&urlize($domain)."&verify=1");
	exit;
	}

my $dkim_status = ovmns_check_dkim($domain);
my $msg = $in{'msg'};
my $verify = $in{'verify'};

# Verification results
my $verify_result;
if ($verify && ovmns_check_dig()) {
	my $selector = $dkim_status->{'selector'} || 'default';
	my $dkim_name = "$selector._domainkey.$domain";
	my $cmd = "dig +short TXT $dkim_name 2>/dev/null";
	my $out = `$cmd`;
	$out =~ s/^"//;
	$out =~ s/"$//;
	$verify_result = {
		'name' => $dkim_name,
		'record' => $out,
		'found' => ($out =~ /v=DKIM1/) ? 1 : 0,
		};
	}

my $opendkim_available = ovmns_check_opendkim();

&ui_print_header(undef, "DKIM Management: ".&html_escape($domain), '', 'dkim');

print qq{
<style>
.ovmns-dkim { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 10px; }
.ovmns-header {
	display: flex; justify-content: space-between; align-items: center;
	padding: 15px; background: linear-gradient(135deg, #f2994a 0%, #f2c94c 100%);
	color: #fff; border-radius: 8px; margin-bottom: 20px;
}
.ovmns-header h2 { margin: 0; font-size: 20px; }
.ovmns-section { background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 15px; margin-bottom: 20px; }
.ovmns-section-title { font-size: 16px; font-weight: 600; color: #333; margin-bottom: 15px; padding-bottom: 8px; border-bottom: 2px solid #f2994a; }
.ovmns-table { width: 100%; border-collapse: collapse; }
.ovmns-table th { background: #f8f9fa; padding: 10px; text-align: left; font-size: 12px; color: #666; border-bottom: 2px solid #dee2e6; }
.ovmns-table td { padding: 10px; border-bottom: 1px solid #eee; font-size: 13px; }
.ovmns-badge { display: inline-block; padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; }
.ovmns-badge.ok { background: #d4edda; color: #155724; }
.ovmns-badge.missing { background: #f8d7da; color: #721c24; }
.ovmns-badge.warning { background: #fff3cd; color: #856404; }
.ovmns-badge.info { background: #d1ecf1; color: #0c5460; }
.ovmns-btn {
	display: inline-block; padding: 8px 16px; border-radius: 4px; font-size: 13px;
	text-decoration: none; color: #fff; cursor: pointer; border: none;
}
.ovmns-btn.primary { background: #667eea; }
.ovmns-btn.success { background: #28a745; }
.ovmns-btn.warning { background: #f2994a; }
.ovmns-btn.danger { background: #dc3545; }
.ovmns-btn:hover { opacity: 0.85; }
.ovmns-msg { padding: 10px 15px; border-radius: 6px; margin-bottom: 15px; font-size: 13px; }
.ovmns-msg.success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
.ovmns-msg.error { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
.ovmns-code {
	background: #2d2d2d; color: #f8f8f2; padding: 15px; border-radius: 8px;
	font-family: monospace; font-size: 12px; overflow-x: auto; margin: 10px 0;
	white-space: pre-wrap; word-break: break-all;
}
.ovmns-form-group { margin-bottom: 15px; }
.ovmns-form-group label { display: block; font-size: 13px; font-weight: 600; color: #555; margin-bottom: 5px; }
.ovmns-info-box {
	background: #e7f3ff; border: 1px solid #b8daff; border-radius: 6px;
	padding: 12px; margin: 10px 0; font-size: 13px;
}
.ovmns-warning-box {
	background: #fff3cd; border: 1px solid #ffc107; border-radius: 6px;
	padding: 12px; margin: 10px 0; font-size: 13px;
}
</style>

<div class="ovmns-dkim">

<div class="ovmns-header">
	<div>
		<h2>&#128272; DKIM: }.&html_escape($domain).qq{</h2>
		<div style="font-size:12px;opacity:0.8;margin-top:5px;">DomainKeys Identified Mail - Firma digital para tus emails</div>
	</div>
	<div style="display:flex;gap:8px;">
		<a href="edit_zone.cgi?domain=}.&urlize($domain).qq{" class="ovmns-btn" style="background:rgba(255,255,255,0.2);color:#fff;">&#8592; Zona DNS</a>
		<a href="index.cgi" class="ovmns-btn" style="background:rgba(255,255,255,0.2);color:#fff;">Dashboard</a>
	</div>
</div>

};

# Show message
if ($msg) {
	print qq{<div class="ovmns-msg success">&#10003; }.&html_escape($msg).qq{</div>\n};
	}

# DKIM Status
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128269; Estado DKIM Actual</div>\n};
print qq{<table class="ovmns-table">\n};
print qq{<tr><th>Parametro</th><th>Valor</th></tr>\n};

my $status_badge = $dkim_status->{'status'} eq 'ok'
	? '<span class="ovmns-badge ok">&#10003; Configurado</span>'
	: $dkim_status->{'status'} eq 'warning'
	? '<span class="ovmns-badge warning">&#9888; Clave sin DNS</span>'
	: '<span class="ovmns-badge missing">&#10007; No configurado</span>';

print qq{<tr><td>Estado</td><td>$status_badge</td></tr>\n};
print qq{<tr><td>Selector</td><td>}.&html_escape($dkim_status->{'selector'}).qq{</td></tr>\n};
print qq{<tr><td>Clave local</td><td>}.($dkim_status->{'key_found'} ? '<span class="ovmns-badge ok">&#10003; Encontrada</span>' : '<span class="ovmns-badge missing">&#10007; No encontrada</span>').qq{</td></tr>\n};
if ($dkim_status->{'key_path'}) {
	print qq{<tr><td>Ruta clave</td><td><code>}.&html_escape($dkim_status->{'key_path'}).qq{</code></td></tr>\n};
	}
if ($dkim_status->{'dns_record'}) {
	print qq{<tr><td>Registro DNS</td><td><div class="ovmns-code">}.&html_escape($dkim_status->{'dns_record'}).qq{</div></td></tr>\n};
	}
print qq{</table>\n};
print qq{</div>\n};

# Generate DKIM Key
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128273; Generar Clave DKIM</div>\n};

if ($opendkim_available) {
	print qq{<form method="post" action="dkim.cgi">\n};
	print qq{<input type="hidden" name="domain" value="}.&html_escape($domain).qq{">\n};
	print qq{<input type="hidden" name="action" value="generate_dkim">\n};

	print qq{<div class="ovmns-form-group">\n};
	print qq{<label>Selector:</label>\n};
	print qq{<select name="selector" style="padding:8px;border:1px solid #ddd;border-radius:4px;font-size:13px;">\n};
	print qq{<option value="default" selected>default</option>\n};
	print qq{<option value="selector1">selector1</option>\n};
	print qq{<option value="selector2">selector2</option>\n};
	print qq{<option value="mail">mail</option>\n};
	print qq{</select>\n};
	print qq{</div>\n};

	print qq{<div class="ovmns-form-group">\n};
	print qq{<label>Tamano de clave:</label>\n};
	print qq{<select name="key_size" style="padding:8px;border:1px solid #ddd;border-radius:4px;font-size:13px;">\n};
	print qq{<option value="2048" selected>2048 bits (Recomendado)</option>\n};
	print qq{<option value="1024">1024 bits (Legado)</option>\n};
	print qq{<option value="4096">4096 bits (Alta seguridad)</option>\n};
	print qq{</select>\n};
	print qq{</div>\n};

	print qq{<button type="submit" class="ovmns-btn warning" style="font-size:14px;padding:10px 20px;">&#128273; Generar Clave DKIM</button>\n};
	print qq{</form>\n};
	}
else {
	print qq{<div class="ovmns-warning-box">\n};
	print qq{<strong>&#9888; OpenDKIM no esta instalado.</strong><br>\n};
	print qq{<p>Para generar claves DKIM necesitas instalar opendkim:</p>\n};
	print qq{<div class="ovmns-code">apt-get install opendkim opendkim-tools</div>\n};
	print qq{</div>\n};
	}
print qq{</div>\n};

# Verify DKIM
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128269; Verificar DKIM en DNS</div>\n};
print qq{<form method="post" action="dkim.cgi" style="margin-bottom:15px;">\n};
print qq{<input type="hidden" name="domain" value="}.&html_escape($domain).qq{">\n};
print qq{<input type="hidden" name="action" value="verify_dkim">\n};
print qq{<button type="submit" class="ovmns-btn primary">&#128269; Verificar DKIM en DNS</button>\n};
print qq{</form>\n};

if ($verify_result) {
	print qq{<table class="ovmns-table">\n};
	print qq{<tr><th>Nombre DNS</th><th>Resultado</th></tr>\n};
	my $v_status = $verify_result->{'found'}
		? '<span class="ovmns-badge ok">&#10003; Registro DKIM encontrado</span>'
		: '<span class="ovmns-badge missing">&#10007; Registro DKIM no encontrado</span>';
	print qq{<tr><td><code>}.&html_escape($verify_result->{'name'}).qq{</code></td><td>$v_status</td></tr>\n};
	if ($verify_result->{'record'}) {
		print qq{<tr><td colspan="2"><div class="ovmns-code">}.&html_escape($verify_result->{'record'}).qq{</div></td></tr>\n};
		}
	print qq{</table>\n};
	}
print qq{</div>\n};

# DNS Record to add
if ($dkim_status->{'status'} eq 'warning' || $dkim_status->{'key_found'}) {
	print qq{<div class="ovmns-section">\n};
	print qq{<div class="ovmns-section-title">&#128196; Registro DNS DKIM para Agregar</div>\n};
	print qq{<div class="ovmns-info-box">\n};
	print qq{<p>Agrega el siguiente registro TXT a tu zona DNS:</p>\n};
	my $dns_name = ($dkim_status->{'selector'} || 'default')."._domainkey.$domain";
	print qq{<p><strong>Nombre:</strong> <code>}.&html_escape($dns_name).qq{</code></p>\n};
	if ($dkim_status->{'dns_record'}) {
		print qq{<p><strong>Valor:</strong></p>\n};
		print qq{<div class="ovmns-code">}.&html_escape($dkim_status->{'dns_record'}).qq{</div>\n};
		}
	else {
		print qq{<p style="color:#666;">Genera la clave DKIM para obtener el registro DNS.</p>\n};
		}
	print qq{</div>\n};
	print qq{</div>\n};
	}

# Postfix configuration instructions
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128295; Instrucciones para Postfix</div>\n};
print qq{<div class="ovmns-info-box">\n};
print qq{<p><strong>1. Configurar OpenDKIM</strong> - Editar <code>/etc/opendkim.conf</code>:</p>\n};
print qq{<div class="ovmns-code">AutoRestart             Yes
AutoRestartRate         10/1h
Syslog                  yes
SyslogSuccess           yes
LogWhy                  yes

Canonicalization        relaxed/simple
Mode                    sv
SubDomains              no

OversignHeaders         From

# Key and signing table
KeyTable                refile:/etc/opendkim/key.table
SigningTable             refile:/etc/opendkim/signing.table
ExternalIgnoreList      refile:/etc/opendkim/trusted.hosts
InternalHosts           refile:/etc/opendkim/trusted.hosts

Socket                  inet:8891\@localhost
PidFile                 /run/opendkim/opendkim.pid
UMask                   007
UserID                  opendkim</div>\n};

print qq{<p><strong>2. Configurar Key Table</strong> - <code>/etc/opendkim/key.table</code>:</p>\n};
print qq{<div class="ovmns-code">}.&html_escape($domain).qq{ _domainkey.}.&html_escape($domain).qq{ }.&html_escape($domain).qq{:default:/etc/opendkim/keys/}.&html_escape($domain).qq{/default.private</div>\n};

print qq{<p><strong>3. Configurar Signing Table</strong> - <code>/etc/opendkim/signing.table</code>:</p>\n};
print qq{<div class="ovmns-code">*@\@}.&html_escape($domain).qq{ }.&html_escape($domain).qq{</div>\n};

print qq{<p><strong>4. Configurar Postfix</strong> - Agregar a <code>/etc/postfix/main.cf</code>:</p>\n};
print qq{<div class="ovmns-code">milter_default_action = accept
milter_protocol = 6
smtpd_milters = inet:localhost:8891
non_smtpd_milters = inet:localhost:8891</div>\n};

print qq{<p><strong>5. Reiniciar servicios:</strong></p>\n};
print qq{<div class="ovmns-code">systemctl restart opendkim
systemctl restart postfix</div>\n};
print qq{</div>\n};
print qq{</div>\n};

print qq{</div>\n};

&ui_print_footer("edit_zone.cgi?domain=".&urlize($domain), "Volver a Zona DNS");
