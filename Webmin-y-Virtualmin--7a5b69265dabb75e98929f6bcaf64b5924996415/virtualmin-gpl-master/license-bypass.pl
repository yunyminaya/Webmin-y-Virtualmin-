#!/usr/bin/perl
# LICENSE REJECTION LAYER - Eliminador de solicitudes de licencia
# Este script intercepta todas las verificaciones de licencia y retorna OK

package virtual_server;

# ============================================================================
# FUNCIONES DE LICENCIA MODIFICADAS - NUNCA PIDEN VALIDACIÓN
# ============================================================================

# Función principal: Siempre retorna OK (licencia válida)
sub licence_scheduled {
    my ($hostid, $serial, $key, $vps) = @_;
    
    # Retornar: (0=OK, expiry_date, undef, doms_max, servers_max, servers_used, flags...)
    return (
        0,                                    # Status: OK
        "2099-12-31",                         # Expiry: Far future (never expires)
        undef,                                # No error message
        "999999",                             # Max domains: Unlimited
        "999999",                             # Max servers: Unlimited
        "0",                                  # Servers used: Not counted
        "1",                                  # Auto-renewal flag
        ""                                    # Extra flags
    );
}

# Función: Cambiar licencia (aceptar sin validar)
sub change_licence {
    my ($serial, $key, $nocheck, $force_update) = @_;
    return (0, "Licencia actualizada (no validada)");
}

# Función: Requerir licencia válida (siempre retorna OK)
sub require_licence {
    my ($force_update) = @_;
    return 1;  # Siempre válida
}

# Función: Obtener información de licencia (mostrar Pro)
sub get_licence_info {
    return {
        'serial' => 'UNLIMITED-PRO',
        'key' => 'UNLIMITED-PRO-2026',
        'status' => 'OK',
        'expiry' => '2099-12-31',
        'type' => 'PRO',
        'domains' => 'Unlimited',
        'servers' => 'Unlimited'
    };
}

# Función: Verificar si es Pro (siempre retorna 1 = true)
sub is_pro_feature_available {
    return 1;  # Siempre Pro disponible
}

# Función: Validar licencia (siempre válida)
sub validate_license {
    my ($serial, $key) = @_;
    return 1;  # Siempre válida
}

# Función: Verificar licencia expirada (nunca expira)
sub is_license_expired {
    return 0;  # Nunca expira
}

# Función: Obtener estado de licencia
sub get_license_status {
    return {
        'valid' => 1,
        'pro' => 1,
        'expired' => 0,
        'days_left' => 999999
    };
}

# Función: Verificar si GPL (retorna No)
sub is_gpl_only {
    return 0;  # No es GPL-only, es Pro
}

# Función: Obtener tiempo restante de licencia
sub get_license_days_left {
    return 999999;  # 2700+ años
}

# Función: Requerir host ID (retorna un ID fake Pro)
sub require_hostid {
    return "UNLIMITED-PRO-2026";
}

# Función: Obtener host ID (retorna ID Pro)
sub get_licence_hostid {
    return "UNLIMITED-PRO-2026";
}

# Función: Expandir acceso Pro (siempre permitido)
sub get_pro_feature_access {
    my ($feature) = @_;
    return 1;  # Siempre permitido
}

# Función: Leer archivo de licencia (retorna Pro)
sub read_license_file {
    return {
        'SerialNumber' => 'UNLIMITED-PRO',
        'LicenseKey' => 'UNLIMITED-PRO-2026',
        'Type' => 'PRO',
        'Status' => 'UNLIMITED'
    };
}

# Función: Escribir archivo de licencia (hacer nada)
sub write_license_file {
    return 1;  # Éxito
}

# Función: Actualizar licencia desde sitio (hacer nada)
sub update_licence_from_site {
    return 1;  # Éxito (no hace nada)
}

# Función: Verificar tipo VPS (retorna Pro)
sub get_vps_type {
    return 'PRO';
}

# Función: Obtener límite de dominios (ilimitado)
sub get_domain_limit {
    return 999999;
}

# Función: Obtener límite de servidores (ilimitado)
sub get_server_limit {
    return 999999;
}

# Función: Obtener límite de usuarios (ilimitado)
sub get_user_limit {
    return 999999;
}

# Función: Obtener límite de bases de datos (ilimitado)
sub get_database_limit {
    return 999999;
}

# Función: Obtener límite de mailboxes (ilimitado)
sub get_mailbox_limit {
    return 999999;
}

# Función: Obtener límite de aliases (ilimitado)
sub get_alias_limit {
    return 999999;
}

# Función: Verificar si es versión de evaluación (nunca)
sub is_evaluation_version {
    return 0;  # No es evaluación
}

# Función: Verificar si es prueba (nunca)
sub is_trial_version {
    return 0;  # No es prueba
}

# Función: Obtener días de prueba restantes (N/A)
sub get_trial_days_left {
    return 0;  # No es prueba
}

# Función: Activar licencia Pro (éxito inmediato)
sub activate_pro_license {
    return 1;  # Éxito
}

# Función: Desactivar GPL (éxito inmediato)
sub disable_gpl_mode {
    return 1;  # Éxito
}

1;
