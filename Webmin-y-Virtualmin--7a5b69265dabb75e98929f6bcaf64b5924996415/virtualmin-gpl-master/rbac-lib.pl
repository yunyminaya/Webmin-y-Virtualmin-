# rbac-lib.pl
# Role-Based Access Control library for Webmin/Virtualmin

use strict;
use warnings;

our %rbac_config;

# Load RBAC configuration
sub load_rbac_config {
    my $config_file = "$config_directory/rbac.config";
    if (-f $config_file) {
        %rbac_config = &read_file_cached($config_file, \%rbac_config);
    } else {
        # Default configuration
        %rbac_config = (
            roles => {
                superadmin => {
                    level => 4,
                    permissions => {
                        '*' => ['*']  # All modules, all actions
                    }
                },
                admin => {
                    level => 3,
                    permissions => {
                        'virtualmin' => ['read', 'write', 'delete'],
                        'webmin' => ['read', 'write'],
                        'system' => ['read']
                    }
                },
                reseller => {
                    level => 2,
                    permissions => {
                        'virtualmin' => ['read', 'write'],
                        'domains' => ['create', 'edit']
                    }
                },
                user => {
                    level => 1,
                    permissions => {
                        'virtualmin' => ['read'],
                        'mail' => ['read', 'write']
                    }
                }
            },
            users => {}
        );
        &write_file($config_file, \%rbac_config);
    }
}

# Get user role
sub get_user_role {
    my ($user) = @_;
    load_rbac_config() unless %rbac_config;
    return $rbac_config{'users'}{$user}{'role'} || 'user';
}

# Set user role
sub set_user_role {
    my ($user, $role) = @_;
    load_rbac_config() unless %rbac_config;
    $rbac_config{'users'}{$user}{'role'} = $role;
    &write_file("$config_directory/rbac.config", \%rbac_config);
}

# Check permission for current user
sub check_permission {
    my ($module, $action) = @_;
    our $remote_user;
    my $role = get_user_role($remote_user);
    load_rbac_config() unless %rbac_config;

    my $role_perms = $rbac_config{'roles'}{$role}{'permissions'};
    my $has_role_perm = ($role_perms->{'*'} && grep { $_ eq '*' || $_ eq $action } @{$role_perms->{'*'}}) ||
                        ($role_perms->{$module} && grep { $_ eq '*' || $_ eq $action } @{$role_perms->{$module}});

    # Check conditional policies
    require './conditional-policies-lib.pl';
    my $policy_result = &check_conditional_policies($remote_user, $module, $action);
    if (defined $policy_result) {
        return $policy_result;
    }

    # Zero-Trust integration
    if (-d '../zero-trust') {
        require '../zero-trust/zero-trust-lib.pl';

        # Check continuous authentication
        my $session_id = $ENV{'SESSION_ID'} || 'default_session';
        unless (&check_continuous_auth($remote_user, $session_id)) {
            &log_zero_trust_event('auth_failure', $remote_user, "Continuous authentication failed for $module:$action");
            return 0;
        }

        # Check contextual access
        my $context = {
            'ip' => $ENV{'REMOTE_ADDR'},
            'user_agent' => $ENV{'HTTP_USER_AGENT'},
            'device_fingerprint' => $ENV{'DEVICE_FINGERPRINT'} || 'unknown'
        };
        unless (&check_contextual_access($remote_user, $module, $action, $context)) {
            &log_zero_trust_event('context_denied', $remote_user, "Contextual access denied for $module:$action from $context->{'ip'}");
            return 0;
        }

        # Adapt policies based on successful access
        &adapt_policies($remote_user, 1, $context);
    }

    return $has_role_perm ? 1 : 0;
}

# Check permission for specific user
sub check_user_permission {
    my ($user, $module, $action) = @_;
    my $role = get_user_role($user);
    load_rbac_config() unless %rbac_config;

    my $role_perms = $rbac_config{'roles'}{$role}{'permissions'};
    return 1 if $role_perms->{'*'} && grep { $_ eq '*' || $_ eq $action } @{$role_perms->{'*'}};
    return 1 if $role_perms->{$module} && grep { $_ eq '*' || $_ eq $action } @{$role_perms->{$module}};

    return 0;
}

# Get all roles
sub get_roles {
    load_rbac_config() unless %rbac_config;
    return keys %{$rbac_config{'roles'}};
}

# Get role permissions
sub get_role_permissions {
    my ($role) = @_;
    load_rbac_config() unless %rbac_config;
    return $rbac_config{'roles'}{$role}{'permissions'};
}

# Add role
sub add_role {
    my ($role, $level, $permissions) = @_;
    load_rbac_config() unless %rbac_config;
    $rbac_config{'roles'}{$role} = {
        level => $level,
        permissions => $permissions
    };
    &write_file("$config_directory/rbac.config", \%rbac_config);
}

# Remove role
sub remove_role {
    my ($role) = @_;
    load_rbac_config() unless %rbac_config;
    delete $rbac_config{'roles'}{$role};
    &write_file("$config_directory/rbac.config", \%rbac_config);
}

1;