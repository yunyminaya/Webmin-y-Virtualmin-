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
if ($action eq 'enable_dnssec') {
	my $result = ovmns_enable_dnssec($domain);
	if ($result->{'ok'}) {
		my $msg = $result->{'message'};
		if (@{$result->{'ds_records'} || []}) {
			$msg .= " | DS Records: ".join("; ", @{$result->{'ds_records'}});
			}
		&redirect("dnssec.cgi?domain=".&urlize($domain)."&msg=".&urlize($msg));
		exit;
		}
	else {
		&error($result->{'error'});
		}
	}
elsif ($action eq 'rotate_keys') {
	# Re-generate keys (same as enable, will overwrite)
	my $result = ovmns_enable_dnssec($domain);
	if ($result->{'ok'}) {
		&redirect("dnssec.cgi?domain=".&urlize($domain)."&msg=".&urlize("Claves DNSSEC rotadas exitosamente"));
		exit;
		}
	else {
		&error($result->{'error'});
		}
	}

my $dnssec_status = ovmns_check_dnssec($domain);
my $init = ovmns_init();
my $msg = $in{'msg'};

&ui_print_header(undef, "DNSSEC: ".&html_escape($domain), '', 'dnssec');

print qq{
<style>
.ovmns-dnssec { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 10px; }
.ovmns-header {
	display: flex; justify-content: space-between; align-items: center;
	padding: 15px; background: linear-gradient(135deg, #cb2d3e 0%, #ef473a 100%);
	color: #fff; border-radius: 8px; margin-bottom: 20px;
}
.ovmns-header h2 { margin: 0; font-size: 20px; }
.ovmns-section { background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 15px; margin-bottom: 20px; }
.ovmns-section-title { font-size: 16px; font-weight: 600; color: #333; margin-bottom: 15px; padding-bottom: 8px; border-bottom: 2px solid #cb2d3e; }
.ovmns-table { width: 100%; border-collapse: collapse; }
.ovmns-table th { background: #f8f9fa; padding: 10px; text-align: left; font-size: 12px; color: #666; border-bottom: 2px solid #dee2e6; }
.ovmns-table td { padding: 10px; border-bottom: 1px solid #eee; font-size: 13px; }
.ovmns-badge { display: inline-block; padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; }
.ovmns-badge.ok { background: #d4edda; color: #155724; }
.ovmns-badge.missing { background: #f8d7da; color: #721c24; }
.ovmns-badge.warning { background: #fff3cd; color: #856404; }
.ovmns-badge.active { background: #cce5ff; color: #004085; }
.ovmns-badge.disabled { background: #e2e3e5; color: #383d41; }
.ovmns-btn {
	display: inline-block; padding: 8px 16px; border-radius: 4px; font-size: 13px;
	text-decoration: none; color: #fff; cursor: pointer; border: none;
}
.ovmns-btn.primary { background: #667eea; }
.ovmns-btn.success { background: #28a745; }
.ovmns-btn.danger { background: #dc3545; }
.ovmns-btn.warning { background: #f2994a; }
.ovmns-btn:hover { opacity: 0.85; }
.ovmns-msg { padding: 10px 15px; border-radius: 6px; margin-bottom: 15px; font-size: 13px; }
.ovmns-msg.success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
.ovmns-code {
	background: #2d2d2d; color: #f8f8f2; padding: 15px; border-radius: 8px;
	font-family: monospace; font-size: 12px; overflow-x: auto; margin: 10px 0;
	white-space: pre-wrap; word-break: break-all;
}
.ovmns-warning-box {
	background: #fff3cd; border: 1px solid #ffc107; border-radius: 6px;
	padding: 12px; margin: 10px 0; font-size: 13px;
}
.ovmns-danger-box {
	background: #f8d7da; border: 1px solid #f5c6cb; border-radius: 6px;
	padding: 12px; margin: 10px 0; font-size: 13px;
}
.ovmns-info-box {
	background: #e7f3ff; border: 1px solid #b8daff; border-radius: 6px;
	padding: 12px; margin: 10px 0; font-size: 13px;
}
</style>

<div class="ovmns-dnssec">

<div class="ovmns-header">
	<div>
		<h2>&#128274; DNSSEC: }.&html_escape($domain).qq{</h2>
		<div style="font-size:12px;opacity:0.8;margin-top:5px;">DNS Security Extensions - Firma criptografica de tu zona DNS</div>
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

# DNSSEC Status
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128269; Estado DNSSEC</div>\n};
print qq{<table class="ovmns-table">\n};
print qq{<tr><th>Parametro</th><th>Valor</th></tr>\n};

my $status_badge = $dnssec_status->{'status'} eq 'active'
	? '<span class="ovmns-badge ok">&#10003; Activo (DS en parent)</span>'
	: $dnssec_status->{'status'} eq 'signed'
	? '<span class="ovmns-badge warning">&#9888; Firmado (sin DS en parent)</span>'
	: '<span class="ovmns-badge disabled">&#10007; Deshabilitado</span>';

print qq{<tr><td>Estado</td><td>$status_badge</td></tr>\n};
print qq{<tr><td>KSK (Key Signing Key)</td><td>}.($dnssec_status->{'ksk_found'} ? '<span class="ovmns-badge ok">&#10003; Encontrada</span>' : '<span class="ovmns-badge missing">&#10007; No encontrada</span>').qq{</td></tr>\n};
print qq{<tr><td>ZSK (Zone Signing Key)</td><td>}.($dnssec_status->{'zsk_found'} ? '<span class="ovmns-badge ok">&#10003; Encontrada</span>' : '<span class="ovmns-badge missing">&#10007; No encontrada</span>').qq{</td></tr>\n};

if (@{$dnssec_status->{'key_tags'} || []}) {
	print qq{<tr><td>Key Tags</td><td>}.join(', ', @{$dnssec_status->{'key_tags'}}).qq{</td></tr>\n};
	}
print qq{</table>\n};
print qq{</div>\n};

# DS Records
if (@{$dnssec_status->{'ds_records'} || []}) {
	print qq{<div class="ovmns-section">\n};
	print qq{<div class="ovmns-section-title">&#128273; DS Records (Delegation Signer)</div>\n};
	print qq{<div class="ovmns-info-box">\n};
	print qq{<p>Estos registros DS deben ser registrados en tu registrar de dominio para completar la cadena de confianza DNSSEC:</p>\n};
	foreach my $ds (@{$dnssec_status->{'ds_records'}}) {
		print qq{<div class="ovmns-code">}.&html_escape($ds).qq{</div>\n};
		}
	print qq{</div>\n};
	print qq{</div>\n};
	}

# Tools availability
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128295; Herramientas DNSSEC</div>\n};
print qq{<table class="ovmns-table">\n};
print qq{<tr><th>Herramienta</th><th>Estado</th></tr>\n};
foreach my $tool (sort keys %{$init->{'dnssec_tools'}}) {
	my $available = $init->{'dnssec_tools'}{$tool}
		? '<span class="ovmns-badge ok">&#10003; Disponible</span>'
		: '<span class="ovmns-badge missing">&#10007; No instalado</span>';
	print qq{<tr><td><code>$tool</code></td><td>$available</td></tr>\n};
	}
print qq{</table>\n};

if (!$init->{'dnssec_tools'}{'dnssec-keygen'}) {
	print qq{<div class="ovmns-warning-box">\n};
	print qq{<strong>&#9888; Herramientas DNSSEC no instaladas.</strong><br>\n};
	print qq{<p>Instala las herramientas con:</p>\n};
	print qq{<div class="ovmns-code">apt-get install bind9utils bind9-dnsutils</div>\n};
	print qq{</div>\n};
	}
print qq{</div>\n};

# Actions
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#9889; Acciones</div>\n};

if ($dnssec_status->{'status'} eq 'disabled' || $dnssec_status->{'status'} eq 'signed') {
	print qq{<form method="post" action="dnssec.cgi" style="display:inline;margin-right:10px;">\n};
	print qq{<input type="hidden" name="domain" value="}.&html_escape($domain).qq{">\n};
	print qq{<input type="hidden" name="action" value="enable_dnssec">\n};
	print qq{<button type="submit" class="ovmns-btn success" style="font-size:14px;padding:10px 20px;">&#128274; Habilitar DNSSEC</button>\n};
	print qq{</form>\n};
	}

if ($dnssec_status->{'status'} eq 'active' || $dnssec_status->{'status'} eq 'signed') {
	print qq{<form method="post" action="dnssec.cgi" style="display:inline;margin-right:10px;">\n};
	print qq{<input type="hidden" name="domain" value="}.&html_escape($domain).qq{">\n};
	print qq{<input type="hidden" name="action" value="rotate_keys">\n};
	print qq{<button type="submit" class="ovmns-btn warning" style="font-size:14px;padding:10px 20px;" onclick="return confirm('Rotar claves DNSSEC? Esto generara nuevas claves y re-firmara la zona.')">&#128260; Rotar Claves</button>\n};
	print qq{</form>\n};
	}
print qq{</div>\n};

# Warnings
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#9888; Advertencias de Seguridad</div>\n};
print qq{<div class="ovmns-danger-box">\n};
print qq{<p><strong>&#9888; IMPORTANTE - Antes de habilitar DNSSEC:</strong></p>\n};
print qq{<ol>\n};
print qq{<li>Asegurate de que tu registrar soporta DNSSEC</li>\n};
print qq{<li>Los DS records deben ser registrados manualmente en tu registrar</li>\n};
print qq{<li>Si eliminas las claves DNSSEC sin remover los DS records, tu dominio sera inaccesible</li>\n};
print qq{<li>Las claves deben rotarse periodicamente (recomendado: KSK anualmente, ZSK trimestralmente)</li>\n};
print qq{<li>Manten un backup seguro de las claves privadas</li>\n};
print qq{</ol>\n};
print qq{</div>\n};
print qq{</div>\n};

# What is DNSSEC
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128218; Que es DNSSEC?</div>\n};
print qq{<div class="ovmns-info-box">\n};
print qq{<p>DNSSEC agrega firmas criptograficas a los registros DNS, protegiendo contra ataques de suplantacion DNS (DNS spoofing/cache poisoning).</p>\n};
print qq{<table class="ovmns-table">\n};
print qq{<tr><th>Componente</th><th>Descripcion</th></tr>\n};
print qq{<tr><td><strong>ZSK</strong> (Zone Signing Key)</td><td>Firma los registros individuales de la zona. Se rota con mas frecuencia.</td></tr>\n};
print qq{<tr><td><strong>KSK</strong> (Key Signing Key)</td><td>Firma la ZSK. Se comparte con el registrar via DS records.</td></tr>\n};
print qq{<tr><td><strong>DS</strong> (Delegation Signer)</td><td>Registro en el registrar que valida la KSK. Completa la cadena de confianza.</td></tr>\n};
print qq{<tr><td><strong>RRSIG</strong></td><td> Firma digital de un conjunto de registros DNS.</td></tr>\n};
print qq{</table>\n};
print qq{</div>\n};
print qq{</div>\n};

print qq{</div>\n};

&ui_print_footer("edit_zone.cgi?domain=".&urlize($domain), "Volver a Zona DNS");
