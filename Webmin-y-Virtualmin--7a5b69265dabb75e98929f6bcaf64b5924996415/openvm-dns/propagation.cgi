#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
chdir($FindBin::Bin);
require './openvm-dns-lib.pl';
&ReadParse();

ovmd_require_access();

my $domain = $in{'domain'};
my $type = $in{'type'} || 'A';
my $action = $in{'action'} || '';

# Handle check action
if ($action eq 'check' && $domain) {
	# Will be handled below in display
	}

my @domains;
if (defined(&list_domains)) {
	ovmd_load_virtualmin();
	my @doms = &list_domains();
	@domains = map { $_->{'dom'} } grep { $_->{'dns_domain'} } @doms;
	}

my $propagation;
if ($domain && $action eq 'check') {
	$propagation = ovmns_check_propagation($domain, $type);
	}

&ui_print_header(undef, 'DNS Propagation Check', '', 'propagation');

print qq{
<style>
.ovmns-prop { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 10px; }
.ovmns-header {
	display: flex; justify-content: space-between; align-items: center;
	padding: 15px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
	color: #fff; border-radius: 8px; margin-bottom: 20px;
}
.ovmns-header h2 { margin: 0; font-size: 20px; }
.ovmns-section { background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 15px; margin-bottom: 20px; }
.ovmns-section-title { font-size: 16px; font-weight: 600; color: #333; margin-bottom: 15px; padding-bottom: 8px; border-bottom: 2px solid #667eea; }
.ovmns-table { width: 100%; border-collapse: collapse; }
.ovmns-table th { background: #f8f9fa; padding: 10px; text-align: left; font-size: 12px; color: #666; border-bottom: 2px solid #dee2e6; }
.ovmns-table td { padding: 10px; border-bottom: 1px solid #eee; font-size: 13px; }
.ovmns-table tr:hover { background: #f8f9fa; }
.ovmns-badge { display: inline-block; padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; }
.ovmns-badge.ok { background: #d4edda; color: #155724; }
.ovmns-badge.missing { background: #f8d7da; color: #721c24; }
.ovmns-badge.warning { background: #fff3cd; color: #856404; }
.ovmns-btn {
	display: inline-block; padding: 8px 16px; border-radius: 4px; font-size: 13px;
	text-decoration: none; color: #fff; cursor: pointer; border: none;
}
.ovmns-btn.primary { background: #667eea; }
.ovmns-btn.success { background: #28a745; }
.ovmns-btn:hover { opacity: 0.85; }
.ovmns-form-row { display: flex; gap: 10px; align-items: center; margin-bottom: 15px; flex-wrap: wrap; }
.ovmns-form-row label { font-size: 13px; font-weight: 600; color: #555; }
.ovmns-form-row input, .ovmns-form-row select {
	padding: 8px 12px; border: 1px solid #ddd; border-radius: 4px; font-size: 13px;
}
.ovmns-form-row input:focus, .ovmns-form-row select:focus { border-color: #667eea; outline: none; }
.ovmns-prop-bar {
	height: 24px; background: #e9ecef; border-radius: 12px; overflow: hidden;
	position: relative; margin: 10px 0;
}
.ovmns-prop-fill {
	height: 100%; border-radius: 12px; display: flex; align-items: center;
	justify-content: center; color: #fff; font-weight: 600; font-size: 12px;
	transition: width 0.5s;
}
.ovmns-prop-card {
	display: inline-block; padding: 15px; border-radius: 8px; text-align: center;
	min-width: 120px; margin: 5px;
}
.ovmns-prop-card.match { background: #d4edda; border: 2px solid #28a745; }
.ovmns-prop-card.nomatch { background: #f8d7da; border: 2px solid #dc3545; }
.ovmns-prop-card.empty { background: #e2e3e5; border: 2px solid #6c757d; }
.ovmns-prop-card .server-name { font-size: 11px; color: #666; margin-bottom: 5px; }
.ovmns-prop-card .server-value { font-size: 13px; font-weight: 600; word-break: break-all; }
.ovmns-prop-card .server-status { font-size: 18px; margin-top: 5px; }
.ovmns-prop-card .server-time { font-size: 10px; color: #888; margin-top: 3px; }
</style>

<div class="ovmns-prop">

<div class="ovmns-header">
	<div>
		<h2>&#127760; Verificacion de Propagacion DNS</h2>
		<div style="font-size:12px;opacity:0.8;margin-top:5px;">Consulta multiples DNS publicos para verificar la propagacion de tus registros</div>
	</div>
	<div>
		<a href="index.cgi" class="ovmns-btn" style="background:rgba(255,255,255,0.2);color:#fff;">&#8592; Dashboard</a>
	</div>
</div>

<!-- Check Form -->
<div class="ovmns-section">
<div class="ovmns-section-title">&#128269; Consultar Propagacion</div>
<form method="post" action="propagation.cgi">
<input type="hidden" name="action" value="check">
<div class="ovmns-form-row">
	<label>Dominio:</label>
	<input type="text" name="domain" placeholder="example.com" value="}.&html_escape($domain || '').qq{" size="30" required>
	<label>Tipo:</label>
	<select name="type">
};

foreach my $t ('A', 'AAAA', 'CNAME', 'MX', 'NS', 'TXT', 'SOA', 'SRV', 'CAA') {
	my $sel = ($t eq $type) ? ' selected' : '';
	print qq{<option value="$t"$sel>$t</option>\n};
	}

print qq{
	</select>
	<button type="submit" class="ovmns-btn primary">&#128269; Verificar Propagacion</button>
</div>
</form>
</div>

};

# Show results
if ($propagation && $propagation->{'ok'}) {
	my $pct = $propagation->{'propagation_pct'};
	my $total = $propagation->{'total_servers'};
	my $matching = $propagation->{'matching_servers'};
	my $local_val = &html_escape($propagation->{'local_value'} || 'N/A');

	# Overall propagation bar
	my $bar_color = $pct >= 80 ? '#28a745' : $pct >= 50 ? '#ffc107' : '#dc3545';
	my $status_text = $pct >= 80 ? 'Propagacion Completa' : $pct >= 50 ? 'Propagacion Parcial' : 'Propagacion Baja';

	print qq{<div class="ovmns-section">\n};
	print qq{<div class="ovmns-section-title">&#128202; Resultado: }.&html_escape($domain).qq{ / }.&html_escape($type).qq{</div>\n};

	# Summary stats
	print qq{<div style="display:flex;gap:15px;margin-bottom:15px;flex-wrap:wrap;">\n};
	print qq{<div style="background:#f8f9fa;padding:10px 15px;border-radius:6px;text-align:center;min-width:100px;">\n};
	print qq{<div style="font-size:11px;color:#666;">Valor Local</div>\n};
	print qq{<div style="font-size:14px;font-weight:600;">$local_val</div>\n};
	print qq{</div>\n};
	print qq{<div style="background:#f8f9fa;padding:10px 15px;border-radius:6px;text-align:center;min-width:100px;">\n};
	print qq{<div style="font-size:11px;color:#666;">Servidores</div>\n};
	print qq{<div style="font-size:14px;font-weight:600;">$matching / $total</div>\n};
	print qq{</div>\n};
	print qq{<div style="background:#f8f9fa;padding:10px 15px;border-radius:6px;text-align:center;min-width:100px;">\n};
	print qq{<div style="font-size:11px;color:#666;">Estado</div>\n};
	print qq{<div style="font-size:14px;font-weight:600;color:$bar_color;">$status_text</div>\n};
	print qq{</div>\n};
	print qq{</div>\n};

	# Propagation bar
	print qq{<div class="ovmns-prop-bar">\n};
	print qq{<div class="ovmns-prop-fill" style="width:$pct%;background:$bar_color;">$pct%</div>\n};
	print qq{</div>\n};

	# Server cards
	print qq{<div style="display:flex;flex-wrap:wrap;gap:5px;margin-top:15px;">\n};
	foreach my $srv (@{$propagation->{'servers'} || []}) {
		my $card_class = !$srv->{'value'} ? 'empty' : $srv->{'match'} ? 'match' : 'nomatch';
		my $status_icon = !$srv->{'value'} ? '&#9724;' : $srv->{'match'} ? '&#10003;' : '&#10007;';
		my $val = &html_escape($srv->{'value'} || 'Sin respuesta');
		my $time = $srv->{'time_ms'} ? sprintf("%.0fms", $srv->{'time_ms'}) : '-';

		print qq{<div class="ovmns-prop-card $card_class">\n};
		print qq{<div class="server-name">}.&html_escape($srv->{'name'}).qq{<br><small>}.&html_escape($srv->{'ip'}).qq{</small></div>\n};
		print qq{<div class="server-value">$val</div>\n};
		print qq{<div class="server-status">$status_icon</div>\n};
		print qq{<div class="server-time">$time</div>\n};
		print qq{</div>\n};
		}
	print qq{</div>\n};

	print qq{</div>\n};

	# Detailed comparison table
	print qq{<div class="ovmns-section">\n};
	print qq{<div class="ovmns-section-title">&#128203; Tabla Comparativa Detallada</div>\n};
	print qq{<table class="ovmns-table">\n};
	print qq{<tr><th>Servidor</th><th>IP</th><th>Valor</th><th>Tiempo</th><th>Coincide</th></tr>\n};

	foreach my $srv (@{$propagation->{'servers'} || []}) {
		my $match_badge = !$srv->{'value'}
			? '<span class="ovmns-badge warning">Sin datos</span>'
			: $srv->{'match'}
			? '<span class="ovmns-badge ok">&#10003; Si</span>'
			: '<span class="ovmns-badge missing">&#10007; No</span>';
		my $val = &html_escape($srv->{'value'} || '-');
		my $time = $srv->{'time_ms'} ? sprintf("%.0f ms", $srv->{'time_ms'}) : '-';

		print qq{<tr>
			<td>}.&html_escape($srv->{'name'}).qq{</td>
			<td><code>}.&html_escape($srv->{'ip'}).qq{</code></td>
			<td>$val</td>
			<td>$time</td>
			<td>$match_badge</td>
			</tr>\n};
		}
	print qq{</table>\n};
	print qq{</div>\n};

	# Re-check button
	print qq{<div style="text-align:center;margin:15px 0;">\n};
	print qq{<form method="post" action="propagation.cgi" style="display:inline;">\n};
	print qq{<input type="hidden" name="action" value="check">\n};
	print qq{<input type="hidden" name="domain" value="}.&html_escape($domain).qq{">\n};
	print qq{<input type="hidden" name="type" value="}.&html_escape($type).qq{">\n};
	print qq{<button type="submit" class="ovmns-btn primary" style="font-size:14px;padding:10px 20px;">&#128260; Re-verificar</button>\n};
	print qq{</form>\n};
	print qq{</div>\n};
	}
elsif ($domain && $action eq 'check' && !$propagation->{'ok'}) {
	print qq{<div class="ovmns-section">\n};
	print qq{<div style="text-align:center;padding:20px;color:#dc3545;">\n};
	print qq{<p>&#10007; Error al verificar la propagacion: }.&html_escape($propagation->{'error'} || 'Error desconocido').qq{</p>\n};
	print qq{</div>\n};
	print qq{</div>\n};
	}

# Quick check for all domains
if (@domains && !$propagation) {
	print qq{<div class="ovmns-section">\n};
	print qq{<div class="ovmns-section-title">&#9889; Verificacion Rapida de Todos los Dominios</div>\n};
	print qq{<table class="ovmns-table">\n};
	print qq{<tr><th>Dominio</th><th>IP Local</th><th>Propagacion A</th><th>Acciones</th></tr>\n};

	foreach my $dom (@domains) {
		my $prop = ovmns_check_propagation($dom, 'A');
		my $pct = $prop->{'propagation_pct'} || 0;
		my $color = $pct >= 80 ? '#28a745' : $pct >= 50 ? '#ffc107' : '#dc3545';
		my $local = &html_escape($prop->{'local_value'} || 'N/A');

		print qq{<tr>
			<td><strong>}.&html_escape($dom).qq{</strong></td>
			<td>$local</td>
			<td>
				<div style="display:flex;align-items:center;gap:10px;">
					<div style="flex:1;height:16px;background:#e9ecef;border-radius:8px;overflow:hidden;">
						<div style="height:100%;width:$pct%;background:$color;border-radius:8px;"></div>
					</div>
					<span style="font-weight:600;color:$color;font-size:12px;">$pct%</span>
				</div>
			</td>
			<td>
				<a href="propagation.cgi?action=check&domain=}.&urlize($dom).qq{&type=A" class="ovmns-btn primary" style="padding:3px 8px;font-size:11px;">Detalles</a>
				<a href="propagation.cgi?action=check&domain=}.&urlize($dom).qq{&type=MX" class="ovmns-btn success" style="padding:3px 8px;font-size:11px;">MX</a>
				<a href="propagation.cgi?action=check&domain=}.&urlize($dom).qq{&type=TXT" class="ovmns-btn primary" style="padding:3px 8px;font-size:11px;">TXT</a>
			</td>
			</tr>\n};
		}
	print qq{</table>\n};
	print qq{</div>\n};
	}

# DNS servers info
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#127760; Servidores DNS Publicos Utilizados</div>\n};
print qq{<table class="ovmns-table">\n};
print qq{<tr><th>Proveedor</th><th>IP Primaria</th><th>IP Secundaria</th></tr>\n};
print qq{<tr><td>Google</td><td>8.8.8.8</td><td>8.8.4.4</td></tr>\n};
print qq{<tr><td>Cloudflare</td><td>1.1.1.1</td><td>1.0.0.1</td></tr>\n};
print qq{<tr><td>OpenDNS</td><td>208.67.222.222</td><td>208.67.220.220</td></tr>\n};
print qq{<tr><td>Quad9</td><td>9.9.9.9</td><td>-</td></tr>\n};
print qq{</table>\n};
print qq{</div>\n};

print qq{</div>\n};

&ui_print_footer("index.cgi", "Volver a DNS Manager");
