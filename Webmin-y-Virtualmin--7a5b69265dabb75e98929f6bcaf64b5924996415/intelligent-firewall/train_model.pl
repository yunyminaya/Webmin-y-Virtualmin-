#!/usr/bin/perl
# train_model.pl - Entrenamiento periódico del modelo ML

require './intelligent-firewall-lib.pl';

# Función de validación de rutas de archivos
sub validate_file_path {
    my ($path) = @_;
    # Permitir solo rutas absolutas sin .. y caracteres peligrosos
    return $path =~ /^\/[a-zA-Z0-9_\/\-\.]+$/ && $path !~ /\.\./ && $path !~ /[;&|`$]/;
}

print "Iniciando entrenamiento del modelo ML...\n";

my $data_file = '/var/log/intelligent-firewall/traffic_data.csv';
my $min_samples = 100;  # Mínimo de muestras para entrenar

# Verificar si hay suficientes datos
if (! -f $data_file) {
    print "Archivo de datos no encontrado: $data_file\n";
    exit(0);
}

# Contar líneas de datos
my $line_count = `wc -l < $data_file`;
chomp($line_count);

if ($line_count < $min_samples) {
    print "Insuficientes datos para entrenar: $line_count < $min_samples\n";
    exit(0);
}

print "Datos disponibles: $line_count muestras\n";

# Backup del modelo anterior
my $config = read_config();
my $model_path = $config->{ml_model_path};
if (-f $model_path && validate_file_path($model_path)) {
    my $backup_path = $model_path . '.backup';
    if (validate_file_path($backup_path)) {
        my $safe_model = quotemeta($model_path);
        my $safe_backup = quotemeta($backup_path);
        system("cp $safe_model $safe_backup");
        print "Backup del modelo anterior creado\n";
    } else {
        print "Error: Ruta de backup inválida: $backup_path\n";
    }
} else {
    print "Error: Ruta del modelo inválida: $model_path\n" if !validate_file_path($model_path);
}

# Entrenar modelo
my $start_time = time();
train_ml_model();
my $end_time = time();

print "Entrenamiento completado en " . ($end_time - $start_time) . " segundos.\n";

# Validar modelo entrenado
if (-f $model_path) {
    print "Modelo guardado exitosamente: $model_path\n";

    # Limpiar datos antiguos para evitar crecimiento excesivo
    cleanup_old_data($data_file, 10000);  # Mantener máximo 10000 líneas
} else {
    print "Error: Modelo no fue guardado\n";
    exit(1);
}

# Función para limpiar datos antiguos
sub cleanup_old_data {
    my ($file, $max_lines) = @_;

    if (!validate_file_path($file)) {
        print "Error: Ruta de archivo inválida: $file\n";
        return;
    }

    my $safe_file = quotemeta($file);
    my $current_lines = `wc -l < $safe_file`;
    chomp($current_lines);

    if ($current_lines > $max_lines) {
        my $lines_to_remove = $current_lines - $max_lines;
        system("sed -i '1,${lines_to_remove}d' $safe_file");
        print "Limpiados $lines_to_remove registros antiguos\n";
    }
}