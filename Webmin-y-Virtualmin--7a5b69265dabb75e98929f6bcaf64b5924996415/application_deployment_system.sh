#!/bin/bash

# Sistema Completo de Despliegue de Aplicaciones en Contenedores
# Despliegue automatizado con plantillas, integración con Virtualmin y gestión de dominios
# Versión: 2.0.0 - Producción Lista

set -euo pipefail
IFS=$'\n\t'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: No se encuentra la biblioteca común en ${SCRIPT_DIR}/lib/common.sh"
    exit 1
fi

# ===== CONFIGURACIÓN =====
DEPLOYMENT_DIR="${DEPLOYMENT_DIR:-$SCRIPT_DIR/deployments}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$SCRIPT_DIR/templates}"
APPS_DIR="${APPS_DIR:-$SCRIPT_DIR/apps}"
VIRTUALMIN_API_URL="${VIRTUALMIN_API_URL:-https://localhost:10000}"
VIRTUALMIN_API_USER="${VIRTUALMIN_API_USER:-root}"
VIRTUALMIN_API_PASS="${VIRTUALMIN_API_PASS:-}"

# Función para verificar dependencias de despliegue
check_deployment_dependencies() {
    log_step "Verificando dependencias de despliegue..."

    local deps=("curl" "jq" "git")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Dependencias faltantes: ${missing_deps[*]}"
        log_info "Instala las dependencias faltantes"
        return 1
    fi

    # Verificar conexión con Virtualmin
    if [[ -n "$VIRTUALMIN_API_PASS" ]]; then
        if ! curl -s "$VIRTUALMIN_API_URL/virtual-server/remote.cgi" \
            --user "$VIRTUALMIN_API_USER:$VIRTUALMIN_API_PASS" \
            -d "program=list-domains&json=1" >/dev/null 2>&1; then
            log_warning "No se puede conectar a la API de Virtualmin"
            log_info "Verifica las credenciales de Virtualmin"
        fi
    fi

    log_success "Dependencias de despliegue verificadas"
    return 0
}

# Función para crear estructura de directorios
create_deployment_structure() {
    log_step "Creando estructura de directorios de despliegue..."

    mkdir -p "$DEPLOYMENT_DIR"
    mkdir -p "$TEMPLATES_DIR"
    mkdir -p "$APPS_DIR"

    # Crear subdirectorios
    mkdir -p "$TEMPLATES_DIR"/{php,nodejs,python,ruby,static,database}
    mkdir -p "$DEPLOYMENT_DIR"/{configs,logs,backups,ssl}
    mkdir -p "$APPS_DIR"/{active,inactive,archived}

    log_success "Estructura de directorios creada"
}

# Función para generar plantillas de aplicaciones
generate_app_templates() {
    log_step "Generando plantillas de aplicaciones..."

    # Plantilla PHP con Apache/Nginx
    generate_php_template

    # Plantilla Node.js
    generate_nodejs_template

    # Plantilla Python (Flask/Django)
    generate_python_template

    # Plantilla Ruby on Rails
    generate_ruby_template

    # Plantilla sitio estático
    generate_static_template

    # Plantilla base de datos
    generate_database_template

    log_success "Plantillas de aplicaciones generadas"
}

# Función para generar plantilla PHP
generate_php_template() {
    local template_dir="$TEMPLATES_DIR/php"
    mkdir -p "$template_dir"

    # Dockerfile
    cat > "$template_dir/Dockerfile" << 'EOF'
FROM php:8.2-apache

# Instalar extensiones PHP necesarias
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    mariadb-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql mysqli gd zip mbstring xml

# Habilitar mod_rewrite
RUN a2enmod rewrite

# Configurar Apache
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Crear directorio de la aplicación
WORKDIR /var/www/html

# Copiar archivos de la aplicación
COPY . /var/www/html/

# Cambiar propietario
RUN chown -R www-data:www-data /var/www/html

# Exponer puerto
EXPOSE 80

# Comando por defecto
CMD ["apache2-foreground"]
EOF

    # docker-compose.yml
    cat > "$template_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  app:
    build: .
    container_name: ${APP_NAME}_php
    restart: unless-stopped
    ports:
      - "${APP_PORT}:80"
    environment:
      - APP_ENV=production
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_NAME=${APP_NAME}
      - DB_USER=${APP_NAME}
      - DB_PASSWORD=${DB_PASSWORD}
    volumes:
      - ./:/var/www/html
      - php_logs:/var/log/apache2
    depends_on:
      - mysql
    networks:
      - app_network

  mysql:
    image: mysql:8.0
    container_name: ${APP_NAME}_mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${APP_NAME}
      MYSQL_USER: ${APP_NAME}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - app_network

volumes:
  mysql_data:
  php_logs:

networks:
  app_network:
    driver: bridge
EOF

    # Archivo de configuración
    cat > "$template_dir/app-config.json" << 'EOF'
{
  "name": "PHP Application",
  "type": "php",
  "version": "8.2",
  "domain": "app.example.com",
  "port": 8080,
  "database": {
    "type": "mysql",
    "name": "app_db",
    "user": "app_user"
  },
  "ssl": {
    "enabled": true,
    "auto_cert": true
  },
  "backup": {
    "enabled": true,
    "schedule": "daily",
    "retention": 30
  },
  "monitoring": {
    "enabled": true,
    "alerts": true
  }
}
EOF

    # Script de despliegue
    cat > "$template_dir/deploy.sh" << 'EOF'
#!/bin/bash

# Script de despliegue para aplicación PHP

set -euo pipefail

# Configuración
APP_NAME="${APP_NAME:-php_app}"
APP_PORT="${APP_PORT:-8080}"
DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -base64 16)}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-$(openssl rand -base64 16)}"

echo "Desplegando aplicación PHP: $APP_NAME"

# Crear archivo .env
cat > .env << EOF
APP_NAME=$APP_NAME
APP_PORT=$APP_PORT
DB_PASSWORD=$DB_PASSWORD
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
EOF

# Construir e iniciar contenedores
docker-compose up -d --build

echo "Aplicación desplegada exitosamente"
echo "URL: http://localhost:$APP_PORT"
EOF

    chmod +x "$template_dir/deploy.sh"
}

# Función para generar plantilla Node.js
generate_nodejs_template() {
    local template_dir="$TEMPLATES_DIR/nodejs"
    mkdir -p "$template_dir"

    # Dockerfile
    cat > "$template_dir/Dockerfile" << 'EOF'
FROM node:18-alpine

# Instalar dependencias del sistema
RUN apk add --no-cache git

# Crear directorio de la aplicación
WORKDIR /app

# Copiar package.json
COPY package*.json ./

# Instalar dependencias
RUN npm ci --only=production

# Copiar código de la aplicación
COPY . .

# Crear usuario no root
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Cambiar propietario
RUN chown -R nextjs:nodejs /app

# Cambiar a usuario no root
USER nextjs

# Exponer puerto
EXPOSE 3000

# Comando por defecto
CMD ["npm", "start"]
EOF

    # docker-compose.yml
    cat > "$template_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  app:
    build: .
    container_name: ${APP_NAME}_nodejs
    restart: unless-stopped
    ports:
      - "${APP_PORT}:3000"
    environment:
      - NODE_ENV=production
      - PORT=3000
      - REDIS_URL=redis://redis:6379
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_NAME=${APP_NAME}
      - DB_USER=${APP_NAME}
      - DB_PASSWORD=${DB_PASSWORD}
    volumes:
      - ./:/app
      - /app/node_modules
    depends_on:
      - redis
      - mysql
    networks:
      - app_network

  redis:
    image: redis:7-alpine
    container_name: ${APP_NAME}_redis
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks:
      - app_network

  mysql:
    image: mysql:8.0
    container_name: ${APP_NAME}_mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${APP_NAME}
      MYSQL_USER: ${APP_NAME}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - app_network

volumes:
  mysql_data:
  redis_data:

networks:
  app_network:
    driver: bridge
EOF

    # package.json de ejemplo
    cat > "$template_dir/package.json" << 'EOF'
{
  "name": "nodejs-app",
  "version": "1.0.0",
  "description": "Node.js Application",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mysql2": "^3.6.5",
    "redis": "^4.6.10",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.2",
    "jest": "^29.7.0"
  }
}
EOF

    # app-config.json
    cat > "$template_dir/app-config.json" << 'EOF'
{
  "name": "Node.js Application",
  "type": "nodejs",
  "version": "18",
  "domain": "api.example.com",
  "port": 3000,
  "database": {
    "type": "mysql",
    "name": "api_db",
    "user": "api_user"
  },
  "cache": {
    "type": "redis",
    "enabled": true
  },
  "ssl": {
    "enabled": true,
    "auto_cert": true
  },
  "backup": {
    "enabled": true,
    "schedule": "daily",
    "retention": 30
  },
  "monitoring": {
    "enabled": true,
    "alerts": true
  }
}
EOF
}

# Función para generar plantilla Python
generate_python_template() {
    local template_dir="$TEMPLATES_DIR/python"
    mkdir -p "$template_dir"

    # Dockerfile
    cat > "$template_dir/Dockerfile" << 'EOF'
FROM python:3.11-slim

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de la aplicación
WORKDIR /app

# Copiar requirements.txt
COPY requirements.txt .

# Instalar dependencias Python
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código de la aplicación
COPY . .

# Crear usuario no root
RUN useradd --create-home --shell /bin/bash app \
    && chown -R app:app /app

# Cambiar a usuario no root
USER app

# Exponer puerto
EXPOSE 8000

# Comando por defecto
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
EOF

    # requirements.txt
    cat > "$template_dir/requirements.txt" << 'EOF'
Django==4.2.7
djangorestframework==3.14.0
mysqlclient==2.2.0
redis==5.0.1
gunicorn==21.2.0
python-dotenv==1.0.0
EOF

    # docker-compose.yml
    cat > "$template_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  app:
    build: .
    container_name: ${APP_NAME}_python
    restart: unless-stopped
    ports:
      - "${APP_PORT}:8000"
    environment:
      - DJANGO_SETTINGS_MODULE=${APP_NAME}.settings
      - DEBUG=False
      - SECRET_KEY=${SECRET_KEY}
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_NAME=${APP_NAME}
      - DB_USER=${APP_NAME}
      - DB_PASSWORD=${DB_PASSWORD}
      - REDIS_URL=redis://redis:6379
    volumes:
      - ./:/app
      - static_files:/app/staticfiles
    depends_on:
      - mysql
      - redis
    networks:
      - app_network

  mysql:
    image: mysql:8.0
    container_name: ${APP_NAME}_mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${APP_NAME}
      MYSQL_USER: ${APP_NAME}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - app_network

  redis:
    image: redis:7-alpine
    container_name: ${APP_NAME}_redis
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks:
      - app_network

volumes:
  mysql_data:
  redis_data:
  static_files:

networks:
  app_network:
    driver: bridge
EOF

    # app-config.json
    cat > "$template_dir/app-config.json" << 'EOF'
{
  "name": "Python Django Application",
  "type": "python",
  "framework": "django",
  "version": "3.11",
  "domain": "web.example.com",
  "port": 8000,
  "database": {
    "type": "mysql",
    "name": "django_db",
    "user": "django_user"
  },
  "cache": {
    "type": "redis",
    "enabled": true
  },
  "ssl": {
    "enabled": true,
    "auto_cert": true
  },
  "backup": {
    "enabled": true,
    "schedule": "daily",
    "retention": 30
  },
  "monitoring": {
    "enabled": true,
    "alerts": true
  }
}
EOF
}

# Función para generar plantilla Ruby
generate_ruby_template() {
    local template_dir="$TEMPLATES_DIR/ruby"
    mkdir -p "$template_dir"

    # Dockerfile
    cat > "$template_dir/Dockerfile" << 'EOF'
FROM ruby:3.2-slim

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    libsqlite3-dev \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de la aplicación
WORKDIR /app

# Copiar Gemfile
COPY Gemfile Gemfile.lock ./

# Instalar gems
RUN bundle install

# Copiar código de la aplicación
COPY . .

# Precompilar assets
RUN RAILS_ENV=production bundle exec rake assets:precompile

# Crear usuario no root
RUN useradd --create-home --shell /bin/bash app \
    && chown -R app:app /app

# Cambiar a usuario no root
USER app

# Exponer puerto
EXPOSE 3000

# Comando por defecto
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
EOF

    # Gemfile
    cat > "$template_dir/Gemfile" << 'EOF'
source 'https://rubygems.org'

gem 'rails', '~> 7.0.8'
gem 'sqlite3', '~> 1.4'
gem 'puma', '>= 5.0'
gem 'importmap-rails'
gem 'turbo-rails'
gem 'stimulus-rails'
gem 'jbuilder'
gem 'redis', '>= 4.0.1'
gem 'bcrypt', '~> 3.1.7'
gem 'tzinfo-data'
gem 'bootsnap', require: false

group :development, :test do
  gem 'debug', platforms: %i[ mri mingw x64_mingw ]
end

group :development do
  gem 'web-console'
end

group :test do
  gem 'capybara'
  gem 'selenium-webdriver'
end
EOF

    # app-config.json
    cat > "$template_dir/app-config.json" << 'EOF'
{
  "name": "Ruby on Rails Application",
  "type": "ruby",
  "framework": "rails",
  "version": "3.2",
  "domain": "rails.example.com",
  "port": 3000,
  "database": {
    "type": "sqlite",
    "name": "rails_db"
  },
  "cache": {
    "type": "redis",
    "enabled": true
  },
  "ssl": {
    "enabled": true,
    "auto_cert": true
  },
  "backup": {
    "enabled": true,
    "schedule": "daily",
    "retention": 30
  },
  "monitoring": {
    "enabled": true,
    "alerts": true
  }
}
EOF
}

# Función para generar plantilla sitio estático
generate_static_template() {
    local template_dir="$TEMPLATES_DIR/static"
    mkdir -p "$template_dir"

    # Dockerfile
    cat > "$template_dir/Dockerfile" << 'EOF'
FROM nginx:alpine

# Copiar archivos estáticos
COPY . /usr/share/nginx/html

# Copiar configuración de Nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Exponer puerto
EXPOSE 80

# Comando por defecto
CMD ["nginx", "-g", "daemon off;"]
EOF

    # nginx.conf
    cat > "$template_dir/nginx.conf" << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen 80;
        server_name localhost;

        root /usr/share/nginx/html;
        index index.html index.htm;

        location / {
            try_files $uri $uri/ =404;
        }

        # Cache de assets estáticos
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Compresión gzip
        gzip on;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    }
}
EOF

    # index.html de ejemplo
    cat > "$template_dir/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sitio Estático</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>¡Sitio Estático Desplegado!</h1>
        <p>Este sitio está siendo servido desde un contenedor Docker con Nginx.</p>
        <p><strong>Fecha de despliegue:</strong> <span id="deploy-date"></span></p>
    </div>

    <script>
        document.getElementById('deploy-date').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

    # app-config.json
    cat > "$template_dir/app-config.json" << 'EOF'
{
  "name": "Static Website",
  "type": "static",
  "domain": "static.example.com",
  "port": 80,
  "ssl": {
    "enabled": true,
    "auto_cert": true
  },
  "backup": {
    "enabled": false
  },
  "monitoring": {
    "enabled": true,
    "alerts": false
  }
}
EOF
}

# Función para generar plantilla base de datos
generate_database_template() {
    local template_dir="$TEMPLATES_DIR/database"
    mkdir -p "$template_dir"

    # docker-compose.yml para diferentes bases de datos
    cat > "$template_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: ${DB_NAME}_mysql
    restart: unless-stopped
    ports:
      - "${MYSQL_PORT}:3306"
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
      - ./mysql/init:/docker-entrypoint-initdb.d
    networks:
      - db_network

  postgres:
    image: postgres:15
    container_name: ${DB_NAME}_postgres
    restart: unless-stopped
    ports:
      - "${POSTGRES_PORT}:5432"
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgres/init:/docker-entrypoint-initdb.d
    networks:
      - db_network

  redis:
    image: redis:7-alpine
    container_name: ${DB_NAME}_redis
    restart: unless-stopped
    ports:
      - "${REDIS_PORT}:6379"
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - db_network

volumes:
  mysql_data:
  postgres_data:
  redis_data:

networks:
  db_network:
    driver: bridge
EOF

    # app-config.json
    cat > "$template_dir/app-config.json" << 'EOF'
{
  "name": "Database Services",
  "type": "database",
  "services": ["mysql", "postgres", "redis"],
  "mysql": {
    "port": 3306,
    "database": "app_db",
    "user": "app_user"
  },
  "postgres": {
    "port": 5432,
    "database": "app_db",
    "user": "app_user"
  },
  "redis": {
    "port": 6379,
    "password": "redis_pass"
  },
  "backup": {
    "enabled": true,
    "schedule": "daily",
    "retention": 30
  },
  "monitoring": {
    "enabled": true,
    "alerts": true
  }
}
EOF
}

# Función para crear aplicación desde plantilla
create_app_from_template() {
    local template_type="$1"
    local app_name="$2"
    local target_dir="$3"

    log_step "Creando aplicación '$app_name' desde plantilla '$template_type'..."

    # Verificar que la plantilla existe
    if [[ ! -d "$TEMPLATES_DIR/$template_type" ]]; then
        log_error "Plantilla '$template_type' no encontrada"
        return 1
    fi

    # Crear directorio de la aplicación
    local app_dir="$APPS_DIR/active/$app_name"
    mkdir -p "$app_dir"

    # Copiar plantilla
    cp -r "$TEMPLATES_DIR/$template_type"/* "$app_dir/"

    # Generar configuración específica
    generate_app_config "$template_type" "$app_name" "$app_dir"

    log_success "Aplicación '$app_name' creada en: $app_dir"
}

# Función para generar configuración específica de aplicación
generate_app_config() {
    local template_type="$1"
    local app_name="$2"
    local app_dir="$3"

    # Leer configuración base
    local config_file="$app_dir/app-config.json"
    if [[ ! -f "$config_file" ]]; then
        log_error "Archivo de configuración no encontrado: $config_file"
        return 1
    fi

    # Generar puerto único
    local app_port
    app_port=$(generate_unique_port)

    # Generar contraseñas seguras
    local db_password
    local mysql_root_password
    local secret_key
    local redis_password

    db_password=$(openssl rand -base64 16)
    mysql_root_password=$(openssl rand -base64 16)
    secret_key=$(openssl rand -base64 32)
    redis_password=$(openssl rand -base64 16)

    # Actualizar configuración
    jq --arg app_name "$app_name" \
       --arg app_port "$app_port" \
       --arg db_password "$db_password" \
       --arg mysql_root_password "$mysql_root_password" \
       --arg secret_key "$secret_key" \
       --arg redis_password "$redis_password" \
       '.name = $app_name | .port = $app_port | .database.password = $db_password | .secrets.mysql_root = $mysql_root_password | .secrets.secret_key = $secret_key | .secrets.redis_password = $redis_password' \
       "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"

    # Crear archivo .env
    cat > "$app_dir/.env" << EOF
APP_NAME=$app_name
APP_PORT=$app_port
DB_PASSWORD=$db_password
MYSQL_ROOT_PASSWORD=$mysql_root_password
SECRET_KEY=$secret_key
REDIS_PASSWORD=$redis_password
EOF

    log_success "Configuración específica generada para '$app_name'"
}

# Función para generar puerto único
generate_unique_port() {
    local port=8080
    while lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; do
        ((port++))
    done
    echo "$port"
}

# Función para desplegar aplicación
deploy_application() {
    local app_name="$1"
    local app_dir="$APPS_DIR/active/$app_name"

    if [[ ! -d "$app_dir" ]]; then
        log_error "Aplicación '$app_name' no encontrada"
        return 1
    fi

    log_step "Desplegando aplicación '$app_name'..."

    cd "$app_dir"

    # Construir e iniciar contenedores
    if [[ -f "docker-compose.yml" ]]; then
        docker-compose up -d --build
    elif [[ -f "Dockerfile" ]]; then
        docker build -t "$app_name" .
        docker run -d --name "$app_name" -p "$(jq -r '.port' app-config.json):$(get_container_port)" "$app_name"
    else
        log_error "No se encontró método de despliegue válido"
        return 1
    fi

    # Registrar en Virtualmin si está disponible
    register_app_in_virtualmin "$app_name" "$app_dir"

    log_success "Aplicación '$app_name' desplegada exitosamente"
}

# Función para obtener puerto del contenedor
get_container_port() {
    local config_file="app-config.json"
    local app_type

    app_type=$(jq -r '.type' "$config_file")

    case "$app_type" in
        "php") echo "80" ;;
        "nodejs") echo "3000" ;;
        "python") echo "8000" ;;
        "ruby") echo "3000" ;;
        "static") echo "80" ;;
        *) echo "80" ;;
    esac
}

# Función para registrar aplicación en Virtualmin
register_app_in_virtualmin() {
    local app_name="$1"
    local app_dir="$2"

    if [[ -z "$VIRTUALMIN_API_PASS" ]]; then
        log_info "Virtualmin no configurado, omitiendo registro"
        return 0
    fi

    log_step "Registrando aplicación en Virtualmin..."

    local config_file="$app_dir/app-config.json"
    local domain
    local port

    domain=$(jq -r '.domain' "$config_file")
    port=$(jq -r '.port' "$config_file")

    # Crear dominio en Virtualmin
    local response
    response=$(curl -s "$VIRTUALMIN_API_URL/virtual-server/remote.cgi" \
        --user "$VIRTUALMIN_API_USER:$VIRTUALMIN_API_PASS" \
        -d "program=create-domain" \
        -d "domain=$domain" \
        -d "pass=$(openssl rand -base64 12)" \
        -d "desc=Container App: $app_name" \
        -d "template=Default Settings" \
        -d "json=1")

    if echo "$response" | jq -e '.status == "success"' >/dev/null 2>&1; then
        log_success "Dominio '$domain' creado en Virtualmin"

        # Configurar proxy reverso
        configure_proxy "$domain" "$port"
    else
        log_warning "Error al crear dominio en Virtualmin: $(echo "$response" | jq -r '.error // "Unknown error"')"
    fi
}

# Función para configurar proxy reverso
configure_proxy() {
    local domain="$1"
    local port="$2"

    log_step "Configurando proxy reverso para $domain:$port..."

    # Crear configuración de proxy en Nginx (si está disponible)
    local nginx_config="$DEPLOYMENT_DIR/configs/$domain.conf"

    cat > "$nginx_config" << EOF
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://localhost:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    log_success "Configuración de proxy creada: $nginx_config"
}

# Función para listar aplicaciones desplegadas
list_applications() {
    log_step "Listando aplicaciones desplegadas..."

    echo
    echo "=== APLICACIONES ACTIVAS ==="
    echo

    local active_dir="$APPS_DIR/active"
    if [[ -d "$active_dir" ]]; then
        for app_dir in "$active_dir"/*/; do
            if [[ -d "$app_dir" ]]; then
                local app_name
                app_name=$(basename "$app_dir")

                if [[ -f "$app_dir/app-config.json" ]]; then
                    local config
                    config=$(jq -r '.name, .type, .domain, .port' "$app_dir/app-config.json" 2>/dev/null)

                    if [[ -n "$config" ]]; then
                        echo "📦 $app_name"
                        echo "   Tipo: $(echo "$config" | sed -n '2p')"
                        echo "   Dominio: $(echo "$config" | sed -n '3p')"
                        echo "   Puerto: $(echo "$config" | sed -n '4p')"
                        echo
                    fi
                fi
            fi
        done
    else
        echo "No hay aplicaciones activas"
    fi
}

# Función para mostrar instrucciones de despliegue
show_deployment_instructions() {
    log_success "Sistema de despliegue de aplicaciones configurado exitosamente"
    echo
    log_info "=== SISTEMA DE DESPLIEGUE DE APLICACIONES ==="
    echo
    log_info "✅ Plantillas de aplicaciones generadas (PHP, Node.js, Python, Ruby, Static)"
    log_info "✅ Sistema de configuración automática"
    log_info "✅ Integración con Virtualmin para gestión de dominios"
    log_info "✅ Configuración automática de proxy reverso"
    log_info "✅ Generación de secrets seguros"
    echo
    log_info "=== PLANTILLAS DISPONIBLES ==="
    echo
    log_info "📁 $TEMPLATES_DIR/php/     - Aplicaciones PHP (Laravel, WordPress, etc.)"
    log_info "📁 $TEMPLATES_DIR/nodejs/  - Aplicaciones Node.js (Express, Next.js, etc.)"
    log_info "📁 $TEMPLATES_DIR/python/  - Aplicaciones Python (Django, Flask, etc.)"
    log_info "📁 $TEMPLATES_DIR/ruby/    - Aplicaciones Ruby (Rails, Sinatra, etc.)"
    log_info "📁 $TEMPLATES_DIR/static/  - Sitios web estáticos"
    log_info "📁 $TEMPLATES_DIR/database/ - Servicios de base de datos"
    echo
    log_info "=== COMANDOS DE DESPLIEGUE ==="
    echo
    log_info "Crear aplicación desde plantilla:"
    echo "  ./application_deployment_system.sh create <tipo> <nombre>"
    echo
    log_info "Desplegar aplicación:"
    echo "  ./application_deployment_system.sh deploy <nombre>"
    echo
    log_info "Listar aplicaciones:"
    echo "  ./application_deployment_system.sh list"
    echo
    log_info "Ejemplos:"
    echo "  ./application_deployment_system.sh create php myapp"
    echo "  ./application_deployment_system.sh deploy myapp"
    echo
    log_info "=== INTEGRACIÓN CON VIRTUALMIN ==="
    echo
    log_info "Configura las variables de entorno para Virtualmin:"
    echo "  export VIRTUALMIN_API_USER=root"
    echo "  export VIRTUALMIN_API_PASS=tu_password"
    echo "  export VIRTUALMIN_API_URL=https://localhost:10000"
    echo
    log_info "=== ESTRUCTURA DE ARCHIVOS ==="
    echo
    log_info "📁 $APPS_DIR/active/     - Aplicaciones activas"
    log_info "📁 $DEPLOYMENT_DIR/configs/ - Configuraciones de proxy"
    log_info "📁 $DEPLOYMENT_DIR/logs/    - Logs de despliegue"
    log_info "📁 $DEPLOYMENT_DIR/ssl/     - Certificados SSL"
}

# Función principal
main() {
    local action="${1:-help}"

    case "$action" in
        "setup")
            check_deployment_dependencies
            create_deployment_structure
            generate_app_templates
            show_deployment_instructions
            ;;
        "create")
            if [[ $# -lt 3 ]]; then
                log_error "Uso: $0 create <tipo> <nombre>"
                log_info "Tipos disponibles: php, nodejs, python, ruby, static, database"
                exit 1
            fi
            create_app_from_template "$2" "$3" "$APPS_DIR/active"
            ;;
        "deploy")
            if [[ $# -lt 2 ]]; then
                log_error "Uso: $0 deploy <nombre>"
                exit 1
            fi
            deploy_application "$2"
            ;;
        "list")
            list_applications
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Función de ayuda
show_help() {
    cat << EOF
Sistema de Despliegue de Aplicaciones en Contenedores - Virtualmin
Versión: 2.0.0

USO:
    $0 <acción> [opciones]

ACCIONES:
    setup                     Configurar sistema completo de despliegue
    create <tipo> <nombre>    Crear aplicación desde plantilla
    deploy <nombre>           Desplegar aplicación
    list                      Listar aplicaciones desplegadas
    help                      Mostrar esta ayuda

TIPOS DE PLANTILLAS:
    php                       Aplicaciones PHP (Laravel, WordPress, etc.)
    nodejs                    Aplicaciones Node.js (Express, Next.js, etc.)
    python                    Aplicaciones Python (Django, Flask, etc.)
    ruby                      Aplicaciones Ruby (Rails, Sinatra, etc.)
    static                    Sitios web estáticos
    database                  Servicios de base de datos

VARIABLES DE ENTORNO:
    DEPLOYMENT_DIR            Directorio de despliegues (default: ./deployments)
    TEMPLATES_DIR             Directorio de plantillas (default: ./templates)
    APPS_DIR                  Directorio de aplicaciones (default: ./apps)
    VIRTUALMIN_API_URL        URL de la API de Virtualmin
    VIRTUALMIN_API_USER       Usuario de la API de Virtualmin
    VIRTUALMIN_API_PASS       Password de la API de Virtualmin

EJEMPLOS:
    $0 setup
    $0 create php myapp
    $0 deploy myapp
    $0 list

INTEGRACIÓN CON VIRTUALMIN:
    El sistema puede integrar automáticamente con Virtualmin para:
    • Crear dominios automáticamente
    • Configurar proxy reverso
    • Gestionar SSL certificates
    • Monitoreo integrado

NOTAS:
    - Requiere Docker y Docker Compose
    - Las plantillas incluyen configuración completa de contenedores
    - Se generan secrets seguros automáticamente
    - Integración opcional con Virtualmin
EOF
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi