#!/usr/bin/perl

# Forensic Blockchain Search CGI
# Advanced search and timeline analysis for blockchain logs

use strict;
use warnings;
use WebminCore;
use JSON;
use POSIX qw(strftime);

&init_config();
&ReadParse();

my $module_root = $module_root_directory;

&ui_print_header("Blockchain Forensic Search", "", undef, undef, 0, 1);

print &ui_subheading('Blockchain Forensic Analysis');

# Search form
print &ui_form_start('forensic_blockchain_search.cgi', 'post');

print &ui_table_start('Search Parameters', 'width=100%');

print &ui_table_row('IP Address',
    &ui_textbox('ip_address', $in{'ip_address'}, 20));

print &ui_table_row('Source',
    &ui_select('source', $in{'source'}, [
        [ '', 'All Sources' ],
        [ 'syslog', 'System Log' ],
        [ 'auth', 'Authentication' ],
        [ 'apache', 'Apache' ],
        [ 'nginx', 'Nginx' ],
        [ 'firewall', 'Firewall' ],
        [ 'ids', 'IDS' ],
        [ 'webmin', 'Webmin' ],
        [ 'virtualmin', 'Virtualmin' ]
    ]));

print &ui_table_row('Event Type',
    &ui_textbox('event_type', $in{'event_type'}, 30));

print &ui_table_row('Severity',
    &ui_select('severity', $in{'severity'}, [
        [ '', 'All Severities' ],
        [ 'critical', 'Critical' ],
        [ 'high', 'High' ],
        [ 'medium', 'Medium' ],
        [ 'low', 'Low' ],
        [ 'info', 'Info' ]
    ]));

print &ui_table_row('Time Range',
    &ui_date_input('start_date', $in{'start_date'}) . ' to ' . &ui_date_input('end_date', $in{'end_date'}));

print &ui_table_row('Message Contains',
    &ui_textbox('message_contains', $in{'message_contains'}, 50));

print &ui_table_end();

print &ui_form_end([ [ 'search', 'Search Blockchain' ], [ 'timeline', 'Generate Timeline' ] ]);

# Process search
if ($in{'search'} || $in{'timeline'}) {
    print &ui_hr();

    # Build search filters
    my %filters;
    $filters{'ip_address'} = $in{'ip_address'} if $in{'ip_address'};
    $filters{'source'} = $in{'source'} if $in{'source'};
    $filters{'event_type'} = $in{'event_type'} if $in{'event_type'};
    $filters{'severity'} = $in{'severity'} if $in{'severity'};
    $filters{'message'} = $in{'message_contains'} if $in{'message_contains'};

    # Convert dates to timestamps
    my $start_time = $in{'start_date'} ? &ui_date_to_timestamp($in{'start_date'}) : undef;
    my $end_time = $in{'end_date'} ? &ui_date_to_timestamp($in{'end_date'}) + 86400 : undef; # Add 1 day

    my $search_json = encode_json(\%filters);

    if ($in{'search'}) {
        print &ui_subheading('Search Results');

        my $output = `cd $module_root && python3 blockchain_manager.py search '$search_json' 2>/dev/null`;
        my $exit_code = $?;

        if ($exit_code == 0) {
            eval {
                my $results = decode_json($output);
                if (@$results) {
                    print "<p>Found " . scalar(@$results) . " matching logs in blockchain:</p>";

                    print "<div style='max-height: 600px; overflow-y: auto;'>";
                    print &ui_columns_table([
                        'Block',
                        'Timestamp',
                        'Source',
                        'Event Type',
                        'Severity',
                        'IP Address',
                        'Message'
                    ], 100, [], ['block_index', 'timestamp', 'source', 'event_type', 'severity', 'ip_address', 'message']);

                    foreach my $result (@$results) {
                        my $log = $result->{'log'};
                        print &ui_columns_row([
                            $result->{'block_index'},
                            scalar(localtime($log->{'timestamp'})),
                            $log->{'source'},
                            $log->{'event_type'},
                            $log->{'severity'},
                            $log->{'ip_address'} || '-',
                            substr($log->{'message'}, 0, 100) . (length($log->{'message'}) > 100 ? '...' : '')
                        ]);
                    }
                    print "</table></div>";
                } else {
                    print "<p class='alert alert-info'>No logs found matching the search criteria.</p>";
                }
            };
            if ($@) {
                print "<p class='alert alert-danger'>Error parsing search results: $@</p>";
            }
        } else {
            print "<p class='alert alert-danger'>Search failed. Exit code: $exit_code</p>";
            print "<pre>$output</pre>" if $output;
        }
    }

    elsif ($in{'timeline'}) {
        print &ui_subheading('Timeline Analysis');

        # For timeline, we'll get all logs in time range and sort them
        my $timeline_output = `cd $module_root && python3 -c "
import sys
sys.path.append('.')
from blockchain_manager import BlockchainManager
import json
from datetime import datetime

manager = BlockchainManager()
timeline = manager.get_timeline($start_time, $end_time)

# Filter by additional criteria
filtered_timeline = []
for entry in timeline:
    log = entry['log']
    match = True
    if '$in{'ip_address'}' and log.get('ip_address') != '$in{'ip_address'}':
        match = False
    if '$in{'source'}' and log.get('source') != '$in{'source'}':
        match = False
    if '$in{'event_type'}' and log.get('event_type') != '$in{'event_type'}':
        match = False
    if '$in{'severity'}' and log.get('severity') != '$in{'severity'}':
        match = False
    if '$in{'message_contains'}' and '$in{'message_contains'}' not in log.get('message', ''):
        match = False
    if match:
        filtered_timeline.append(entry)

print(json.dumps(filtered_timeline))
" 2>/dev/null`;

        eval {
            my $timeline_data = decode_json($timeline_output);
            if (@$timeline_data) {
                print "<p>Timeline with " . scalar(@$timeline_data) . " events:</p>";

                print "<div style='max-height: 600px; overflow-y: auto;'>";
                print "<table class='table table-striped'>";
                print "<thead><tr><th>Time</th><th>Block</th><th>Source</th><th>Event</th><th>Severity</th><th>Details</th></tr></thead>";
                print "<tbody>";

                foreach my $entry (@$timeline_data) {
                    my $log = $entry->{'log'};
                    my $time_str = strftime("%Y-%m-%d %H:%M:%S", localtime($entry->{'timestamp'}));
                    print "<tr>";
                    print "<td>$time_str</td>";
                    print "<td>$entry->{'block_index'}</td>";
                    print "<td>$log->{'source'}</td>";
                    print "<td>$log->{'event_type'}</td>";
                    print "<td>$log->{'severity'}</td>";
                    print "<td>" . substr($log->{'message'}, 0, 80) . (length($log->{'message'}) > 80 ? '...' : '') . "</td>";
                    print "</tr>";
                }

                print "</tbody></table></div>";
            } else {
                print "<p class='alert alert-info'>No events found in the specified time range.</p>";
            }
        };
        if ($@) {
            print "<p class='alert alert-danger'>Error generating timeline: $@</p>";
        }
    }
}

print &ui_buttons_start();
print &ui_button("Back to SIEM", "index.cgi?tab=forensics");
print &ui_buttons_end();

&ui_print_footer('index.cgi?tab=forensics', 'Back to Forensics');