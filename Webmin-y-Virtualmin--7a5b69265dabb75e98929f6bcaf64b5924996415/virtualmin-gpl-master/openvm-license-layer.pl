#!/usr/bin/perl
# OpenVM Enterprise License Layer - Capa de Licencia Definitiva
# Copyright (C) 2026 OpenVM Project
# Licensed under GNU General Public License v3.0 or later / Commercial dual license.
# See LICENSE_MATRIX.md and OPENVM_ENTERPRISE_LICENSE.md for details.
#
# Esta capa implementa la gestion de licencia OpenVM Enterprise sobre Virtualmin GPL.
# Funciona como licencia definitiva para siempre: sin expiracion, sin limites.

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

# ============================================================
# FUNCIONES CRÍTICAS PARA ELIMINAR CANDADOS DE LA UI
# Estas funciones son las que Virtualmin usa para decidir
# si muestra candados (locks) o no en la interfaz web.
# ============================================================

# licence_status() - Función principal de verificación de licencia
# Es llamada por TODOS los scripts CGI y CLI de Virtualmin.
# Al retornar vacío sin errores, Virtualmin asume licencia válida.
sub licence_status {
    return;  # Sin errores = licencia válida = sin candados
}

# is_pro_available() - Verifica si las funciones PRO están disponibles
# Retorna 1 = PRO activo, sin candados en funciones PRO
sub is_pro_available {
    return 1;
}

# is_virtualmin_pro() - Verifica si es versión Pro
sub is_virtualmin_pro {
    return 1;
}

# get_product_name() - Nombre del producto
sub get_product_name {
    return "OpenVM Enterprise Professional";
}

# get_licence_type() - Tipo de licencia
sub get_licence_type {
    return "PRO";
}

# check_licence_warning() - Verificar advertencia de licencia
# Retorna vacío = sin advertencia = sin candados
sub check_licence_warning {
    return;
}

# licence_expired() - Verificar si la licencia expiró
sub licence_expired {
    return 0;  # No expirada
}

# get_licence_info() - Información completa de licencia para la UI
sub get_licence_info {
    return {
        'serial' => 'OPENVM-ENTERPRISE-UNLIMITED',
        'key' => 'OPENVM-PRO-FOREVER-2026',
        'status' => 0,  # 0 = OK
        'type' => 'PRO',
        'expiry' => '2099-12-31',
        'domains' => 999999,
        'servers' => 999999,
        'mailboxes' => 999999,
    };
}

# show_licence_upgrade_link() - Enlace de upgrade PRO
# Retorna 0 = no mostrar enlace de upgrade = sin candados
sub show_licence_upgrade_link {
    return 0;
}

# is_gpl() - Verificar si es GPL limitado
sub is_gpl {
    return 0;  # No es GPL limitado
}

# can_use_pro_feature() - Verificar si se puede usar feature PRO
sub can_use_pro_feature {
    return 1;  # Siempre se puede
}

# pro_upgrade_link() - Link de upgrade (vacío = sin candado)
sub pro_upgrade_link {
    return "";
}

# licence_scheduled_check() - Check programado (no-op)
sub licence_scheduled_check {
    return;
}

# get_virtualmin_shop_link() - Link a tienda (vacío)
sub get_virtualmin_shop_link {
    return "";
}

1;
