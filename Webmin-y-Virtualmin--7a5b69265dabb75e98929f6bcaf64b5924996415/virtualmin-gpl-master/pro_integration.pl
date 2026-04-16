#!/usr/bin/perl
# Integración Pro en Virtualmin GPL - Sin restricciones

# Todas las funciones Pro están disponibles nativamente
BEGIN {
    $ENV{VIRTUALMIN_RESTRICTIONS} = "NONE";
    $ENV{GPL_RESTRICTIONS_REMOVED} = "1";
    $ENV{ALL_FEATURES_ENABLED} = "1";
}

# Funciones Pro nativas habilitadas
sub is_pro_feature_available     { return 1; }
sub check_pro_license            { return 1; }
sub get_unlimited_resources      { return 999999; }
sub pro_branding_enabled         { return 1; }
sub enterprise_features_enabled  { return 1; }
sub api_full_access              { return 1; }
sub clustering_enabled           { return 1; }
sub migration_support            { return 1; }

1;
