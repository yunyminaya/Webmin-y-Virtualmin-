#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-billing-lib.pl';
&ReadParse();

ovmbl_init();

# Handle actions
if ($in{'action'}) {
	if ($in{'action'} eq 'mark_paid' && $in{'id'}) {
		ovmbl_mark_paid($in{'id'});
		}
	elsif ($in{'action'} eq 'cancel' && $in{'id'}) {
		ovmbl_mark_cancelled($in{'id'});
		}
	elsif ($in{'action'} eq 'delete_invoice' && $in{'id'}) {
		ovmbl_delete_invoice($in{'id'});
		}
	elsif ($in{'action'} eq 'generate_recurring') {
		my $count = ovmbl_generate_recurring_invoices();
		}
	}

my $overview = ovmbl_get_billing_overview();
my $stats = $overview->{'stats'};
my $invoices = ovmbl_list_invoices('all');
my $overdue = ovmbl_get_overdue_invoices();
my $suspensions = ovmbl_check_suspensions();
my $monthly = ovmbl_get_monthly_revenue(6);

# Sort invoices by created desc, take last 10
my @sorted_inv = sort { ($b->{'created'} || 0) <=> ($a->{'created'} || 0) } @$invoices;
my @recent = @sorted_inv[0 .. ($#sorted_inv > 9 ? 9 : $#sorted_inv)];

&ui_print_header(undef, 'OpenVM Billing', '', 'index');

# ── Stats Cards ──
my $month_rev = ovmbl_format_currency($stats->{'month_revenue'});
my $pend_amt  = ovmbl_format_currency($stats->{'pending_amount'});
my $over_amt  = ovmbl_format_currency($stats->{'overdue_amount'});

print qq{
<div style="display:flex;flex-wrap:wrap;gap:15px;margin-bottom:20px;">
  <div style="flex:1;min-width:200px;background:linear-gradient(135deg,#0065ff,#2684ff);color:#fff;border-radius:8px;padding:18px 20px;">
    <div style="font-size:13px;opacity:0.85;">Ingresos del Mes</div>
    <div style="font-size:28px;font-weight:bold;margin-top:4px;">$month_rev</div>
  </div>
  <div style="flex:1;min-width:200px;background:linear-gradient(135deg,#ff991f,#ffc400);color:#fff;border-radius:8px;padding:18px 20px;">
    <div style="font-size:13px;opacity:0.85;">Facturas Pendientes</div>
    <div style="font-size:28px;font-weight:bold;margin-top:4px;">$stats->{'pending_count'} <span style="font-size:14px;">($pend_amt)</span></div>
  </div>
  <div style="flex:1;min-width:200px;background:linear-gradient(135deg,#de350b,#ff7452);color:#fff;border-radius:8px;padding:18px 20px;">
    <div style="font-size:13px;opacity:0.85;">Facturas Vencidas</div>
    <div style="font-size:28px;font-weight:bold;margin-top:4px;">$stats->{'overdue_count'} <span style="font-size:14px;">($over_amt)</span></div>
  </div>
  <div style="flex:1;min-width:200px;background:linear-gradient(135deg,#36b37e,#57d9a3);color:#fff;border-radius:8px;padding:18px 20px;">
    <div style="font-size:13px;opacity:0.85;">Clientes Activos</div>
    <div style="font-size:28px;font-weight:bold;margin-top:4px;">$overview->{'active_clients'}</div>
  </div>
</div>
};

# ── Action buttons ──
print qq{<div style="margin-bottom:15px;display:flex;flex-wrap:wrap;gap:8px;">};
print qq{<a href="invoices.cgi?action=new" style="text-decoration:none;background:#0065ff;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;font-weight:bold;">+ Nueva Factura</a>};
print qq{<a href="plans.cgi" style="text-decoration:none;background:#6554c0;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;">Planes</a>};
print qq{<a href="clients.cgi" style="text-decoration:none;background:#36b37e;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;">Clientes</a>};
print qq{<a href="reports.cgi" style="text-decoration:none;background:#44546f;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;">Reportes</a>};
print qq{<a href="settings.cgi" style="text-decoration:none;background:#6b778c;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;">Configuraci&oacute;n</a>};
print qq{<a href="index.cgi?action=generate_recurring" style="text-decoration:none;background:#ff991f;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;">Generar Recurrentes</a>};
print qq{</div>};

# ── Alerts section ──
if (scalar(@$overdue) > 0 || scalar(@$suspensions) > 0) {
	print qq{<div style="background:#fff3cd;border:1px solid #ffc107;border-radius:6px;padding:12px 16px;margin-bottom:15px;">};
	print qq{<div style="font-weight:bold;color:#856404;margin-bottom:6px;">&#9888; Alertas</div>};
	if (scalar(@$overdue) > 0) {
		print qq{<div style="color:#856404;font-size:13px;">&#8226; Hay <b>} . scalar(@$overdue) . qq{</b> factura(s) vencida(s) por un total de <b>} . ovmbl_format_currency($stats->{'overdue_amount'}) . qq{</b></div>};
		}
	if (scalar(@$suspensions) > 0) {
		print qq{<div style="color:#de350b;font-size:13px;">&#8226; <b>} . scalar(@$suspensions) . qq{</b> cuenta(s) candidata(s) a suspensi&oacute;n autom&aacute;tica</div>};
		}
	print qq{</div>};
	}

# ── Revenue Chart (CSS bar chart) ──
print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;margin-bottom:15px;">
  <div style="font-weight:bold;font-size:14px;margin-bottom:12px;color:#172b4d;">Ingresos &mdash; &Uacute;ltimos 6 meses</div>
  <div style="display:flex;align-items:flex-end;gap:8px;height:160px;padding-top:10px;">
};

my $max_rev = 1;
foreach my $m (@$monthly) {
	my $r = $m->{'revenue'} || 0;
	$max_rev = $r if $r > $max_rev;
	}
foreach my $m (@$monthly) {
	my $r = $m->{'revenue'} || 0;
	my $pct = $max_rev > 0 ? int(($r / $max_rev) * 100) : 0;
	$pct = 5 if $pct < 5;
	my $label = ovmbl_format_currency($r);
	my $short_month = substr($m->{'month'}, 5, 2) . '/' . substr($m->{'month'}, 2, 2);
	print qq{
    <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;height:100%;">
      <div style="font-size:10px;color:#6b778c;margin-bottom:2px;">$label</div>
      <div style="width:100%;background:linear-gradient(180deg,#0065ff,#2684ff);height:$pct%;border-radius:3px 3px 0 0;min-height:4px;"></div>
      <div style="font-size:10px;color:#6b778c;margin-top:4px;">$short_month</div>
    </div>
	};
	}
print qq{</div></div>};

# ── Recent invoices table ──
print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;overflow:hidden;margin-bottom:15px;">
  <div style="padding:12px 16px;font-weight:bold;font-size:14px;border-bottom:1px solid #dfe1e6;color:#172b4d;">&Uacute;ltimas Facturas</div>
};

if (@recent) {
	print qq{
	<table style="width:100%;border-collapse:collapse;font-size:13px;">
	  <thead>
	    <tr style="background:#f4f5f7;">
	      <th style="padding:8px 12px;text-align:left;color:#6b778c;">N&uacute;mero</th>
	      <th style="padding:8px 12px;text-align:left;color:#6b778c;">Cliente</th>
	      <th style="padding:8px 12px;text-align:right;color:#6b778c;">Monto</th>
	      <th style="padding:8px 12px;text-align:center;color:#6b778c;">Estado</th>
	      <th style="padding:8px 12px;text-align:left;color:#6b778c;">Fecha</th>
	      <th style="padding:8px 12px;text-align:center;color:#6b778c;">Acciones</th>
	    </tr>
	  </thead>
	  <tbody>
	};
	foreach my $inv (@recent) {
		my $status = $inv->{'status'} || 'pending';
		# Check if overdue
		if ($status eq 'pending' && $inv->{'due_date'} && $inv->{'due_date'} < time()) {
			$status = 'overdue';
			}
		my $badge = ovmbl_status_badge($status);
		my $date = ovmbl_human_date($inv->{'created'});
		my $total = ovmbl_format_currency($inv->{'total'});
		my $esc_num = &html_escape($inv->{'number'} || 'N/A');
		my $esc_cli = &html_escape($inv->{'client_name'} || 'N/A');

		print qq{
	    <tr style="border-bottom:1px solid #ebecf0;">
	      <td style="padding:8px 12px;"><a href="invoices.cgi?action=view&id=$inv->{'id'}" style="color:#0065ff;text-decoration:none;">$esc_num</a></td>
	      <td style="padding:8px 12px;">$esc_cli</td>
	      <td style="padding:8px 12px;text-align:right;font-weight:bold;">$total</td>
	      <td style="padding:8px 12px;text-align:center;">$badge</td>
	      <td style="padding:8px 12px;color:#6b778c;">$date</td>
	      <td style="padding:8px 12px;text-align:center;">
		};
		if ($status eq 'pending' || $status eq 'overdue') {
			print qq{<a href="index.cgi?action=mark_paid&id=$inv->{'id'}" style="font-size:11px;color:#36b37e;text-decoration:none;margin-right:6px;">Pagar</a>};
			}
		print qq{<a href="invoices.cgi?action=edit&id=$inv->{'id'}" style="font-size:11px;color:#0065ff;text-decoration:none;">Ver</a>};
		print qq{</td></tr>};
		}
	print qq{</tbody></table>};
	}
else {
	print qq{<div style="padding:20px;text-align:center;color:#6b778c;">No hay facturas. <a href="invoices.cgi?action=new" style="color:#0065ff;">Crear primera factura</a></div>};
	}
print qq{</div>};

# ── Footer links ──
print qq{
<div style="text-align:center;padding:10px;color:#6b778c;font-size:12px;">
  <a href="plans.cgi" style="color:#0065ff;text-decoration:none;">Planes</a> &middot;
  <a href="invoices.cgi" style="color:#0065ff;text-decoration:none;">Facturas</a> &middot;
  <a href="clients.cgi" style="color:#0065ff;text-decoration:none;">Clientes</a> &middot;
  <a href="reports.cgi" style="color:#0065ff;text-decoration:none;">Reportes</a> &middot;
  <a href="settings.cgi" style="color:#0065ff;text-decoration:none;">Configuraci&oacute;n</a>
</div>
};

&ui_print_footer('/', 'Index');
