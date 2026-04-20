#!/usr/bin/perl

use strict;
use warnings;

our (%in, %text, $module_config_directory, $module_name, $base_remote_user);
our $OVMBL_VIRTUALMIN_LOADED = 0;

# ---------------------------------------------------------------------------
# JSON helpers — lightweight, no external deps
# ---------------------------------------------------------------------------

sub ovmbl_json_escape
{
my ($str) = @_;
return '' unless defined $str;
$str =~ s/\\/\\\\/g;
$str =~ s/"/\\"/g;
$str =~ s/\n/\\n/g;
$str =~ s/\r/\\r/g;
$str =~ s/\t/\\t/g;
$str =~ s/([^\x20-\x7e])/sprintf("\\u%04x",ord($1))/ge;
return $str;
}

sub ovmbl_to_json
{
my ($data) = @_;
return 'null' unless defined $data;
my $ref = ref($data);
if ($ref eq 'HASH') {
	my @pairs;
	foreach my $k (sort keys %$data) {
		push @pairs, '"'.ovmbl_json_escape($k).'":'.ovmbl_to_json($data->{$k});
		}
	return '{'.join(',', @pairs).'}';
	}
elsif ($ref eq 'ARRAY') {
	my @items;
	foreach my $v (@$data) {
		push @items, ovmbl_to_json($v);
		}
	return '['.join(',', @items).']';
	}
elsif ($ref eq 'JSON::PP::Boolean' || $ref eq 'boolean') {
	return $data ? 'true' : 'false';
	}
elsif (!defined $data) {
	return 'null';
	}
elsif ($data =~ /^-?\d+(?:\.\d+)?$/ && $data !~ /^0\d/) {
	return $data;
	}
else {
	return '"'.ovmbl_json_escape($data).'"';
	}
}

sub ovmbl_from_json
{
my ($json) = @_;
return undef unless defined $json && $json ne '';
$json =~ s/^\s+//;
$json =~ s/\s+$//;

if ($json eq 'null') {
	return undef;
	}
elsif ($json eq 'true') {
	return 1;
	}
elsif ($json eq 'false') {
	return 0;
	}
elsif ($json =~ /^"(.*)"$/s) {
	my $s = $1;
	$s =~ s/\\"/"/g;
	$s =~ s/\\\\/\\/g;
	$s =~ s/\\n/\n/g;
	$s =~ s/\\r/\r/g;
	$s =~ s/\\t/\t/g;
	$s =~ s/\\u([0-9a-fA-F]{4})/chr(hex($1))/ge;
	return $s;
	}
elsif ($json =~ /^-?\d+(?:\.\d+)?$/) {
	return 0 + $json;
	}
elsif ($json =~ /^\[/) {
	$json =~ s/^\[//;
	$json =~ s/\]$//;
	my @items;
	my $depth = 0;
	my $current = '';
	my $in_string = 0;
	my $escape = 0;
	for my $ch (split //, $json) {
		if ($escape) {
			$current .= $ch;
			$escape = 0;
			next;
			}
		if ($ch eq '\\') {
			$current .= $ch;
			$escape = 1;
			next;
			}
		if ($ch eq '"') {
			$in_string = !$in_string;
			$current .= $ch;
			next;
			}
		if (!$in_string) {
			if ($ch eq '[' || $ch eq '{') {
				$depth++;
				$current .= $ch;
				next;
				}
			elsif ($ch eq ']' || $ch eq '}') {
				$depth--;
				$current .= $ch;
				next;
				}
			elsif ($ch eq ',' && $depth == 0) {
				$current =~ s/^\s+//;
				$current =~ s/\s+$//;
				push @items, ovmbl_from_json($current) if $current ne '';
				$current = '';
				next;
				}
			}
		$current .= $ch;
		}
	$current =~ s/^\s+//;
	$current =~ s/\s+$//;
	push @items, ovmbl_from_json($current) if $current ne '';
	return \@items;
	}
elsif ($json =~ /^\{/) {
	$json =~ s/^\{//;
	$json =~ s/\}$//;
	my %hash;
	my $depth = 0;
	my $current = '';
	my $in_string = 0;
	my $escape = 0;
	my @parts;
	for my $ch (split //, $json) {
		if ($escape) {
			$current .= $ch;
			$escape = 0;
			next;
			}
		if ($ch eq '\\') {
			$current .= $ch;
			$escape = 1;
			next;
			}
		if ($ch eq '"') {
			$in_string = !$in_string;
			$current .= $ch;
			next;
			}
		if (!$in_string) {
			if ($ch eq '[' || $ch eq '{') {
				$depth++;
				$current .= $ch;
				next;
				}
			elsif ($ch eq ']' || $ch eq '}') {
				$depth--;
				$current .= $ch;
				next;
				}
			elsif ($ch eq ',' && $depth == 0) {
				$current =~ s/^\s+//;
				$current =~ s/\s+$//;
				push @parts, $current if $current ne '';
				$current = '';
				next;
				}
			}
		$current .= $ch;
		}
	$current =~ s/^\s+//;
	$current =~ s/\s+$//;
	push @parts, $current if $current ne '';
	foreach my $part (@parts) {
		if ($part =~ /^"([^"]*)"\s*:\s*(.*)$/s) {
			my $key = $1;
			my $val = $2;
			$val =~ s/^\s+//;
			$val =~ s/\s+$//;
			$hash{$key} = ovmbl_from_json($val);
			}
		}
	return \%hash;
	}
return $json;
}

# ---------------------------------------------------------------------------
# File helpers
# ---------------------------------------------------------------------------

sub ovmbl_read_json_file
{
my ($file) = @_;
return [] unless -f $file;
open(my $fh, '<', $file) or return [];
local $/;
my $content = <$fh>;
close($fh);
return [] unless defined $content && $content ne '';
my $data = ovmbl_from_json($content);
return $data if ref($data) eq 'ARRAY';
return [];
}

sub ovmbl_write_json_file
{
my ($file, $data) = @_;
my $json = ovmbl_to_json($data);
open(my $fh, '>', $file) or return 0;
print $fh $json;
close($fh);
return 1;
}

sub ovmbl_data_file
{
my ($name) = @_;
return $module_config_directory . '/' . $name . '.json';
}

# ---------------------------------------------------------------------------
# Config helpers
# ---------------------------------------------------------------------------

our %ovmbl_config;

sub ovmbl_init
{
%ovmbl_config = (
	currency         => 'USD',
	currency_symbol  => '$',
	tax_rate         => 0,
	tax_enabled      => 'no',
	invoice_prefix   => 'INV-',
	invoice_start    => 1000,
	payment_terms    => 30,
	late_fee_percent => 5,
	auto_suspend     => 'no',
	suspend_after_days => 30,
	billing_email    => 'billing@localhost',
	company_name     => 'OpenVM Hosting',
	company_address  => '',
	);
if (defined(&read_file_contents)) {
	my $conf_file = $module_config_directory . '/config';
	if (-f $conf_file) {
		open(my $fh, '<', $conf_file) or return;
		while (<$fh>) {
			chomp;
			next if /^\s*#/ || /^\s*$/;
			if (/^(\S+?)=(.*)$/) {
				$ovmbl_config{$1} = $2;
				}
			}
		close($fh);
		}
	}
# Ensure data files exist
my $plans_file = ovmbl_data_file('plans');
my $invoices_file = ovmbl_data_file('invoices');
my $clients_file = ovmbl_data_file('clients');
ovmbl_write_json_file($plans_file, []) unless -f $plans_file;
ovmbl_write_json_file($invoices_file, []) unless -f $invoices_file;
ovmbl_write_json_file($clients_file, []) unless -f $clients_file;
}

sub ovmbl_save_config
{
my $conf_file = $module_config_directory . '/config';
open(my $fh, '>', $conf_file) or return 0;
foreach my $k (sort keys %ovmbl_config) {
	print $fh "$k=$ovmbl_config{$k}\n";
	}
close($fh);
return 1;
}

# ---------------------------------------------------------------------------
# Plan management
# ---------------------------------------------------------------------------

sub ovmbl_list_plans
{
my $file = ovmbl_data_file('plans');
return ovmbl_read_json_file($file);
}

sub ovmbl_get_plan
{
my ($id) = @_;
my $plans = ovmbl_list_plans();
foreach my $p (@$plans) {
	return $p if $p->{'id'} eq $id;
	}
return undef;
}

sub ovmbl_create_plan
{
my (%plan) = @_;
my $file = ovmbl_data_file('plans');
my $plans = ovmbl_list_plans();
$plan{'id'} = 'plan_' . time() . '_' . int(rand(10000));
$plan{'created'} = time();
$plan{'status'} ||= 'active';
push @$plans, \%plan;
ovmbl_write_json_file($file, $plans);
return $plan{'id'};
}

sub ovmbl_update_plan
{
my ($id, %plan) = @_;
my $file = ovmbl_data_file('plans');
my $plans = ovmbl_list_plans();
for my $i (0 .. $#$plans) {
	if ($plans->[$i]{'id'} eq $id) {
		foreach my $k (keys %plan) {
			$plans->[$i]{$k} = $plan{$k};
			}
		$plans->[$i]{'updated'} = time();
		ovmbl_write_json_file($file, $plans);
		return 1;
		}
	}
return 0;
}

sub ovmbl_delete_plan
{
my ($id) = @_;
my $file = ovmbl_data_file('plans');
my $plans = ovmbl_list_plans();
my @new_plans = grep { $_->{'id'} ne $id } @$plans;
ovmbl_write_json_file($file, \@new_plans);
return 1;
}

# ---------------------------------------------------------------------------
# Invoice management
# ---------------------------------------------------------------------------

sub ovmbl_list_invoices
{
my ($filter) = @_;
$filter ||= 'all';
my $file = ovmbl_data_file('invoices');
my $invoices = ovmbl_read_json_file($file);
if ($filter && $filter ne 'all') {
	my @filtered;
	foreach my $inv (@$invoices) {
		if ($filter eq 'overdue') {
			my $now = time();
			push @filtered, $inv if $inv->{'status'} eq 'pending' && $inv->{'due_date'} && $inv->{'due_date'} < $now;
			}
		elsif ($inv->{'status'} eq $filter) {
			push @filtered, $inv;
			}
		}
	return \@filtered;
	}
return $invoices;
}

sub ovmbl_get_invoice
{
my ($id) = @_;
my $invoices = ovmbl_list_invoices('all');
foreach my $inv (@$invoices) {
	return $inv if $inv->{'id'} eq $id;
	}
return undef;
}

sub ovmbl_create_invoice
{
my (%inv) = @_;
my $file = ovmbl_data_file('invoices');
my $invoices = ovmbl_list_invoices('all');
$inv{'id'} = 'inv_' . time() . '_' . int(rand(10000));
$inv{'number'} = ovmbl_generate_invoice_number();
$inv{'created'} = time();
$inv{'status'} ||= 'pending';
$inv{'items'} ||= [];
$inv{'subtotal'} ||= 0;
$inv{'tax_amount'} ||= 0;
$inv{'total'} ||= 0;
push @$invoices, \%inv;
ovmbl_write_json_file($file, $invoices);
return $inv{'id'};
}

sub ovmbl_update_invoice
{
my ($id, %inv) = @_;
my $file = ovmbl_data_file('invoices');
my $invoices = ovmbl_list_invoices('all');
for my $i (0 .. $#$invoices) {
	if ($invoices->[$i]{'id'} eq $id) {
		foreach my $k (keys %inv) {
			$invoices->[$i]{$k} = $inv{$k};
			}
		$invoices->[$i]{'updated'} = time();
		ovmbl_write_json_file($file, $invoices);
		return 1;
		}
	}
return 0;
}

sub ovmbl_delete_invoice
{
my ($id) = @_;
my $file = ovmbl_data_file('invoices');
my $invoices = ovmbl_list_invoices('all');
my @new = grep { $_->{'id'} ne $id } @$invoices;
ovmbl_write_json_file($file, \@new);
return 1;
}

sub ovmbl_mark_paid
{
my ($id) = @_;
return ovmbl_update_invoice($id, 'status' => 'paid', 'paid_date' => time());
}

sub ovmbl_mark_cancelled
{
my ($id) = @_;
return ovmbl_update_invoice($id, 'status' => 'cancelled');
}

sub ovmbl_generate_recurring_invoices
{
my $clients = ovmbl_list_clients();
my $generated = 0;
foreach my $client (@$clients) {
	next unless $client->{'plan_id'} && $client->{'status'} eq 'active';
	my $plan = ovmbl_get_plan($client->{'plan_id'});
	next unless $plan && $plan->{'price_monthly'};
	# Check if client already has a pending invoice
	my $existing = ovmbl_list_invoices('pending');
	my $has_pending = 0;
	foreach my $ex (@$existing) {
		if ($ex->{'client_id'} eq $client->{'id'}) {
			$has_pending = 1;
			last;
			}
		}
	next if $has_pending;
	my $subtotal = $plan->{'price_monthly'};
	my $tax = ovmbl_calculate_tax($subtotal);
	my $terms = $ovmbl_config{'payment_terms'} || 30;
	ovmbl_create_invoice(
		'client_id'   => $client->{'id'},
		'client_name' => $client->{'name'},
		'items'       => [{ 'description' => "Hosting Plan: $plan->{'name'}", 'qty' => 1, 'price' => $subtotal }],
		'subtotal'    => $subtotal,
		'tax_amount'  => $tax,
		'total'       => $subtotal + $tax,
		'due_date'    => time() + ($terms * 86400),
		'notes'       => 'Recurring invoice',
		);
	$generated++;
	}
return $generated;
}

# ---------------------------------------------------------------------------
# Client management
# ---------------------------------------------------------------------------

sub ovmbl_list_clients
{
my $file = ovmbl_data_file('clients');
return ovmbl_read_json_file($file);
}

sub ovmbl_get_client
{
my ($id) = @_;
my $clients = ovmbl_list_clients();
foreach my $c (@$clients) {
	return $c if $c->{'id'} eq $id;
	}
return undef;
}

sub ovmbl_create_client
{
my (%client) = @_;
my $file = ovmbl_data_file('clients');
my $clients = ovmbl_list_clients();
$client{'id'} = 'cli_' . time() . '_' . int(rand(10000));
$client{'created'} = time();
$client{'status'} ||= 'active';
$client{'balance'} ||= 0;
push @$clients, \%client;
ovmbl_write_json_file($file, $clients);
return $client{'id'};
}

sub ovmbl_update_client
{
my ($id, %client) = @_;
my $file = ovmbl_data_file('clients');
my $clients = ovmbl_list_clients();
for my $i (0 .. $#$clients) {
	if ($clients->[$i]{'id'} eq $id) {
		foreach my $k (keys %client) {
			$clients->[$i]{$k} = $client{$k};
			}
		$clients->[$i]{'updated'} = time();
		ovmbl_write_json_file($file, $clients);
		return 1;
		}
	}
return 0;
}

sub ovmbl_get_client_balance
{
my ($id) = @_;
my $invoices = ovmbl_list_invoices('all');
my $balance = 0;
foreach my $inv (@$invoices) {
	next unless $inv->{'client_id'} eq $id;
	if ($inv->{'status'} eq 'pending' || $inv->{'status'} eq 'paid') {
		$balance += $inv->{'total'} || 0;
		}
	if ($inv->{'status'} eq 'paid') {
		$balance -= $inv->{'total'} || 0;
		}
	}
return sprintf("%.2f", $balance);
}

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

sub ovmbl_calculate_tax
{
my ($amount) = @_;
return 0 unless $ovmbl_config{'tax_enabled'} eq 'yes';
my $rate = $ovmbl_config{'tax_rate'} || 0;
return sprintf("%.2f", $amount * ($rate / 100));
}

sub ovmbl_format_currency
{
my ($amount) = @_;
$amount = 0 unless defined $amount;
my $symbol = $ovmbl_config{'currency_symbol'} || '$';
return $symbol . sprintf("%.2f", $amount);
}

sub ovmbl_get_revenue_stats
{
my $invoices = ovmbl_list_invoices('all');
my $now = time();
my $month_start = $now - (30 * 86400);
my %stats = (
	total_revenue    => 0,
	month_revenue    => 0,
	pending_amount   => 0,
	overdue_amount   => 0,
	paid_count       => 0,
	pending_count    => 0,
	overdue_count    => 0,
	cancelled_count  => 0,
	total_invoices   => scalar(@$invoices),
	);
foreach my $inv (@$invoices) {
	if ($inv->{'status'} eq 'paid') {
		$stats{'total_revenue'} += $inv->{'total'} || 0;
		$stats{'paid_count'}++;
		if ($inv->{'paid_date'} && $inv->{'paid_date'} >= $month_start) {
			$stats{'month_revenue'} += $inv->{'total'} || 0;
			}
		}
	elsif ($inv->{'status'} eq 'pending') {
		$stats{'pending_amount'} += $inv->{'total'} || 0;
		$stats{'pending_count'}++;
		if ($inv->{'due_date'} && $inv->{'due_date'} < $now) {
			$stats{'overdue_amount'} += $inv->{'total'} || 0;
			$stats{'overdue_count'}++;
			}
		}
	elsif ($inv->{'status'} eq 'cancelled') {
		$stats{'cancelled_count'}++;
		}
	}
$stats{'total_revenue'}  = sprintf("%.2f", $stats{'total_revenue'});
$stats{'month_revenue'}  = sprintf("%.2f", $stats{'month_revenue'});
$stats{'pending_amount'} = sprintf("%.2f", $stats{'pending_amount'});
$stats{'overdue_amount'} = sprintf("%.2f", $stats{'overdue_amount'});
return \%stats;
}

sub ovmbl_get_overdue_invoices
{
my $invoices = ovmbl_list_invoices('all');
my $now = time();
my @overdue;
foreach my $inv (@$invoices) {
	if ($inv->{'status'} eq 'pending' && $inv->{'due_date'} && $inv->{'due_date'} < $now) {
		push @overdue, $inv;
		}
	}
return \@overdue;
}

sub ovmbl_check_suspensions
{
return [] unless $ovmbl_config{'auto_suspend'} eq 'yes';
my $overdue = ovmbl_get_overdue_invoices();
my $days = $ovmbl_config{'suspend_after_days'} || 30;
my $threshold = time() - ($days * 86400);
my @to_suspend;
foreach my $inv (@$overdue) {
	if ($inv->{'due_date'} && $inv->{'due_date'} < $threshold) {
		push @to_suspend, $inv;
		}
	}
return \@to_suspend;
}

sub ovmbl_generate_invoice_number
{
my $prefix = $ovmbl_config{'invoice_prefix'} || 'INV-';
my $start = $ovmbl_config{'invoice_start'} || 1000;
my $invoices = ovmbl_list_invoices('all');
my $max_num = $start;
foreach my $inv (@$invoices) {
	if ($inv->{'number'} && $inv->{'number'} =~ /^$prefix(\d+)$/) {
		$max_num = $1 + 1 if $1 >= $max_num;
		}
	}
# If no invoices with numbers, start from invoice_start
if (scalar(@$invoices) == 0) {
	$max_num = $start;
	}
return $prefix . $max_num;
}

sub ovmbl_human_date
{
my ($timestamp) = @_;
return 'N/A' unless $timestamp;
my @t = localtime($timestamp);
return sprintf("%04d-%02d-%02d", $t[5]+1900, $t[4]+1, $t[3]);
}

sub ovmbl_get_billing_overview
{
my $stats = ovmbl_get_revenue_stats();
my $clients = ovmbl_list_clients();
my $plans = ovmbl_list_plans();
my $overdue = ovmbl_get_overdue_invoices();
my $suspensions = ovmbl_check_suspensions();

my $active_clients = scalar(grep { $_->{'status'} eq 'active' } @$clients);

my %overview = (
	'stats'          => $stats,
	'active_clients' => $active_clients,
	'total_clients'  => scalar(@$clients),
	'total_plans'    => scalar(@$plans),
	'overdue_count'  => scalar(@$overdue),
	'suspension_count' => scalar(@$suspensions),
	);
return \%overview;
}

sub ovmbl_get_monthly_revenue
{
my ($months) = @_;
$months ||= 6;
my $invoices = ovmbl_list_invoices('all');
my %monthly;
my $now = time();
for my $m (0 .. $months - 1) {
	my @t = localtime($now - ($m * 30 * 86400));
	my $key = sprintf("%04d-%02d", $t[5]+1900, $t[4]+1);
	$monthly{$key} = 0;
	}
foreach my $inv (@$invoices) {
	next unless $inv->{'status'} eq 'paid' && $inv->{'paid_date'};
	my @t = localtime($inv->{'paid_date'});
	my $key = sprintf("%04d-%02d", $t[5]+1900, $t[4]+1);
	$monthly{$key} += $inv->{'total'} || 0 if exists $monthly{$key};
	}
my @result;
foreach my $k (sort keys %monthly) {
	push @result, { 'month' => $k, 'revenue' => sprintf("%.2f", $monthly{$k}) };
	}
return \@result;
}

sub ovmbl_get_plan_distribution
{
my $clients = ovmbl_list_clients();
my %dist;
foreach my $c (@$clients) {
	next unless $c->{'plan_id'};
	my $plan = ovmbl_get_plan($c->{'plan_id'});
	my $name = $plan ? $plan->{'name'} : 'Unknown';
	$dist{$name} ||= 0;
	$dist{$name}++;
	}
my @result;
foreach my $k (sort keys %dist) {
	push @result, { 'plan' => $k, 'count' => $dist{$k} };
	}
return \@result;
}

sub ovmbl_get_top_clients
{
my ($limit) = @_;
$limit ||= 10;
my $invoices = ovmbl_list_invoices('all');
my %totals;
foreach my $inv (@$invoices) {
	next unless $inv->{'status'} eq 'paid';
	my $cid = $inv->{'client_id'} || 'unknown';
	$totals{$cid}{'total'} += $inv->{'total'} || 0;
	$totals{$cid}{'name'} = $inv->{'client_name'} || 'Unknown';
	}
my @sorted = sort { $b->{'total'} <=> $a->{'total'} }
              map { { 'id' => $_, 'name' => $totals{$_}{'name'}, 'total' => sprintf("%.2f", $totals{$_}{'total'}) } }
              keys %totals;
return [ @sorted[0 .. ($#sorted > $limit - 1 ? $limit - 1 : $#sorted)] ];
}

sub ovmbl_export_csv
{
my ($type) = @_;
$type ||= 'invoices';
my $data;
my @headers;
my @rows;

if ($type eq 'invoices') {
	$data = ovmbl_list_invoices('all');
	@headers = ('Number', 'Client', 'Subtotal', 'Tax', 'Total', 'Status', 'Created', 'Due Date');
	foreach my $inv (@$data) {
		push @rows, join(',', map { ovmbl_csv_escape($_) } (
			$inv->{'number'} || '',
			$inv->{'client_name'} || '',
			$inv->{'subtotal'} || 0,
			$inv->{'tax_amount'} || 0,
			$inv->{'total'} || 0,
			$inv->{'status'} || '',
			ovmbl_human_date($inv->{'created'}),
			ovmbl_human_date($inv->{'due_date'}),
			));
		}
	}
elsif ($type eq 'clients') {
	$data = ovmbl_list_clients();
	@headers = ('Name', 'Email', 'Plan', 'Balance', 'Status', 'Created');
	foreach my $c (@$data) {
		my $plan_name = '';
		if ($c->{'plan_id'}) {
			my $p = ovmbl_get_plan($c->{'plan_id'});
			$plan_name = $p->{'name'} if $p;
			}
		push @rows, join(',', map { ovmbl_csv_escape($_) } (
			$c->{'name'} || '',
			$c->{'email'} || '',
			$plan_name,
			$c->{'balance'} || 0,
			$c->{'status'} || '',
			ovmbl_human_date($c->{'created'}),
			));
		}
	}

my $csv = join(',', @headers) . "\n";
$csv .= join("\n", @rows) . "\n";
return $csv;
}

sub ovmbl_csv_escape
{
my ($val) = @_;
return '""' unless defined $val;
$val =~ s/"/""/g;
return qq{"$val"} if $val =~ /[,"\n]/;
return $val;
}

# ---------------------------------------------------------------------------
# Status badge helper
# ---------------------------------------------------------------------------

sub ovmbl_status_badge
{
my ($status) = @_;
my %styles = (
	'paid'      => 'background:#36b37e;color:#fff;',
	'pending'   => 'background:#ff991f;color:#fff;',
	'overdue'   => 'background:#de350b;color:#fff;',
	'cancelled' => 'background:#6b778c;color:#fff;',
	'active'    => 'background:#36b37e;color:#fff;',
	'inactive'  => 'background:#6b778c;color:#fff;',
	);
my $style = $styles{$status} || 'background:#44546f;color:#fff;';
my $label = ucfirst($status || 'unknown');
return qq{<span style="$style;padding:2px 10px;border-radius:12px;font-size:11px;font-weight:bold;">$label</span>};
}

1;
