#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-notifications-lib.pl';
&ReadParse();

ovmnt_init();

# Handle save
if ($in{'save'}) {
	my %cfg;
	$cfg{'notify_email'}   = $in{'notify_email'}   || '';
	$cfg{'notify_slack'}   = $in{'notify_slack'}    || 'no';
	$cfg{'slack_webhook'}  = $in{'slack_webhook'}   || '';
	$cfg{'notify_webhook'} = $in{'notify_webhook'}  || 'no';
	$cfg{'webhook_url'}    = $in{'webhook_url'}     || '';
	$cfg{'notify_browser'} = $in{'notify_browser'}  || 'no';
	$cfg{'digest_daily'}   = $in{'digest_daily'}    || 'no';
	$cfg{'digest_time'}    = $in{'digest_time'}     || '08:00';
	$cfg{'max_notifications'} = $in{'max_notifications'} || 1000;
	ovmnt_save_config(\%cfg);
	}

# Handle test
if ($in{'test_channel'}) {
	my $result = ovmnt_test_channel($in{'test_channel'});
	my $ch_name = $in{'test_channel'};
	if ($result) {
		print "Status: 302 Found\n";
		print "Location: channels.cgi?msg=Test+enviado+correctamente+por+$ch_name\n\n";
		exit(0);
		}
	else {
		print "Status: 302 Found\n";
		print "Location: channels.cgi?msg=Error+enviando+test+por+$ch_name\n\n";
		exit(0);
		}
	}

my $cfg = ovmnt_module_config();
my $msg = $in{'msg'} || '';

&ui_print_header(undef, 'OpenVM Notifications - Canales', '', 'channels');

if ($msg) {
	print qq{<div style="background:#deebff;color:#0747a6;padding:10px 16px;border-radius:4px;margin-bottom:16px;border:1px solid #4c9aff;">&html_escape($msg)</div>};
	}

print qq{<p>Configura los canales de notificación para recibir alertas del sistema.</p>};

# ── Form ──
print qq{<form method="post" action="channels.cgi">};

# ── Email Section ──
print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;margin-bottom:16px;overflow:hidden;">
  <div style="background:#f4f5f7;padding:12px 16px;border-bottom:1px solid #dfe1e6;font-weight:bold;font-size:14px;">
    Email
  </div>
  <div style="padding:16px;">
    <table style="width:100%;">
      <tr>
        <td style="padding:6px 10px;white-space:nowrap;"><label for="notify_email">Email de destino:</label></td>
        <td style="padding:6px 10px;width:100%;"><input type="text" name="notify_email" id="notify_email" value="} . &html_escape($cfg->{'notify_email'}) . qq{" style="width:100%;max-width:400px;padding:6px 8px;border:1px solid #dfe1e6;border-radius:3px;"></td>
      </tr>
      <tr>
        <td style="padding:6px 10px;"><label>Habilitar:</label></td>
        <td style="padding:6px 10px;">
          <select name="notify_slack_email" style="padding:4px;">
            <option value="yes">Sí</option>
            <option value="no">No</option>
          </select>
        </td>
      </tr>
    </table>
    <a href="channels.cgi?test_channel=email" style="text-decoration:none;background:#0065ff;color:#fff;padding:5px 12px;border-radius:3px;font-size:12px;">Enviar prueba</a>
  </div>
</div>
};

# ── Slack Section ──
print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;margin-bottom:16px;overflow:hidden;">
  <div style="background:#f4f5f7;padding:12px 16px;border-bottom:1px solid #dfe1e6;font-weight:bold;font-size:14px;">
    Slack
  </div>
  <div style="padding:16px;">
    <table style="width:100%;">
      <tr>
        <td style="padding:6px 10px;white-space:nowrap;"><label for="slack_webhook">Webhook URL:</label></td>
        <td style="padding:6px 10px;width:100%;"><input type="text" name="slack_webhook" id="slack_webhook" value="} . &html_escape($cfg->{'slack_webhook'}) . qq{" style="width:100%;max-width:500px;padding:6px 8px;border:1px solid #dfe1e6;border-radius:3px;" placeholder="https://hooks.slack.com/services/..."></td>
      </tr>
      <tr>
        <td style="padding:6px 10px;"><label>Habilitar:</label></td>
        <td style="padding:6px 10px;">
          <select name="notify_slack" style="padding:4px;">
            <option value="yes"} . ($cfg->{'notify_slack'} eq 'yes' ? ' selected' : '') . qq{>Sí</option>
            <option value="no"} . ($cfg->{'notify_slack'} ne 'yes' ? ' selected' : '') . qq{>No</option>
          </select>
        </td>
      </tr>
    </table>
    <a href="channels.cgi?test_channel=slack" style="text-decoration:none;background:#0065ff;color:#fff;padding:5px 12px;border-radius:3px;font-size:12px;">Enviar prueba</a>
  </div>
</div>
};

# ── Webhook Section ──
print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;margin-bottom:16px;overflow:hidden;">
  <div style="background:#f4f5f7;padding:12px 16px;border-bottom:1px solid #dfe1e6;font-weight:bold;font-size:14px;">
    Webhook genérico
  </div>
  <div style="padding:16px;">
    <table style="width:100%;">
      <tr>
        <td style="padding:6px 10px;white-space:nowrap;"><label for="webhook_url">URL:</label></td>
        <td style="padding:6px 10px;width:100%;"><input type="text" name="webhook_url" id="webhook_url" value="} . &html_escape($cfg->{'webhook_url'}) . qq{" style="width:100%;max-width:500px;padding:6px 8px;border:1px solid #dfe1e6;border-radius:3px;" placeholder="https://example.com/webhook"></td>
      </tr>
      <tr>
        <td style="padding:6px 10px;"><label>Habilitar:</label></td>
        <td style="padding:6px 10px;">
          <select name="notify_webhook" style="padding:4px;">
            <option value="yes"} . ($cfg->{'notify_webhook'} eq 'yes' ? ' selected' : '') . qq{>Sí</option>
            <option value="no"} . ($cfg->{'notify_webhook'} ne 'yes' ? ' selected' : '') . qq{>No</option>
          </select>
        </td>
      </tr>
    </table>
    <a href="channels.cgi?test_channel=webhook" style="text-decoration:none;background:#0065ff;color:#fff;padding:5px 12px;border-radius:3px;font-size:12px;">Enviar prueba</a>
  </div>
</div>
};

# ── Browser Section ──
print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;margin-bottom:16px;overflow:hidden;">
  <div style="background:#f4f5f7;padding:12px 16px;border-bottom:1px solid #dfe1e6;font-weight:bold;font-size:14px;">
    Notificaciones del navegador
  </div>
  <div style="padding:16px;">
    <label>
      <input type="checkbox" name="notify_browser" value="yes"} . ($cfg->{'notify_browser'} eq 'yes' ? ' checked' : '') . qq{>
      Mostrar notificaciones en el navegador
    </label>
  </div>
</div>
};

# ── Digest Section ──
print qq{
<div style="background:#fff;border:1px solid #dfe1e6;border-radius:6px;margin-bottom:16px;overflow:hidden;">
  <div style="background:#f4f5f7;padding:12px 16px;border-bottom:1px solid #dfe1e6;font-weight:bold;font-size:14px;">
    Digest diario
  </div>
  <div style="padding:16px;">
    <table>
      <tr>
        <td style="padding:6px 10px;">
          <label>
            <input type="checkbox" name="digest_daily" value="yes"} . ($cfg->{'digest_daily'} eq 'yes' ? ' checked' : '') . qq{>
            Enviar digest diario
          </label>
        </td>
      </tr>
      <tr>
        <td style="padding:6px 10px;">
          <label for="digest_time">Hora del digest:</label>
          <input type="time" name="digest_time" id="digest_time" value="} . &html_escape($cfg->{'digest_time'}) . qq{" style="padding:4px 8px;border:1px solid #dfe1e6;border-radius:3px;">
        </td>
      </tr>
      <tr>
        <td style="padding:6px 10px;">
          <label for="max_notifications">Máximo de notificaciones almacenadas:</label>
          <input type="number" name="max_notifications" id="max_notifications" value="} . &html_escape($cfg->{'max_notifications'}) . qq{" min="100" max="10000" style="padding:4px 8px;border:1px solid #dfe1e6;border-radius:3px;width:100px;">
        </td>
      </tr>
    </table>
  </div>
</div>
};

# ── Save button ──
print qq{
<div style="margin-top:16px;">
  <input type="hidden" name="save" value="1">
  <button type="submit" style="background:#0065ff;color:#fff;border:none;padding:10px 24px;border-radius:4px;font-size:14px;font-weight:bold;cursor:pointer;">Guardar configuración</button>
</div>
};

print qq{</form>};

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
