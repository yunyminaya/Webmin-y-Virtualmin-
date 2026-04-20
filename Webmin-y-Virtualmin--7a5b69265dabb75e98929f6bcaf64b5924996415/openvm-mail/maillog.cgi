#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-mail-lib.pl';
&ReadParse();

ovmm_require_access();

my $lines  = $in{'lines'}  || 100;
my $filter = $in{'filter'} || '';

my $entries = ovmm_get_maillog($lines);

# Apply filter
my @filtered;
if ($filter ne '') {
	foreach my $e (@$entries) {
		if ($filter eq 'sent') {
			next unless ($e->{'type'} || '') eq 'sent';
			}
		elsif ($filter eq 'received') {
			next unless ($e->{'line'} || '') =~ /received|connect from/i;
			}
		elsif ($filter eq 'bounced') {
			next unless ($e->{'type'} || '') eq 'error' || ($e->{'line'} || '') =~ /bounce/i;
			}
		elsif ($filter eq 'deferred') {
			next unless ($e->{'type'} || '') eq 'warning' || ($e->{'line'} || '') =~ /defer/i;
			}
		elsif ($filter eq 'spam') {
			next unless ($e->{'type'} || '') eq 'spam';
			}
		elsif ($filter eq 'error') {
			next unless ($e->{'type'} || '') eq 'error';
			}
		push @filtered, $e;
		}
	}
else {
	@filtered = @$entries;
	}

&ui_print_header(undef, 'OpenVM Mail - Log de email', '', 'maillog');

print qq{<meta http-equiv="refresh" content="30">};

# ── Controls ──
print qq{
<div style="display:flex;flex-wrap:wrap;gap:10px;align-items:end;margin-bottom:16px;">
  <form method="get" action="maillog.cgi" style="display:flex;gap:8px;align-items:end;">
    <div>
      <label style="font-size:11px;color:#6b778c;display:block;">Líneas</label>
      <select name="lines" style="padding:4px;">
        <option value="50"} . ($lines == 50 ? ' selected' : '') . qq{>50</option>
        <option value="100"} . ($lines == 100 ? ' selected' : '') . qq{>100</option>
        <option value="250"} . ($lines == 250 ? ' selected' : '') . qq{>250</option>
        <option value="500"} . ($lines == 500 ? ' selected' : '') . qq{>500</option>
        <option value="1000"} . ($lines == 1000 ? ' selected' : '') . qq{>1000</option>
      </select>
    </div>
    <div>
      <label style="font-size:11px;color:#6b778c;display:block;">Filtro</label>
      <select name="filter" style="padding:4px;">
        <option value="">Todo</option>
        <option value="sent"} . ($filter eq 'sent' ? ' selected' : '') . qq{>Enviados</option>
        <option value="received"} . ($filter eq 'received' ? ' selected' : '') . qq{>Recibidos</option>
        <option value="bounced"} . ($filter eq 'bounced' ? ' selected' : '') . qq{>Bounced</option>
        <option value="deferred"} . ($filter eq 'deferred' ? ' selected' : '') . qq{>Deferred</option>
        <option value="spam"} . ($filter eq 'spam' ? ' selected' : '') . qq{>Spam</option>
        <option value="error"} . ($filter eq 'error' ? ' selected' : '') . qq{>Errores</option>
      </select>
    </div>
    <button type="submit" style="padding:4px 12px;cursor:pointer;">Aplicar</button>
  </form>
  <a href="maillog.cgi?action=download&lines=$lines&filter=$filter" style="text-decoration:none;background:#36b37e;color:#fff;padding:5px 12px;border-radius:3px;font-size:12px;">Descargar log</a>
</div>
};

# ── Handle download ──
if ($in{'action'} eq 'download') {
	print "Content-type: text/plain\n";
	print "Content-Disposition: attachment; filename=maillog_export.txt\n\n";
	foreach my $e (@filtered) {
		print $e->{'line'} . "\n";
		}
	exit(0);
	}

# ── Log table ──
my $total = scalar @filtered;
print qq{<p style="color:#6b778c;font-size:12px;">Mostrando $total entradas</p>};

if (@filtered) {
	print qq{
<table style="width:100%;border-collapse:collapse;background:#fff;border:1px solid #dfe1e6;border-radius:6px;overflow:hidden;font-size:12px;">
  <thead>
    <tr style="background:#f4f5f7;">
      <th style="padding:8px 10px;text-align:left;font-size:11px;color:#6b778c;border-bottom:2px solid #dfe1e6;width:140px;">Fecha</th>
      <th style="padding:8px 10px;text-align:left;font-size:11px;color:#6b778c;border-bottom:2px solid #dfe1e6;width:150px;">De</th>
      <th style="padding:8px 10px;text-align:left;font-size:11px;color:#6b778c;border-bottom:2px solid #dfe1e6;width:150px;">Para</th>
      <th style="padding:8px 10px;text-align:left;font-size:11px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Estado</th>
    </tr>
  </thead>
  <tbody>
	};

	my $row_idx = 0;
	foreach my $e (@filtered) {
		my $bg = ($row_idx % 2 == 0) ? '#fff' : '#fafbfc';

		# Color coding based on type
		my $row_style = '';
		if (($e->{'type'} || '') eq 'spam') {
			$row_style = 'background:#ffebe6;';
			}
		elsif (($e->{'type'} || '') eq 'error') {
			$row_style = 'background:#fff7e6;';
			}
		elsif (($e->{'type'} || '') eq 'warning') {
			$row_style = 'background:#fff7e6;';
			}
		elsif (($e->{'type'} || '') eq 'sent') {
			$row_style = 'background:#e3fcef;';
			}
		else {
			$row_style = "background:$bg;";
			}

		my $status_color = ($e->{'type'} || '') eq 'spam'    ? '#de350b'
		                 : ($e->{'type'} || '') eq 'error'  ? '#de350b'
		                 : ($e->{'type'} || '') eq 'warning' ? '#ff991f'
		                 : ($e->{'type'} || '') eq 'sent'   ? '#36b37e'
		                 : '#0065ff';
		my $status_badge = qq{<span style="background:$status_color;color:#fff;padding:1px 6px;border-radius:3px;font-size:10px;">} . &html_escape(uc($e->{'status'} || $e->{'type'} || 'INFO')) . qq{</span>};

		# Truncate line for display
		my $line_preview = $e->{'line'} || '';
		if (length($line_preview) > 120) {
			$line_preview = substr($line_preview, 0, 120) . '...';
			}

		print qq{
    <tr style="$row_style border-bottom:1px solid #ebecf0;">
      <td style="padding:5px 8px;font-size:11px;color:#44546f;">} . &html_escape($e->{'date'}) . qq{</td>
      <td style="padding:5px 8px;font-size:11px;">} . &html_escape($e->{'from'}) . qq{</td>
      <td style="padding:5px 8px;font-size:11px;">} . &html_escape($e->{'to'}) . qq{</td>
      <td style="padding:5px 8px;font-size:11px;">$status_badge <span style="color:#6b778c;">} . &html_escape($line_preview) . qq{</span></td>
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
  <div style="font-size:16px;margin-bottom:6px;">No hay entradas en el log</div>
  <div style="font-size:13px;">No se encontraron entradas con los filtros seleccionados.</div>
</div>
	};
	}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
