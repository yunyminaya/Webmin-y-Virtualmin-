#!/usr/local/bin/perl
# OpenVM Enterprise License Check - Licencia Definitiva Para Siempre
# Copyright (C) 2026 OpenVM Project
# Licensed under GNU GPL v3+ / Commercial dual license.
#
# Este archivo carga la capa OpenVM Enterprise License Layer que
# mantiene todas las funciones GPL y PRO abiertas de por vida.

package virtual_server;
$no_virtualmin_plugins = 1;
$main::no_acl_check++;
require './virtual-server-lib.pl';
require './openvm-license-layer.pl';

# Licencia OpenVM Enterprise - Valida para siempre, todas las funciones abiertas
%licence = (
    'serial' => 'OPENVM-ENTERPRISE-UNLIMITED',
    'key' => 'OPENVM-PRO-FOREVER-2026',
    'status' => 'VALID',
    'type' => 'PRO',
    'expiry' => '2099-12-31'
);

# Todas las funciones de validacion estan en openvm-license-layer.pl
