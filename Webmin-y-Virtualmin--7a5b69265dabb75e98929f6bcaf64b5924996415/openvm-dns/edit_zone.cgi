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

# Handle POST actions
if ($action eq 'add_record') {
	my $type = $in{'record_type'};
	my $name = $in{'record_name'};
	my $value = $in{'record_value'};
	my $ttl = $in{'record_ttl'} || 86400;
	my $result = ovmns_add_record($domain, $type, $name, $value, $ttl);
	if ($result->{'ok'}) {
		&redirect("edit_zone.cgi?domain=".&urlize($domain)."&msg=".&urlize($result->{'message'}));
		exit;
		}
	else {
		&error($result->{'error'});
		}
	}
elsif ($action eq 'delete_record') {
	my $type = $in{'record_type'};
	my $name = $in{'record_name'};
	my $result = ovmns_delete_record($domain, $type, $name);
	if ($result->{'ok'}) {
		&redirect("edit_zone.cgi?domain=".&urlize($domain)."&msg=".&urlize($result->{'message'}));
		exit;
		}
	else {
		&error($result->{'error'});
		}
	}
elsif ($action eq 'edit_record') {
	my $type = $in{'record_type'};
	my $old_name = $in{'old_name'};
	my $new_name = $in{'new_name'};
	my $new_value = $in{'new_value'};
	my $new_ttl = $in{'new_ttl'} || 86400;
	my $result = ovmns_edit_record($domain, $type, $old_name, $new_name, $new_value, $new_ttl);
	if ($result->{'ok'}) {
		&redirect("edit_zone.cgi?domain=".&urlize($domain)."&msg=".&urlize($result->{'message'}));
		exit;
		}
	else {
		&error($result->{'error'});
		}
	}

my @records = ovmns_list_records($domain);
my $soa = ovmns_get_soa($domain);
my $msg = $in{'msg'};

&ui_print_header(undef, "DNS Zone Editor: ".&html_escape($domain), '', 'edit_zone');

print qq{
<style>
.ovmns-zone { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 10px; }
.ovmns-zone-header {
	display: flex; justify-content: space-between; align-items: center;
	padding: 15px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
	color: #fff; border-radius: 8px; margin-bottom: 20px;
}
.ovmns-zone-header h2 { margin: 0; font-size: 20px; }
.ovmns-section { background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 15px; margin-bottom: 20px; }
.ovmns-section-title { font-size: 16px; font-weight: 600; color: #333; margin-bottom: 15px; padding-bottom: 8px; border-bottom: 2px solid #667eea; }
.ovmns-table { width: 100%; border-collapse: collapse; }
.ovmns-table th { background: #f8f9fa; padding: 10px; text-align: left; font-size: 12px; color: #666; border-bottom: 2px solid #dee2e6; }
.ovmns-table td { padding: 8px 10px; border-bottom: 1px solid #eee; font-size: 13px; }
.ovmns-table tr:hover { background: #f8f9fa; }
.ovmns-type-badge {
	display: inline-block; padding: 3px 8px; border-radius: 4px; font-size: 11px;
	font-weight: 600; color: #fff; min-width: 50px; text-align: center;
}
.ovmns-type-A { background: #28a745; }
.ovmns-type-AAAA { background: #17a2b8; }
.ovmns-type-MX { background: #6610f2; }
.ovmns-type-CNAME { background: #fd7e14; }
.ovmns-type-TXT { background: #6c757d; }
.ovmns-type-NS { background: #dc3545; }
.ovmns-type-SRV { background: #20c997; }
.ovmns-type-CAA { background: #e83e8c; }
.ovmns-type-SOA { background: #007bff; }
.ovmns-btn {
	display: inline-block; padding: 5px 12px; border-radius: 4px; font-size: 12px;
	text-decoration: none; color: #fff; cursor: pointer; border: none;
}
.ovmns-btn.primary { background: #667eea; }
.ovmns-btn.success { background: #28a745; }
.ovmns-btn.danger { background: #dc3545; }
.ovmns-btn.warning { background: #ffc107; color: #333; }
.ovmns-btn.sm { padding: 3px 8px; font-size: 11px; }
.ovmns-btn:hover { opacity: 0.85; }
.ovmns-form-row { display: flex; gap: 10px; align-items: center; margin-bottom: 10px; flex-wrap: wrap; }
.ovmns-form-row label { font-size: 13px; font-weight: 600; color: #555; min-width: 60px; }
.ovmns-form-row input, .ovmns-form-row select {
	padding: 6px 10px; border: 1px solid #ddd; border-radius: 4px; font-size: 13px;
}
.ovmns-form-row input:focus, .ovmns-form-row select:focus { border-color: #667eea; outline: none; }
.ovmns-msg {
	padding: 10px 15px; border-radius: 6px; margin-bottom: 15px; font-size: 13px;
}
.ovmns-msg.success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
.ovmns-value-cell { max-width: 400px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ovmns-actions-cell { display: flex; gap: 5px; }
</style>

<div class="ovmns-zone">

<div class="ovmns-zone-header">
	<div>
		<h2>&#128203; Zona DNS: }.&html_escape($domain).qq{</h2>
		<div style="font-size:12px;opacity:0.8;margin-top:5px;">} . ($soa ? "Serial: $soa->{'serial'} | Primary NS: $soa->{'mname'}" : "SOA no disponible") . qq{</div>
	</div>
	<div style="display:flex;gap:8px;">
		<a href="index.cgi" class="ovmns-btn" style="background:rgba(255,255,255,0.2);color:#fff;">&#8592; Volver</a>
		<a href="spf_wizard.cgi?domain=}.&urlize($domain).qq{" class="ovmns-btn success">SPF Wizard</a>
		<a href="dkim.cgi?domain=}.&urlize($domain).qq{" class="ovmns-btn warning">DKIM</a>
		<a href="dmarc.cgi?domain=}.&urlize($domain).qq{" class="ovmns-btn primary">DMARC</a>
	</div>
</div>

};

# Show success message
if ($msg) {
	print qq{<div class="ovmns-msg success">&#10003; }.&html_escape($msg).qq{</div>\n};
	}

# SOA Information section
if ($soa) {
	print qq{<div class="ovmns-section">\n};
	print qq{<div class="ovmns-section-title">&#128196; Registro SOA</div>\n};
	print qq{<table class="ovmns-table">\n};
	print qq{<tr><th>Primary NS</th><th>Admin Email</th><th>Serial</th><th>Refresh</th><th>Retry</th><th>Expire</th><th>Minimum TTL</th></tr>\n};
	print qq{<tr>
		<td>}.&html_escape($soa->{'mname'}).qq{</td>
		<td>}.&html_escape($soa->{'rname'}).qq{</td>
		<td><strong>}.&html_escape($soa->{'serial'}).qq{</strong></td>
		<td>}.&html_escape($soa->{'refresh'}).qq{s</td>
		<td>}.&html_escape($soa->{'retry'}).qq{s</td>
		<td>}.&html_escape($soa->{'expire'}).qq{s</td>
		<td>}.&html_escape($soa->{'minimum'}).qq{s</td>
		</tr>\n};
	print qq{</table>\n};
	print qq{</div>\n};
	}

# DNS Records table
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128203; Registros DNS (}.scalar(@records).qq{ registros)</div>\n};

if (@records) {
	print qq{<table class="ovmns-table">\n};
	print qq{<tr><th>Tipo</th><th>Nombre</th><th>Valor</th><th>TTL</th><th>Acciones</th></tr>\n};

	foreach my $rec (@records) {
		my $type = &html_escape($rec->{'type'});
		my $name = &html_escape($rec->{'name'});
		my $value = &html_escape($rec->{'value'});
		my $ttl = $rec->{'ttl'};
		my $type_class = "ovmns-type-$rec->{'type'}";

		print qq{<tr>
			<td><span class="ovmns-type-badge $type_class">$type</span></td>
			<td>$name</td>
			<td class="ovmns-value-cell" title="$value">$value</td>
			<td>}.($ttl ? "${ttl}s" : '-').qq{</td>
			<td class="ovmns-actions-cell">
				<form method="post" action="edit_zone.cgi" style="display:inline;">
					<input type="hidden" name="domain" value="}.&html_escape($domain).qq{">
					<input type="hidden" name="action" value="delete_record">
					<input type="hidden" name="record_type" value="}.&html_escape($rec->{'type'}).qq{">
					<input type="hidden" name="record_name" value="}.&html_escape($rec->{'name'}).qq{">
					<button type="submit" class="ovmns-btn danger sm" onclick="return confirm('Eliminar registro $type $name?')">&#128465; Eliminar</button>
				</form>
			</td>
			</tr>\n};
		}
	print qq{</table>\n};
	}
else {
	print qq{<p style="color:#666; text-align:center; padding:20px;">No se encontraron registros DNS para este dominio.</p>\n};
	}
print qq{</div>\n};

# Add new record form
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#10133; Agregar Nuevo Registro</div>\n};
print qq{<form method="post" action="edit_zone.cgi">\n};
print qq{<input type="hidden" name="domain" value="}.&html_escape($domain).qq{">\n};
print qq{<input type="hidden" name="action" value="add_record">\n};
print qq{<div class="ovmns-form-row">\n};
print qq{<label>Tipo:</label>\n};
print qq{<select name="record_type">\n};
foreach my $t ('A', 'AAAA', 'CNAME', 'MX', 'TXT', 'NS', 'SRV', 'CAA') {
	print qq{<option value="$t">$t</option>\n};
	}
print qq{</select>\n};
print qq{<label>Nombre:</label>\n};
print qq{<input type="text" name="record_name" placeholder="$domain o subdominio" size="25">\n};
print qq{<label>Valor:</label>\n};
print qq{<input type="text" name="record_value" placeholder="IP, hostname, texto..." size="35" required>\n};
print qq{<label>TTL:</label>\n};
print qq{<select name="record_ttl">\n};
print qq{<option value="300">5 min (300)</option>\n};
print qq{<option value="900">15 min (900)</option>\n};
print qq{<option value="1800">30 min (1800)</option>\n};
print qq{<option value="3600">1 hora (3600)</option>\n};
print qq{<option value="14400">4 horas (14400)</option>\n};
print qq{<option value="86400" selected>1 dia (86400)</option>\n};
print qq{</select>\n};
print qq{<button type="submit" class="ovmns-btn success">&#10133; Agregar Registro</button>\n};
print qq{</div>\n};
print qq{</form>\n};
print qq{</div>\n};

# Quick reference
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128218; Referencia Rapida de Tipos de Registro</div>\n};
print qq{<table class="ovmns-table">\n};
print qq{<tr><th>Tipo</th><th>Descripcion</th><th>Ejemplo de Valor</th></tr>\n};
print qq{<tr><td><span class="ovmns-type-badge ovmns-type-A">A</span></td><td>Direccion IPv4</td><td>192.168.1.100</td></tr>\n};
print qq{<tr><td><span class="ovmns-type-badge ovmns-type-AAAA">AAAA</span></td><td>Direccion IPv6</td><td>2001:db8::1</td></tr>\n};
print qq{<tr><td><span class="ovmns-type-badge ovmns-type-CNAME">CNAME</span></td><td>Alias a otro dominio</td><td>www.example.com.</td></tr>\n};
print qq{<tr><td><span class="ovmns-type-badge ovmns-type-MX">MX</span></td><td>Servidor de correo</td><td>10 mail.example.com.</td></tr>\n};
print qq{<tr><td><span class="ovmns-type-badge ovmns-type-TXT">TXT</span></td><td>Texto (SPF, DKIM, etc.)</td><td>"v=spf1 +a +mx -all"</td></tr>\n};
print qq{<tr><td><span class="ovmns-type-badge ovmns-type-NS">NS</span></td><td>Servidor de nombres</td><td>ns1.example.com.</td></tr>\n};
print qq{<tr><td><span class="ovmns-type-badge ovmns-type-SRV">SRV</span></td><td>Servicio</td><td>10 5 5060 sip.example.com.</td></tr>\n};
print qq{<tr><td><span class="ovmns-type-badge ovmns-type-CAA">CAA</span></td><td>Autoridad de certificacion</td><td>0 issue "letsencrypt.org"</td></tr>\n};
print qq{</table>\n};
print qq{</div>\n};

print qq{</div>\n};

&ui_print_footer("index.cgi", "Volver a DNS Manager");
