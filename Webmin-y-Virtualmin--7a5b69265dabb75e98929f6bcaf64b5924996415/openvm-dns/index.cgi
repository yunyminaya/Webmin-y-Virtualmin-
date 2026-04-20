#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
chdir($FindBin::Bin);
require './openvm-dns-lib.pl';
&ReadParse();

ovmd_require_access();

my $init = ovmns_init();
my @domains = ovmns_list_domains_with_dns();
my $clouds = ovmd_dns_clouds();
my $remote = ovmd_remote_dns();

my $total_domains = scalar(@domains);
my $spf_ok = scalar(grep { $_->{'spf_status'} eq 'ok' } @domains);
my $dkim_ok = scalar(grep { $_->{'dkim_status'} eq 'ok' } @domains);
my $dmarc_ok = scalar(grep { $_->{'dmarc_status'} eq 'ok' } @domains);
my $dnssec_ok = scalar(grep { $_->{'dnssec_status'} eq 'active' || $_->{'dnssec_status'} eq 'signed' } @domains);

&ui_print_header(undef, 'OpenVM DNS Visual Manager', '', 'index');

print qq{
<style>
.ovmns-dashboard { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 10px; }
.ovmns-stats { display: flex; flex-wrap: wrap; gap: 15px; margin-bottom: 20px; }
.ovmns-stat-card {
	background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
	color: #fff; border-radius: 10px; padding: 20px; min-width: 180px;
	flex: 1; text-align: center; box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}
.ovmns-stat-card.green { background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); }
.ovmns-stat-card.blue { background: linear-gradient(135deg, #2193b0 0%, #6dd5ed 100%); }
.ovmns-stat-card.orange { background: linear-gradient(135deg, #f2994a 0%, #f2c94c 100%); }
.ovmns-stat-card.red { background: linear-gradient(135deg, #cb2d3e 0%, #ef473a 100%); }
.ovmns-stat-card.purple { background: linear-gradient(135deg, #7f00ff 0%, #e100ff 100%); }
.ovmns-stat-number { font-size: 32px; font-weight: bold; margin-bottom: 5px; }
.ovmns-stat-label { font-size: 13px; opacity: 0.9; }
.ovmns-section { background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 15px; margin-bottom: 20px; }
.ovmns-section-title { font-size: 16px; font-weight: 600; color: #333; margin-bottom: 15px; padding-bottom: 8px; border-bottom: 2px solid #667eea; }
.ovmns-domain-table { width: 100%; border-collapse: collapse; }
.ovmns-domain-table th { background: #f8f9fa; padding: 10px; text-align: left; font-size: 12px; color: #666; border-bottom: 2px solid #dee2e6; }
.ovmns-domain-table td { padding: 10px; border-bottom: 1px solid #eee; font-size: 13px; }
.ovmns-domain-table tr:hover { background: #f8f9fa; }
.ovmns-badge { display: inline-block; padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; }
.ovmns-badge.ok { background: #d4edda; color: #155724; }
.ovmns-badge.missing { background: #f8d7da; color: #721c24; }
.ovmns-badge.warning { background: #fff3cd; color: #856404; }
.ovmns-badge.active { background: #cce5ff; color: #004085; }
.ovmns-badge.disabled { background: #e2e3e5; color: #383d41; }
.ovmns-actions { display: flex; gap: 5px; flex-wrap: wrap; }
.ovmns-btn {
	display: inline-block; padding: 5px 12px; border-radius: 4px; font-size: 12px;
	text-decoration: none; color: #fff; cursor: pointer; border: none;
}
.ovmns-btn.primary { background: #667eea; }
.ovmns-btn.success { background: #28a745; }
.ovmns-btn.warning { background: #ffc107; color: #333; }
.ovmns-btn.danger { background: #dc3545; }
.ovmns-btn.info { background: #17a2b8; }
.ovmns-btn:hover { opacity: 0.85; }
.ovmns-propagation-bar {
	height: 20px; background: #e9ecef; border-radius: 10px; overflow: hidden; margin-top: 5px;
}
.ovmns-propagation-fill {
	height: 100%; border-radius: 10px; transition: width 0.5s;
}
.ovmns-toolbar { display: flex; gap: 10px; margin-bottom: 20px; flex-wrap: wrap; }
</style>

<div class="ovmns-dashboard">

<!-- Stats Cards -->
<div class="ovmns-stats">
<div class="ovmns-stat-card blue">
	<div class="ovmns-stat-number">$total_domains</div>
	<div class="ovmns-stat-label">Zonas DNS</div>
</div>
<div class="ovmns-stat-card green">
	<div class="ovmns-stat-number">$spf_ok / $total_domains</div>
	<div class="ovmns-stat-label">SPF Configurado</div>
</div>
<div class="ovmns-stat-card orange">
	<div class="ovmns-stat-number">$dkim_ok / $total_domains</div>
	<div class="ovmns-stat-label">DKIM Activo</div>
</div>
<div class="ovmns-stat-card purple">
	<div class="ovmns-stat-number">$dmarc_ok / $total_domains</div>
	<div class="ovmns-stat-label">DMARC Activo</div>
</div>
<div class="ovmns-stat-card red">
	<div class="ovmns-stat-number">$dnssec_ok / $total_domains</div>
	<div class="ovmns-stat-label">DNSSEC Activo</div>
</div>
</div>

<!-- Quick Actions Toolbar -->
<div class="ovmns-toolbar">
};

print qq{<a href="propagation.cgi" class="ovmns-btn info">&#128269; Verificar Propagacion</a>\n};

print qq{
</div>

};

# Domain security overview section
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128736; Estado de Seguridad DNS por Dominio</div>\n};

if (@domains) {
	print qq{<table class="ovmns-domain-table">\n};
	print qq{<tr>
		<th>Dominio</th>
		<th>Registros</th>
		<th>SPF</th>
		<th>DKIM</th>
		<th>DMARC</th>
		<th>DNSSEC</th>
		<th>Acciones</th>
		</tr>\n};

	foreach my $d (@domains) {
		my $dom = &html_escape($d->{'domain'});

		# Status badges
		my $spf_badge = $d->{'spf_status'} eq 'ok'
			? '<span class="ovmns-badge ok">&#10003; OK</span>'
			: '<span class="ovmns-badge missing">&#10007; Missing</span>';

		my $dkim_badge = $d->{'dkim_status'} eq 'ok'
			? '<span class="ovmns-badge ok">&#10003; OK</span>'
			: $d->{'dkim_status'} eq 'warning'
			? '<span class="ovmns-badge warning">&#9888; Warn</span>'
			: '<span class="ovmns-badge missing">&#10007; Missing</span>';

		my $dmarc_badge = $d->{'dmarc_status'} eq 'ok'
			? '<span class="ovmns-badge ok">&#10003; OK</span>'
			: '<span class="ovmns-badge missing">&#10007; Missing</span>';

		my $dnssec_badge = ($d->{'dnssec_status'} eq 'active' || $d->{'dnssec_status'} eq 'signed')
			? '<span class="ovmns-badge active">&#10003; Active</span>'
			: '<span class="ovmns-badge disabled">&#10007; Off</span>';

		my $rec_count = $d->{'records_count'} || 0;

		print qq{<tr>
			<td><strong>$dom</strong></td>
			<td>$rec_count</td>
			<td>$spf_badge</td>
			<td>$dkim_badge</td>
			<td>$dmarc_badge</td>
			<td>$dnssec_badge</td>
			<td>
				<div class="ovmns-actions">
				<a href="edit_zone.cgi?domain=}.$d->{'domain'}.qq{" class="ovmns-btn primary">Editar Zona</a>
				<a href="spf_wizard.cgi?domain=}.$d->{'domain'}.qq{" class="ovmns-btn success">SPF</a>
				<a href="dkim.cgi?domain=}.$d->{'domain'}.qq{" class="ovmns-btn warning">DKIM</a>
				<a href="dmarc.cgi?domain=}.$d->{'domain'}.qq{" class="ovmns-btn info">DMARC</a>
				<a href="dnssec.cgi?domain=}.$d->{'domain'}.qq{" class="ovmns-btn danger">DNSSEC</a>
				</div>
			</td>
			</tr>\n};
		}
	print qq{</table>\n};
	}
else {
	print qq{<p style="color:#666; text-align:center; padding:20px;">No se encontraron dominios con zonas DNS configuradas.</p>\n};
	}
print qq{</div>\n};

# DNS Propagation visual section
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#127760; Resumen de Propagacion DNS</div>\n};
if (@domains && ovmns_check_dig()) {
	print qq{<table class="ovmns-domain-table">\n};
	print qq{<tr><th>Dominio</th><th>IP Principal</th><th>Propagacion Estimada</th></tr>\n};
	foreach my $d (@domains) {
		my $dom = &html_escape($d->{'domain'});
		my $prop = ovmns_check_propagation($d->{'domain'}, 'A');
		my $pct = $prop->{'propagation_pct'} || 0;
		my $color = $pct >= 80 ? '#28a745' : $pct >= 50 ? '#ffc107' : '#dc3545';
		my $local_val = &html_escape($prop->{'local_value'} || 'N/A');
		print qq{<tr>
			<td>$dom</td>
			<td>$local_val</td>
			<td>
				<div style="display:flex;align-items:center;gap:10px;">
					<div class="ovmns-propagation-bar" style="flex:1;">
						<div class="ovmns-propagation-fill" style="width:$pct%;background:$color;"></div>
					</div>
					<span style="font-weight:600;color:$color;">$pct%</span>
				</div>
			</td>
			</tr>\n};
		}
	print qq{</table>\n};
	}
else {
	print qq{<p style="color:#666; text-align:center; padding:20px;">Herramienta dig no disponible para verificar propagacion.</p>\n};
	}
print qq{</div>\n};

# DNS Cloud Providers section (preserved from original)
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#9729; Proveedores DNS Cloud</div>\n};
if (@$clouds) {
	print qq{<table class="ovmns-domain-table">\n};
	print qq{<tr><th>Proveedor</th><th>Estado</th><th>Dominios</th></tr>\n};
	foreach my $cloud (@$clouds) {
		my $status = $cloud->{'state_ok'}
			? '<span class="ovmns-badge ok">&#10003; READY</span>'
			: '<span class="ovmns-badge warning">&#9888; UNCONFIGURED</span>';
		my $domains = @{$cloud->{'users'} || []} ? join(', ', @{$cloud->{'users'}}) : '-';
		my $label = $cloud->{'desc'} || $cloud->{'name'};
		my $title = &html_escape($label);
		if ($cloud->{'url'}) {
			$title = &ui_link($cloud->{'url'}, $title, undef, 'target=_blank');
			}
		print qq{<tr><td>$title</td><td>$status</td><td>}.&html_escape($domains).qq{</td></tr>\n};
		}
	print qq{</table>\n};
	}
else {
	print qq{<p style="color:#666; text-align:center; padding:20px;">No se detectaron proveedores DNS cloud.</p>\n};
	}
print qq{</div>\n};

# Remote DNS Servers section (preserved from original)
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128421; Servidores DNS Remotos</div>\n};
if (@$remote) {
	print qq{<table class="ovmns-domain-table">\n};
	print qq{<tr><th>Servidor</th><th>Tipo</th><th>Dominios</th><th>Cantidad</th></tr>\n};
	foreach my $server (@$remote) {
		my $host = &html_escape($server->{'host'} || '-');
		my $type = &html_escape($server->{'type'} || 'Remote');
		my $doms = &html_escape(join(', ', @{$server->{'domains'} || []}) || '-');
		my $count = $server->{'domain_count'} || 0;
		print qq{<tr><td>$host</td><td>$type</td><td>$doms</td><td>$count</td></tr>\n};
		}
	print qq{</table>\n};
	}
else {
	print qq{<p style="color:#666; text-align:center; padding:20px;">No se detectaron servidores DNS remotos.</p>\n};
	}
print qq{</div>\n};

# System tools status
print qq{<div class="ovmns-section">\n};
print qq{<div class="ovmns-section-title">&#128295; Herramientas del Sistema</div>\n};
print qq{<table class="ovmns-domain-table">\n};
my $bind_status = $init->{'bind_available'} ? '<span class="ovmns-badge ok">&#10003; Disponible</span>' : '<span class="ovmns-badge missing">&#10007; No encontrado</span>';
my $dig_status = $init->{'dig_available'} ? '<span class="ovmns-badge ok">&#10003; Disponible</span>' : '<span class="ovmns-badge missing">&#10007; No encontrado</span>';
my $dkim_status = $init->{'opendkim_available'} ? '<span class="ovmns-badge ok">&#10003; Disponible</span>' : '<span class="ovmns-badge missing">&#10007; No encontrado</span>';
my $dnssec_status = ($init->{'dnssec_tools'}{'dnssec-keygen'}) ? '<span class="ovmns-badge ok">&#10003; Disponible</span>' : '<span class="ovmns-badge missing">&#10007; No encontrado</span>';
print qq{<tr><td>BIND/named</td><td>$bind_status</td></tr>\n};
print qq{<tr><td>dig (DNS lookup)</td><td>$dig_status</td></tr>\n};
print qq{<tr><td>OpenDKIM</td><td>$dkim_status</td></tr>\n};
print qq{<tr><td>DNSSEC tools</td><td>$dnssec_status</td></tr>\n};
print qq{</table>\n};
print qq{</div>\n};

print qq{</div>\n};

&ui_print_footer('/', $text{'index_return'} || 'Return');
