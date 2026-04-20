#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-dashboard-lib.pl';
&ReadParse();

my $cfg = ovmd_init();
my $m   = ovmd_system_metrics();
my $stats    = ovmd_quick_stats();
my $domains  = ovmd_domain_summary();
my $services = ovmd_service_status();
my $events   = ovmd_recent_events(15);

my $refresh = $cfg->{'refresh_interval'} || 30;

# ---------------------------------------------------------------------------
# Inline CSS
# ---------------------------------------------------------------------------
my $css = <<'ENDCSS';
<style>
  :root {
    --ovmd-green:  #4CAF50;
    --ovmd-amber:  #FF9800;
    --ovmd-red:    #F44336;
    --ovmd-blue:   #2196F3;
    --ovmd-gray:   #607D8B;
    --ovmd-dark:   #333;
    --ovmd-light:  #f5f5f5;
    --ovmd-border: #ddd;
  }
  .ovmd-wrap { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 0; padding: 0; }
  .ovmd-header { background: linear-gradient(135deg, #1a237e, #0d47a1); color: #fff; padding: 16px 20px; border-radius: 6px; margin-bottom: 16px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; }
  .ovmd-header h1 { margin: 0; font-size: 20px; }
  .ovmd-header-info { font-size: 13px; opacity: 0.9; text-align: right; }

  .ovmd-cards { display: flex; flex-wrap: wrap; gap: 12px; margin-bottom: 20px; }
  .ovmd-card { flex: 1 1 200px; background: #fff; border: 1px solid var(--ovmd-border); border-radius: 6px; padding: 14px; min-width: 180px; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
  .ovmd-card-title { font-size: 12px; text-transform: uppercase; color: #888; margin-bottom: 6px; letter-spacing: 0.5px; }
  .ovmd-card-value { font-size: 28px; font-weight: 700; margin-bottom: 4px; }
  .ovmd-card-sub { font-size: 11px; color: #999; }

  .ovmd-bar-wrap { background: #e0e0e0; border-radius: 4px; height: 18px; overflow: hidden; margin-top: 6px; position: relative; }
  .ovmd-bar-fill { height: 100%; border-radius: 4px; transition: width 0.4s ease; }
  .ovmd-bar-label { position: absolute; right: 6px; top: 1px; font-size: 11px; font-weight: 600; color: #fff; text-shadow: 0 1px 1px rgba(0,0,0,0.3); }

  .ovmd-section { background: #fff; border: 1px solid var(--ovmd-border); border-radius: 6px; padding: 14px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.06); }
  .ovmd-section h2 { margin: 0 0 12px 0; font-size: 16px; color: #333; border-bottom: 2px solid var(--ovmd-blue); padding-bottom: 6px; }

  .ovmd-table { width: 100%; border-collapse: collapse; font-size: 13px; }
  .ovmd-table th { background: #f0f0f0; text-align: left; padding: 8px 10px; border-bottom: 2px solid #ccc; font-weight: 600; }
  .ovmd-table td { padding: 6px 10px; border-bottom: 1px solid #eee; }
  .ovmd-table tr:hover td { background: #f9f9f9; }

  .ovmd-badge { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; color: #fff; }
  .ovmd-badge-green  { background: var(--ovmd-green); }
  .ovmd-badge-red    { background: var(--ovmd-red); }
  .ovmd-badge-amber  { background: var(--ovmd-amber); }
  .ovmd-badge-blue   { background: var(--ovmd-blue); }
  .ovmd-badge-gray   { background: var(--ovmd-gray); }

  .ovmd-dot { display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin-right: 6px; vertical-align: middle; }
  .ovmd-dot-green { background: var(--ovmd-green); box-shadow: 0 0 4px var(--ovmd-green); }
  .ovmd-dot-red   { background: var(--ovmd-red);   box-shadow: 0 0 4px var(--ovmd-red); }

  .ovmd-graph-row { display: flex; align-items: center; margin-bottom: 6px; }
  .ovmd-graph-label { width: 120px; font-size: 12px; color: #555; flex-shrink: 0; }
  .ovmd-graph-bar { flex: 1; background: #e0e0e0; border-radius: 3px; height: 14px; overflow: hidden; }
  .ovmd-graph-fill { height: 100%; border-radius: 3px; }
  .ovmd-graph-pct { width: 40px; font-size: 11px; text-align: right; color: #777; flex-shrink: 0; }

  .ovmd-event-item { padding: 5px 0; border-bottom: 1px solid #f0f0f0; font-size: 12px; }
  .ovmd-event-time { color: #999; font-family: monospace; margin-right: 8px; }
  .ovmd-event-user { color: var(--ovmd-blue); font-weight: 600; margin-right: 8px; }
  .ovmd-event-action { color: #333; }

  .ovmd-footer { text-align: center; font-size: 11px; color: #aaa; padding: 10px 0; margin-top: 10px; }

  @media (max-width: 768px) {
    .ovmd-cards { flex-direction: column; }
    .ovmd-header { flex-direction: column; text-align: center; }
    .ovmd-header-info { text-align: center; margin-top: 8px; }
  }
</style>
ENDCSS

# ---------------------------------------------------------------------------
# Begin page output
# ---------------------------------------------------------------------------
print "<meta http-equiv=\"refresh\" content=\"$refresh\">\n";
&ui_print_header(undef, 'OpenVM Dashboard', '', 'index');
print $css;
print "<div class=\"ovmd-wrap\">\n";

# --- Header ---
print "<div class=\"ovmd-header\">\n";
print "  <h1>&#9776; OpenVM Dashboard</h1>\n";
print "  <div class=\"ovmd-header-info\">\n";
print "    <strong>" . &html_escape($m->{'hostname'}) . "</strong><br>\n";
print "    Kernel: " . &html_escape($m->{'kernel'}) . " &bull; Uptime: " . &html_escape($m->{'uptime_human'}) . "\n";
print "  </div>\n";
print "</div>\n";

# --- Metric Cards ---
my $cpu_color = ovmd_status_color($m->{'cpu_percent'});
my $mem_color = ovmd_status_color($m->{'mem_percent'});

# Calculate overall disk percent (use first partition or average)
my $disk_pct = 0;
my $disk_total = 0;
my $disk_used = 0;
for my $p (@{$m->{'partitions'}}) {
    $disk_total += $p->{'total'};
    $disk_used  += $p->{'used'};
}
$disk_pct = $disk_total > 0 ? int(($disk_used / $disk_total) * 100) : 0;
my $disk_color = ovmd_status_color($disk_pct);

my $dom_color = $stats->{'disabled_domains'} > 0 ? '#FF9800' : '#4CAF50';

print "<div class=\"ovmd-cards\">\n";

# CPU Card
print "<div class=\"ovmd-card\">\n";
print "  <div class=\"ovmd-card-title\">CPU Usage</div>\n";
print "  <div class=\"ovmd-card-value\" style=\"color:$cpu_color\">" . $m->{'cpu_percent'} . "%</div>\n";
print "  <div class=\"ovmd-card-sub\">Load: " . $m->{'load_1'} . " / " . $m->{'load_5'} . " / " . $m->{'load_15'} . " (" . $m->{'cpu_cores'} . " cores)</div>\n";
print "  <div class=\"ovmd-bar-wrap\"><div class=\"ovmd-bar-fill\" style=\"width:" . $m->{'cpu_percent'} . "%;background:$cpu_color\"></div><span class=\"ovmd-bar-label\">" . $m->{'cpu_percent'} . "%</span></div>\n";
print "</div>\n";

# Memory Card
print "<div class=\"ovmd-card\">\n";
print "  <div class=\"ovmd-card-title\">Memory</div>\n";
print "  <div class=\"ovmd-card-value\" style=\"color:$mem_color\">" . $m->{'mem_percent'} . "%</div>\n";
print "  <div class=\"ovmd-card-sub\">Used: " . ovmd_human_size($m->{'mem_used'} * 1024) . " / " . ovmd_human_size($m->{'mem_total'} * 1024) . "</div>\n";
print "  <div class=\"ovmd-bar-wrap\"><div class=\"ovmd-bar-fill\" style=\"width:" . $m->{'mem_percent'} . "%;background:$mem_color\"></div><span class=\"ovmd-bar-label\">" . $m->{'mem_percent'} . "%</span></div>\n";
print "</div>\n";

# Disk Card
print "<div class=\"ovmd-card\">\n";
print "  <div class=\"ovmd-card-title\">Disk</div>\n";
print "  <div class=\"ovmd-card-value\" style=\"color:$disk_color\">" . $disk_pct . "%</div>\n";
print "  <div class=\"ovmd-card-sub\">Used: " . ovmd_human_size($disk_used * 1024) . " / " . ovmd_human_size($disk_total * 1024) . "</div>\n";
print "  <div class=\"ovmd-bar-wrap\"><div class=\"ovmd-bar-fill\" style=\"width:$disk_pct%;background:$disk_color\"></div><span class=\"ovmd-bar-label\">$disk_pct%</span></div>\n";
print "</div>\n";

# Domains Card
print "<div class=\"ovmd-card\">\n";
print "  <div class=\"ovmd-card-title\">Domains</div>\n";
print "  <div class=\"ovmd-card-value\" style=\"color:$dom_color\">" . $stats->{'total_domains'} . "</div>\n";
print "  <div class=\"ovmd-card-sub\">" . $stats->{'active_domains'} . " active &bull; " . $stats->{'disabled_domains'} . " disabled</div>\n";
print "  <div style=\"margin-top:4px\"><span class=\"ovmd-badge ovmd-badge-blue\">" . $stats->{'total_users'} . " users</span> <span class=\"ovmd-badge ovmd-badge-gray\">" . $stats->{'total_databases'} . " DBs</span></div>\n";
print "</div>\n";

print "</div>\n"; # close ovmd-cards

# --- CPU Graph (CSS bars for load average) ---
if ($cfg->{'show_cpu_graph'}) {
    print "<div class=\"ovmd-section\">\n";
    print "  <h2>CPU Load Average</h2>\n";
    my $max_load = $m->{'cpu_cores'} * 2;
    for my $label ('1 min', '5 min', '15 min') {
        my $val = $label eq '1 min'  ? $m->{'load_1'}  :
                  $label eq '5 min'  ? $m->{'load_5'}  : $m->{'load_15'};
        my $pct = $max_load > 0 ? int(($val / $max_load) * 100) : 0;
        $pct = 100 if $pct > 100;
        my $c = ovmd_status_color($pct);
        print "  <div class=\"ovmd-graph-row\">\n";
        print "    <div class=\"ovmd-graph-label\">$label</div>\n";
        print "    <div class=\"ovmd-graph-bar\"><div class=\"ovmd-graph-fill\" style=\"width:$pct%;background:$c\"></div></div>\n";
        print "    <div class=\"ovmd-graph-pct\">$val</div>\n";
        print "  </div>\n";
    }
    print "</div>\n";
}

# --- Memory Graph ---
if ($cfg->{'show_memory_graph'}) {
    print "<div class=\"ovmd-section\">\n";
    print "  <h2>Memory Distribution</h2>\n";
    my $mt = $m->{'mem_total'} || 1;
    my $used_pct  = int(($m->{'mem_used'} / $mt) * 100);
    my $cache_pct = int(($m->{'mem_cached'} / $mt) * 100);
    my $free_pct  = 100 - $used_pct - $cache_pct;
    $free_pct = 0 if $free_pct < 0;

    print "  <div class=\"ovmd-graph-row\">\n";
    print "    <div class=\"ovmd-graph-label\">Used</div>\n";
    print "    <div class=\"ovmd-graph-bar\"><div class=\"ovmd-graph-fill\" style=\"width:$used_pct%;background:#F44336\"></div></div>\n";
    print "    <div class=\"ovmd-graph-pct\">$used_pct%</div>\n";
    print "  </div>\n";
    print "  <div class=\"ovmd-graph-row\">\n";
    print "    <div class=\"ovmd-graph-label\">Cached/Buffers</div>\n";
    print "    <div class=\"ovmd-graph-bar\"><div class=\"ovmd-graph-fill\" style=\"width:$cache_pct%;background:#2196F3\"></div></div>\n";
    print "    <div class=\"ovmd-graph-pct\">$cache_pct%</div>\n";
    print "  </div>\n";
    print "  <div class=\"ovmd-graph-row\">\n";
    print "    <div class=\"ovmd-graph-label\">Free</div>\n";
    print "    <div class=\"ovmd-graph-bar\"><div class=\"ovmd-graph-fill\" style=\"width:$free_pct%;background:#4CAF50\"></div></div>\n";
    print "    <div class=\"ovmd-graph-pct\">$free_pct%</div>\n";
    print "  </div>\n";

    # Swap
    if ($m->{'swap_total'} > 0) {
        my $sw_pct = $m->{'swap_percent'};
        my $sw_c   = ovmd_status_color($sw_pct);
        print "  <div class=\"ovmd-graph-row\" style=\"margin-top:8px\">\n";
        print "    <div class=\"ovmd-graph-label\">Swap</div>\n";
        print "    <div class=\"ovmd-graph-bar\"><div class=\"ovmd-graph-fill\" style=\"width:$sw_pct%;background:$sw_c\"></div></div>\n";
        print "    <div class=\"ovmd-graph-pct\">$sw_pct%</div>\n";
        print "  </div>\n";
    }
    print "</div>\n";
}

# --- Disk Graph per partition ---
if ($cfg->{'show_disk_graph'}) {
    print "<div class=\"ovmd-section\">\n";
    print "  <h2>Disk Usage by Partition</h2>\n";
    for my $p (@{$m->{'partitions'}}) {
        my $dp = $p->{'percent'};
        my $dc = ovmd_status_color($dp);
        my $used_h  = ovmd_human_size($p->{'used'} * 1024);
        my $total_h = ovmd_human_size($p->{'total'} * 1024);
        print "  <div class=\"ovmd-graph-row\">\n";
        print "    <div class=\"ovmd-graph-label\" title=\"" . &html_escape($p->{'mount'}) . "\">" . &html_escape($p->{'mount'}) . "</div>\n";
        print "    <div class=\"ovmd-graph-bar\"><div class=\"ovmd-graph-fill\" style=\"width:$dp%;background:$dc\"></div></div>\n";
        print "    <div class=\"ovmd-graph-pct\" title=\"$used_h / $total_h\">$dp%</div>\n";
        print "  </div>\n";
    }
    print "</div>\n";
}

# --- Domains Table ---
if ($cfg->{'show_domain_list'} && scalar(@$domains) > 0) {
    my $max = $cfg->{'max_domains_display'} || 20;
    my @show = @$domains;
    @show = @show[0 .. ($max - 1)] if scalar(@show) > $max;

    print "<div class=\"ovmd-section\">\n";
    print "  <h2>Domains Overview <span style=\"font-size:12px;color:#999\">(" . scalar(@$domains) . " total" . ($max < scalar(@$domains) ? ", showing $max" : "") . ")</span></h2>\n";
    print "  <table class=\"ovmd-table\">\n";
    print "  <tr><th>Domain</th><th>User</th><th>Web</th><th>Mail</th><th>SSL</th><th>DNS</th><th>Status</th></tr>\n";
    for my $d (@show) {
        my $status_badge = $d->{'status'} eq 'active'
            ? '<span class="ovmd-badge ovmd-badge-green">Active</span>'
            : '<span class="ovmd-badge ovmd-badge-red">Disabled</span>';
        my $web_icon = $d->{'web'} ? '&#10003;' : '&#10007;';
        my $mail_icon = $d->{'mail'} ? '&#10003;' : '&#10007;';
        my $ssl_icon  = $d->{'ssl'} ? '&#10003;' : '&#10007;';
        my $dns_icon  = $d->{'dns'} ? '&#10003;' : '&#10007;';
        print "<tr>";
        print "<td><a href=\"domains.cgi?dom=" . &urlize($d->{'dom'}) . "\">" . &html_escape($d->{'dom'}) . "</a></td>";
        print "<td>" . &html_escape($d->{'user'}) . "</td>";
        print "<td>$web_icon</td><td>$mail_icon</td><td>$ssl_icon</td><td>$dns_icon</td>";
        print "<td>$status_badge</td>";
        print "</tr>\n";
    }
    print "  </table>\n";
    if (scalar(@$domains) > $max) {
        print "  <p style=\"text-align:center;margin-top:8px\"><a href=\"domains.cgi\">View all " . scalar(@$domains) . " domains &rarr;</a></p>\n";
    }
    print "</div>\n";
}

# --- Services Table ---
print "<div class=\"ovmd-section\">\n";
print "  <h2>Service Status</h2>\n";
print "  <table class=\"ovmd-table\">\n";
print "  <tr><th>Service</th><th>Status</th><th>Port</th></tr>\n";
for my $s (@$services) {
    my $dot   = $s->{'status'} eq 'running' ? 'ovmd-dot-green' : 'ovmd-dot-red';
    my $badge = $s->{'status'} eq 'running'
        ? '<span class="ovmd-badge ovmd-badge-green">Running</span>'
        : '<span class="ovmd-badge ovmd-badge-red">Stopped</span>';
    my $port = $s->{'port'} ? $s->{'port'} : '-';
    print "<tr><td><span class=\"ovmd-dot $dot\"></span>" . &html_escape($s->{'name'}) . "</td><td>$badge</td><td>$port</td></tr>\n";
}
print "  </table>\n";
print "</div>\n";

# --- Recent Events ---
if (scalar(@$events) > 0) {
    print "<div class=\"ovmd-section\">\n";
    print "  <h2>Recent Events</h2>\n";
    for my $e (@$events) {
        print "<div class=\"ovmd-event-item\">\n";
        print "  <span class=\"ovmd-event-time\">" . &html_escape($e->{'time'}) . "</span>\n";
        print "  <span class=\"ovmd-event-user\">" . &html_escape($e->{'user'}) . "</span>\n";
        print "  <span class=\"ovmd-event-action\">" . &html_escape($e->{'action'}) . " " . &html_escape($e->{'object'}) . "</span>\n";
        if ($e->{'detail'}) {
            print "  <span style=\"color:#aaa;font-size:11px\"> - " . &html_escape($e->{'detail'}) . "</span>\n";
        }
        print "</div>\n";
    }
    print "</div>\n";
}

# --- Quick Actions ---
print "<div class=\"ovmd-section\">\n";
print "  <h2>Quick Actions</h2>\n";
print &ui_buttons_start();
print &ui_buttons_row('domains.cgi', 'Manage Domains', 'View and manage all virtual server domains.');
print &ui_buttons_row('metrics.cgi', 'JSON Metrics', 'Raw system metrics in JSON format for external monitoring.');
print &ui_buttons_end();
print "</div>\n";

# --- Footer ---
print "<div class=\"ovmd-footer\">OpenVM Dashboard &bull; Auto-refresh: ${refresh}s &bull; Generated: " . scalar(localtime()) . "</div>\n";

print "</div>\n"; # close ovmd-wrap

&ui_print_footer('/', $text{'index_return'} || 'Return');
