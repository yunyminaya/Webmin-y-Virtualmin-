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

# Handle apply SPF action
if ($action eq 'apply_spf') {
	my $spf_text = $in{'spf_text'};
	&error("SPF text is required") unless ($spf_text);
	my $result = ovmns_set_spf($domain, $spf_text);
	if ($result->{'ok'}) {
		&redirect("spf_wizard.cgi?domain=".&urlize($domain)."&msg=".&urlize($result->{'message'}));
		exit;
		}
	else {
		&error($result->{'error'});
		}
	}

my $current_spf = ovmns_get_spf($domain);
my $msg = $in{'msg'};

# Get server IP for suggestions
my $server_ip = '';
if (ovmns_check_dig()) {
	my $cmd = "dig +short $domain A \@localhost 2>/dev/null";
	$server_ip = `$cmd`;
	chomp($server_ip);
	}

# Get MX servers
my @mx_servers;
if (ovmns_check_dig()) {
	my $cmd = "dig +short MX $domain \@localhost 2>/dev/null";
	my $out = `$cmd`;
	foreach my $line (split(/\n/, $out)) {
		chomp($line);
		if ($line =~ /^\d+\s+(\S+)/) {
			push(@mx_servers, $1);
			}
		}
	}

&ui_print_header(undef, "SPF Wizard: ".&html_escape($domain), '', 'spf_wizard');

print qq{
<style>
.ovmns-spf { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 10px; }
.ovmns-header {
	display: flex; justify-content: space-between; align-items: center;
	padding: 15px; background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
	color: #fff; border-radius: 8px; margin-bottom: 20px;
}
.ovmns-header h2 { margin: 0; font-size: 20px; }
.ovmns-section { background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 15px; margin-bottom: 20px; }
.ovmns-section-title { font-size: 16px; font-weight: 600; color: #333; margin-bottom: 15px; padding-bottom: 8px; border-bottom: 2px solid #28a745; }
.ovmns-table { width: 100%; border-collapse: collapse; }
.ovmns-table th { background: #f8f9fa; padding: 10px; text-align: left; font-size: 12px; color: #666; border-bottom: 2px solid #dee2e6; }
.ovmns-table td { padding: 10px; border-bottom: 1px solid #eee; font-size: 13px; }
.ovmns-badge { display: inline-block; padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; }
.ovmns-badge.ok { background: #d4edda; color: #155724; }
.ovmns-badge.missing { background: #f8d7da; color: #721c24; }
.ovmns-btn {
	display: inline-block; padding: 8px 16px; border-radius: 4px; font-size: 13px;
	text-decoration: none; color: #fff; cursor: pointer; border: none;
}
.ovmns-btn.primary { background: #667eea; }
.ovmns-btn.success { background: #28a745; }
.ovmns-btn.danger { background: #dc3545; }
.ovmns-btn:hover { opacity: 0.85; }
.ovmns-form-group { margin-bottom: 15px; }
.ovmns-form-group label { display: block; font-size: 13px; font-weight: 600; color: #555; margin-bottom: 5px; }
.ovmns-checkbox-group { display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 10px; }
.ovmns-checkbox-item {
	display: flex; align-items: center; gap: 5px; padding: 8px 12px;
	background: #f8f9fa; border: 1px solid #ddd; border-radius: 6px; font-size: 13px;
}
.ovmns-checkbox-item input[type="checkbox"] { transform: scale(1.2); }
.ovmns-preview {
	background: #f0f7ff; border: 2px solid #667eea; border-radius: 8px;
	padding: 15px; margin: 15px 0; font-family: monospace; font-size: 14px;
	word-break: break-all;
}
.ovmns-msg { padding: 10px 15px; border-radius: 6px; margin-bottom: 15px; font-size: 13px; }
.ovmns-msg.success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
.ovmns-explain { background: #fff3cd; border: 1px solid #ffc107; border-radius: 6px; padding: 12px; margin: 10px 0; font-size: 12px; }
.ovmns-explain-title { font-weight: 600; color: #856404; margin-bottom: 5px; }
</style>

<div class="ovmns-spf">

<div class="ovmns-header">
	<div>
		<h2>&#128274; SPF Wizard: }.&html_escape($domain).qq{</h2>
		<div style="font-size:12px;opacity:0.8;margin-top:5px;">Configura el registro SPF para proteger tu dominio contra suplantacion de email</div>
	</div>
	<div style="display:flex;gap:8px;">
		<a href="edit_zone.cgi?domain=}.&urlize($domain).qq{" class="ovmns-btn" style="background:rgba(255,255,255,0.2);color:#fff;">&#8592; Zona DNS</a>
		<a href="index.cgi" class="ovmns-btn" style="background:rgba(255,255,255,0.2);color:#fff;">Dashboard</a>
	</div>
</div>

};

# Show success message
if ($msg) {
	print qq{<div class="ovmns-msg success">&#10003; }.&html_escape($msg).qq{</div>\n};
	}

# Current SPF status
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128269; Estado SPF Actual</div>\n};
if ($current_spf) {
	print qq{<p><span class="ovmns-badge ok">&#10003; SPF Configurado</span></p>\n};
	print qq{<div class="ovmns-preview">}.&html_escape($current_spf).qq{</div>\n};
	}
else {
	print qq{<p><span class="ovmns-badge missing">&#10007; SPF No Configurado</span></p>\n};
	print qq{<p style="color:#666;">No se encontro un registro SPF para este dominio. Configuralo usando el formulario abajo.</p>\n};
	}
print qq{</div>\n};

# SPF Explanation
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128218; Que es SPF?</div>\n};
print qq{<div class="ovmns-explain">\n};
print qq{<div class="ovmns-explain-title">Sender Policy Framework (SPF)</div>\n};
print qq{<p>SPF es un registro DNS TXT que especifica que servidores de correo estan autorizados para enviar emails en nombre de tu dominio.</p>\n};
print qq{<p><strong>Estructura del registro SPF:</strong></p>\n};
print qq{<table class="ovmns-table">\n};
print qq{<tr><th>Mecanismo</th><th>Significado</th><th>Ejemplo</th></tr>\n};
print qq{<tr><td><code>v=spf1</code></td><td>Version de SPF</td><td>Requerido al inicio</td></tr>\n};
print qq{<tr><td><code>+a</code></td><td>Permitir IP del registro A</td><td>Incluye IP del dominio</td></tr>\n};
print qq{<tr><td><code>+mx</code></td><td>Permitir servidores MX</td><td>Incluye servidores de correo</td></tr>\n};
print qq{<tr><td><code>ip4:</code></td><td>Permitir IPv4 especifica</td><td>ip4:192.168.1.100</td></tr>\n};
print qq{<tr><td><code>ip6:</code></td><td>Permitir IPv6 especifica</td><td>ip6:2001:db8::1</td></tr>\n};
print qq{<tr><td><code>include:</code></td><td>Incluir SPF de otro dominio</td><td>include:_spf.google.com</td></tr>\n};
print qq{<tr><td><code>-all</code></td><td>Rechazar todo lo demas (estricto)</td><td>Recomendado para produccion</td></tr>\n};
print qq{<tr><td><code>~all</code></td><td>Sospechoso (softfail)</td><td>Recomendado para pruebas</td></tr>\n};
print qq{<tr><td><code>+all</code></td><td>Permitir todo (NO recomendado)</td><td>Nunca usar en produccion</td></tr>\n};
print qq{</table>\n};
print qq{</div>\n};
print qq{</div>\n};

# SPF Builder Form
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128295; Constructor SPF</div>\n};
print qq{<form method="post" action="spf_wizard.cgi" id="spf_form">\n};
print qq{<input type="hidden" name="domain" value="}.&html_escape($domain).qq{">\n};
print qq{<input type="hidden" name="action" value="apply_spf">\n};

# Server IP
print qq{<div class="ovmns-form-group">\n};
print qq{<label>&#127760; IP del Servidor:</label>\n};
print qq{<div class="ovmns-checkbox-item">\n};
print qq{<input type="checkbox" name="include_a" value="1" id="chk_a" checked> <label for="chk_a">Incluir IP del registro A del dominio (+a)</label>\n};
print qq{</div>\n};
print qq{<div style="font-size:12px;color:#666;margin-top:5px;">IP detectada: <strong>}.&html_escape($server_ip || 'No detectada').qq{</strong></div>\n};
print qq{</div>\n};

# MX Servers
print qq{<div class="ovmns-form-group">\n};
print qq{<label>&#128231; Servidores MX:</label>\n};
print qq{<div class="ovmns-checkbox-item">\n};
print qq{<input type="checkbox" name="include_mx" value="1" id="chk_mx" checked> <label for="chk_mx">Incluir servidores MX del dominio (+mx)</label>\n};
print qq{</div>\n};
if (@mx_servers) {
	print qq{<div style="font-size:12px;color:#666;margin-top:5px;">MX detectados: <strong>}.&html_escape(join(', ', @mx_servers)).qq{</strong></div>\n};
	}
print qq{</div>\n};

# Additional IPs
print qq{<div class="ovmns-form-group">\n};
print qq{<label>&#128273; IPs Adicionales (una por linea):</label>\n};
print qq{<textarea name="additional_ips" rows="3" style="width:100%;padding:8px;border:1px solid #ddd;border-radius:4px;font-size:13px;" placeholder="192.168.1.100&#10;10.0.0.1"></textarea>\n};
print qq{</div>\n};

# Third-party includes
print qq{<div class="ovmns-form-group">\n};
print qq{<label>&#127760; Proveedores de Terceros:</label>\n};
print qq{<div class="ovmns-checkbox-group">\n};
print qq{<div class="ovmns-checkbox-item"><input type="checkbox" name="include_google" value="1" id="chk_google"> <label for="chk_google">Google Workspace</label></div>\n};
print qq{<div class="ovmns-checkbox-item"><input type="checkbox" name="include_microsoft" value="1" id="chk_ms"> <label for="chk_ms">Microsoft 365</label></div>\n};
print qq{<div class="ovmns-checkbox-item"><input type="checkbox" name="include_mailgun" value="1" id="chk_mg"> <label for="chk_mg">Mailgun</label></div>\n};
print qq{<div class="ovmns-checkbox-item"><input type="checkbox" name="include_sendgrid" value="1" id="chk_sg"> <label for="chk_sg">SendGrid</label></div>\n};
print qq{<div class="ovmns-checkbox-item"><input type="checkbox" name="include_amazon" value="1" id="chk_aws"> <label for="chk_aws">Amazon SES</label></div>\n};
print qq{<div class="ovmns-checkbox-item"><input type="checkbox" name="include_postmark" value="1" id="chk_pm"> <label for="chk_pm">Postmark</label></div>\n};
print qq{</div>\n};
print qq{</div>\n};

# Custom includes
print qq{<div class="ovmns-form-group">\n};
print qq{<label>&#128279; Inclusiones Personalizadas (una por linea):</label>\n};
print qq{<textarea name="custom_includes" rows="2" style="width:100%;padding:8px;border:1px solid #ddd;border-radius:4px;font-size:13px;" placeholder="_spf.otro-dominio.com"></textarea>\n};
print qq{</div>\n};

# Policy
print qq{<div class="ovmns-form-group">\n};
print qq{<label>&#128737; Politica por defecto (all):</label>\n};
print qq{<select name="policy" style="padding:8px;border:1px solid #ddd;border-radius:4px;font-size:13px;">\n};
print qq{<option value="-all">-all (Rechazar todo lo demas) - Recomendado</option>\n};
print qq{<option value="~all">~all (Softfail - sospechoso)</option>\n};
print qq{<option value="?all">?all (Neutral)</option>\n};
print qq{</select>\n};
print qq{</div>\n};

# SPF Preview (built by server-side on submit)
print qq{<div class="ovmns-form-group">\n};
print qq{<label>&#128065; Vista Previa del Registro SPF:</label>\n};
print qq{<div class="ovmns-preview" id="spf_preview">v=spf1 +a +mx -all</div>\n};
print qq{<input type="text" name="spf_text" id="spf_text" value="v=spf1 +a +mx -all" style="width:100%;padding:8px;border:1px solid #ddd;border-radius:4px;font-size:13px;font-family:monospace;">\n};
print qq{<div style="font-size:11px;color:#666;margin-top:5px;">Puedes editar manualmente el registro SPF antes de aplicarlo.</div>\n};
print qq{</div>\n};

print qq{<div style="display:flex;gap:10px;margin-top:15px;">\n};
print qq{<button type="submit" class="ovmns-btn success" style="font-size:14px;padding:10px 20px;">&#10003; Aplicar SPF</button>\n};
print qq{<a href="spf_wizard.cgi?domain=}.&urlize($domain).qq{" class="ovmns-btn danger">&#8634; Restaurar</a>\n};
print qq{</div>\n};
print qq{</form>\n};
print qq{</div>\n};

# Quick SPF templates
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#9889; Plantillas Rapidas SPF</div>\n};
print qq{<table class="ovmns-table">\n};
print qq{<tr><th>Escenario</th><th>Registro SPF</th><th>Accion</th></tr>\n};

my @templates = (
	['Solo servidor (basico)', 'v=spf1 +a -all'],
	['Servidor + MX', 'v=spf1 +a +mx -all'],
	['Con Google Workspace', 'v=spf1 +a +mx include:_spf.google.com -all'],
	['Con Microsoft 365', 'v=spf1 +a +mx include:spf.protection.outlook.com -all'],
	['Con Mailgun', 'v=spf1 +a +mx include:mailgun.org -all'],
	['Con SendGrid', 'v=spf1 +a +mx include:sendgrid.net -all'],
	['Con Amazon SES', 'v=spf1 +a +mx include:amazonses.com -all'],
	['Todo permitido (NO recomendado)', 'v=spf1 +all'],
	);

foreach my $t (@templates) {
	my $esc_spf = &html_escape($t->[1]);
	print qq{<tr>
		<td>}.&html_escape($t->[0]).qq{</td>
		<td><code>$esc_spf</code></td>
		<td>
			<form method="post" action="spf_wizard.cgi" style="display:inline;">
				<input type="hidden" name="domain" value="}.&html_escape($domain).qq{">
				<input type="hidden" name="action" value="apply_spf">
				<input type="hidden" name="spf_text" value="$esc_spf">
				<button type="submit" class="ovmns-btn success" style="padding:4px 10px;font-size:11px;">Aplicar</button>
			</form>
		</td>
		</tr>\n};
	}
print qq{</table>\n};
print qq{</div>\n};

print qq{</div>\n};

&ui_print_footer("edit_zone.cgi?domain=".&urlize($domain), "Volver a Zona DNS");
