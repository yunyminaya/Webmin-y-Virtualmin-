#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-mail-lib.pl';
&ReadParse();

ovmm_require_access();

my $domain = $in{'dom'} || '';
my $action = $in{'action'} || '';

# Handle actions
if ($action eq 'create' && $in{'user'} && $in{'subject'} && $in{'dom'}) {
	ovmm_set_autoresponder($in{'dom'}, $in{'user'}, $in{'subject'}, $in{'body'});
	$domain = $in{'dom'};
	}
elsif ($action eq 'remove' && $in{'del_user'} && $in{'dom'}) {
	ovmm_remove_autoresponder($in{'dom'}, $in{'del_user'});
	$domain = $in{'dom'};
	}
elsif ($action eq 'test' && $in{'test_user'} && $in{'dom'}) {
	# Send test email
	my $autoresponders = ovmm_get_autoresponders($in{'dom'});
	foreach my $ar (@$autoresponders) {
		if ($ar->{'user'} eq $in{'test_user'}) {
			if (defined(&foreign_require)) {
				&foreign_require("mailboxes", "mailboxes-lib.pl");
				if (defined(&send_text_mail)) {
					&send_text_mail("autoresponder\@$in{'dom'}", "test\@localhost", "[Test] $ar->{'subject'}", $ar->{'body'});
					}
				}
			last;
			}
		}
	$domain = $in{'dom'};
	}

my $domains = ovmm_visible_domains();

&ui_print_header(undef, 'OpenVM Mail - Autorespondedores', '', 'autoresponders');

# ── Domain selector ──
print qq{<form method="get" action="autoresponders.cgi" style="margin-bottom:16px;">};
print qq{<b>Dominio:</b> <select name="dom" style="padding:4px;">};
print qq{<option value="">-- Seleccionar --</option>};
foreach my $d (@$domains) {
	my $sel = ($domain eq $d->{'dom'}) ? ' selected' : '';
	print qq{<option value="} . &html_escape($d->{'dom'}) . qq{"$sel>} . &html_escape($d->{'dom'}) . qq{</option>};
	}
print qq{</select>};
print qq{ <button type="submit" style="padding:4px 12px;cursor:pointer;">Ver</button>};
print qq{</form>};

if ($domain) {
	my $autoresponders = ovmm_get_autoresponders($domain);
	my $mailboxes      = ovmm_list_mailboxes($domain);

	# ── Create autoresponder form ──
	print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;margin-bottom:20px;">
  <div style="font-weight:bold;font-size:14px;margin-bottom:12px;">Crear autoresponder</div>
  <form method="post" action="autoresponders.cgi">
    <input type="hidden" name="action" value="create">
    <input type="hidden" name="dom" value="} . &html_escape($domain) . qq{">
    <table>
      <tr>
        <td style="padding:4px 8px;white-space:nowrap;"><label>Buzón:</label></td>
        <td style="padding:4px 8px;">
          <select name="user" style="padding:4px;">
            <option value="">-- Seleccionar --</option>
			};
	foreach my $mb (@$mailboxes) {
		print qq{<option value="} . &html_escape($mb->{'user'}) . qq{">} . &html_escape($mb->{'email'}) . qq{</option>};
		}
	print qq{
          </select>
        </td>
      </tr>
      <tr>
        <td style="padding:4px 8px;"><label>Asunto:</label></td>
        <td style="padding:4px 8px;"><input type="text" name="subject" value="Fuera de la oficina" style="width:300px;padding:4px;"></td>
      </tr>
      <tr>
        <td style="padding:4px 8px;vertical-align:top;"><label>Cuerpo:</label></td>
        <td style="padding:4px 8px;"><textarea name="body" rows="5" cols="50" style="padding:4px;">Gracias por su mensaje. Actualmente no estoy disponible y responderé a su correo lo antes posible.</textarea></td>
      </tr>
    </table>
    <div style="margin-top:8px;">
      <button type="submit" style="background:#0065ff;color:#fff;border:none;padding:6px 16px;border-radius:3px;cursor:pointer;">Crear autoresponder</button>
    </div>
  </form>
</div>
	};

	# ── Autoresponders table ──
	if (@$autoresponders) {
		print qq{
<table style="width:100%;border-collapse:collapse;background:#fff;border:1px solid #dfe1e6;border-radius:6px;overflow:hidden;">
  <thead>
    <tr style="background:#f4f5f7;">
      <th style="padding:10px 12px;text-align:left;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Buzón</th>
      <th style="padding:10px 12px;text-align:left;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Asunto</th>
      <th style="padding:10px 12px;text-align:center;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Estado</th>
      <th style="padding:10px 12px;text-align:center;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Acciones</th>
    </tr>
  </thead>
  <tbody>
		};

		my $row_idx = 0;
		foreach my $ar (@$autoresponders) {
			my $bg = ($row_idx % 2 == 0) ? '#fff' : '#fafbfc';
			my $status_html = $ar->{'enabled'}
				? '<span style="background:#36b37e;color:#fff;padding:2px 8px;border-radius:3px;font-size:11px;">Activo</span>'
				: '<span style="background:#6b778c;color:#fff;padding:2px 8px;border-radius:3px;font-size:11px;">Inactivo</span>';

			print qq{
    <tr style="background:$bg;border-bottom:1px solid #ebecf0;">
      <td style="padding:8px 12px;font-size:13px;">} . &html_escape($ar->{'email'}) . qq{</td>
      <td style="padding:8px 12px;font-size:13px;">} . &html_escape($ar->{'subject'}) . qq{</td>
      <td style="padding:8px 12px;text-align:center;">$status_html</td>
      <td style="padding:8px 12px;text-align:center;">
        <div style="display:flex;gap:6px;justify-content:center;">
          <form method="post" action="autoresponders.cgi" style="display:inline;">
            <input type="hidden" name="action" value="test">
            <input type="hidden" name="dom" value="$domain">
            <input type="hidden" name="test_user" value="} . &html_escape($ar->{'user'}) . qq{">
            <button type="submit" style="font-size:11px;padding:3px 8px;cursor:pointer;background:#0065ff;color:#fff;border:none;border-radius:3px;">Probar</button>
          </form>
          <form method="post" action="autoresponders.cgi" style="display:inline;" onsubmit="return confirm('Eliminar autoresponder?')">
            <input type="hidden" name="action" value="remove">
            <input type="hidden" name="dom" value="$domain">
            <input type="hidden" name="del_user" value="} . &html_escape($ar->{'user'}) . qq{">
            <button type="submit" style="font-size:11px;padding:3px 8px;cursor:pointer;background:#de350b;color:#fff;border:none;border-radius:3px;">Eliminar</button>
          </form>
        </div>
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
		print qq{<p style="color:#6b778c;">No hay autorespondedores configurados para este dominio.</p>};
		}
	}
else {
	print qq{<p style="color:#6b778c;">Selecciona un dominio para gestionar los autorespondedores.</p>};
	}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
