#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-billing-lib.pl';
&ReadParse();

ovmbl_init();

my $action = $in{'action'} || '';
my $id     = $in{'id'} || '';
my $filter = $in{'filter'} || 'all';

# Handle POST actions
if ($in{'save_invoice'}) {
	my %inv;
	$inv{'client_id'}   = $in{'client_id'} || '';
	$inv{'client_name'} = $in{'client_name'} || '';
	$inv{'notes'}       = $in{'notes'} || '';
	$inv{'due_date'}    = $in{'due_date'} ? ovmbl_parse_date($in{'due_date'}) : time() + (($ovmbl_config{'payment_terms'} || 30) * 86400);

	# Parse items
	my @items;
	my $subtotal = 0;
	my $idx = 1;
	while (defined $in{"item_desc_$idx"}) {
		my $desc  = $in{"item_desc_$idx"} || '';
		my $qty   = $in{"item_qty_$idx"} || 1;
		my $price = $in{"item_price_$idx"} || 0;
		last if $desc eq '' && $idx > 1;
		if ($desc ne '') {
			push @items, { 'description' => $desc, 'qty' => $qty + 0, 'price' => $price + 0 };
			$subtotal += ($qty + 0) * ($price + 0);
			}
		$idx++;
		}
	$inv{'items'} = \@items;
	$inv{'subtotal'} = sprintf("%.2f", $subtotal);
	$inv{'tax_amount'} = ovmbl_calculate_tax($subtotal);
	$inv{'total'} = sprintf("%.2f", $subtotal + $inv{'tax_amount'});

	if ($in{'invoice_id'}) {
		ovmbl_update_invoice($in{'invoice_id'}, %inv);
		}
	else {
		ovmbl_create_invoice(%inv);
		}
	$action = '';
	}
elsif ($action eq 'mark_paid' && $id) {
	ovmbl_mark_paid($id);
	$action = '';
	}
elsif ($action eq 'cancel' && $id) {
	ovmbl_mark_cancelled($id);
	$action = '';
	}
elsif ($action eq 'delete' && $id) {
	ovmbl_delete_invoice($id);
	$action = '';
	}
elsif ($in{'export_csv'}) {
	my $csv = ovmbl_export_csv('invoices');
	print "Content-type: text/csv\n";
	print "Content-Disposition: attachment; filename=invoices.csv\n\n";
	print $csv;
	exit(0);
	}

my $invoices = ovmbl_list_invoices($filter);
my $clients  = ovmbl_list_clients();

&ui_print_header(undef, 'OpenVM Billing &mdash; Invoices', '', 'invoices');

# ── Action buttons ──
print qq{<div style="margin-bottom:15px;display:flex;flex-wrap:wrap;gap:8px;">};
print qq{<a href="invoices.cgi?action=new" style="text-decoration:none;background:#0065ff;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;font-weight:bold;">+ Nueva Factura</a>};
print qq{<a href="invoices.cgi?export_csv=1" style="text-decoration:none;background:#6554c0;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;">Exportar CSV</a>};
print qq{<a href="index.cgi?action=generate_recurring" style="text-decoration:none;background:#ff991f;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;">Generar Recurrentes</a>};
print qq{<a href="index.cgi" style="text-decoration:none;background:#6b778c;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;">Dashboard</a>};
print qq{</div>};

# ── Filter buttons ──
print qq{<div style="margin-bottom:15px;display:flex;flex-wrap:wrap;gap:6px;">};
my @filters = (
	['all',       'Todas',       '#44546f'],
	['pending',   'Pendientes',  '#ff991f'],
	['paid',      'Pagadas',     '#36b37e'],
	['overdue',   'Vencidas',    '#de350b'],
	['cancelled', 'Canceladas',  '#6b778c'],
	);
foreach my $f (@filters) {
	my $active = ($filter eq $f->[0]) ? ';border:2px solid #333;font-weight:bold' : ';border:1px solid #ccc';
	print qq{<a href="invoices.cgi?filter=$f->[0]" style="text-decoration:none;background:$f->[2]$active;color:#fff;padding:5px 14px;border-radius:4px;font-size:12px;">$f->[1]</a>};
	}
print qq{</div>};

# ── New/Edit form ──
if ($action eq 'new' || $action eq 'edit') {
	my $inv = $action eq 'edit' ? ovmbl_get_invoice($id) : {};
	$inv ||= {};
	my $title = $action eq 'edit' ? 'Editar Factura' : 'Nueva Factura';

	print qq{
	<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;margin-bottom:15px;">
	  <div style="font-weight:bold;font-size:14px;margin-bottom:12px;color:#172b4d;">$title</div>
	  <form method="post" action="invoices.cgi">
	    <input type="hidden" name="save_invoice" value="1">
	    <input type="hidden" name="invoice_id" value="} . ($inv->{'id'} || '') . qq{">
	};

	# Client selector
	print qq{
	    <div style="margin-bottom:12px;">
	      <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Cliente</label>
	      <select name="client_id" id="client_select" style="padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;min-width:300px;">
	        <option value="">-- Seleccionar cliente --</option>
	};
	foreach my $c (@$clients) {
		my $sel = ($inv->{'client_id'} && $inv->{'client_id'} eq $c->{'id'}) ? 'selected' : '';
		print qq{<option value="$c->{'id'}" data-name="} . &html_escape($c->{'name'} || '') . qq{" $sel>} . &html_escape($c->{'name'} || 'Unknown') . qq{</option>};
		}
	print qq{
	      </select>
	      <input type="hidden" name="client_name" id="client_name" value="} . &html_escape($inv->{'client_name'} || '') . qq{">
	    </div>
	};

	# Items table
	print qq{
	    <div style="font-weight:bold;font-size:13px;margin:12px 0 8px;color:#172b4d;">Items</div>
	    <table id="items_table" style="width:100%;border-collapse:collapse;font-size:13px;margin-bottom:12px;">
	      <thead>
	        <tr style="background:#f4f5f7;">
	          <th style="padding:6px 10px;text-align:left;color:#6b778c;">Descripci&oacute;n</th>
	          <th style="padding:6px 10px;text-align:center;color:#6b778c;width:80px;">Cantidad</th>
	          <th style="padding:6px 10px;text-align:right;color:#6b778c;width:120px;">Precio Unit.</th>
	          <th style="padding:6px 10px;text-align:right;color:#6b778c;width:120px;">Total</th>
	        </tr>
	      </thead>
	      <tbody>
	};

	my $items = $inv->{'items'} || [];
	if (@$items) {
		my $i = 1;
		foreach my $item (@$items) {
			my $line_total = sprintf("%.2f", ($item->{'qty'} || 0) * ($item->{'price'} || 0));
			print qq{
	        <tr>
	          <td style="padding:6px 10px;"><input type="text" name="item_desc_$i" value="} . &html_escape($item->{'description'} || '') . qq{" style="width:100%;padding:4px 8px;border:1px solid #dfe1e6;border-radius:3px;"></td>
	          <td style="padding:6px 10px;"><input type="number" name="item_qty_$i" value="} . ($item->{'qty'} || 1) . qq{" min="1" style="width:70px;padding:4px 8px;border:1px solid #dfe1e6;border-radius:3px;text-align:center;"></td>
	          <td style="padding:6px 10px;"><input type="number" name="item_price_$i" step="0.01" value="} . ($item->{'price'} || 0) . qq{" style="width:110px;padding:4px 8px;border:1px solid #dfe1e6;border-radius:3px;text-align:right;"></td>
	          <td style="padding:6px 10px;text-align:right;font-weight:bold;">} . ovmbl_format_currency($line_total) . qq{</td>
	        </tr>
			};
			$i++;
			}
		}
	else {
		print qq{
	        <tr>
	          <td style="padding:6px 10px;"><input type="text" name="item_desc_1" style="width:100%;padding:4px 8px;border:1px solid #dfe1e6;border-radius:3px;" placeholder="Descripci&oacute;n del item"></td>
	          <td style="padding:6px 10px;"><input type="number" name="item_qty_1" value="1" min="1" style="width:70px;padding:4px 8px;border:1px solid #dfe1e6;border-radius:3px;text-align:center;"></td>
	          <td style="padding:6px 10px;"><input type="number" name="item_price_1" step="0.01" value="0" style="width:110px;padding:4px 8px;border:1px solid #dfe1e6;border-radius:3px;text-align:right;"></td>
	          <td style="padding:6px 10px;text-align:right;font-weight:bold;">} . ovmbl_format_currency(0) . qq{</td>
	        </tr>
		};
		}

	print qq{
	      </tbody>
	    </table>
	    <div style="margin-bottom:12px;">
	      <button type="button" onclick="add_item_row()" style="background:#f4f5f7;border:1px solid #dfe1e6;padding:4px 12px;border-radius:3px;font-size:12px;cursor:pointer;">+ Agregar Item</button>
	    </div>
	};

	# Totals
	my $sub = $inv->{'subtotal'} || 0;
	my $tax = $inv->{'tax_amount'} || 0;
	my $tot = $inv->{'total'} || 0;

	print qq{
	    <div style="display:flex;justify-content:flex-end;margin-bottom:12px;">
	      <div style="width:250px;">
	        <div style="display:flex;justify-content:space-between;padding:4px 0;font-size:13px;">
	          <span style="color:#6b778c;">Subtotal:</span>
	          <span>} . ovmbl_format_currency($sub) . qq{</span>
	        </div>
	        <div style="display:flex;justify-content:space-between;padding:4px 0;font-size:13px;">
	          <span style="color:#6b778c;">Impuesto:</span>
	          <span>} . ovmbl_format_currency($tax) . qq{</span>
	        </div>
	        <div style="display:flex;justify-content:space-between;padding:6px 0;font-size:15px;font-weight:bold;border-top:2px solid #172b4d;">
	          <span>Total:</span>
	          <span>} . ovmbl_format_currency($tot) . qq{</span>
	        </div>
	      </div>
	    </div>
	};

	# Due date and notes
	my $due_str = $inv->{'due_date'} ? ovmbl_human_date($inv->{'due_date'}) : ovmbl_human_date(time() + (($ovmbl_config{'payment_terms'} || 30) * 86400));

	print qq{
	    <div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:12px;">
	      <div>
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Fecha de Vencimiento</label>
	        <input type="date" name="due_date" value="$due_str" style="padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	    </div>
	    <div style="margin-bottom:12px;">
	      <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Notas</label>
	      <textarea name="notes" rows="3" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">} . &html_escape($inv->{'notes'} || '') . qq{</textarea>
	    </div>
	    <div>
	      <button type="submit" style="background:#0065ff;color:#fff;border:none;padding:8px 20px;border-radius:4px;font-size:13px;cursor:pointer;">Guardar Factura</button>
	      <a href="invoices.cgi" style="margin-left:8px;color:#6b778c;text-decoration:none;font-size:13px;">Cancelar</a>
	    </div>
	  </form>
	</div>
	};

	# JS for dynamic items
	print qq{
	<script>
	function add_item_row() {
		var table = document.getElementById('items_table').getElementsByTagName('tbody')[0];
		var rows = table.getElementsByTagName('tr');
		var idx = rows.length + 1;
		var row = table.insertRow();
		row.innerHTML = '<td style="padding:6px 10px;"><input type="text" name="item_desc_' + idx + '" style="width:100%;padding:4px 8px;border:1px solid #dfe1e6;border-radius:3px;" placeholder="Descripcion del item"></td>' +
		  '<td style="padding:6px 10px;"><input type="number" name="item_qty_' + idx + '" value="1" min="1" style="width:70px;padding:4px 8px;border:1px solid #dfe1e6;border-radius:3px;text-align:center;"></td>' +
		  '<td style="padding:6px 10px;"><input type="number" name="item_price_' + idx + '" step="0.01" value="0" style="width:110px;padding:4px 8px;border:1px solid #dfe1e6;border-radius:3px;text-align:right;"></td>' +
		  '<td style="padding:6px 10px;text-align:right;font-weight:bold;">-</td>';
	}
	document.getElementById('client_select').addEventListener('change', function() {
		var opt = this.options[this.selectedIndex];
		document.getElementById('client_name').value = opt.getAttribute('data-name') || '';
	});
	</script>
	};
	}

# ── View single invoice ──
elsif ($action eq 'view' && $id) {
	my $inv = ovmbl_get_invoice($id);
	if ($inv) {
		my $status = $inv->{'status'} || 'pending';
		if ($status eq 'pending' && $inv->{'due_date'} && $inv->{'due_date'} < time()) {
			$status = 'overdue';
			}
		my $badge = ovmbl_status_badge($status);
		my $items = $inv->{'items'} || [];

		print qq{
		<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;margin-bottom:15px;">
		  <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
		    <div>
		      <div style="font-size:18px;font-weight:bold;color:#172b4d;">} . &html_escape($inv->{'number'} || 'N/A') . qq{</div>
		      <div style="font-size:13px;color:#6b778c;">Cliente: } . &html_escape($inv->{'client_name'} || 'N/A') . qq{</div>
		    </div>
		    <div style="display:flex;align-items:center;gap:8px;">
		      $badge
		      <a href="invoices.cgi?action=edit&id=$inv->{'id'}" style="text-decoration:none;background:#0065ff;color:#fff;padding:5px 12px;border-radius:3px;font-size:11px;">Editar</a>
		};
		if ($status eq 'pending' || $status eq 'overdue') {
			print qq{<a href="invoices.cgi?action=mark_paid&id=$inv->{'id'}" style="text-decoration:none;background:#36b37e;color:#fff;padding:5px 12px;border-radius:3px;font-size:11px;">Marcar Pagada</a>};
			print qq{<a href="invoices.cgi?action=cancel&id=$inv->{'id'}" style="text-decoration:none;background:#6b778c;color:#fff;padding:5px 12px;border-radius:3px;font-size:11px;">Cancelar</a>};
			}
		print qq{
		    </div>
		  </div>
		  <table style="width:100%;border-collapse:collapse;font-size:13px;margin-bottom:12px;">
		    <thead>
		      <tr style="background:#f4f5f7;">
		        <th style="padding:6px 10px;text-align:left;color:#6b778c;">Descripci&oacute;n</th>
		        <th style="padding:6px 10px;text-align:center;color:#6b778c;width:80px;">Cant.</th>
		        <th style="padding:6px 10px;text-align:right;color:#6b778c;width:120px;">Precio</th>
		        <th style="padding:6px 10px;text-align:right;color:#6b778c;width:120px;">Total</th>
		      </tr>
		    </thead>
		    <tbody>
		};
		foreach my $item (@$items) {
			my $lt = sprintf("%.2f", ($item->{'qty'} || 0) * ($item->{'price'} || 0));
			print qq{
		      <tr style="border-bottom:1px solid #ebecf0;">
		        <td style="padding:6px 10px;">} . &html_escape($item->{'description'} || '') . qq{</td>
		        <td style="padding:6px 10px;text-align:center;">$item->{'qty'}</td>
		        <td style="padding:6px 10px;text-align:right;">} . ovmbl_format_currency($item->{'price'}) . qq{</td>
		        <td style="padding:6px 10px;text-align:right;">} . ovmbl_format_currency($lt) . qq{</td>
		      </tr>
			};
			}
		print qq{
		    </tbody>
		  </table>
		  <div style="display:flex;justify-content:flex-end;">
		    <div style="width:250px;">
		      <div style="display:flex;justify-content:space-between;padding:4px 0;font-size:13px;">
		        <span style="color:#6b778c;">Subtotal:</span>
		        <span>} . ovmbl_format_currency($inv->{'subtotal'}) . qq{</span>
		      </div>
		      <div style="display:flex;justify-content:space-between;padding:4px 0;font-size:13px;">
		        <span style="color:#6b778c;">Impuesto:</span>
		        <span>} . ovmbl_format_currency($inv->{'tax_amount'}) . qq{</span>
		      </div>
		      <div style="display:flex;justify-content:space-between;padding:6px 0;font-size:15px;font-weight:bold;border-top:2px solid #172b4d;">
		        <span>Total:</span>
		        <span>} . ovmbl_format_currency($inv->{'total'}) . qq{</span>
		      </div>
		    </div>
		  </div>
		  <div style="margin-top:12px;font-size:12px;color:#6b778c;">
		    <div>Creada: } . ovmbl_human_date($inv->{'created'}) . qq{</div>
		    <div>Vencimiento: } . ovmbl_human_date($inv->{'due_date'}) . qq{</div>
		};
		if ($inv->{'paid_date'}) {
			print qq{<div>Pagada: } . ovmbl_human_date($inv->{'paid_date'}) . qq{</div>};
			}
		if ($inv->{'notes'}) {
			print qq{<div style="margin-top:6px;">Notas: } . &html_escape($inv->{'notes'}) . qq{</div>};
			}
		print qq{
		  </div>
		</div>
		};
		}
	else {
		print qq{<div style="padding:20px;color:#de350b;">Factura no encontrada.</div>};
		}
	}

# ── Invoices table ──
my @sorted = sort { ($b->{'created'} || 0) <=> ($a->{'created'} || 0) } @$invoices;

if (@sorted) {
	print qq{
	<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;overflow:hidden;">
	  <table style="width:100%;border-collapse:collapse;font-size:13px;">
	    <thead>
	      <tr style="background:#f4f5f7;">
	        <th style="padding:8px 12px;text-align:left;color:#6b778c;">N&uacute;mero</th>
	        <th style="padding:8px 12px;text-align:left;color:#6b778c;">Cliente</th>
	        <th style="padding:8px 12px;text-align:right;color:#6b778c;">Subtotal</th>
	        <th style="padding:8px 12px;text-align:right;color:#6b778c;">Impuesto</th>
	        <th style="padding:8px 12px;text-align:right;color:#6b778c;">Total</th>
	        <th style="padding:8px 12px;text-align:center;color:#6b778c;">Estado</th>
	        <th style="padding:8px 12px;text-align:left;color:#6b778c;">Fecha</th>
	        <th style="padding:8px 12px;text-align:center;color:#6b778c;">Acciones</th>
	      </tr>
	    </thead>
	    <tbody>
	};

	foreach my $inv (@sorted) {
		my $status = $inv->{'status'} || 'pending';
		if ($status eq 'pending' && $inv->{'due_date'} && $inv->{'due_date'} < time()) {
			$status = 'overdue';
			}
		my $badge = ovmbl_status_badge($status);
		my $date = ovmbl_human_date($inv->{'created'});

		print qq{
	      <tr style="border-bottom:1px solid #ebecf0;">
	        <td style="padding:8px 12px;"><a href="invoices.cgi?action=view&id=$inv->{'id'}" style="color:#0065ff;text-decoration:none;">} . &html_escape($inv->{'number'} || 'N/A') . qq{</a></td>
	        <td style="padding:8px 12px;">} . &html_escape($inv->{'client_name'} || 'N/A') . qq{</td>
	        <td style="padding:8px 12px;text-align:right;">} . ovmbl_format_currency($inv->{'subtotal'}) . qq{</td>
	        <td style="padding:8px 12px;text-align:right;">} . ovmbl_format_currency($inv->{'tax_amount'}) . qq{</td>
	        <td style="padding:8px 12px;text-align:right;font-weight:bold;">} . ovmbl_format_currency($inv->{'total'}) . qq{</td>
	        <td style="padding:8px 12px;text-align:center;">$badge</td>
	        <td style="padding:8px 12px;color:#6b778c;">$date</td>
	        <td style="padding:8px 12px;text-align:center;white-space:nowrap;">
	          <a href="invoices.cgi?action=view&id=$inv->{'id'}" style="font-size:11px;color:#0065ff;text-decoration:none;margin-right:4px;">Ver</a>
		};
		if ($status eq 'pending' || $status eq 'overdue') {
			print qq{<a href="invoices.cgi?action=mark_paid&id=$inv->{'id'}" style="font-size:11px;color:#36b37e;text-decoration:none;margin-right:4px;">Pagar</a>};
			}
		print qq{<a href="invoices.cgi?action=delete&id=$inv->{'id'}" onclick="return confirm('Eliminar factura?')" style="font-size:11px;color:#de350b;text-decoration:none;">X</a>};
		print qq{</td></tr>};
		}

	print qq{</tbody></table></div>};
	}
else {
	print qq{<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:30px;text-align:center;color:#6b778c;">No hay facturas. <a href="invoices.cgi?action=new" style="color:#0065ff;">Crear primera factura</a></div>};
	}

# ── Footer ──
print qq{
<div style="text-align:center;padding:10px;color:#6b778c;font-size:12px;margin-top:15px;">
  <a href="index.cgi" style="color:#0065ff;text-decoration:none;">Dashboard</a> &middot;
  <a href="plans.cgi" style="color:#0065ff;text-decoration:none;">Planes</a> &middot;
  <a href="clients.cgi" style="color:#0065ff;text-decoration:none;">Clientes</a> &middot;
  <a href="reports.cgi" style="color:#0065ff;text-decoration:none;">Reportes</a> &middot;
  <a href="settings.cgi" style="color:#0065ff;text-decoration:none;">Configuraci&oacute;n</a>
</div>
};

&ui_print_footer('/', 'Index');

# Helper: parse date string (YYYY-MM-DD) to timestamp
sub ovmbl_parse_date
{
my ($str) = @_;
return 0 unless $str;
if ($str =~ /^(\d{4})-(\d{2})-(\d{2})/) {
	use Time::Local;
	my ($y, $m, $d) = ($1, $2, $3);
	return eval { timegm(0, 0, 12, $d, $m - 1, $y - 1900) } || time();
	}
return time();
}
