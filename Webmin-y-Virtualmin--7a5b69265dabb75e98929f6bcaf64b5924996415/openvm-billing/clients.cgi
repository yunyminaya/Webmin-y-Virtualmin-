#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-billing-lib.pl';
&ReadParse();

ovmbl_init();

my $action = $in{'action'} || '';
my $id     = $in{'id'} || '';

# Handle POST actions
if ($in{'save_client'}) {
	my %client;
	$client{'name'}        = $in{'name'} || '';
	$client{'company'}     = $in{'company'} || '';
	$client{'email'}       = $in{'email'} || '';
	$client{'phone'}       = $in{'phone'} || '';
	$client{'address'}     = $in{'address'} || '';
	$client{'plan_id'}     = $in{'plan_id'} || '';
	$client{'domains'}     = $in{'domains'} || '';
	$client{'payment_method'} = $in{'payment_method'} || '';
	$client{'notes'}       = $in{'notes'} || '';
	$client{'status'}      = $in{'status'} || 'active';

	if ($in{'client_id'}) {
		ovmbl_update_client($in{'client_id'}, %client);
		$id = $in{'client_id'};
		$action = 'view';
		}
	else {
		my $new_id = ovmbl_create_client(%client);
		$id = $new_id;
		$action = 'view';
		}
	}
elsif ($action eq 'delete' && $id) {
	ovmbl_delete_client($id);
	$action = '';
	$id = '';
	}

my $clients = ovmbl_list_clients();
my $plans   = ovmbl_list_plans();

&ui_print_header(undef, 'OpenVM Billing &mdash; Clients', '', 'clients');

# ── Action buttons ──
print qq{<div style="margin-bottom:15px;display:flex;flex-wrap:wrap;gap:8px;">};
print qq{<a href="clients.cgi?action=new" style="text-decoration:none;background:#0065ff;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;font-weight:bold;">+ Nuevo Cliente</a>};
print qq{<a href="index.cgi" style="text-decoration:none;background:#6b778c;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;">Dashboard</a>};
print qq{</div>};

# ── New/Edit form ──
if ($action eq 'new' || $action eq 'edit') {
	my $client = $action eq 'edit' ? ovmbl_get_client($id) : {};
	$client ||= {};
	my $title = $action eq 'edit' ? 'Editar Cliente' : 'Nuevo Cliente';

	print qq{
	<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;margin-bottom:15px;">
	  <div style="font-weight:bold;font-size:14px;margin-bottom:12px;color:#172b4d;">$title</div>
	  <form method="post" action="clients.cgi">
	    <input type="hidden" name="save_client" value="1">
	    <input type="hidden" name="client_id" value="} . ($client->{'id'} || '') . qq{">
	};

	print qq{
	    <div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:12px;">
	      <div style="flex:1;min-width:200px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Nombre / Contacto</label>
	        <input type="text" name="name" value="} . &html_escape($client->{'name'} || '') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	      <div style="flex:1;min-width:200px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Empresa</label>
	        <input type="text" name="company" value="} . &html_escape($client->{'company'} || '') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	    </div>
	};

	print qq{
	    <div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:12px;">
	      <div style="flex:1;min-width:200px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Email</label>
	        <input type="email" name="email" value="} . &html_escape($client->{'email'} || '') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	      <div style="flex:1;min-width:200px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Tel&eacute;fono</label>
	        <input type="text" name="phone" value="} . &html_escape($client->{'phone'} || '') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	    </div>
	};

	print qq{
	    <div style="margin-bottom:12px;">
	      <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Direcci&oacute;n</label>
	      <textarea name="address" rows="2" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">} . &html_escape($client->{'address'} || '') . qq{</textarea>
	    </div>
	};

	print qq{
	    <div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:12px;">
	      <div style="flex:1;min-width:200px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Plan Asignado</label>
	        <select name="plan_id" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	          <option value="">-- Sin plan --</option>
	};
	foreach my $p (@$plans) {
		my $sel = ($client->{'plan_id'} && $client->{'plan_id'} eq $p->{'id'}) ? 'selected' : '';
		print qq{<option value="$p->{'id'}" $sel>} . &html_escape($p->{'name'} || 'Unnamed') . qq{</option>};
		}
	print qq{
	        </select>
	      </div>
	      <div style="flex:1;min-width:200px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Dominio(s)</label>
	        <input type="text" name="domains" value="} . &html_escape($client->{'domains'} || '') . qq{" placeholder="ej: example.com, test.com" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	    </div>
	};

	print qq{
	    <div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:12px;">
	      <div style="flex:1;min-width:200px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">M&eacute;todo de Pago</label>
	        <select name="payment_method" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	          <option value="">-- Seleccionar --</option>
	          <option value="credit_card" } . (($client->{'payment_method'} || '') eq 'credit_card' ? 'selected' : '') . qq{>Tarjeta de Cr&eacute;dito</option>
	          <option value="paypal" } . (($client->{'payment_method'} || '') eq 'paypal' ? 'selected' : '') . qq{>PayPal</option>
	          <option value="bank_transfer" } . (($client->{'payment_method'} || '') eq 'bank_transfer' ? 'selected' : '') . qq{>Transferencia Bancaria</option>
	          <option value="crypto" } . (($client->{'payment_method'} || '') eq 'crypto' ? 'selected' : '') . qq{>Criptomonedas</option>
	          <option value="other" } . (($client->{'payment_method'} || '') eq 'other' ? 'selected' : '') . qq{>Otro</option>
	        </select>
	      </div>
	      <div style="flex:1;min-width:200px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Estado</label>
	        <select name="status" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	          <option value="active" } . (($client->{'status'} || 'active') eq 'active' ? 'selected' : '') . qq{>Activo</option>
	          <option value="inactive" } . (($client->{'status'} || '') eq 'inactive' ? 'selected' : '') . qq{>Inactivo</option>
	          <option value="suspended" } . (($client->{'status'} || '') eq 'suspended' ? 'selected' : '') . qq{>Suspendido</option>
	        </select>
	      </div>
	    </div>
	};

	print qq{
	    <div style="margin-bottom:12px;">
	      <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Notas</label>
	      <textarea name="notes" rows="3" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">} . &html_escape($client->{'notes'} || '') . qq{</textarea>
	    </div>
	    <div>
	      <button type="submit" style="background:#0065ff;color:#fff;border:none;padding:8px 20px;border-radius:4px;font-size:13px;cursor:pointer;">Guardar Cliente</button>
	      <a href="clients.cgi" style="margin-left:8px;color:#6b778c;text-decoration:none;font-size:13px;">Cancelar</a>
	    </div>
	  </form>
	</div>
	};
	}

# ── View single client ──
elsif ($action eq 'view' && $id) {
	my $client = ovmbl_get_client($id);
	if ($client) {
		my $badge = ovmbl_status_badge($client->{'status'} || 'active');
		my $balance = ovmbl_get_client_balance($id);
		my $plan_name = 'Sin plan';
		if ($client->{'plan_id'}) {
			my $p = ovmbl_get_plan($client->{'plan_id'});
			$plan_name = $p->{'name'} if $p;
			}

		# Client invoices
		my $all_invoices = ovmbl_list_invoices('all');
		my @client_invoices = sort { ($b->{'created'} || 0) <=> ($a->{'created'} || 0) }
		                      grep { $_->{'client_id'} eq $id } @$all_invoices;

		# Next invoice (pending)
		my @pending = grep { $_->{'status'} eq 'pending' } @client_invoices;

		print qq{
		<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;margin-bottom:15px;">
		  <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:16px;">
		    <div>
		      <div style="font-size:18px;font-weight:bold;color:#172b4d;">} . &html_escape($client->{'name'} || 'Unknown') . qq{</div>
		      <div style="font-size:13px;color:#6b778c;">} . &html_escape($client->{'company'} || '') . qq{</div>
		    </div>
		    <div style="display:flex;align-items:center;gap:8px;">
		      $badge
		      <a href="clients.cgi?action=edit&id=$client->{'id'}" style="text-decoration:none;background:#0065ff;color:#fff;padding:5px 12px;border-radius:3px;font-size:11px;">Editar</a>
		      <a href="clients.cgi?action=delete&id=$client->{'id'}" onclick="return confirm('Eliminar cliente?')" style="text-decoration:none;background:#de350b;color:#fff;padding:5px 12px;border-radius:3px;font-size:11px;">Eliminar</a>
		    </div>
		  </div>
		  <div style="display:flex;flex-wrap:wrap;gap:20px;font-size:13px;">
		    <div><span style="color:#6b778c;">Email:</span> } . &html_escape($client->{'email'} || 'N/A') . qq{</div>
		    <div><span style="color:#6b778c;">Tel:</span> } . &html_escape($client->{'phone'} || 'N/A') . qq{</div>
		    <div><span style="color:#6b778c;">Plan:</span> $plan_name</div>
		    <div><span style="color:#6b778c;">Dominio(s):</span> } . &html_escape($client->{'domains'} || 'N/A') . qq{</div>
		    <div><span style="color:#6b778c;">Pago:</span> } . &html_escape($client->{'payment_method'} || 'N/A') . qq{</div>
		  </div>
		};
		if ($client->{'address'}) {
			print qq{<div style="font-size:13px;color:#6b778c;margin-top:6px;">Direcci&oacute;n: } . &html_escape($client->{'address'}) . qq{</div>};
			}
		if ($client->{'notes'}) {
			print qq{<div style="font-size:13px;color:#6b778c;margin-top:6px;">Notas: } . &html_escape($client->{'notes'}) . qq{</div>};
			}
		print qq{</div>};

		# Balance card
		print qq{
		<div style="display:flex;flex-wrap:wrap;gap:15px;margin-bottom:15px;">
		  <div style="flex:1;min-width:150px;background:linear-gradient(135deg,#0065ff,#2684ff);color:#fff;border-radius:8px;padding:14px 18px;">
		    <div style="font-size:12px;opacity:0.85;">Balance Pendiente</div>
		    <div style="font-size:24px;font-weight:bold;margin-top:4px;">} . ovmbl_format_currency($balance) . qq{</div>
		  </div>
		  <div style="flex:1;min-width:150px;background:linear-gradient(135deg,#36b37e,#57d9a3);color:#fff;border-radius:8px;padding:14px 18px;">
		    <div style="font-size:12px;opacity:0.85;">Total Facturas</div>
		    <div style="font-size:24px;font-weight:bold;margin-top:4px;">} . scalar(@client_invoices) . qq{</div>
		  </div>
		  <div style="flex:1;min-width:150px;background:linear-gradient(135deg,#ff991f,#ffc400);color:#fff;border-radius:8px;padding:14px 18px;">
		    <div style="font-size:12px;opacity:0.85;">Pendientes</div>
		    <div style="font-size:24px;font-weight:bold;margin-top:4px;">} . scalar(@pending) . qq{</div>
		  </div>
		</div>
		};

		# Invoice history
		if (@client_invoices) {
			print qq{
			<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;overflow:hidden;margin-bottom:15px;">
			  <div style="padding:10px 16px;font-weight:bold;font-size:14px;border-bottom:1px solid #dfe1e6;color:#172b4d;">Historial de Facturas</div>
			  <table style="width:100%;border-collapse:collapse;font-size:13px;">
			    <thead>
			      <tr style="background:#f4f5f7;">
			        <th style="padding:6px 10px;text-align:left;color:#6b778c;">N&uacute;mero</th>
			        <th style="padding:6px 10px;text-align:right;color:#6b778c;">Total</th>
			        <th style="padding:6px 10px;text-align:center;color:#6b778c;">Estado</th>
			        <th style="padding:6px 10px;text-align:left;color:#6b778c;">Fecha</th>
			      </tr>
			    </thead>
			    <tbody>
			};
			foreach my $inv (@client_invoices) {
				my $st = $inv->{'status'} || 'pending';
				if ($st eq 'pending' && $inv->{'due_date'} && $inv->{'due_date'} < time()) {
					$st = 'overdue';
					}
				print qq{
			      <tr style="border-bottom:1px solid #ebecf0;">
			        <td style="padding:6px 10px;"><a href="invoices.cgi?action=view&id=$inv->{'id'}" style="color:#0065ff;text-decoration:none;">} . &html_escape($inv->{'number'} || 'N/A') . qq{</a></td>
			        <td style="padding:6px 10px;text-align:right;">} . ovmbl_format_currency($inv->{'total'}) . qq{</td>
			        <td style="padding:6px 10px;text-align:center;">} . ovmbl_status_badge($st) . qq{</td>
			        <td style="padding:6px 10px;color:#6b778c;">} . ovmbl_human_date($inv->{'created'}) . qq{</td>
			      </tr>
				};
				}
			print qq{</tbody></table></div>};
			}
		else {
			print qq{<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:20px;text-align:center;color:#6b778c;margin-bottom:15px;">Sin facturas. <a href="invoices.cgi?action=new" style="color:#0065ff;">Crear factura</a></div>};
			}
		}
	else {
		print qq{<div style="padding:20px;color:#de350b;">Cliente no encontrado.</div>};
		}
	}

# ── Clients table (default view) ──
elsif ($action ne 'new' && $action ne 'edit') {
	if (@$clients) {
		print qq{
		<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;overflow:hidden;">
		  <table style="width:100%;border-collapse:collapse;font-size:13px;">
		    <thead>
		      <tr style="background:#f4f5f7;">
		        <th style="padding:8px 12px;text-align:left;color:#6b778c;">Nombre</th>
		        <th style="padding:8px 12px;text-align:left;color:#6b778c;">Email</th>
		        <th style="padding:8px 12px;text-align:left;color:#6b778c;">Plan</th>
		        <th style="padding:8px 12px;text-align:right;color:#6b778c;">Balance</th>
		        <th style="padding:8px 12px;text-align:center;color:#6b778c;">Estado</th>
		        <th style="padding:8px 12px;text-align:center;color:#6b778c;">Acciones</th>
		      </tr>
		    </thead>
		    <tbody>
		};
		foreach my $c (@$clients) {
			my $badge = ovmbl_status_badge($c->{'status'} || 'active');
			my $balance = ovmbl_get_client_balance($c->{'id'});
			my $plan_name = '';
			if ($c->{'plan_id'}) {
				my $p = ovmbl_get_plan($c->{'plan_id'});
				$plan_name = $p->{'name'} if $p;
				}
			$plan_name ||= 'Sin plan';

			print qq{
		      <tr style="border-bottom:1px solid #ebecf0;">
		        <td style="padding:8px 12px;"><a href="clients.cgi?action=view&id=$c->{'id'}" style="color:#0065ff;text-decoration:none;font-weight:bold;">} . &html_escape($c->{'name'} || 'Unknown') . qq{</a></td>
		        <td style="padding:8px 12px;">} . &html_escape($c->{'email'} || 'N/A') . qq{</td>
		        <td style="padding:8px 12px;">$plan_name</td>
		        <td style="padding:8px 12px;text-align:right;font-weight:bold;">} . ovmbl_format_currency($balance) . qq{</td>
		        <td style="padding:8px 12px;text-align:center;">$badge</td>
		        <td style="padding:8px 12px;text-align:center;white-space:nowrap;">
		          <a href="clients.cgi?action=view&id=$c->{'id'}" style="font-size:11px;color:#0065ff;text-decoration:none;margin-right:4px;">Ver</a>
		          <a href="clients.cgi?action=edit&id=$c->{'id'}" style="font-size:11px;color:#ff991f;text-decoration:none;margin-right:4px;">Editar</a>
		          <a href="clients.cgi?action=delete&id=$c->{'id'}" onclick="return confirm('Eliminar cliente?')" style="font-size:11px;color:#de350b;text-decoration:none;">X</a>
		        </td>
		      </tr>
			};
			}
		print qq{</tbody></table></div>};
		}
	else {
		print qq{<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:30px;text-align:center;color:#6b778c;">No hay clientes. <a href="clients.cgi?action=new" style="color:#0065ff;">Crear primer cliente</a></div>};
		}
	}

# ── Footer ──
print qq{
<div style="text-align:center;padding:10px;color:#6b778c;font-size:12px;margin-top:15px;">
  <a href="index.cgi" style="color:#0065ff;text-decoration:none;">Dashboard</a> &middot;
  <a href="plans.cgi" style="color:#0065ff;text-decoration:none;">Planes</a> &middot;
  <a href="invoices.cgi" style="color:#0065ff;text-decoration:none;">Facturas</a> &middot;
  <a href="reports.cgi" style="color:#0065ff;text-decoration:none;">Reportes</a> &middot;
  <a href="settings.cgi" style="color:#0065ff;text-decoration:none;">Configuraci&oacute;n</a>
</div>
};

&ui_print_footer('/', 'Index');
