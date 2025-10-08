# audit-lib.pl
# Audit logging library for RBAC actions

use strict;
use warnings;

our $audit_log_file = "$config_directory/rbac_audit.log";

# Log action
sub log_action {
    my ($user, $action, $module, $details) = @_;
    my $timestamp = time();
    my $log_entry = "$timestamp|$user|$action|$module|$details\n";

    open(my $fh, '>>', $audit_log_file) or die "Cannot open audit log: $!";
    print $fh $log_entry;
    close($fh);
}

# Get audit logs
sub get_audit_logs {
    my ($limit) = @_;
    $limit ||= 100;

    my @logs;
    if (-f $audit_log_file) {
        open(my $fh, '<', $audit_log_file) or return [];
        my @lines = <$fh>;
        close($fh);

        @lines = reverse @lines;  # Most recent first
        splice(@lines, $limit) if @lines > $limit;

        foreach my $line (@lines) {
            chomp $line;
            my ($timestamp, $user, $action, $module, $details) = split(/\|/, $line);
            push @logs, {
                timestamp => $timestamp,
                user => $user,
                action => $action,
                module => $module,
                details => $details
            };
        }
    }
    return \@logs;
}

# Clean old logs (older than 90 days)
sub clean_audit_logs {
    my $cutoff = time() - (90 * 24 * 60 * 60);

    if (-f $audit_log_file) {
        open(my $fh, '<', $audit_log_file) or return;
        my @lines = <$fh>;
        close($fh);

        my @new_lines;
        foreach my $line (@lines) {
            my ($timestamp) = split(/\|/, $line);
            push @new_lines, $line if $timestamp > $cutoff;
        }

        open(my $fh, '>', $audit_log_file) or return;
        print $fh @new_lines;
        close($fh);
    }
}

1;