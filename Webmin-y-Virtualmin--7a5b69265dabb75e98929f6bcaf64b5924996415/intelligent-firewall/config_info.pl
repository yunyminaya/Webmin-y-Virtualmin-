use strict;
use warnings;

our %config_info = (
    'enabled' => {
        'type' => 'yesno',
        'name' => 'Habilitar firewall inteligente',
        'default' => 1,
    },
    'ml_model_path' => {
        'type' => 'string',
        'name' => 'Ruta al modelo de ML',
        'default' => '/etc/webmin/intelligent-firewall/models/anomaly_model.pkl',
    },
    'traffic_log_path' => {
        'type' => 'string',
        'name' => 'Ruta a logs de tráfico',
        'default' => '/var/log/intelligent-firewall/traffic.log',
    },
    'block_threshold' => {
        'type' => 'float',
        'name' => 'Umbral de bloqueo (puntuación de riesgo)',
        'default' => 0.8,
    },
    'learning_interval' => {
        'type' => 'integer',
        'name' => 'Intervalo de aprendizaje (horas)',
        'default' => 24,
    },
    'iptables_chain' => {
        'type' => 'string',
        'name' => 'Cadena de iptables',
        'default' => 'INTELLIGENT_FIREWALL',
    },
);

1;