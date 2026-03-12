#!/usr/local/bin/perl
# RBAC Dashboard for managing users and roles

require './virtual-server-lib.pl';
require './rbac-lib.pl';
require './audit-lib.pl';
&ReadParse();
&check_permission('rbac', 'admin') || &error($text{'rbac_denied'});

&ui_print_header(undef, $text{'rbac_dashboard_title'}, "");

# Tabs for different sections
@tabs = (
    [ 'users', $text{'rbac_users_tab'} ],
    [ 'roles', $text{'rbac_roles_tab'} ],
    [ 'audit', $text{'rbac_audit_tab'} ],
);
print &ui_tabs_start(\@tabs, 'mode', $in{'mode'} || 'users');

# Users tab
if ($in{'mode'} eq 'users' || !$in{'mode'}) {
    print &ui_tabs_start_tab('mode', 'users');
    print &ui_form_start("rbac_dashboard.cgi", "post");
    print &ui_hidden('mode', 'users');

    # List users and their roles
    my @users = &list_users();
    my @table;
    foreach my $user (@users) {
        my $role = &get_user_role($user->{'name'});
        push @table, [
            $user->{'name'},
            $role,
            &ui_select("role_$user->{'name'}", $role, [&get_roles()]),
        ];
    }

    print &ui_columns_table(
        [ $text{'rbac_user'}, $text{'rbac_role'}, $text{'rbac_new_role'} ],
        undef,
        \@table,
        undef,
        0,
        undef,
        $text{'rbac_no_users'}
    );

    print &ui_form_end([ [ 'save_users', $text{'save'} ] ]);
    print &ui_tabs_end_tab('mode', 'users');
}

# Roles tab
elsif ($in{'mode'} eq 'roles') {
    print &ui_tabs_start_tab('mode', 'roles');
    print &ui_form_start("rbac_dashboard.cgi", "post");
    print &ui_hidden('mode', 'roles');

    # List roles and permissions
    my @roles = &get_roles();
    my @table;
    foreach my $role (@roles) {
        my $perms = &get_role_permissions($role);
        my $perms_str = join(', ', map { "$_:" . join(',', @{$perms->{$_}}) } keys %$perms);
        push @table, [
            $role,
            $perms_str,
            &ui_textbox("perms_$role", $perms_str, 50),
        ];
    }

    print &ui_columns_table(
        [ $text{'rbac_role'}, $text{'rbac_permissions'}, $text{'rbac_edit_perms'} ],
        undef,
        \@table,
        undef,
        0,
        undef,
        $text{'rbac_no_roles'}
    );

    print &ui_form_end([ [ 'save_roles', $text{'save'} ] ]);
    print &ui_tabs_end_tab('mode', 'roles');
}

# Audit tab
elsif ($in{'mode'} eq 'audit') {
    print &ui_tabs_start_tab('mode', 'audit');

    my $logs = &get_audit_logs(50);
    my @table;
    foreach my $log (@$logs) {
        push @table, [
            scalar(localtime($log->{'timestamp'})),
            $log->{'user'},
            $log->{'action'},
            $log->{'module'},
            $log->{'details'},
        ];
    }

    print &ui_columns_table(
        [ $text{'rbac_timestamp'}, $text{'rbac_user'}, $text{'rbac_action'}, $text{'rbac_module'}, $text{'rbac_details'} ],
        undef,
        \@table,
        undef,
        0,
        undef,
        $text{'rbac_no_logs'}
    );

    print &ui_tabs_end_tab('mode', 'audit');
}

print &ui_tabs_end();

&ui_print_footer("", $text{'index_return'});

# Handle form submissions
if ($in{'save_users'}) {
    my @users = &list_users();
    foreach my $user (@users) {
        my $new_role = $in{"role_$user->{'name'}"};
        if ($new_role && $new_role ne &get_user_role($user->{'name'})) {
            &set_user_role($user->{'name'}, $new_role);
            &log_action($remote_user, 'change_role', 'rbac', "Changed role for $user->{'name'} to $new_role");
        }
    }
    &redirect("rbac_dashboard.cgi?mode=users");
}

if ($in{'save_roles'}) {
    # Implement role permission editing
    &redirect("rbac_dashboard.cgi?mode=roles");
}