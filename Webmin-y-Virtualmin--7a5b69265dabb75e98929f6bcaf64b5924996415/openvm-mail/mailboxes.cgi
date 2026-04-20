#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-mail-lib.pl';
&ReadParse();

ovmm_require_access();

my $domain = $in{'dom'} || '';
my $action = $in{'action'} || '';

# Handle actions
if ($action eq 'create' && $in{'user'} && $in{'password'}) {
	my $result = ovmm_create_mailbox($in{'dom'}, $in{'user'}, $in{'password'}, $in{'quota'} || 0);
	$domain = $in{'dom'};
	}
elsif ($action eq 'delete' && $in{'del_user'} && $in{'dom'}) {
	ovmm_delete_mailbox($in{'dom'}, $in{'del_user'});
	$domain = $in{'dom'};
	}
elsif ($action eq 'change_pass' && $in{'chg_user'} && $in{'new_pass'} && $in{'dom'}) {
	ovmm_change_password($in{'dom'}, $in{'chg_user'}, $in{'new_pass'});
	$domain = $in{'dom'};
	}
elsif ($action eq 'set_quota' && $in{'quota_user'} && $in{'new_quota'} && $in{'dom'}) {
	ovmm_set_quota($in{'dom'}, $in{'quota_user'}, $in{'new_quota'});
	$domain = $in{'dom'};
	}

my $domains = ovmm_visible_domains();

&ui_print_header(undef, 'OpenVM Mail - Buzones', '', 'mailboxes');

# ── Domain selector ──
print qq{<form method="get" action="mailboxes.cgi" style="margin-bottom:16px;">};
print qq{<b>Dominio:</b> <select name="dom" style="padding:4px;">};
print qq{<option value="">-- Seleccionar --</option>};
foreach my $d (@$domains) {
	my $sel = ($domain eq $d->{'dom'}) ? ' selected' : '';
	print qq{<option value="} . &html_escape($d->{'dom'}) . qq{"$sel>} . &html_escape($d->{'dom'}) . qq{</option>};
	}
print qq{</select>};
print qq{ <button type="submit" style="padding:4px 12px;cursor:pointer;">Ver buzones</button>};
print qq{</form>};

if ($domain) {
	my $mailboxes = ovmm_list_mailboxes($domain);

	# ── Create mailbox form ──
	print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;margin-bottom:20px;">
  <div style="font-weight:bold;font-size:14px;margin-bottom:12px;">Crear nuevo buzón</div>
  <form method="post" action="mailboxes.cgi">
    <input type="hidden" name="action" value="create">
    <input type="hidden" name="dom" value="} . &html_escape($domain) . qq{">
    <table>
      <tr>
        <td style="padding:4px 8px;"><label>Usuario:</label></td>
        <td style="padding:4px 8px;"><input type="text" name="user" style="width:150px;padding:4px;"> @$domain</td>
      </tr>
      <tr>
        <td style="padding:4px 8px;"><label>Contraseña:</label></td>
        <td style="padding:4px 8px;"><input type="password" name="password" style="width:200px;padding:4px;"></td>
      </tr>
      <tr>
        <td style="padding:4px 8px;"><label>Cuota (MB):</label></td>
        <td style="padding:4px 8px;"><input type="number" name="quota" value="100" style="width:80px;padding:4px;"> (0 = sin límite)</td>
      </tr>
      <tr>
        <td style="padding:4px 8px;"><label>Nombre completo:</label></td>
        <td style="padding:4px 8px;"><input type="text" name="realname" style="width:250px;padding:4px;"></td>
      </tr>
    </table>
    <div style="margin-top:8px;">
      <button type="submit" style="background:#0065ff;color:#fff;border:none;padding:6px 16px;border-radius:3px;cursor:pointer;">Crear buzón</button>
    </div>
  </form>
</div>
	};

	# ── Mailbox table ──
	if (@$mailboxes) {
		print qq{
<table style="width:100%;border-collapse:collapse;background:#fff;border:1px solid #dfe1e6;border-radius:6px;overflow:hidden;">
  <thead>
    <tr style="background:#f4f5f7;">
      <th style="padding:10px 12px;text-align:left;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Usuario</th>
      <th style="padding:10px 12px;text-align:left;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Email</th>
      <th style="padding:10px 12px;text-align:left;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Nombre</th>
      <th style="padding:10px 12px;text-align:center;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Cuota</th>
      <th style="padding:10px 12px;text-align:center;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Uso</th>
      <th style="padding:10px 12px;text-align:center;font-size:12px;color:#6b778c;border-bottom:2px solid #dfe1e6;">Acciones</th>
    </tr>
  </thead>
  <tbody>
		};

		my $row_idx = 0;
		foreach my $mb (@$mailboxes) {
			my $bg = ($row_idx % 2 == 0) ? '#fff' : '#fafbfc';
			my $quota_mb = $mb->{'quota'} ? int($mb->{'quota'} / 1024 / 1024) : 0;
			my $used_mb  = int($mb->{'used'} / 1024 / 1024);
			my $pct = ($quota_mb > 0) ? int($used_mb * 100 / $quota_mb) : 0;
			$pct = 100 if $pct > 100;

			# Quota bar
			my $bar_color = $pct >= 85 ? '#de350b' : $pct >= 60 ? '#ff991f' : '#36b37e';
			my $quota_display = $quota_mb > 0
				? qq{<div style="background:#ebecf0;border-radius:3px;height:8px;width:80px;display:inline-block;vertical-align:middle;"><div style="background:$bar_color;height:8px;border-radius:3px;width:$pct%;"></div></div> <span style="font-size:11px;">$used_mb / $quota_mb MB ($pct%)</span>}
				: '<span style="color:#6b778c;font-size:12px;">Sin límite</span>';

			print qq{
    <tr style="background:$bg;border-bottom:1px solid #ebecf0;">
      <td style="padding:8px 12px;font-size:13px;">} . &html_escape($mb->{'user'}) . qq{</td>
      <td style="padding:8px 12px;font-size:13px;">} . &html_escape($mb->{'email'}) . qq{</td>
      <td style="padding:8px 12px;font-size:13px;">} . &html_escape($mb->{'realname'}) . qq{</td>
      <td style="padding:8px 12px;text-align:center;font-size:13px;">} . ($quota_mb || '∞') . qq{ MB</td>
      <td style="padding:8px 12px;text-align:center;">$quota_display</td>
      <td style="padding:8px 12px;text-align:center;">
        <form method="post" action="mailboxes.cgi" style="display:inline;">
          <input type="hidden" name="dom" value="} . &html_escape($domain) . qq{">
          <input type="hidden" name="chg_user" value="} . &html_escape($mb->{'user'}) . qq{">
          <input type="hidden" name="action" value="change_pass">
          <input type="password" name="new_pass" placeholder="Nueva pass" style="width:90px;padding:2px 4px;font-size:11px;">
          <button type="submit" style="font-size:11px;padding:2px 6px;cursor:pointer;">Cambiar</button>
        </form>
        <form method="post" action="mailboxes.cgi" style="display:inline;" onsubmit="return confirm('Eliminar buzón $mb->{'user'}?')">
          <input type="hidden" name="dom" value="} . &html_escape($domain) . qq{">
          <input type="hidden" name="del_user" value="} . &html_escape($mb->{'user'}) . qq{">
          <input type="hidden" name="action" value="delete">
          <button type="submit" style="font-size:11px;padding:2px 6px;color:#de350b;cursor:pointer;">Eliminar</button>
        </form>
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
		print qq{<p style="color:#6b778c;">No se encontraron buzones para este dominio.</p>};
		}
	}
else {
	print qq{<p style="color:#6b778c;">Selecciona un dominio para ver sus buzones.</p>};
	}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
