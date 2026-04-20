#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-notifications-lib.pl';
&ReadParse();

ovmnt_init();

# Handle actions
if ($in{'action'}) {
	if ($in{'action'} eq 'mark_read' && $in{'id'}) {
		ovmnt_mark_read($in{'id'});
		}
	elsif ($in{'action'} eq 'mark_all_read') {
		ovmnt_mark_all_read();
		}
	elsif ($in{'action'} eq 'delete' && $in{'id'}) {
		ovmnt_delete_notification($in{'id'});
		}
	elsif ($in{'action'} eq 'clear_all') {
		ovmnt_clear_all();
		}
	}

my $filter = $in{'filter'} || 'all';
my $stats  = ovmnt_get_stats();
my $notifications = ovmnt_list_notifications($filter, 50);

&ui_print_header(undef, 'OpenVM Notifications', '', 'index');

print qq{<meta http-equiv="refresh" content="30">};

# ── Stats Cards ──
print qq{
<div style="display:flex;flex-wrap:wrap;gap:15px;margin-bottom:20px;">
  <div style="flex:1;min-width:180px;background:linear-gradient(135deg,#0065ff,#2684ff);color:#fff;border-radius:8px;padding:18px 20px;">
    <div style="font-size:13px;opacity:0.85;">No leídas</div>
    <div style="font-size:28px;font-weight:bold;margin-top:4px;">$stats->{'unread'}</div>
  </div>
  <div style="flex:1;min-width:180px;background:linear-gradient(135deg,#36b37e,#57d9a3);color:#fff;border-radius:8px;padding:18px 20px;">
    <div style="font-size:13px;opacity:0.85;">Total hoy</div>
    <div style="font-size:28px;font-weight:bold;margin-top:4px;">$stats->{'today'}</div>
  </div>
  <div style="flex:1;min-width:180px;background:linear-gradient(135deg,#6554c0,#8777d9);color:#fff;border-radius:8px;padding:18px 20px;">
    <div style="font-size:13px;opacity:0.85;">Esta semana</div>
    <div style="font-size:28px;font-weight:bold;margin-top:4px;">$stats->{'week'}</div>
  </div>
  <div style="flex:1;min-width:180px;background:linear-gradient(135deg,#ff991f,#ffc400);color:#fff;border-radius:8px;padding:18px 20px;">
    <div style="font-size:13px;opacity:0.85;">Canales activos</div>
    <div style="font-size:28px;font-weight:bold;margin-top:4px;">$stats->{'channels'}</div>
  </div>
</div>
};

# ── Filter buttons ──
print qq{<div style="margin-bottom:15px;display:flex;flex-wrap:wrap;gap:6px;">};
my @filters = (
	['all',       'Todas',       '#44546f'],
	['unread',    'No leídas',   '#0065ff'],
	['info',      'Info',        '#0065ff'],
	['warning',   'Warning',     '#ff991f'],
	['error',     'Error',       '#de350b'],
	['critical',  'Critical',    '#de350b'],
	);
foreach my $f (@filters) {
	my $active = ($filter eq $f->[0]) ? ';border:2px solid #333;font-weight:bold' : ';border:1px solid #ccc';
	print qq{<a href="index.cgi?filter=$f->[0]" style="text-decoration:none;background:$f->[2]$active;color:#fff;padding:5px 14px;border-radius:4px;font-size:12px;">$f->[1]</a>};
	}
print qq{</div>};

# ── Action buttons ──
print qq{<div style="margin-bottom:15px;display:flex;flex-wrap:wrap;gap:8px;">};
print qq{<a href="index.cgi?action=mark_all_read&filter=$filter" style="text-decoration:none;background:#0065ff;color:#fff;padding:6px 14px;border-radius:4px;font-size:12px;">Marcar todas leídas</a>};
print qq{<a href="index.cgi?action=clear_all&filter=$filter" onclick="return confirm('Eliminar TODAS las notificaciones?')" style="text-decoration:none;background:#de350b;color:#fff;padding:6px 14px;border-radius:4px;font-size:12px;">Limpiar todas</a>};
print qq{<a href="channels.cgi" style="text-decoration:none;background:#6554c0;color:#fff;padding:6px 14px;border-radius:4px;font-size:12px;">Configurar canales</a>};
print qq{<a href="history.cgi" style="text-decoration:none;background:#44546f;color:#fff;padding:6px 14px;border-radius:4px;font-size:12px;">Historial</a>};
print qq{</div>};

# ── Notification list ──
if (@$notifications) {
	print qq{<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;overflow:hidden;">};
	foreach my $n (@$notifications) {
		my $bg      = $n->{'read'} ? '#f4f5f7' : '#fff';
		my $border  = $n->{'read'} ? '#dfe1e6' : '#0065ff';
		my $opacity = $n->{'read'} ? '0.7' : '1.0';
		my $type_badge    = ovmnt_format_type($n->{'type'});
		my $priority_badge = ovmnt_format_priority($n->{'priority'});
		my $time_ago = ovmnt_time_ago($n->{'timestamp'});

		print qq{
<div style="background:$bg;border-left:4px solid $border;padding:12px 16px;border-bottom:1px solid #ebecf0;opacity:$opacity;">
  <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;">
    <div style="display:flex;align-items:center;gap:8px;">
      $type_badge
      $priority_badge
      <span style="font-weight:bold;font-size:14px;">&html_escape($n->{'title'})</span>
    </div>
    <div style="display:flex;align-items:center;gap:8px;">
      <span style="color:#6b778c;font-size:11px;">$time_ago</span>
    </div>
  </div>
  <div style="color:#44546f;font-size:13px;margin-bottom:8px;padding-left:4px;">&html_escape($n->{'message'})</div>
  <div style="display:flex;gap:6px;">
    <a href="index.cgi?action=mark_read&id=$n->{'id'}&filter=$filter" style="text-decoration:none;font-size:11px;color:#0065ff;">Marcar leída</a>
    <a href="index.cgi?action=delete&id=$n->{'id'}&filter=$filter" onclick="return confirm('Eliminar esta notificación?')" style="text-decoration:none;font-size:11px;color:#de350b;">Eliminar</a>
  </div>
</div>
		};
	}
	print qq{</div>};
}
else {
	print qq{
<div style="background:#f4f5f7;border-radius:6px;padding:30px;text-align:center;color:#6b778c;">
  <div style="font-size:16px;margin-bottom:6px;">No hay notificaciones</div>
  <div style="font-size:13px;">Las notificaciones aparecerán aquí cuando se generen eventos del sistema.</div>
</div>
	};
}

&ui_print_footer('/', $text{'index_return'} || 'Return');
