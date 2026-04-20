#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-mail-lib.pl';
&ReadParse();

ovmm_require_access();

my $action = $in{'action'} || '';

# Handle actions
if ($action eq 'flush') {
	ovmm_flush_queue();
	}
elsif ($action eq 'delete' && $in{'id'}) {
	ovmm_delete_from_queue($in{'id'});
	}
elsif ($action eq 'delete_all') {
	my $queue = ovmm_get_mail_queue();
	foreach my $q (@$queue) {
		ovmm_delete_from_queue($q->{'id'});
		}
	}
elsif ($action eq 'retry_all') {
	ovmm_flush_queue();
	}

my $queue = ovmm_get_mail_queue();
my $filter_status = $in{'status'} || '';

# Filter
my @filtered;
if ($filter_status ne '') {
	foreach my $q (@$queue) {
		next unless defined $q->{'status'} && $q->{'status'} =~ /$filter_status/i;
		push @filtered, $q;
		}
	}
else {
	@filtered = @$queue;
	}

&ui_print_header(undef, 'OpenVM Mail - Cola de email', '', 'queue');

print qq{<meta http-equiv="refresh" content="15">};

# ── Queue summary ──
my $queue_count = scalar @$queue;
my $deferred    = grep { ($_->{'status'} || '') =~ /defer/i } @$queue;
my $bounced     = grep { ($_->{'status'} || '') =~ /bounce/i } @$queue;
my $held        = grep { ($_->{'status'} || '') =~ /hold/i } @$queue;

print qq{
<div style="display:flex;flex-wrap:wrap;gap:15px;margin-bottom:20px;">
  <div style="flex:1;min-width:150px;background:linear-gradient(135deg,#0065ff,#2684ff);color:#fff;border-radius:8px;padding:16px 18px;">
    <div style="font-size:12px;opacity:0.85;">Total en cola</div>
    <div style="font-size:24px;font-weight:bold;">$queue_count</div>
  </div>
  <div style="flex:1;min-width:150px;background:linear-gradient(135deg,#ff991f,#ffc400);color:#fff;border-radius:8px;padding:16px 18px;">
    <div style="font-size:12px;opacity:0.85;">Deferred</div>
    <div style="font-size:24px;font-weight:bold;">$deferred</div>
  </div>
  <div style="flex:1;min-width:150px;background:linear-gradient(135deg,#de350b,#ff7452);color:#fff;border-radius:8px;padding:16px 18px;">
    <div style="font-size:12px;opacity:0.85;">Bounced</div>
    <div style="font-size:24px;font-weight:bold;">$bounced</div>
  </div>
  <div style="flex:1;min-width:150px;background:linear-gradient(135deg,#6554c0,#8777d9);color:#fff;border-radius:8px;padding:16px 18px;">
    <div style="font-size:12px;opacity:0.85;">Held</div>
    <div style="font-size:24px;font-weight:bold;">$held</div>
  </div>
</div>
};

# ── Action buttons ──
print qq{<div style="display:flex;gap:8px;margin-bottom:16px;flex-wrap:wrap;">};
print qq{<a href="queue.cgi?action=flush" style="text-decoration:none;background:#36b37e;color:#fff;padding:6px 14px;border-radius:3px;font-size:12px;">Procesar cola</a>};
print qq{<a href="queue.cgi?action=retry_all" style="text-decoration:none;background:#0065ff;color:#fff;padding:6px 14px;border-radius:3px;font-size:12px;">Reintentar todo</a>};
print qq{<a href="queue.cgi?action=delete_all" onclick="return confirm('Eliminar TODOS los emails de la cola?')" style="text-decoration:none;background:#de350b;color:#fff;padding:6px 14px;border-radius:3px;font-size:12px;">Eliminar todo</a>};
print qq{</div>};

# ── Filters ──
print qq{<div style="margin-bottom:12px;display:flex;gap:6px;">};
print qq{<a href="queue.cgi" style="text-decoration:none;background:#f4f5f7;color:#44546f;padding:4px 10px;border-radius:3px;font-size:12px;">Todos</a>};
print qq{<a href="queue.cgi?status=deferred" style="text-decoration:none;background:#ff991f;color:#fff;padding:4px 10px;border-radius:3px;font-size:12px;">Deferred</a>};
print qq{<a href="queue.cgi?status=bounced" style="text-decoration:none;background:#de350b;color:#fff;padding:4px 10px;border-radius:3px;font-size:12px;">Bounced</a>};
print qq{<a href="queue.cgi?status=held" style="text-decoration:none;background:#6554c0;color:#fff;padding:4px 10px;border-radius:3px;font-size:12px;">Held</a>};
print qq{</div>};

# ── Queue table ──
if (@filtered) {
	print qq{
<table style="width:100%;border-collapse:collapse;background:#fff;border:1px solid #dfe1e6;border-radius:6px;overflow:hidden;">
  <thead>
    <tr style="background:#f4f5f7;">
      <th style="padding:8px 10px;text-align:left;font-size:11px;color:#6b778c;border-bottom:2px solid #dfe1e6;">ID</th>
      <th style="padding:8px 10px;text-align:left;font-size:11px;color:#6b778c;border-bottom:2px solid #dfe1e6;">De</th>
      <th style="padding:8px 10px;text-align:left;font-size:11px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Fecha</th>
      <th style="padding:8px 10px;text-align:center;font-size:11px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Tamaño</th>
      <th style="padding:8px 10px;text-align:center;font-size:11px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Estado</th>
      <th style="padding:8px 10px;text-align:center;font-size:11px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Acciones</th>
    </tr>
  </thead>
  <tbody>
	};

	my $row_idx = 0;
	foreach my $q (@filtered) {
		my $bg = ($row_idx % 2 == 0) ? '#fff' : '#fafbfc';
		my $status_color = ($q->{'status'} || '') =~ /defer/i ? '#ff991f'
		                 : ($q->{'status'} || '') =~ /bounce/i ? '#de350b'
		                 : ($q->{'status'} || '') =~ /hold/i ? '#6554c0'
		                 : '#0065ff';
		my $status_badge = qq{<span style="background:$status_color;color:#fff;padding:2px 6px;border-radius:3px;font-size:10px;">} . &html_escape(uc($q->{'status'} || 'QUEUED')) . qq{</span>};

		print qq{
    <tr style="background:$bg;border-bottom:1px solid #ebecf0;">
      <td style="padding:6px 10px;font-size:11px;font-family:monospace;">} . &html_escape($q->{'id'} || '-') . qq{</td>
      <td style="padding:6px 10px;font-size:12px;">} . &html_escape($q->{'sender'} || '-') . qq{</td>
      <td style="padding:6px 10px;font-size:12px;">} . &html_escape($q->{'date'} || '-') . qq{</td>
      <td style="padding:6px 10px;text-align:center;font-size:12px;">} . ($q->{'size'} || '-') . qq{</td>
      <td style="padding:6px 10px;text-align:center;">$status_badge</td>
      <td style="padding:6px 10px;text-align:center;">
        <a href="queue.cgi?action=delete&id=} . &html_escape($q->{'id'}) . qq{" onclick="return confirm('Eliminar este email?')" style="color:#de350b;font-size:11px;text-decoration:none;">Eliminar</a>
      </td>
    </tr>
		};
		$row_idx++;
		}

	print qq{
  </tbody>
</table>
	};
	}
else {
	print qq{
<div style="background:#f4f5f7;border-radius:6px;padding:30px;text-align:center;color:#6b778c;">
  <div style="font-size:16px;margin-bottom:6px;">Cola vacía</div>
  <div style="font-size:13px;">No hay emails en la cola de envío.</div>
</div>
	};
	}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
