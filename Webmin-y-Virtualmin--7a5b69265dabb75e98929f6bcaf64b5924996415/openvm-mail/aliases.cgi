#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-mail-lib.pl';
&ReadParse();

ovmm_require_access();

my $domain = $in{'dom'} || '';
my $action = $in{'action'} || '';
my $tab    = $in{'tab'}    || 'aliases';

# Handle actions
if ($action eq 'create_alias' && $in{'from'} && $in{'to'} && $in{'dom'}) {
	ovmm_create_alias($in{'dom'}, $in{'from'}, $in{'to'});
	$domain = $in{'dom'};
	}
elsif ($action eq 'delete_alias' && $in{'del_from'} && $in{'dom'}) {
	ovmm_delete_alias($in{'dom'}, $in{'del_from'});
	$domain = $in{'dom'};
	}
elsif ($action eq 'create_forwarder' && $in{'from'} && $in{'to'} && $in{'dom'}) {
	ovmm_create_forwarder($in{'dom'}, $in{'from'}, $in{'to'});
	$domain = $in{'dom'};
	}
elsif ($action eq 'delete_forwarder' && $in{'del_from'} && $in{'dom'}) {
	ovmm_delete_forwarder($in{'dom'}, $in{'del_from'});
	$domain = $in{'dom'};
	}

my $domains = ovmm_visible_domains();

&ui_print_header(undef, 'OpenVM Mail - Aliases y Forwarders', '', 'aliases');

# ── Domain selector ──
print qq{<form method="get" action="aliases.cgi" style="margin-bottom:16px;">};
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
	# ── Tabs ──
	print qq{<div style="display:flex;gap:4px;margin-bottom:16px;">};
	my @tabs = (
		['aliases',    'Aliases',     '#0065ff'],
		['forwarders', 'Forwarders',  '#36b37e'],
		['catchall',   'Catch-all',   '#6554c0'],
		);
	foreach my $t (@tabs) {
		my $active = ($tab eq $t->[0]) ? ';font-weight:bold;border-bottom:3px solid '.$t->[2] : '';
		print qq{<a href="aliases.cgi?dom=$domain&tab=$t->[0]" style="text-decoration:none;padding:8px 16px;color:#44546f;font-size:13px;$active">$t->[1]</a>};
		}
	print qq{</div>};

	# ── Aliases tab ──
	if ($tab eq 'aliases') {
		my $aliases = ovmm_list_aliases($domain);

		# Create alias form
		print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;margin-bottom:16px;">
  <div style="font-weight:bold;font-size:14px;margin-bottom:10px;">Crear alias</div>
  <form method="post" action="aliases.cgi">
    <input type="hidden" name="action" value="create_alias">
    <input type="hidden" name="dom" value="} . &html_escape($domain) . qq{">
    <input type="hidden" name="tab" value="aliases">
    <table>
      <tr>
        <td style="padding:4px 8px;">De:</td>
        <td style="padding:4px 8px;"><input type="text" name="from" style="width:150px;padding:4px;"> @$domain</td>
      </tr>
      <tr>
        <td style="padding:4px 8px;">A:</td>
        <td style="padding:4px 8px;"><input type="text" name="to" style="width:250px;padding:4px;" placeholder="destino@ejemplo.com"></td>
      </tr>
    </table>
    <div style="margin-top:8px;"><button type="submit" style="background:#0065ff;color:#fff;border:none;padding:6px 16px;border-radius:3px;cursor:pointer;">Crear alias</button></div>
  </form>
</div>
		};

		if (@$aliases) {
			print &ui_columns_start(['Origen', 'Destino', 'Tipo', 'Acciones']);
			foreach my $a (@$aliases) {
				my $del_form = qq{<form method="post" action="aliases.cgi" style="display:inline;" onsubmit="return confirm('Eliminar alias?')">
					<input type="hidden" name="action" value="delete_alias">
					<input type="hidden" name="dom" value="$domain">
					<input type="hidden" name="del_from" value="} . &html_escape($a->{'from'}) . qq{">
					<button type="submit" style="color:#de350b;cursor:pointer;border:none;background:none;font-size:12px;">Eliminar</button>
				</form>};
				print &ui_columns_row([
					&html_escape($a->{'from'}),
					&html_escape($a->{'to'}),
					&html_escape($a->{'type'} || 'alias'),
					$del_form,
					]);
				}
			print &ui_columns_end();
			}
		else {
			print qq{<p style="color:#6b778c;">No hay aliases configurados.</p>};
			}
		}

	# ── Forwarders tab ──
	elsif ($tab eq 'forwarders') {
		my $forwarders = ovmm_list_forwarders($domain);

		# Create forwarder form
		print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;margin-bottom:16px;">
  <div style="font-weight:bold;font-size:14px;margin-bottom:10px;">Crear forwarder</div>
  <form method="post" action="aliases.cgi">
    <input type="hidden" name="action" value="create_forwarder">
    <input type="hidden" name="dom" value="} . &html_escape($domain) . qq{">
    <input type="hidden" name="tab" value="forwarders">
    <table>
      <tr>
        <td style="padding:4px 8px;">De:</td>
        <td style="padding:4px 8px;"><input type="text" name="from" style="width:200px;padding:4px;" placeholder="usuario"></td>
      </tr>
      <tr>
        <td style="padding:4px 8px;">A:</td>
        <td style="padding:4px 8px;"><input type="text" name="to" style="width:250px;padding:4px;" placeholder="destino@ejemplo.com"></td>
      </tr>
    </table>
    <div style="margin-top:8px;"><button type="submit" style="background:#36b37e;color:#fff;border:none;padding:6px 16px;border-radius:3px;cursor:pointer;">Crear forwarder</button></div>
  </form>
</div>
		};

		if (@$forwarders) {
			print &ui_columns_start(['Origen', 'Destino', 'Tipo', 'Acciones']);
			foreach my $f (@$forwarders) {
				my $del_form = qq{<form method="post" action="aliases.cgi" style="display:inline;" onsubmit="return confirm('Eliminar forwarder?')">
					<input type="hidden" name="action" value="delete_forwarder">
					<input type="hidden" name="dom" value="$domain">
					<input type="hidden" name="del_from" value="} . &html_escape($f->{'from'}) . qq{">
					<button type="submit" style="color:#de350b;cursor:pointer;border:none;background:none;font-size:12px;">Eliminar</button>
				</form>};
				print &ui_columns_row([
					&html_escape($f->{'from'}),
					&html_escape($f->{'to'}),
					&html_escape($f->{'type'} || 'forwarder'),
					$del_form,
					]);
				}
			print &ui_columns_end();
			}
		else {
			print qq{<p style="color:#6b778c;">No hay forwarders configurados.</p>};
			}
		}

	# ── Catch-all tab ──
	elsif ($tab eq 'catchall') {
		print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;">
  <div style="font-weight:bold;font-size:14px;margin-bottom:10px;">Configuración Catch-all</div>
  <p style="color:#6b778c;font-size:13px;">El catch-all redirige todo el correo enviado a direcciones inexistentes de <b>} . &html_escape($domain) . qq{</b> a un buzón específico.</p>
  <form method="post" action="aliases.cgi">
    <input type="hidden" name="dom" value="} . &html_escape($domain) . qq{">
    <input type="hidden" name="tab" value="catchall">
    <table>
      <tr>
        <td style="padding:4px 8px;"><label>Destino catch-all:</label></td>
        <td style="padding:4px 8px;"><input type="text" name="catchall_to" style="width:250px;padding:4px;" placeholder="admin@$domain"></td>
      </tr>
    </table>
    <div style="margin-top:8px;"><button type="submit" style="background:#6554c0;color:#fff;border:none;padding:6px 16px;border-radius:3px;cursor:pointer;">Guardar catch-all</button></div>
  </form>
</div>
		};
		}
	}
else {
	print qq{<p style="color:#6b778c;">Selecciona un dominio para ver sus aliases y forwarders.</p>};
	}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
