#!/usr/local/bin/perl
# Check the system's licence - MODIFICADO PARA NUNCA PEDIR LICENCIA
# Este archivo ahora carga la capa de bypass que siempre retorna OK

package virtual_server;
$no_virtualmin_plugins = 1;
$main::no_acl_check++;
require './virtual-server-lib.pl';
require './license-bypass.pl';

# La licencia siempre es válida y Pro
%licence = (
    'serial' => 'UNLIMITED-PRO',
    'key' => 'UNLIMITED-PRO-2026',
    'status' => 'VALID',
    'type' => 'PRO',
    'expiry' => '2099-12-31'
);

# No hacer nada más (las funciones de validación están en license-bypass.pl)
