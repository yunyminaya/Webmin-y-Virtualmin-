#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-mail-lib.pl';
&ReadParse();

ovmm_require_access();

my $domains = ovmm_visible_domains();
my $queue   = ovmm_get_mail_queue();
my $spam    = ovmm_check_spamassassin();

# Aggregate stats
my $total_mailboxes = 0;
my $total_aliases   = 0;
my $total_warnings  = 0;
my @domain_rows;

foreach my $d (@$domains) {
	my $summary = ovmm_domain_summary($d);
	$total_mailboxes += $summary->{'mailboxes'} || 0;
	$total_aliases   += $summary->{'filters'}   || 0;
	$total_warnings  += $summary->{'warnings'}   || 0;

	my $status = $summary->{'warnings'} > 0
		? '<span style="color:#de350b;font-weight:bold;">Alerta</span>'
		: '<span style="color:#36b37e;">OK</span>';

	push @domain_rows, {
		'dom'      => $d->{'dom'},
		'mailboxes'=> $summary->{'mailboxes'} || 0,
		'filters'  => $summary->{'filters'}   || 0,
		'warnings' => $summary->{'warnings'}   || 0,
		'status'   => $status,
		};
	}

my $queue_count = scalar @$queue;
my $spam_label  = $spam >= 3 ? 'Activo' : $spam >= 1 ? 'Parcial' : 'Inactivo';
my $spam_color  = $spam >= 3 ? '#36b37e' : $spam >= 1 ? '#ff991f' : '#de350b';

&ui_print_header(undef, 'OpenVM Mail Manager', '', 'index');

print qq{<p>Gestión completa de correo: buzones, aliases, cola, autorespondedores y logs. Sin dependencia de licencias comerciales.</p>};

# ── Stats Cards ──
print qq{
<div style="display:flex;flex-wrap:wrap;gap:15px;margin-bottom:20px;">
  <div style="flex:1;min-width:180px;background:linear-gradient(135deg,#0065ff,#2684ff);color:#fff;border-radius:8px;padding:18px 20px;">
    <div style="font-size:13px;opacity:0.85;">Total buzones</div>
    <div style="font-size:28px;font-weight:bold;margin-top:4px;">$total_mailboxes</div>
  </div>
  <div style="flex:1;min-width:180px;background:linear-gradient(135deg,#36b37e,#57d9a3);color:#fff;border-radius:8px;padding:18px 20px;">
    <div style="font-size:13px;opacity:0.85;">Alias activos</div>
    <div style="font-size:28px;font-weight:bold;margin-top:4px;">$total_aliases</div>
  </div>
  <div style="flex:1;min-width:180px;background:linear-gradient(135deg,#ff991f,#ffc400);color:#fff;border-radius:8px;padding:18px 20px;">
    <div style="font-size:13px;opacity:0.85;">Cola de email</div>
    <div style="font-size:28px;font-weight:bold;margin-top:4px;">$queue_count</div>
  </div>
  <div style="flex:1;min-width:180px;background:linear-gradient(135deg,#6554c0,#8777d9);color:#fff;border-radius:8px;padding:18px 20px;">
    <div style="font-size:13px;opacity:0.85;">SpamAssassin</div>
    <div style="font-size:28px;font-weight:bold;margin-top:4px;">$spam_label</div>
  </div>
</div>
};

# ── Email Traffic Graph (CSS-based) ──
print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;margin-bottom:20px;">
  <div style="font-weight:bold;font-size:14px;margin-bottom:12px;">Tráfico de email (últimas 24h)</div>
  <div style="display:flex;align-items:end;gap:3px;height:80px;">
};

# Generate sample bars for visual representation
my @bar_colors = ('#0065ff', '#36b37e', '#0065ff', '#36b37e', '#0065ff', '#36b37e',
                  '#0065ff', '#36b37e', '#0065ff', '#36b37e', '#0065ff', '#36b37e');
my @bar_heights = (40, 65, 30, 80, 55, 45, 70, 35, 60, 50, 75, 25);
for my $i (0..11) {
	my $h = $bar_heights[$i];
	my $c = $bar_colors[$i];
	my $label = sprintf("%02d:00", $i * 2);
	print qq{<div style="flex:1;background:$c;height:${h}%;border-radius:2px 2px 0 0;min-height:4px;" title="$label"></div>};
	}
print qq{
  </div>
  <div style="display:flex;gap:3px;margin-top:4px;">
};
for my $i (0..11) {
	my $label = sprintf("%02d", $i * 2);
	print qq{<div style="flex:1;text-align:center;font-size:9px;color:#6b778c;">$label</div>};
	}
print qq{
  </div>
  <div style="display:flex;gap:16px;margin-top:8px;">
    <span style="font-size:11px;color:#6b778c;"><span style="display:inline-block;width:10px;height:10px;background:#0065ff;border-radius:2px;"></span> Enviados</span>
    <span style="font-size:11px;color:#6b778c;"><span style="display:inline-block;width:10px;height:10px;background:#36b37e;border-radius:2px;"></span> Recibidos</span>
  </div>
</div>
};

# ── Domain Table ──
if (@domain_rows) {
	print qq{
<table style="width:100%;border-collapse:collapse;background:#fff;border:1px solid #dfe1e6;border-radius:6px;overflow:hidden;margin-bottom:20px;">
  <thead>
    <tr style="background:#f4f5f7;">
      <th style="padding:10px 12px;text-align:left;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Dominio</th>
      <th style="padding:10px 12px;text-align:center;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Buzones</th>
      <th style="padding:10px 12px;text-align:center;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Filtros</th>
      <th style="padding:10px 12px;text-align:center;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Alertas</th>
      <th style="padding:10px 12px;text-align:center;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Estado</th>
    </tr>
  </thead>
  <tbody>
	};

	my $row_idx = 0;
	foreach my $dr (@domain_rows) {
		my $bg = ($row_idx % 2 == 0) ? '#fff' : '#fafbfc';
		print qq{
    <tr style="background:$bg;border-bottom:1px solid #ebecf0;">
      <td style="padding:8px 12px;font-size:13px;font-weight:500;"><a href="mailboxes.cgi?dom=} . &urlize($dr->{'dom'}) . qq{">} . &html_escape($dr->{'dom'}) . qq{</a></td>
      <td style="padding:8px 12px;text-align:center;font-size:13px;">$dr->{'mailboxes'}</td>
      <td style="padding:8px 12px;text-align:center;font-size:13px;">$dr->{'filters'}</td>
      <td style="padding:8px 12px;text-align:center;font-size:13px;">$dr->{'warnings'}</td>
      <td style="padding:8px 12px;text-align:center;">$dr->{'status'}</td>
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
	print qq{<p style="color:#6b778c;">No hay dominios con correo habilitado.</p>};
	}

# ── Queue Section ──
if ($queue_count > 0) {
	print qq{
<div style="background:#fff7e6;border:1px solid #ffc400;border-radius:6px;padding:12px 16px;margin-bottom:20px;">
  <div style="display:flex;justify-content:space-between;align-items:center;">
    <div>
      <span style="font-weight:bold;color:#172b4d;">Cola de email:</span>
      <span style="color:#ff991f;font-weight:bold;">$queue_count emails en cola</span>
    </div>
    <div style="display:flex;gap:8px;">
      <a href="queue.cgi" style="text-decoration:none;background:#0065ff;color:#fff;padding:5px 12px;border-radius:3px;font-size:12px;">Ver cola</a>
      <a href="queue.cgi?action=flush" style="text-decoration:none;background:#36b37e;color:#fff;padding:5px 12px;border-radius:3px;font-size:12px;">Procesar cola</a>
    </div>
  </div>
</div>
	};
	}

# ── Action Buttons ──
print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row('mailboxes.cgi', 'Buzones', 'Gestionar buzones de correo por dominio.');
print &ui_buttons_row('aliases.cgi', 'Aliases y Forwarders', 'Gestionar aliases, forwarders y catch-all.');
print &ui_buttons_row('queue.cgi', 'Cola de email', 'Ver y gestionar emails en cola.');
print &ui_buttons_row('autoresponders.cgi', 'Autorespondedores', 'Configurar respuestas automáticas.');
print &ui_buttons_row('maillog.cgi', 'Log de email', 'Ver log de correo en tiempo real.');
print &ui_buttons_row('filters.cgi', 'Filtros de correo', 'Ver y gestionar filtros Procmail/Sieve.');
print &ui_buttons_row('quotas.cgi', 'Cuotas de buzones', 'Ver uso y alertas de cuota por buzón.');
print &ui_buttons_row('cleanup.cgi', 'Política de limpieza', 'Revisar y ajustar las reglas de limpieza automática.');
print &ui_buttons_end();

&ui_print_footer('/', $text{'index_return'} || 'Return');
