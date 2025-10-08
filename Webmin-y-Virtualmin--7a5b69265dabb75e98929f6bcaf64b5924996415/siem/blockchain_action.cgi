#!/usr/bin/perl

# Blockchain Actions CGI
# Handles blockchain operations from the web interface

use strict;
use warnings;
use WebminCore;
use JSON;

&init_config();
&ReadParse();

my $module_root = $module_root_directory;

&ui_print_header("Blockchain Actions", "", undef, undef, 0, 1);

if ($in{'verify_integrity'}) {
    print &ui_subheading('Verifying Blockchain Integrity...');

    my $output = `cd $module_root && python3 blockchain_manager.py verify 2>/dev/null`;
    my $exit_code = $?;

    if ($exit_code == 0) {
        eval {
            my $result = decode_json($output);
            if ($result->{'valid'}) {
                print "<p class='alert alert-success'>✓ Blockchain integrity verified successfully!</p>";
                print "<ul>";
                print "<li>Total logs in blockchain: $result->{'blockchain_logs'}</li>";
                print "</ul>";
            } else {
                print "<p class='alert alert-danger'>✗ Blockchain integrity check failed!</p>";
                if ($result->{'error'}) {
                    print "<p>Error: $result->{'error'}</p>";
                }
                if (@{$result->{'mismatches'}}) {
                    print "<p>Mismatches found:</p><ul>";
                    foreach my $mismatch (@{$result->{'mismatches'}}) {
                        print "<li>$mismatch</li>";
                    }
                    print "</ul>";
                }
            }
        };
        if ($@) {
            print "<p class='alert alert-danger'>Error parsing verification result: $@</p>";
        }
    } else {
        print "<p class='alert alert-danger'>Failed to run integrity verification. Exit code: $exit_code</p>";
        print "<pre>$output</pre>" if $output;
    }
}

elsif ($in{'mine_pending'}) {
    print &ui_subheading('Mining Pending Logs...');

    my $output = `cd $module_root && python3 blockchain_manager.py mine 2>/dev/null`;
    my $exit_code = $?;

    if ($exit_code == 0) {
        print "<p class='alert alert-success'>✓ Pending logs mined successfully!</p>";
    } else {
        print "<p class='alert alert-warning'>No pending logs to mine or mining failed.</p>";
        print "<pre>$output</pre>" if $output;
    }
}

elsif ($in{'view_chain'}) {
    print &ui_subheading('Blockchain Details');

    my $blockchain_file = "$module_root/blockchain.json";
    if (-f $blockchain_file) {
        print "<p><a href='download.cgi?file=blockchain.json' class='btn btn-primary'>Download Blockchain File</a></p>";

        open my $fh, '<', $blockchain_file or die "Cannot open blockchain file: $!";
        local $/;
        my $json_text = <$fh>;
        close $fh;

        eval {
            my $chain_data = decode_json($json_text);
            print "<h4>Chain Overview</h4>";
            print "<ul>";
            print "<li>Total blocks: " . scalar(@$chain_data) . "</li>";
            print "<li>Genesis block hash: " . substr($chain_data->[0]->{'hash'}, 0, 32) . "...</li>" if @$chain_data;
            print "<li>Latest block hash: " . substr($chain_data->[-1]->{'hash'}, 0, 32) . "...</li>" if @$chain_data;
            print "</ul>";

            print "<h4>Block Details</h4>";
            print "<div style='max-height: 400px; overflow-y: auto;'>";
            foreach my $block (@$chain_data) {
                print "<div class='panel panel-default'>";
                print "<div class='panel-heading'>Block #$block->{'index'}</div>";
                print "<div class='panel-body'>";
                print "<p><strong>Timestamp:</strong> " . scalar(localtime($block->{'timestamp'})) . "</p>";
                print "<p><strong>Logs:</strong> " . scalar(@{$block->{'logs'}}) . "</p>";
                print "<p><strong>Previous Hash:</strong> " . substr($block->{'previous_hash'}, 0, 32) . "...</p>";
                print "<p><strong>Hash:</strong> " . substr($block->{'hash'}, 0, 32) . "...</p>";
                print "<p><strong>Nonce:</strong> $block->{'nonce'}</p>";
                print "</div></div>";
            }
            print "</div>";
        };
        if ($@) {
            print "<p class='alert alert-danger'>Error parsing blockchain file: $@</p>";
        }
    } else {
        print "<p class='alert alert-info'>No blockchain file found. The blockchain may not have been initialized yet.</p>";
    }
}

print &ui_buttons_start();
print &ui_button("Back to Blockchain", "index.cgi?tab=blockchain");
print &ui_buttons_end();

&ui_print_footer('index.cgi?tab=blockchain', 'Back to Blockchain');