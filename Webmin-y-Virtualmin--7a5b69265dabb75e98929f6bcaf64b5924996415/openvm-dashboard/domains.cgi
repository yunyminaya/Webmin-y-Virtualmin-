#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-dashboard-lib.pl';
&ReadParse();

my $cfg     = ovmd_init();
my $domains = ovmd_domain_summary();

# Filter parameters
my $filter_status = $in{'status'} || 'all';
my $search        = $in{'search'} || '';

# Apply filters
my @filtered = @$domains;

if ($filter_status eq 'active') {
    @filtered = grep { $_->{'status'} eq 'active' } @filtered;
} elsif ($filter_status eq 'disabled') {
    @filtered = grep { $_->{'status'} eq 'disabled' } @filtered;
}

if ($search ne '') {
    my $q = lc($search);
    @filtered = grep { lc($_->{'dom'}) =~ /\Q$q\E/ } @filtered;
}

# ---------------------------------------------------------------------------
# Inline CSS (same as index.cgi for consistency)
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
  .ovmd-header { background: linear-gradient(135deg, #1a237e, #0d47a1); color: #fff; padding: 16px 20px; border-radius: 6px; margin-bottom: 16px; }
  .ovmd-header h1 { margin: 0; font-size: 20px; }
  .ovmd-toolbar { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; margin-bottom: 16px; padding: 12px; background: #fff; border: 1px solid var(--ovmd-border); border-radius: 6px; }
  .ovmd-toolbar form { display: inline; margin: 0; }
  .ovmd-toolbar input[type="text"] { padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px; font-size: 13px; width: 220px; }
  .ovmd-toolbar select { padding: 6px 8px; border: 1px solid #ccc; border-radius: 4px; font-size: 13px; }
  .ovmd-toolbar button, .ovmd-toolbar input[type="submit"] { padding: 6px 14px; background: var(--ovmd-blue); color: #fff; border: none; border-radius: 4px; cursor: pointer; font-size: 13px; }
  .ovmd-toolbar button:hover, .ovmd-toolbar input[type="submit"]:hover { background: #1976D2; }
  .ovmd-section { background: #fff; border: 1px solid var(--ovmd-border); border-radius: 6px; padding: 14px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.06); }
  .ovmd-section h2 { margin: 0 0 12px 0; font-size: 16px; color: #333; border-bottom: 2px solid var(--ovmd-blue); padding-bottom: 6px; }
  .ovmd-table { width: 100%; border-collapse: collapse; font-size: 13px; }
  .ovmd-table th { background: #f0f0f0; text-align: left; padding: 8px 10px; border-bottom: 2px solid #ccc; font-weight: 600; white-space: nowrap; }
  .ovmd-table td { padding: 6px 10px; border-bottom: 1px solid #eee; }
  .ovmd-table tr:hover td { background: #f9f9f9; }
  .ovmd-badge { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; color: #fff; }
  .ovmd-badge-green  { background: var(--ovmd-green); }
  .ovmd-badge-red    { background: var(--ovmd-red); }
  .ovmd-badge-amber  { background: var(--ovmd-amber); }
  .ovmd-badge-blue   { background: var(--ovmd-blue); }
  .ovmd-count { font-size: 12px; color: #888; margin-left: 8px; }
  .ovmd-footer { text-align: center; font-size: 11px; color: #aaa; padding: 10px 0; margin-top: 10px; }
  .ovmd-link-btn { display: inline-block; padding: 3px 10px; background: #e3f2fd; color: var(--ovmd-blue); border-radius: 3px; text-decoration: none; font-size: 12px; }
  .ovmd-link-btn:hover { background: #bbdefb; }
  @media (max-width: 768px) {
    .ovmd-toolbar { flex-direction: column; align-items: stretch; }
    .ovmd-toolbar input[type="text"] { width: 100%; }
  }
</style>
ENDCSS

&ui_print_header(undef, 'Domain Management', '', 'domains');
print $css;
print "<div class=\"ovmd-wrap\">\n";

# --- Header ---
print "<div class=\"ovmd-header\">\n";
print "  <h1>&#127760; Domain Management</h1>\n";
print "</div>\n";

# --- Toolbar: Search & Filter ---
print "<div class=\"ovmd-toolbar\">\n";
print "  <form method=\"get\" action=\"domains.cgi\" style=\"display:flex;flex-wrap:wrap;gap:8px;align-items:center\">\n";
print "    <input type=\"text\" name=\"search\" placeholder=\"Search domain...\" value=\"" . &html_escape($search) . "\">\n";
print "    <select name=\"status\">\n";
print "      <option value=\"all\"" . ($filter_status eq 'all' ? ' selected' : '') . ">All</option>\n";
print "      <option value=\"active\"" . ($filter_status eq 'active' ? ' selected' : '') . ">Active</option>\n";
print "      <option value=\"disabled\"" . ($filter_status eq 'disabled' ? ' selected' : '') . ">Disabled</option>\n";
print "    </select>\n";
print "    <input type=\"submit\" value=\"Filter\">\n";
print "  </form>\n";
print "  <span class=\"ovmd-count\">Showing " . scalar(@filtered) . " of " . scalar(@$domains) . " domains</span>\n";
print "</div>\n";

# --- Domains Table ---
print "<div class=\"ovmd-section\">\n";
print "  <h2>Virtual Servers</h2>\n";

if (scalar(@filtered) == 0) {
    print "  <p style=\"color:#999;text-align:center;padding:20px\">No domains found matching your criteria.</p>\n";
} else {
    print "  <div style=\"overflow-x:auto\">\n";
    print "  <table class=\"ovmd-table\">\n";
    print "  <tr>\n";
    print "    <th>Domain</th>\n";
    print "    <th>User</th>\n";
    print "    <th>Web</th>\n";
    print "    <th>Mail</th>\n";
    print "    <th>SSL</th>\n";
    print "    <th>DNS</th>\n";
    print "    <th>Quota Used</th>\n";
    print "    <th>Bandwidth</th>\n";
    print "    <th>Status</th>\n";
    print "    <th>Action</th>\n";
    print "  </tr>\n";

    for my $d (@filtered) {
        my $status_badge = $d->{'status'} eq 'active'
            ? '<span class="ovmd-badge ovmd-badge-green">Active</span>'
            : '<span class="ovmd-badge ovmd-badge-red">Disabled</span>';

        my $web_icon  = $d->{'web'}  ? '<span style="color:#4CAF50">&#10003;</span>' : '<span style="color:#ccc">&#10007;</span>';
        my $mail_icon = $d->{'mail'} ? '<span style="color:#4CAF50">&#10003;</span>' : '<span style="color:#ccc">&#10007;</span>';
        my $ssl_icon  = $d->{'ssl'}  ? '<span style="color:#4CAF50">&#10003;</span>' : '<span style="color:#ccc">&#10007;</span>';
        my $dns_icon  = $d->{'dns'}  ? '<span style="color:#4CAF50">&#10003;</span>' : '<span style="color:#ccc">&#10007;</span>';

        # Quota display
        my $quota_display;
        if ($d->{'quota_total'} > 0) {
            my $q_pct = int(($d->{'quota_used'} / $d->{'quota_total'}) * 100);
            $quota_display = ovmd_human_size($d->{'quota_used'}) . " / " . ovmd_human_size($d->{'quota_total'}) . " ($q_pct%)";
        } else {
            $quota_display = $d->{'quota_used'} > 0 ? ovmd_human_size($d->{'quota_used'}) : '-';
        }

        # Bandwidth display
        my $bw_display;
        if ($d->{'bandwidth_total'} > 0) {
            my $bw_pct = int(($d->{'bandwidth_used'} / $d->{'bandwidth_total'}) * 100);
            $bw_display = ovmd_human_size($d->{'bandwidth_used'}) . " / " . ovmd_human_size($d->{'bandwidth_total'}) . " ($bw_pct%)";
        } else {
            $bw_display = $d->{'bandwidth_used'} > 0 ? ovmd_human_size($d->{'bandwidth_used'}) : '-';
        }

        # Edit link - try to link to virtual-server edit page
        my $edit_url = "../virtual-server/edit_domain.cgi?dom=" . &urlize($d->{'dom'});

        print "  <tr>\n";
        print "    <td><strong>" . &html_escape($d->{'dom'}) . "</strong></td>\n";
        print "    <td>" . &html_escape($d->{'user'}) . "</td>\n";
        print "    <td style=\"text-align:center\">$web_icon</td>\n";
        print "    <td style=\"text-align:center\">$mail_icon</td>\n";
        print "    <td style=\"text-align:center\">$ssl_icon</td>\n";
        print "    <td style=\"text-align:center\">$dns_icon</td>\n";
        print "    <td>$quota_display</td>\n";
        print "    <td>$bw_display</td>\n";
        print "    <td>$status_badge</td>\n";
        print "    <td><a href=\"$edit_url\" class=\"ovmd-link-btn\">Edit</a></td>\n";
        print "  </tr>\n";
    }

    print "  </table>\n";
    print "  </div>\n";
}

print "</div>\n";

# --- Back to Dashboard ---
print "<div style=\"text-align:center;margin-top:12px\">\n";
print "  <a href=\"index.cgi\" style=\"display:inline-block;padding:8px 20px;background:#1a237e;color:#fff;text-decoration:none;border-radius:4px;font-size:13px\">&larr; Back to Dashboard</a>\n";
print "</div>\n";

# --- Footer ---
print "<div class=\"ovmd-footer\">OpenVM Dashboard &bull; Domain Management &bull; Generated: " . scalar(localtime()) . "</div>\n";
print "</div>\n"; # close ovmd-wrap

&ui_print_footer('/', $text{'index_return'} || 'Return');
