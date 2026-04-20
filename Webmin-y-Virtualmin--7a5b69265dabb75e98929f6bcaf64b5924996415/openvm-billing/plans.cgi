#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-billing-lib.pl';
&ReadParse();

ovmbl_init();

my $action = $in{'action'} || '';
my $id     = $in{'id'} || '';

# Handle POST actions
if ($in{'save_plan'}) {
	my %plan;
	$plan{'name'}          = $in{'name'} || 'Unnamed Plan';
	$plan{'description'}   = $in{'description'} || '';
	$plan{'price_monthly'} = $in{'price_monthly'} || 0;
	$plan{'price_yearly'}  = $in{'price_yearly'} || 0;
	$plan{'disk'}          = $in{'disk'} || 0;
	$plan{'bandwidth'}     = $in{'bandwidth'} || 0;
	$plan{'domains'}       = $in{'domains'} || 0;
	$plan{'emails'}        = $in{'emails'} || 0;
	$plan{'databases'}     = $in{'databases'} || 0;
	$plan{'ftp_accounts'}  = $in{'ftp_accounts'} || 0;
	$plan{'ssl'}           = $in{'ssl'} || 'no';
	$plan{'backup'}        = $in{'backup'} || 'no';
	$plan{'priority_support'} = $in{'priority_support'} || 'no';
	$plan{'status'}        = $in{'status'} || 'active';

	if ($in{'plan_id'}) {
		ovmbl_update_plan($in{'plan_id'}, %plan);
		}
	else {
		ovmbl_create_plan(%plan);
		}
	$action = '';
	}
elsif ($in{'action'} eq 'delete' && $in{'id'}) {
	ovmbl_delete_plan($in{'id'});
	$action = '';
	}

my $plans = ovmbl_list_plans();

&ui_print_header(undef, 'OpenVM Billing &mdash; Plans', '', 'plans');

# ── Action buttons ──
print qq{<div style="margin-bottom:15px;display:flex;flex-wrap:wrap;gap:8px;">};
print qq{<a href="plans.cgi?action=new" style="text-decoration:none;background:#0065ff;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;font-weight:bold;">+ Crear Plan</a>};
print qq{<a href="index.cgi" style="text-decoration:none;background:#6b778c;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;">Dashboard</a>};
print qq{</div>};

# ── New/Edit form ──
if ($action eq 'new' || $action eq 'edit') {
	my $plan = $action eq 'edit' ? ovmbl_get_plan($id) : {};
	$plan ||= {};
	my $title = $action eq 'edit' ? 'Editar Plan' : 'Nuevo Plan';

	print qq{
	<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;margin-bottom:15px;">
	  <div style="font-weight:bold;font-size:14px;margin-bottom:12px;color:#172b4d;">$title</div>
	  <form method="post" action="plans.cgi">
	    <input type="hidden" name="save_plan" value="1">
	    <input type="hidden" name="plan_id" value="} . ($plan->{'id'} || '') . qq{">
	};

	print qq{
	    <div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:12px;">
	      <div style="flex:1;min-width:250px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Nombre del Plan</label>
	        <input type="text" name="name" value="} . &html_escape($plan->{'name'} || '') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	      <div style="flex:1;min-width:250px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Descripci&oacute;n</label>
	        <input type="text" name="description" value="} . &html_escape($plan->{'description'} || '') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	    </div>
	};

	print qq{
	    <div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:12px;">
	      <div style="flex:1;min-width:120px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Precio Mensual</label>
	        <input type="number" name="price_monthly" step="0.01" value="} . ($plan->{'price_monthly'} || '0') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	      <div style="flex:1;min-width:120px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Precio Anual</label>
	        <input type="number" name="price_yearly" step="0.01" value="} . ($plan->{'price_yearly'} || '0') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	    </div>
	};

	print qq{
	    <div style="font-weight:bold;font-size:13px;margin:12px 0 8px;color:#172b4d;">Recursos</div>
	    <div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:12px;">
	      <div style="flex:1;min-width:100px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Disco (GB)</label>
	        <input type="number" name="disk" value="} . ($plan->{'disk'} || '0') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	      <div style="flex:1;min-width:100px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">BW (GB)</label>
	        <input type="number" name="bandwidth" value="} . ($plan->{'bandwidth'} || '0') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	      <div style="flex:1;min-width:100px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Dominios</label>
	        <input type="number" name="domains" value="} . ($plan->{'domains'} || '0') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	      <div style="flex:1;min-width:100px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Emails</label>
	        <input type="number" name="emails" value="} . ($plan->{'emails'} || '0') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	      <div style="flex:1;min-width:100px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Bases de Datos</label>
	        <input type="number" name="databases" value="} . ($plan->{'databases'} || '0') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	      <div style="flex:1;min-width:100px;">
	        <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Cuentas FTP</label>
	        <input type="number" name="ftp_accounts" value="} . ($plan->{'ftp_accounts'} || '0') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	      </div>
	    </div>
	};

	my $ssl_chk    = $plan->{'ssl'} eq 'yes' ? 'checked' : '';
	my $backup_chk = $plan->{'backup'} eq 'yes' ? 'checked' : '';
	my $support_chk = $plan->{'priority_support'} eq 'yes' ? 'checked' : '';

	print qq{
	    <div style="font-weight:bold;font-size:13px;margin:12px 0 8px;color:#172b4d;">Caracter&iacute;sticas</div>
	    <div style="display:flex;flex-wrap:wrap;gap:16px;margin-bottom:12px;">
	      <label style="font-size:13px;"><input type="checkbox" name="ssl" value="yes" $ssl_chk> SSL Incluido</label>
	      <label style="font-size:13px;"><input type="checkbox" name="backup" value="yes" $backup_chk> Backup Diario</label>
	      <label style="font-size:13px;"><input type="checkbox" name="priority_support" value="yes" $support_chk> Soporte Prioritario</label>
	    </div>
	};

	my $active_chk = ($plan->{'status'} || 'active') eq 'active' ? 'selected' : '';
	my $inactive_chk = $plan->{'status'} eq 'inactive' ? 'selected' : '';

	print qq{
	    <div style="margin-bottom:12px;">
	      <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Estado</label>
	      <select name="status" style="padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
	        <option value="active" $active_chk>Activo</option>
	        <option value="inactive" $inactive_chk>Inactivo</option>
	      </select>
	    </div>
	};

	print qq{
	    <div style="margin-top:12px;">
	      <button type="submit" style="background:#0065ff;color:#fff;border:none;padding:8px 20px;border-radius:4px;font-size:13px;cursor:pointer;">Guardar Plan</button>
	      <a href="plans.cgi" style="margin-left:8px;color:#6b778c;text-decoration:none;font-size:13px;">Cancelar</a>
	    </div>
	  </form>
	</div>
	};
	}

# ── Plans grid ──
if (@$plans) {
	print qq{<div style="display:flex;flex-wrap:wrap;gap:16px;">};
	foreach my $plan (@$plans) {
		my $badge = ovmbl_status_badge($plan->{'status'} || 'active');
		my $price = ovmbl_format_currency($plan->{'price_monthly'});
		my $yearly = $plan->{'price_yearly'} ? ovmbl_format_currency($plan->{'price_yearly'}) . '/yr' : '';
		my $esc_name = &html_escape($plan->{'name'} || 'Unnamed');
		my $esc_desc = &html_escape($plan->{'description'} || '');

		my @features;
		push @features, 'SSL' if $plan->{'ssl'} eq 'yes';
		push @features, 'Backup' if $plan->{'backup'} eq 'yes';
		push @features, 'Soporte 24/7' if $plan->{'priority_support'} eq 'yes';
		my $feat_str = join(', ', @features) || 'Ninguna';

		print qq{
	<div style="flex:1;min-width:260px;max-width:350px;background:#fff;border:1px solid #dfe1e6;border-radius:8px;overflow:hidden;">
	  <div style="background:linear-gradient(135deg,#0065ff,#2684ff);color:#fff;padding:16px;">
	    <div style="display:flex;justify-content:space-between;align-items:center;">
	      <span style="font-weight:bold;font-size:16px;">$esc_name</span>
	      $badge
	    </div>
	    <div style="font-size:32px;font-weight:bold;margin-top:8px;">$price<span style="font-size:14px;">/mo</span></div>
	    <div style="font-size:12px;opacity:0.8;">$yearly</div>
	  </div>
	  <div style="padding:12px 16px;">
	    <div style="font-size:12px;color:#6b778c;margin-bottom:8px;">$esc_desc</div>
	    <div style="display:grid;grid-template-columns:1fr 1fr;gap:4px;font-size:12px;">
	      <div>&#128190; Disco: <b>} . ($plan->{'disk'} || 0) . qq{ GB</b></div>
	      <div>&#127760; BW: <b>} . ($plan->{'bandwidth'} || 0) . qq{ GB</b></div>
	      <div>&#127748; Dominios: <b>} . ($plan->{'domains'} || 0) . qq{</b></div>
	      <div>&#9993; Emails: <b>} . ($plan->{'emails'} || 0) . qq{</b></div>
	      <div>&#128451; BDs: <b>} . ($plan->{'databases'} || 0) . qq{</b></div>
	      <div>&#128193; FTP: <b>} . ($plan->{'ftp_accounts'} || 0) . qq{</b></div>
	    </div>
	    <div style="font-size:11px;color:#6b778c;margin-top:6px;">Caracter&iacute;sticas: $feat_str</div>
	  </div>
	  <div style="padding:8px 16px;border-top:1px solid #ebecf0;display:flex;gap:8px;">
	    <a href="plans.cgi?action=edit&id=$plan->{'id'}" style="text-decoration:none;background:#0065ff;color:#fff;padding:4px 12px;border-radius:3px;font-size:11px;">Editar</a>
	    <a href="plans.cgi?action=delete&id=$plan->{'id'}" onclick="return confirm('Eliminar plan?')" style="text-decoration:none;background:#de350b;color:#fff;padding:4px 12px;border-radius:3px;font-size:11px;">Eliminar</a>
	  </div>
	</div>
		};
		}
	print qq{</div>};
	}
else {
	print qq{<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:30px;text-align:center;color:#6b778c;">No hay planes creados. <a href="plans.cgi?action=new" style="color:#0065ff;">Crear primer plan</a></div>};
	}

# ── Footer ──
print qq{
<div style="text-align:center;padding:10px;color:#6b778c;font-size:12px;margin-top:15px;">
  <a href="index.cgi" style="color:#0065ff;text-decoration:none;">Dashboard</a> &middot;
  <a href="invoices.cgi" style="color:#0065ff;text-decoration:none;">Facturas</a> &middot;
  <a href="clients.cgi" style="color:#0065ff;text-decoration:none;">Clientes</a> &middot;
  <a href="reports.cgi" style="color:#0065ff;text-decoration:none;">Reportes</a> &middot;
  <a href="settings.cgi" style="color:#0065ff;text-decoration:none;">Configuraci&oacute;n</a>
</div>
};

&ui_print_footer('/', 'Index');
