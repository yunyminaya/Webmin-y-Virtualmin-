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

# Handle apply DMARC action
if ($action eq 'apply_dmarc') {
	my $policy = $in{'policy'} || 'none';
	my $pct = $in{'pct'} || 100;
	my $rua = $in{'rua'};
	my $ruf = $in{'ruf'};
	my $adkim = $in{'adkim'} || 'r';
	my $aspf = $in{'aspf'} || 'r';

	# Build DMARC record manually for full control
	my $dmarc = "v=DMARC1; p=$policy; pct=$pct";
	$dmarc .= "; rua=mailto:$rua" if ($rua && $rua =~ /\@/);
	$dmarc .= "; ruf=mailto:$ruf" if ($ruf && $ruf =~ /\@/);
	$dmarc .= "; adkim=$adkim" if ($adkim);
	$dmarc .= "; aspf=$aspf" if ($aspf);

	# Use ovmns_set_dmarc for the standard fields
	my $result = ovmns_set_dmarc($domain, $policy, $pct, $rua);

	# If we have ruf, we need to update the record with additional fields
	if ($ruf && $ruf =~ /\@/ && $result->{'ok'}) {
		# Delete the basic one and re-add with full DMARC
		ovmns_delete_record($domain, 'TXT', "_dmarc.$domain");
		$result = ovmns_add_record($domain, 'TXT', "_dmarc.$domain", "\"$dmarc\"", 3600);
		}

	if ($result->{'ok'}) {
		&redirect("dmarc.cgi?domain=".&urlize($domain)."&msg=".&urlize("DMARC configurado exitosamente"));
		exit;
		}
	else {
		&error($result->{'error'});
		}
	}

my $current_dmarc = ovmns_get_dmarc($domain);
my $msg = $in{'msg'};

# Parse current DMARC record
my %dmarc_parsed;
if ($current_dmarc) {
	foreach my $part (split(/;/, $current_dmarc)) {
		$part =~ s/^\s+//;
		$part =~ s/\s+$//;
		if ($part =~ /^(\w+)=(.*)$/) {
			$dmarc_parsed{$1} = $2;
			}
		}
	}

&ui_print_header(undef, "DMARC: ".&html_escape($domain), '', 'dmarc');

print qq{
<style>
.ovmns-dmarc { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 10px; }
.ovmns-header {
	display: flex; justify-content: space-between; align-items: center;
	padding: 15px; background: linear-gradient(135deg, #2193b0 0%, #6dd5ed 100%);
	color: #fff; border-radius: 8px; margin-bottom: 20px;
}
.ovmns-header h2 { margin: 0; font-size: 20px; }
.ovmns-section { background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 15px; margin-bottom: 20px; }
.ovmns-section-title { font-size: 16px; font-weight: 600; color: #333; margin-bottom: 15px; padding-bottom: 8px; border-bottom: 2px solid #2193b0; }
.ovmns-table { width: 100%; border-collapse: collapse; }
.ovmns-table th { background: #f8f9fa; padding: 10px; text-align: left; font-size: 12px; color: #666; border-bottom: 2px solid #dee2e6; }
.ovmns-table td { padding: 10px; border-bottom: 1px solid #eee; font-size: 13px; }
.ovmns-badge { display: inline-block; padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; }
.ovmns-badge.ok { background: #d4edda; color: #155724; }
.ovmns-badge.missing { background: #f8d7da; color: #721c24; }
.ovmns-badge.warning { background: #fff3cd; color: #856404; }
.ovmns-btn {
	display: inline-block; padding: 8px 16px; border-radius: 4px; font-size: 13px;
	text-decoration: none; color: #fff; cursor: pointer; border: none;
}
.ovmns-btn.primary { background: #2193b0; }
.ovmns-btn.success { background: #28a745; }
.ovmns-btn.danger { background: #dc3545; }
.ovmns-btn:hover { opacity: 0.85; }
.ovmns-msg { padding: 10px 15px; border-radius: 6px; margin-bottom: 15px; font-size: 13px; }
.ovmns-msg.success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
.ovmns-preview {
	background: #f0f7ff; border: 2px solid #2193b0; border-radius: 8px;
	padding: 15px; margin: 15px 0; font-family: monospace; font-size: 14px;
	word-break: break-all;
}
.ovmns-form-group { margin-bottom: 15px; }
.ovmns-form-group label { display: block; font-size: 13px; font-weight: 600; color: #555; margin-bottom: 5px; }
.ovmns-form-group input, .ovmns-form-group select {
	padding: 8px 12px; border: 1px solid #ddd; border-radius: 4px; font-size: 13px; width: 100%;
	max-width: 400px;
}
.ovmns-form-group input:focus, .ovmns-form-group select:focus { border-color: #2193b0; outline: none; }
.ovmns-radio-group { display: flex; gap: 15px; margin-top: 5px; }
.ovmns-radio-item {
	display: flex; align-items: center; gap: 5px; padding: 10px 15px;
	background: #f8f9fa; border: 2px solid #ddd; border-radius: 8px; cursor: pointer;
	flex: 1; max-width: 200px;
}
.ovmns-radio-item.selected { border-color: #2193b0; background: #e7f3ff; }
.ovmns-radio-item input[type="radio"] { transform: scale(1.2); }
.ovmns-info-box {
	background: #e7f3ff; border: 1px solid #b8daff; border-radius: 6px;
	padding: 12px; margin: 10px 0; font-size: 13px;
}
.ovmns-warning-box {
	background: #fff3cd; border: 1px solid #ffc107; border-radius: 6px;
	padding: 12px; margin: 10px 0; font-size: 13px;
}
</style>

<div class="ovmns-dmarc">

<div class="ovmns-header">
	<div>
		<h2>&#128737; DMARC: }.&html_escape($domain).qq{</h2>
		<div style="font-size:12px;opacity:0.8;margin-top:5px;">Domain-based Message Authentication, Reporting and Conformance</div>
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

# Current DMARC status
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128269; Estado DMARC Actual</div>\n};
if ($current_dmarc) {
	print qq{<p><span class="ovmns-badge ok">&#10003; DMARC Configurado</span></p>\n};
	print qq{<div class="ovmns-preview">}.&html_escape($current_dmarc).qq{</div>\n};
	print qq{<table class="ovmns-table">\n};
	print qq{<tr><th>Parametro</th><th>Valor</th><th>Descripcion</th></tr>\n};
	print qq{<tr><td>Version</td><td>}.&html_escape($dmarc_parsed{'v'} || 'DMARC1').qq{</td><td>Version del protocolo</td></tr>\n};

	my $p_desc = {
		'none' => 'Solo monitoreo, no aplica acciones',
		'quarantine' => 'Los emails sospechosos van a spam',
		'reject' => 'Los emails sospechosos son rechazados',
		};
	print qq{<tr><td>Politica (p)</td><td><strong>}.&html_escape($dmarc_parsed{'p'} || '-').qq{</strong></td><td>}.($p_desc->{$dmarc_parsed{'p'}} || '').qq{</td></tr>\n};
	print qq{<tr><td>Porcentaje (pct)</td><td>}.&html_escape($dmarc_parsed{'pct'} || '-').qq{</td><td>Porcentaje de emails afectados</td></tr>\n};
	print qq{<tr><td>Reportes (rua)</td><td>}.&html_escape($dmarc_parsed{'rua'} || '-').qq{</td><td>Email para reportes agregados</td></tr>\n};
	print qq{<tr><td>Forenses (ruf)</td><td>}.&html_escape($dmarc_parsed{'ruf'} || '-').qq{</td><td>Email para reportes forenses</td></tr>\n};
	print qq{</table>\n};
	}
else {
	print qq{<p><span class="ovmns-badge missing">&#10007; DMARC No Configurado</span></p>\n};
	print qq{<p style="color:#666;">No se encontro un registro DMARC para este dominio. Configuralo usando el formulario abajo.</p>\n};
	}
print qq{</div>\n};

# DMARC Explanation
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128218; Que es DMARC?</div>\n};
print qq{<div class="ovmns-info-box">\n};
print qq{<p>DMARC usa SPF y DKIM para determinar si un email es autentico. Permite al dueno del dominio especificar que hacer con los emails que fallan la autenticacion.</p>\n};
print qq{<table class="ovmns-table">\n};
print qq{<tr><th>Politica</th><th>Efecto</th><th>Recomendacion</th></tr>\n};
print qq{<tr><td><code>none</code></td><td>Solo monitoreo, genera reportes</td><td>Comenzar con esta para analizar</td></tr>\n};
print qq{<tr><td><code>quarantine</code></td><td>Envia emails sospechosos a spam</td><td>Usar despues de analizar reportes</td></tr>\n};
print qq{<tr><td><code>reject</code></td><td>Rechaza emails sospechosos</td><td>Meta final para maxima proteccion</td></tr>\n};
print qq{</table>\n};
print qq{</div>\n};
print qq{</div>\n};

# DMARC Configuration Form
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128295; Configurar DMARC</div>\n};
print qq{<form method="post" action="dmarc.cgi">\n};
print qq{<input type="hidden" name="domain" value="}.&html_escape($domain).qq{">\n};
print qq{<input type="hidden" name="action" value="apply_dmarc">\n};

# Policy selector
print qq{<div class="ovmns-form-group">\n};
print qq{<label>&#128737; Politica DMARC:</label>\n};
print qq{<div class="ovmns-radio-group">\n};
print qq{<div class="ovmns-radio-item">\n};
print qq{<input type="radio" name="policy" value="none" id="pol_none" checked>\n};
print qq{<label for="pol_none"><strong>none</strong><br><span style="font-size:11px;color:#666;">Monitoreo</span></label>\n};
print qq{</div>\n};
print qq{<div class="ovmns-radio-item">\n};
print qq{<input type="radio" name="policy" value="quarantine" id="pol_quar">\n};
print qq{<label for="pol_quar"><strong>quarantine</strong><br><span style="font-size:11px;color:#666;">Cuarentena</span></label>\n};
print qq{</div>\n};
print qq{<div class="ovmns-radio-item">\n};
print qq{<input type="radio" name="policy" value="reject" id="pol_rej">\n};
print qq{<label for="pol_rej"><strong>reject</strong><br><span style="font-size:11px;color:#666;">Rechazar</span></label>\n};
print qq{</div>\n};
print qq{</div>\n};
print qq{</div>\n};

# Percentage
print qq{<div class="ovmns-form-group">\n};
print qq{<label>&#128200; Porcentaje de aplicacion:</label>\n};
print qq{<select name="pct">\n};
print qq{<option value="10">10% (Prueba inicial)</option>\n};
print qq{<option value="25">25%</option>\n};
print qq{<option value="50">50%</option>\n};
print qq{<option value="100" selected>100% (Recomendado)</option>\n};
print qq{</select>\n};
print qq{</div>\n};

# Aggregate reports email
print qq{<div class="ovmns-form-group">\n};
print qq{<label>&#128233; Email para reportes agregados (rua):</label>\n};
print qq{<input type="email" name="rua" placeholder="dmarc\@$domain" value="}.&html_escape($dmarc_parsed{'rua'} ? $dmarc_parsed{'rua'} : "dmarc\@$domain").qq{">\n};
print qq{<div style="font-size:11px;color:#666;margin-top:3px;">Recibiras reportes diarios de los proveedores de email sobre el estado de autenticacion.</div>\n};
print qq{</div>\n};

# Forensic reports email
print qq{<div class="ovmns-form-group">\n};
print qq{<label>&#128233; Email para reportes forenses (ruf):</label>\n};
print qq{<input type="email" name="ruf" placeholder="dmarc-forensics\@$domain">\n};
print qq{<div style="font-size:11px;color:#666;margin-top:3px;">Recibiras copias de emails individuales que fallan la autenticacion. Opcional.</div>\n};
print qq{</div>\n};

# Alignment mode
print qq{<div class="ovmns-form-group">\n};
print qq{<label>&#128295; Alineacion DKIM (adkim):</label>\n};
print qq{<select name="adkim">\n};
print qq{<option value="r" selected>Relajada (r) - Recomendado</option>\n};
print qq{<option value="s">Estricta (s)</option>\n};
print qq{</select>\n};
print qq{</div>\n};

print qq{<div class="ovmns-form-group">\n};
print qq{<label>&#128295; Alineacion SPF (aspf):</label>\n};
print qq{<select name="aspf">\n};
print qq{<option value="r" selected>Relajada (r) - Recomendado</option>\n};
print qq{<option value="s">Estricta (s)</option>\n};
print qq{</select>\n};
print qq{</div>\n};

print qq{<div style="display:flex;gap:10px;margin-top:15px;">\n};
print qq{<button type="submit" class="ovmns-btn success" style="font-size:14px;padding:10px 20px;">&#10003; Aplicar DMARC</button>\n};
print qq{<a href="dmarc.cgi?domain=}.&urlize($domain).qq{" class="ovmns-btn danger">&#8634; Restaurar</a>\n};
print qq{</div>\n};
print qq{</form>\n};
print qq{</div>\n};

# Quick templates
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#9889; Plantillas Rapidas DMARC</div>\n};
print qq{<table class="ovmns-table">\n};
print qq{<tr><th>Nivel</th><th>Registro DMARC</th><th>Accion</th></tr>\n};

my @templates = (
	['Monitoreo (inicio)', "v=DMARC1; p=none; pct=100; rua=mailto:dmarc\@$domain"],
	['Cuarentena parcial', "v=DMARC1; p=quarantine; pct=25; rua=mailto:dmarc\@$domain"],
	['Cuarentena total', "v=DMARC1; p=quarantine; pct=100; rua=mailto:dmarc\@$domain"],
	['Rechazo (maximo)', "v=DMARC1; p=reject; pct=100; rua=mailto:dmarc\@$domain"],
	);

foreach my $t (@templates) {
	my $esc_dmarc = &html_escape($t->[1]);
	print qq{<tr>
		<td>}.&html_escape($t->[0]).qq{</td>
		<td><code style="font-size:11px;">$esc_dmarc</code></td>
		<td>
			<form method="post" action="dmarc.cgi" style="display:inline;">
				<input type="hidden" name="domain" value="}.&html_escape($domain).qq{">
				<input type="hidden" name="action" value="apply_dmarc">
				<input type="hidden" name="policy" value="none">
				<input type="hidden" name="pct" value="100">
				<input type="hidden" name="rua" value="dmarc\@$domain">
				<input type="hidden" name="raw_dmarc" value="$esc_dmarc">
				<button type="submit" class="ovmns-btn success" style="padding:4px 10px;font-size:11px;">Aplicar</button>
			</form>
		</td>
		</tr>\n};
	}
print qq{</table>\n};
print qq{</div>\n};

# Recommendation
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128161; Recomendacion de Implementacion</div>\n};
print qq{<div class="ovmns-warning-box">\n};
print qq{<p><strong>Proceso recomendado para implementar DMARC:</strong></p>\n};
print qq{<ol>\n};
print qq{<li><strong>Semana 1-2:</strong> Configurar SPF y DKIM primero</li>\n};
print qq{<li><strong>Semana 3-4:</strong> Configurar DMARC con <code>p=none</code> para monitorear</li>\n};
print qq{<li><strong>Semana 5-6:</strong> Analizar reportes y corregir problemas</li>\n};
print qq{<li><strong>Semana 7-8:</strong> Cambiar a <code>p=quarantine</code></li>\n};
print qq{<li><strong>Semana 9+:</strong> Cambiar a <code>p=reject</code> si todo funciona correctamente</li>\n};
print qq{</ol>\n};
print qq{</div>\n};
print qq{</div>\n};

print qq{</div>\n};

&ui_print_footer("edit_zone.cgi?domain=".&urlize($domain), "Volver a Zona DNS");
