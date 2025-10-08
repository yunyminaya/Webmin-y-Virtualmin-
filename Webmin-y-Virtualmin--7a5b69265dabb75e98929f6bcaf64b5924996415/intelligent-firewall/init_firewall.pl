#!/usr/bin/perl
# init_firewall.pl - Inicialización del firewall inteligente

require './intelligent-firewall-lib.pl';

# Inicializar
if (init_firewall()) {
    print "Firewall inteligente inicializado correctamente.\n";
} else {
    print "Error al inicializar el firewall.\n";
    exit(1);
}

# Entrenar modelo inicial si no existe
if (! -f '/etc/webmin/intelligent-firewall/models/anomaly_model.pkl') {
    print "Entrenando modelo inicial...\n";
    train_ml_model();
}

print "Inicialización completada.\n";