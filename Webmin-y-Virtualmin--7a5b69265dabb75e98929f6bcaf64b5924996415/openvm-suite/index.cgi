#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-suite-lib.pl';
&ReadParse();

my $grouped = ovms_grouped_catalog();
my $order   = ovms_category_order();
my $total   = ovms_count_modules();

&ui_print_header(undef, 'OpenVM Unified Suite', '', 'index');

# ── Dashboard Header ──────────────────────────────────────────────
print qq{<div style="margin-bottom:15px;padding:15px;background:linear-gradient(135deg,#1a237e 0%,#0d47a1 50%,#01579b 100%);border-radius:8px;color:#fff">};
print qq{<div style="display:flex;justify-content:space-between;align-items:center">};
print qq{<div>};
print qq{<h2 style="margin:0 0 5px 0;color:#fff;font-size:22px">📦 OpenVM Professional Suite</h2>};
print qq{<p style="margin:0;opacity:0.9;font-size:14px">Unified panel for all OpenVM modules — Webmin/Virtualmin open-source ecosystem</p>};
print qq{</div>};
print qq{<div style="text-align:right">};
print qq{<div style="font-size:32px;font-weight:bold">$total</div>};
print qq{<div style="font-size:12px;opacity:0.8">Active Modules</div>};
print qq{</div>};
print qq{</div>};
print qq{</div>\n};

# ── Quick Stats ───────────────────────────────────────────────────
my %cat_counts;
foreach my $cat (keys %$grouped) {
	$cat_counts{$cat} = scalar(@{$grouped->{$cat}});
	}
print qq{<div style="display:flex;flex-wrap:wrap;gap:10px;margin-bottom:20px">};
foreach my $cat (@$order) {
	next unless exists($grouped->{$cat});
	my $icon  = ovms_category_icon($cat);
	my $count = $cat_counts{$cat} || 0;
	print qq{<div style="flex:1;min-width:140px;padding:10px 15px;background:#f8f9fa;border-left:4px solid #1a237e;border-radius:4px">};
	print qq{<div style="font-size:12px;color:#666">$icon $cat</div>};
	print qq{<div style="font-size:20px;font-weight:bold;color:#1a237e">$count</div>};
	print qq{</div>};
	}
print qq{</div>\n};

# ── Module Cards by Category ──────────────────────────────────────
foreach my $cat (@$order) {
	next unless exists($grouped->{$cat});
	my $cat_icon = ovms_category_icon($cat);
	print qq{<h3 style="margin:20px 0 10px 0;padding-bottom:8px;border-bottom:2px solid #e0e0e0;color:#1a237e">$cat_icon $cat</h3>\n};
	print qq{<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:12px;margin-bottom:15px">\n};

	foreach my $module (@{$grouped->{$cat}}) {
		my $name  = &html_escape($module->{'name'});
		my $desc  = &html_escape($module->{'description'});
		my $icon  = $module->{'icon'} || '📁';
		my $path  = $module->{'path'};
		my $ver   = $module->{'version'} || '1.0.0';
		my $mid   = $module->{'id'} || '';

		print qq{<div style="border:1px solid #e0e0e0;border-radius:6px;padding:15px;background:#fff;transition:box-shadow 0.2s" onmouseover="this.style.boxShadow='0 2px 8px rgba(0,0,0,0.15)'" onmouseout="this.style.boxShadow='none'">};
		print qq{<div style="display:flex;align-items:center;margin-bottom:8px">};
		print qq{<span style="font-size:24px;margin-right:10px">$icon</span>};
		print qq{<div>};
		print qq{<div style="font-weight:bold;font-size:14px"><a href="$path" style="color:#1a237e;text-decoration:none">$name</a></div>};
		print qq{<div style="font-size:11px;color:#999">v$ver · $mid</div>};
		print qq{</div>};
		print qq{</div>};
		print qq{<div style="font-size:13px;color:#555;line-height:1.4">$desc</div>};
		print qq{<div style="margin-top:10px;text-align:right"><a href="$path" style="font-size:12px;color:#1565c0;text-decoration:none">Open →</a></div>};
		print qq{</div>\n};
		}

	print qq{</div>\n};
	}

# ── Footer Info ───────────────────────────────────────────────────
print qq{<div style="margin-top:20px;padding:12px;background:#f5f5f5;border-radius:4px;font-size:12px;color:#666">};
print qq{<strong>OpenVM Suite v2.0.0</strong> — $total modules available · };
print qq{<a href="../openvm-api/api_docs.cgi" style="color:#1565c0">API Docs</a> · };
print qq{<a href="../openvm-dashboard/index.cgi" style="color:#1565c0">Dashboard</a> · };
print qq{Supported languages: EN, ES, PT, FR, DE};
print qq{</div>\n};

&ui_print_footer('/', $text{'index_return'} || 'Return');
