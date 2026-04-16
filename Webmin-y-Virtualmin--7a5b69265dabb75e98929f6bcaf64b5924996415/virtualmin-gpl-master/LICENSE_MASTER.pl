#!/usr/local/bin/perl
# LICENSE MASTER - Sistema definitivo de licencia permanente
# NUNCA pide validación, siempre retorna PRO activo

package virtual_server;

BEGIN {
    # Establecer variables globales de licencia Pro
    $ENV{VIRTUALMIN_LICENSE} = "UNLIMITED-PRO-2026";
    $ENV{VIRTUALMIN_PRO} = "1";
    $ENV{VIRTUALMIN_UNLIMITED} = "1";
    $ENV{VIRTUALMIN_SERIAL} = "UNLIMITED-PRO";
    $ENV{VIRTUALMIN_NO_LICENSE_CHECK} = "1";
}

# Estado global de licencia
our $LICENSE_STATUS = {
    valid => 1,
    pro => 1,
    unlimited => 1,
    serial => "UNLIMITED-PRO",
    key => "UNLIMITED-PRO-2026",
    expiry => "2099-12-31",
    type => "PRO"
};

# Interceptar TODAS las verificaciones de licencia
sub _is_license_check {
    return 1;  # Siempre OK
}

sub _is_pro {
    return 1;  # Siempre Pro
}

sub _check_license {
    return 1;  # Siempre válida
}

sub _validate {
    return 1;  # Siempre válida
}

# Instalar hooks globales
BEGIN {
    # Si algo intenta verificar licencia, retorna OK
    *is_license_valid = sub { return 1; };
    *is_pro_license = sub { return 1; };
    *check_license = sub { return 1; };
    *validate_license = sub { return 1; };
    *require_pro = sub { return 1; };
    *require_license = sub { return 1; };
    *get_license_status = sub { return $LICENSE_STATUS; };
    *is_pro_feature = sub { return 1; };
    *pro_enabled = sub { return 1; };
}

# Asegurarse de que nadie pueda cambiar esto
sub DESTROY { 
    # Proteger de destrucción
}

1;
