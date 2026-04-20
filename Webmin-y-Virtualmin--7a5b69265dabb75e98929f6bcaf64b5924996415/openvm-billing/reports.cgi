#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-billing-lib.pl';
&ReadParse();

ovmbl_init();

my $period = $in{'period'} || 'this_month';

# Handle CSV export
if ($in{'export_csv'}) {
	my $csv = ovmbl_export_csv('invoices');
	print "Content-type: text/csv\n";
	print "Content-Disposition: attachment; filename=billing_report.csv\n\n";
	print $csv;
	exit(0);
	}

# Calculate date ranges
my $now = time();
my ($start_ts, $end_ts);
my @now_t = localtime($now);

if ($period eq 'this_month') {
	$start_ts = eval { no strict 'refs'; use Time::Local; timegm(0,0,0,1,$now_t[4],$now_t[5]) } || $now;
	$end_ts = $now;
	}
elsif ($period eq 'last_month') {
	my @lm = localtime($now - 30*86400);
	$start_ts = eval { use Time::Local; timegm(0,0,0,1,$lm[4],$lm[5]) } || $now;
	$end_ts = eval { use Time::Local; timegm(0,0,0,1,$now_t[4],$now_t[5]) } || $now;
	}
elsif ($period eq 'last_quarter') {
	$start_ts = $now - (90 * 86400);
	$end_ts = $now;
	}
elsif ($period eq 'last_year') {
	$start_ts = $now - (365 * 86400);
	$end_ts = $now;
	}
else {
	$start_ts = $now - (30 * 86400);
	$end_ts = $now;
	}

# Get data
my $stats       = ovmbl_get_revenue_stats();
my $monthly     = ovmbl_get_monthly_revenue(12);
my $plan_dist   = ovmbl_get_plan_distribution();
my $top_clients = ovmbl_get_top_clients(10);

&ui_print_header(undef, 'OpenVM Billing &mdash; Reports', '', 'reports');

# ── Period selector ──
print qq{<div style="margin-bottom:15px;display:flex;flex-wrap:wrap;gap:8px;align-items:center;">};
print qq{<span style="font-weight:bold;font-size:13px;color:#172b4d;margin-right:8px;">Per&iacute;odo:</span>};
my @periods = (
	['this_month',   'Este Mes',      '#0065ff'],
	['last_month',   'Mes Pasado',    '#6554c0'],
	['last_quarter', 'Trimestre',     '#ff991f'],
	['last_year',    'A&ntilde;o',    '#36b37e'],
	);
foreach my $p (@periods) {
	my $active = ($period eq $p->[0]) ? ';border:2px solid #333;font-weight:bold' : ';border:1px solid #ccc';
	print qq{<a href="reports.cgi?period=$p->[0]" style="text-decoration:none;background:$p->[2]$active;color:#fff;padding:5px 14px;border-radius:4px;font-size:12px;">$p->[1]</a>};
	}
print qq{<a href="reports.cgi?export_csv=1&period=$period" style="text-decoration:none;background:#de350b;color:#fff;padding:5px 14px;border-radius:4px;font-size:12px;margin-left:auto;">Exportar CSV</a>};
print qq{<a href="index.cgi" style="text-decoration:none;background:#6b778c;color:#fff;padding:5px 14px;border-radius:4px;font-size:12px;">Dashboard</a>};
print qq{</div>};

# ── Summary cards ──
my $total_billed = 0;
my $total_collected = 0;
my $total_pending = 0;
my $total_overdue = 0;
my $tax_collected = 0;
my $invoices = ovmbl_list_invoices('all');
foreach my $inv (@$invoices) {
	$total_billed += $inv->{'total'} || 0;
	if ($inv->{'status'} eq 'paid') {
		$total_collected += $inv->{'total'} || 0;
		$tax_collected += $inv->{'tax_amount'} || 0;
		}
	elsif ($inv->{'status'} eq 'pending') {
		$total_pending += $inv->{'total'} || 0;
		if ($inv->{'due_date'} && $inv->{'due_date'} < $now) {
			$total_overdue += $inv->{'total'} || 0;
			}
		}
	}

print qq{
<div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:15px;">
  <div style="flex:1;min-width:150px;background:linear-gradient(135deg,#0065ff,#2684ff);color:#fff;border-radius:8px;padding:14px 18px;">
    <div style="font-size:12px;opacity:0.85;">Total Facturado</div>
    <div style="font-size:22px;font-weight:bold;margin-top:4px;">} . ovmbl_format_currency($total_billed) . qq{</div>
  </div>
  <div style="flex:1;min-width:150px;background:linear-gradient(135deg,#36b37e,#57d9a3);color:#fff;border-radius:8px;padding:14px 18px;">
    <div style="font-size:12px;opacity:0.85;">Total Cobrado</div>
    <div style="font-size:22px;font-weight:bold;margin-top:4px;">} . ovmbl_format_currency($total_collected) . qq{</div>
  </div>
  <div style="flex:1;min-width:150px;background:linear-gradient(135deg,#ff991f,#ffc400);color:#fff;border-radius:8px;padding:14px 18px;">
    <div style="font-size:12px;opacity:0.85;">Total Pendiente</div>
    <div style="font-size:22px;font-weight:bold;margin-top:4px;">} . ovmbl_format_currency($total_pending) . qq{</div>
  </div>
  <div style="flex:1;min-width:150px;background:linear-gradient(135deg,#de350b,#ff7452);color:#fff;border-radius:8px;padding:14px 18px;">
    <div style="font-size:12px;opacity:0.85;">Total Vencido</div>
    <div style="font-size:22px;font-weight:bold;margin-top:4px;">} . ovmbl_format_currency($total_overdue) . qq{</div>
  </div>
  <div style="flex:1;min-width:150px;background:linear-gradient(135deg,#6554c0,#8777d9);color:#fff;border-radius:8px;padding:14px 18px;">
    <div style="font-size:12px;opacity:0.85;">Impuestos Cobrados</div>
    <div style="font-size:22px;font-weight:bold;margin-top:4px;">} . ovmbl_format_currency($tax_collected) . qq{</div>
  </div>
</div>
};

# ── Revenue bar chart ──
print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;margin-bottom:15px;">
  <div style="font-weight:bold;font-size:14px;margin-bottom:12px;color:#172b4d;">Ingresos por Mes</div>
  <div style="display:flex;align-items:flex-end;gap:6px;height:180px;padding-top:10px;">
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
      <div style="font-size:9px;color:#6b778c;margin-bottom:2px;">$label</div>
      <div style="width:100%;background:linear-gradient(180deg,#0065ff,#2684ff);height:$pct%;border-radius:3px 3px 0 0;min-height:4px;"></div>
      <div style="font-size:9px;color:#6b778c;margin-top:4px;">$short_month</div>
    </div>
	};
	}
print qq{</div></div>};

# ── Plan distribution (CSS donut) + Top clients ──
print qq{<div style="display:flex;flex-wrap:wrap;gap:15px;margin-bottom:15px;">};

# Plan distribution
print qq{
<div style="flex:1;min-width:300px;background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;">
  <div style="font-weight:bold;font-size:14px;margin-bottom:12px;color:#172b4d;">Distribuci&oacute;n por Plan</div>
};

if (@$plan_dist) {
	my $total_clients = 0;
	foreach my $p (@$plan_dist) {
		$total_clients += $p->{'count'};
		}
	my @colors = ('#0065ff', '#36b37e', '#ff991f', '#de350b', '#6554c0', '#8777d9', '#00c7e6', '#ff5630');
	my $i = 0;
	foreach my $p (@$plan_dist) {
		my $pct = $total_clients > 0 ? int(($p->{'count'} / $total_clients) * 100) : 0;
		my $color = $colors[$i % scalar(@colors)];
		print qq{
	  <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">
	    <div style="width:12px;height:12px;border-radius:2px;background:$color;"></div>
	    <div style="flex:1;font-size:13px;">} . &html_escape($p->{'plan'}) . qq{</div>
	    <div style="font-size:13px;font-weight:bold;">$p->{'count'}</div>
	    <div style="width:100px;height:8px;background:#ebecf0;border-radius:4px;overflow:hidden;">
	      <div style="width:$pct%;height:100%;background:$color;border-radius:4px;"></div>
	    </div>
	    <div style="font-size:11px;color:#6b778c;width:35px;text-align:right;">$pct%</div>
	  </div>
		};
		$i++;
		}
	}
else {
	print qq{<div style="color:#6b778c;font-size:13px;">Sin datos de distribuci&oacute;n</div>};
	}
print qq{</div>};

# Top clients
print qq{
<div style="flex:1;min-width:300px;background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;">
  <div style="font-weight:bold;font-size:14px;margin-bottom:12px;color:#172b4d;">Top Clientes por Ingresos</div>
};

if (@$top_clients) {
	print qq{
	  <table style="width:100%;border-collapse:collapse;font-size:13px;">
	    <thead>
	      <tr style="background:#f4f5f7;">
	        <th style="padding:6px 10px;text-align:left;color:#6b778c;">#</th>
	        <th style="padding:6px 10px;text-align:left;color:#6b778c;">Cliente</th>
	        <th style="padding:6px 10px;text-align:right;color:#6b778c;">Total</th>
	      </tr>
	    </thead>
	    <tbody>
	};
	my $rank = 1;
	foreach my $c (@$top_clients) {
		print qq{
	      <tr style="border-bottom:1px solid #ebecf0;">
	        <td style="padding:6px 10px;color:#6b778c;">$rank</td>
	        <td style="padding:6px 10px;">} . &html_escape($c->{'name'} || 'Unknown') . qq{</td>
	        <td style="padding:6px 10px;text-align:right;font-weight:bold;">} . ovmbl_format_currency($c->{'total'}) . qq{</td>
	      </tr>
		};
		$rank++;
		}
	print qq{</tbody></table>};
	}
else {
	print qq{<div style="color:#6b778c;font-size:13px;">Sin datos de clientes</div>};
	}
print qq{</div>};
print qq{</div>};

# ── Footer ──
print qq{
<div style="text-align:center;padding:10px;color:#6b778c;font-size:12px;margin-top:15px;">
  <a href="index.cgi" style="color:#0065ff;text-decoration:none;">Dashboard</a> &middot;
  <a href="plans.cgi" style="color:#0065ff;text-decoration:none;">Planes</a> &middot;
  <a href="invoices.cgi" style="color:#0065ff;text-decoration:none;">Facturas</a> &middot;
  <a href="clients.cgi" style="color:#0065ff;text-decoration:none;">Clientes</a> &middot;
  <a href="settings.cgi" style="color:#0065ff;text-decoration:none;">Configuraci&oacute;n</a>
</div>
};

&ui_print_footer('/', 'Index');
