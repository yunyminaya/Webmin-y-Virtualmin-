#!/usr/local/bin/perl
# RBAC Installation and Setup Script

require './virtual-server-lib.pl';
require './rbac-lib.pl';

# Initialize RBAC system
print "Initializing RBAC system...\n";

# Load default config
&load_rbac_config();

# Set root user as superadmin
&set_user_role('root', 'superadmin');

print "RBAC system initialized successfully.\n";
print "Root user assigned superadmin role.\n";

# Create default policies
require './conditional-policies-lib.pl';
&add_policy({
    enabled => 1,
    module => 'virtualmin',
    action => 'delete',
    user_condition => 'role',
    role => 'user',
    effect => 'deny',
    description => 'Users cannot delete domains'
});

print "Default conditional policies created.\n";

print "RBAC installation complete.\n";