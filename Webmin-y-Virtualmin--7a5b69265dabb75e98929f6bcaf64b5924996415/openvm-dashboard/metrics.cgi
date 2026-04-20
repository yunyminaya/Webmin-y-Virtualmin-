#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-dashboard-lib.pl';
&ReadParse();

# JSON endpoint for AJAX refresh - no HTML headers/footers
my $m = ovmd_system_metrics();

# Calculate overall disk percent
my $disk_total = 0;
my $disk_used  = 0;
for my $p (@{$m->{'partitions'}}) {
    $disk_total += $p->{'total'};
    $disk_used  += $p->{'used'};
}
my $disk_pct = $disk_total > 0 ? int(($disk_used / $disk_total) * 100) : 0;

# Bandwidth today (sum of all domains)
my $bw_data = ovmd_bandwidth_data('day');
my $bw_today = 0;
for my $b (@$bw_data) {
    $bw_today += $b->{'bandwidth'} || 0;
}

# Build JSON manually (no external JSON module required)
my $json = "{\n";
$json .= "  \"cpu_percent\": " . ($m->{'cpu_percent'} || 0) . ",\n";
$json .= "  \"memory_percent\": " . ($m->{'mem_percent'} || 0) . ",\n";
$json .= "  \"disk_percent\": $disk_pct,\n";
$json .= "  \"load_avg\": [" . ($m->{'load_1'} || 0) . ", " . ($m->{'load_5'} || 0) . ", " . ($m->{'load_15'} || 0) . "],\n";
$json .= "  \"uptime\": \"" . &html_escape($m->{'uptime_human'} || '') . "\",\n";
$json .= "  \"uptime_seconds\": " . ($m->{'uptime_seconds'} || 0) . ",\n";
$json .= "  \"hostname\": \"" . &html_escape($m->{'hostname'} || '') . "\",\n";
$json .= "  \"kernel\": \"" . &html_escape($m->{'kernel'} || '') . "\",\n";
$json .= "  \"cpu_cores\": " . ($m->{'cpu_cores'} || 1) . ",\n";
$json .= "  \"mem_total\": " . ($m->{'mem_total'} || 0) . ",\n";
$json .= "  \"mem_used\": " . ($m->{'mem_used'} || 0) . ",\n";
$json .= "  \"mem_free\": " . ($m->{'mem_free'} || 0) . ",\n";
$json .= "  \"mem_cached\": " . ($m->{'mem_cached'} || 0) . ",\n";
$json .= "  \"swap_total\": " . ($m->{'swap_total'} || 0) . ",\n";
$json .= "  \"swap_used\": " . ($m->{'swap_used'} || 0) . ",\n";
$json .= "  \"swap_percent\": " . ($m->{'swap_percent'} || 0) . ",\n";
$json .= "  \"bandwidth_today\": $bw_today,\n";
$json .= "  \"timestamp\": \"" . scalar(localtime()) . "\"\n";
$json .= "}\n";

# Output raw JSON with proper content type
print "Content-Type: application/json\r\n";
print "Cache-Control: no-cache, no-store\r\n";
print "\r\n";
print $json;
