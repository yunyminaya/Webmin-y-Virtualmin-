#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-billing-lib.pl';
&ReadParse();

ovmbl_init();

# Handle save
if ($in{'save_settings'}) {
	$ovmbl_config{'company_name'}      = $in{'company_name'} || '';
	$ovmbl_config{'company_address'}   = $in{'company_address'} || '';
	$ovmbl_config{'billing_email'}     = $in{'billing_email'} || '';
	$ovmbl_config{'currency'}          = $in{'currency'} || 'USD';
	$ovmbl_config{'currency_symbol'}   = $in{'currency_symbol'} || '$';
	$ovmbl_config{'tax_enabled'}       = $in{'tax_enabled'} ? 'yes' : 'no';
	$ovmbl_config{'tax_rate'}          = $in{'tax_rate'} || 0;
	$ovmbl_config{'invoice_prefix'}    = $in{'invoice_prefix'} || 'INV-';
	$ovmbl_config{'invoice_start'}     = $in{'invoice_start'} || 1000;
	$ovmbl_config{'payment_terms'}     = $in{'payment_terms'} || 30;
	$ovmbl_config{'late_fee_percent'}  = $in{'late_fee_percent'} || 5;
	$ovmbl_config{'auto_suspend'}      = $in{'auto_suspend'} ? 'yes' : 'no';
	$ovmbl_config{'suspend_after_days'} = $in{'suspend_after_days'} || 30;
	ovmbl_save_config();
	}

&ui_print_header(undef, 'OpenVM Billing &mdash; Settings', '', 'settings');

# ── Action buttons ──
print qq{<div style="margin-bottom:15px;display:flex;flex-wrap:wrap;gap:8px;">};
print qq{<a href="index.cgi" style="text-decoration:none;background:#6b778c;color:#fff;padding:7px 16px;border-radius:4px;font-size:12px;">Dashboard</a>};
print qq{</div>};

print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;padding:16px;margin-bottom:15px;">
<form method="post" action="settings.cgi">
<input type="hidden" name="save_settings" value="1">
};

# ── Section: Company ──
print qq{
<div style="font-size:15px;font-weight:bold;color:#172b4d;margin-bottom:12px;padding-bottom:6px;border-bottom:2px solid #0065ff;">Empresa</div>
<div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:16px;">
  <div style="flex:1;min-width:250px;">
    <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Nombre de Empresa</label>
    <input type="text" name="company_name" value="} . &html_escape($ovmbl_config{'company_name'} || '') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
  </div>
  <div style="flex:1;min-width:250px;">
    <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Email de Facturaci&oacute;n</label>
    <input type="email" name="billing_email" value="} . &html_escape($ovmbl_config{'billing_email'} || '') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
  </div>
</div>
<div style="margin-bottom:16px;">
  <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Direcci&oacute;n</label>
  <textarea name="company_address" rows="2" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">} . &html_escape($ovmbl_config{'company_address'} || '') . qq{</textarea>
</div>
};

# ── Section: Currency ──
print qq{
<div style="font-size:15px;font-weight:bold;color:#172b4d;margin-bottom:12px;padding-bottom:6px;border-bottom:2px solid #36b37e;">Moneda</div>
<div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:16px;">
  <div style="flex:1;min-width:200px;">
    <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Moneda</label>
    <select name="currency" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
};

my @currencies = (
	['USD', 'USD - D&oacute;lar Americano'],
	['EUR', 'EUR - Euro'],
	['GBP', 'GBP - Libra Esterlina'],
	['CAD', 'CAD - D&oacute;lar Canadiense'],
	['AUD', 'AUD - D&oacute;lar Australiano'],
	['MXN', 'MXN - Peso Mexicano'],
	['COP', 'COP - Peso Colombiano'],
	['ARS', 'ARS - Peso Argentino'],
	['CLP', 'CLP - Peso Chileno'],
	['PEN', 'PEN - Sol Peruano'],
	['BRL', 'BRL - Real Brasile&ntilde;o'],
	['JPY', 'JPY - Yen Japon&eacute;s'],
	);
foreach my $c (@currencies) {
	my $sel = ($ovmbl_config{'currency'} || 'USD') eq $c->[0] ? 'selected' : '';
	print qq{<option value="$c->[0]" $sel>$c->[1]</option>};
	}
print qq{
    </select>
  </div>
  <div style="flex:1;min-width:120px;">
    <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">S&iacute;mbolo</label>
    <input type="text" name="currency_symbol" value="} . &html_escape($ovmbl_config{'currency_symbol'} || '$') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
  </div>
</div>
};

# ── Section: Taxes ──
print qq{
<div style="font-size:15px;font-weight:bold;color:#172b4d;margin-bottom:12px;padding-bottom:6px;border-bottom:2px solid #ff991f;">Impuestos</div>
<div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:16px;align-items:center;">
  <div style="min-width:200px;">
    <label style="display:flex;align-items:center;gap:6px;font-size:13px;cursor:pointer;">
      <input type="checkbox" name="tax_enabled" value="yes" } . ($ovmbl_config{'tax_enabled'} eq 'yes' ? 'checked' : '') . qq{>
      Habilitar Impuestos
    </label>
  </div>
  <div style="flex:1;min-width:120px;">
    <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Tasa de Impuesto (%)</label>
    <input type="number" name="tax_rate" step="0.01" min="0" max="100" value="} . ($ovmbl_config{'tax_rate'} || 0) . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
  </div>
</div>
};

# ── Section: Invoicing ──
print qq{
<div style="font-size:15px;font-weight:bold;color:#172b4d;margin-bottom:12px;padding-bottom:6px;border-bottom:2px solid #6554c0;">Facturaci&oacute;n</div>
<div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:16px;">
  <div style="flex:1;min-width:150px;">
    <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Prefijo de Factura</label>
    <input type="text" name="invoice_prefix" value="} . &html_escape($ovmbl_config{'invoice_prefix'} || 'INV-') . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
  </div>
  <div style="flex:1;min-width:120px;">
    <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">N&uacute;mero Inicial</label>
    <input type="number" name="invoice_start" min="1" value="} . ($ovmbl_config{'invoice_start'} || 1000) . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
  </div>
  <div style="flex:1;min-width:120px;">
    <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">T&eacute;rminos de Pago (d&iacute;as)</label>
    <input type="number" name="payment_terms" min="1" value="} . ($ovmbl_config{'payment_terms'} || 30) . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
  </div>
  <div style="flex:1;min-width:120px;">
    <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">Recargo por Mora (%)</label>
    <input type="number" name="late_fee_percent" step="0.1" min="0" max="100" value="} . ($ovmbl_config{'late_fee_percent'} || 5) . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
  </div>
</div>
};

# ── Section: Auto-suspension ──
print qq{
<div style="font-size:15px;font-weight:bold;color:#172b4d;margin-bottom:12px;padding-bottom:6px;border-bottom:2px solid #de350b;">Suspensi&oacute;n Autom&aacute;tica</div>
<div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:16px;align-items:center;">
  <div style="min-width:200px;">
    <label style="display:flex;align-items:center;gap:6px;font-size:13px;cursor:pointer;">
      <input type="checkbox" name="auto_suspend" value="yes" } . ($ovmbl_config{'auto_suspend'} eq 'yes' ? 'checked' : '') . qq{>
      Habilitar Auto-Suspensi&oacute;n
    </label>
  </div>
  <div style="flex:1;min-width:150px;">
    <label style="display:block;font-size:12px;color:#6b778c;margin-bottom:4px;">D&iacute;as antes de suspender</label>
    <input type="number" name="suspend_after_days" min="1" value="} . ($ovmbl_config{'suspend_after_days'} || 30) . qq{" style="width:100%;padding:6px 10px;border:1px solid #dfe1e6;border-radius:4px;font-size:13px;">
  </div>
</div>
<div style="font-size:12px;color:#6b778c;margin-bottom:16px;padding:8px 12px;background:#fff3cd;border-radius:4px;">
  &#9888; Cuando se habilita, las cuentas con facturas vencidas que excedan los d&iacute;as configurados ser&aacute;n marcadas para suspensi&oacute;n autom&aacute;tica.
</div>
};

# ── Save button ──
print qq{
<div style="margin-top:16px;padding-top:12px;border-top:1px solid #dfe1e6;">
  <button type="submit" style="background:#0065ff;color:#fff;border:none;padding:10px 24px;border-radius:4px;font-size:14px;font-weight:bold;cursor:pointer;">Guardar Configuraci&oacute;n</button>
  <a href="index.cgi" style="margin-left:12px;color:#6b778c;text-decoration:none;font-size:13px;">Cancelar</a>
</div>
};

print qq{</form></div>};

# ── Footer ──
print qq{
<div style="text-align:center;padding:10px;color:#6b778c;font-size:12px;margin-top:15px;">
  <a href="index.cgi" style="color:#0065ff;text-decoration:none;">Dashboard</a> &middot;
  <a href="plans.cgi" style="color:#0065ff;text-decoration:none;">Planes</a> &middot;
  <a href="invoices.cgi" style="color:#0065ff;text-decoration:none;">Facturas</a> &middot;
  <a href="clients.cgi" style="color:#0065ff;text-decoration:none;">Clientes</a> &middot;
  <a href="reports.cgi" style="color:#0065ff;text-decoration:none;">Reportes</a>
</div>
};

&ui_print_footer('/', 'Index');
