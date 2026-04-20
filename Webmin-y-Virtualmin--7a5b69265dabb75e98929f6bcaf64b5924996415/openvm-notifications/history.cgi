#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-notifications-lib.pl';
&ReadParse();

ovmnt_init();

# Handle clear history
if ($in{'action'} eq 'clear_history') {
	ovmnt_clear_all();
	}

# Handle cleanup old
if ($in{'action'} eq 'cleanup' && $in{'days'}) {
	my $removed = ovmnt_cleanup_old($in{'days'});
	}

my $page     = $in{'page'} || 1;
my $per_page = 25;
my $filter_type     = $in{'type'}     || '';
my $filter_priority = $in{'priority'} || '';
my $filter_status   = $in{'status'}   || '';
my $filter_date_from = $in{'date_from'} || '';
my $filter_date_to   = $in{'date_to'}   || '';

# Load all notifications for filtering
my $all = ovmnt_load_notifications();

# Apply filters
my @filtered;
foreach my $n (reverse @$all) {
	if ($filter_type ne '' && $filter_type ne 'all') {
		next unless ($n->{'type'} || '') eq $filter_type;
		}
	if ($filter_priority ne '' && $filter_priority ne 'all') {
		next unless ($n->{'priority'} || '') eq $filter_priority;
		}
	if ($filter_status eq 'read') {
		next unless $n->{'read'};
		}
	elsif ($filter_status eq 'unread') {
		next if $n->{'read'};
		}
	if ($filter_date_from ne '') {
		my $from_ts = ovmnt_parse_date($filter_date_from);
		next if $from_ts && $n->{'timestamp'} < $from_ts;
		}
	if ($filter_date_to ne '') {
		my $to_ts = ovmnt_parse_date($filter_date_to);
		next if $to_ts && $n->{'timestamp'} > ($to_ts + 86400);
		}
	push @filtered, $n;
	}

my $total      = scalar @filtered;
my $total_pages = int(($total + $per_page - 1) / $per_page) || 1;
my $start_idx = ($page - 1) * $per_page;
my $end_idx   = $start_idx + $per_page - 1;
$end_idx = $total - 1 if $end_idx >= $total;

&ui_print_header(undef, 'OpenVM Notifications - Historial', '', 'history');

# ── Filter form ──
print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;margin-bottom:16px;">
  <form method="get" action="history.cgi" style="display:flex;flex-wrap:wrap;gap:10px;align-items:end;">
    <div>
      <label style="font-size:12px;color:#6b778c;display:block;margin-bottom:3px;">Tipo</label>
      <select name="type" style="padding:5px 8px;border:1px solid #dfe1e6;border-radius:3px;">
        <option value="all">Todos</option>
        <option value="info"} . ($filter_type eq 'info' ? ' selected' : '') . qq{>Info</option>
        <option value="warning"} . ($filter_type eq 'warning' ? ' selected' : '') . qq{>Warning</option>
        <option value="error"} . ($filter_type eq 'error' ? ' selected' : '') . qq{>Error</option>
        <option value="success"} . ($filter_type eq 'success' ? ' selected' : '') . qq{>Success</option>
      </select>
    </div>
    <div>
      <label style="font-size:12px;color:#6b778c;display:block;margin-bottom:3px;">Prioridad</label>
      <select name="priority" style="padding:5px 8px;border:1px solid #dfe1e6;border-radius:3px;">
        <option value="all">Todas</option>
        <option value="low"} . ($filter_priority eq 'low' ? ' selected' : '') . qq{>Low</option>
        <option value="medium"} . ($filter_priority eq 'medium' ? ' selected' : '') . qq{>Medium</option>
        <option value="high"} . ($filter_priority eq 'high' ? ' selected' : '') . qq{>High</option>
        <option value="critical"} . ($filter_priority eq 'critical' ? ' selected' : '') . qq{>Critical</option>
      </select>
    </div>
    <div>
      <label style="font-size:12px;color:#6b778c;display:block;margin-bottom:3px;">Estado</label>
      <select name="status" style="padding:5px 8px;border:1px solid #dfe1e6;border-radius:3px;">
        <option value="">Todos</option>
        <option value="read"} . ($filter_status eq 'read' ? ' selected' : '') . qq{>Leídas</option>
        <option value="unread"} . ($filter_status eq 'unread' ? ' selected' : '') . qq{>No leídas</option>
      </select>
    </div>
    <div>
      <label style="font-size:12px;color:#6b778c;display:block;margin-bottom:3px;">Desde</label>
      <input type="date" name="date_from" value="} . &html_escape($filter_date_from) . qq{" style="padding:5px 8px;border:1px solid #dfe1e6;border-radius:3px;">
    </div>
    <div>
      <label style="font-size:12px;color:#6b778c;display:block;margin-bottom:3px;">Hasta</label>
      <input type="date" name="date_to" value="} . &html_escape($filter_date_to) . qq{" style="padding:5px 8px;border:1px solid #dfe1e6;border-radius:3px;">
    </div>
    <div>
      <button type="submit" style="background:#0065ff;color:#fff;border:none;padding:6px 16px;border-radius:3px;cursor:pointer;">Filtrar</button>
    </div>
  </form>
</div>
};

# ── Summary and actions ──
print qq{
<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
  <span style="color:#6b778c;font-size:13px;">Mostrando } . ($total > 0 ? ($start_idx + 1) . '-' . ($end_idx + 1) . " de $total" : '0') . qq{ notificaciones</span>
  <div style="display:flex;gap:8px;">
    <a href="history.cgi?action=export_csv&type=$filter_type&priority=$filter_priority&status=$filter_status" style="text-decoration:none;background:#36b37e;color:#fff;padding:5px 12px;border-radius:3px;font-size:12px;">Exportar CSV</a>
    <a href="history.cgi?action=clear_history" onclick="return confirm('Eliminar TODO el historial de notificaciones?')" style="text-decoration:none;background:#de350b;color:#fff;padding:5px 12px;border-radius:3px;font-size:12px;">Limpiar historial</a>
  </div>
</div>
};

# ── Handle CSV export ──
if ($in{'action'} eq 'export_csv') {
	print "Content-type: text/csv\n";
	print "Content-Disposition: attachment; filename=notifications_export.csv\n\n";
	print "Fecha,Tipo,Prioridad,Titulo,Mensaje,Estado\n";
	foreach my $n (@filtered) {
		my $status = $n->{'read'} ? 'Leida' : 'No leida';
		my $title = $n->{'title'} || '';
		my $msg = $n->{'message'} || '';
		$title =~ s/,/;/g;
		$msg =~ s/,/;/g;
		$msg =~ s/\n/ /g;
		print "$n->{'date'},$n->{'type'},$n->{'priority'},$title,$msg,$status\n";
		}
	exit(0);
	}

# ── Table ──
if ($total > 0) {
	print qq{
<table style="width:100%;border-collapse:collapse;background:#fff;border:1px solid #dfe1e6;border-radius:6px;overflow:hidden;">
  <thead>
    <tr style="background:#f4f5f7;">
      <th style="padding:10px 12px;text-align:left;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Fecha</th>
      <th style="padding:10px 12px;text-align:left;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Tipo</th>
      <th style="padding:10px 12px;text-align:left;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Prioridad</th>
      <th style="padding:10px 12px;text-align:left;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Título</th>
      <th style="padding:10px 12px;text-align:left;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Estado</th>
    </tr>
  </thead>
  <tbody>
	};

	for my $i ($start_idx .. $end_idx) {
		last if $i >= scalar @filtered;
		my $n = $filtered[$i];
		my $type_badge     = ovmnt_format_type($n->{'type'});
		my $priority_badge = ovmnt_format_priority($n->{'priority'});
		my $status_html = $n->{'read'}
			? '<span style="color:#36b37e;font-size:12px;">Leída</span>'
			: '<span style="color:#0065ff;font-size:12px;font-weight:bold;">No leída</span>';
		my $row_bg = ($i % 2 == 0) ? '#fff' : '#fafbfc';

		print qq{
    <tr style="background:$row_bg;border-bottom:1px solid #ebecf0;">
      <td style="padding:8px 12px;font-size:12px;color:#44546f;">} . &html_escape($n->{'date'}) . qq{</td>
      <td style="padding:8px 12px;">$type_badge</td>
      <td style="padding:8px 12px;">$priority_badge</td>
      <td style="padding:8px 12px;font-size:13px;">} . &html_escape($n->{'title'}) . qq{</td>
      <td style="padding:8px 12px;">$status_html</td>
    </tr>
		};
		}

	print qq{
  </tbody>
</table>
	};

	# ── Pagination ──
	if ($total_pages > 1) {
		print qq{<div style="display:flex;justify-content:center;gap:4px;margin-top:16px;">};
		for my $p (1 .. $total_pages) {
			my $style = ($p == $page)
				? 'background:#0065ff;color:#fff;font-weight:bold;'
				: 'background:#f4f5f7;color:#44546f;';
			print qq{<a href="history.cgi?page=$p&type=$filter_type&priority=$filter_priority&status=$filter_status&date_from=$filter_date_from&date_to=$filter_date_to" style="text-decoration:none;{$style}padding:5px 10px;border-radius:3px;font-size:12px;">$p</a>};
			}
		print qq{</div>};
		}
	}
else {
	print qq{
<div style="background:#f4f5f7;border-radius:6px;padding:30px;text-align:center;color:#6b778c;">
  <div style="font-size:16px;margin-bottom:6px;">No hay notificaciones en el historial</div>
  <div style="font-size:13px;">Ajusta los filtros o espera a que se generen nuevas notificaciones.</div>
</div>
	};
	}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');

# ── Helper: parse date string to timestamp ──
sub ovmnt_parse_date
{
my ($date_str) = @_;
return 0 unless defined $date_str && $date_str =~ /^(\d{4})-(\d{2})-(\d{2})/;
my ($y, $m, $d) = ($1, $2, $3);
require Time::Local;
return eval { Time::Local::timegm(0,0,0,$d,$m-1,$y-1900) } || 0;
}
