#!/bin/bash
set -euo pipefail

readonly REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main}"
readonly REMOTE_INSTALLER_URL="${REMOTE_INSTALLER_URL:-${REPO_RAW_BASE}/instalar_webmin_virtualmin.sh}"
readonly REMOTE_INSTALLER_SHA256="${REMOTE_INSTALLER_SHA256:-df8143dd01b725438a71c353e6087813c366f74f7caf7bfa94c972c5fa668d22}"
readonly OPENVM_ENABLE_BOOTSTRAP="${OPENVM_ENABLE_BOOTSTRAP:-1}"
readonly REMOTE_OPENVM_INSTALLER_URL="${REMOTE_OPENVM_INSTALLER_URL:-${REPO_RAW_BASE}/install_openvm_production.sh}"
readonly REMOTE_OPENVM_INSTALLER_SHA256="${REMOTE_OPENVM_INSTALLER_SHA256:-47f2ee0ee4e6a4907b6c4a3fd095e5e961e23121699d5ab105bf7ba37559b085}"
readonly ALLOW_REMOTE_BOOTSTRAP="${ALLOW_REMOTE_BOOTSTRAP:-0}"
readonly PRESERVED_ENV_VARS="VIRTUALMIN_HOSTNAME,VIRTUALMIN_TYPE,VIRTUALMIN_BUNDLE,VIRTUALMIN_DISABLE_HOSTNAME_SSL,VIRTUALMIN_ALLOW_PRECONFIGURED,VIRTUALMIN_ALLOW_GRADE_B,VIRTUALMIN_INSTALL_URL,INSTALL_LOG,REPORT_PATH,VIRTUALMIN_SKIP_REPO_PROFILE,REPO_RAW_BASE,REPO_INSTALLER_URL,REPO_PROFILE_STATUS_FILE,OPENVM_ENABLE_BOOTSTRAP,REMOTE_OPENVM_INSTALLER_URL,REMOTE_INSTALLER_SHA256,REMOTE_OPENVM_INSTALLER_SHA256,ALLOW_REMOTE_BOOTSTRAP"

TEMP_DIR=""

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

sha256_file() {
    local file_path="$1"

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file_path" | awk '{print $1}'
        return 0
    fi

    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file_path" | awk '{print $1}'
        return 0
    fi

    fail 'No se encontro sha256sum ni shasum para validar integridad.'
}

verify_download_checksum() {
    local file_path="$1"
    local expected_checksum="$2"
    local source_url="$3"
    local actual_checksum=""

    [[ -n "$expected_checksum" ]] || fail "No hay checksum configurado para validar ${source_url}."

    actual_checksum="$(sha256_file "$file_path")"
    [[ "$actual_checksum" == "$expected_checksum" ]] || \
        fail "Checksum invalido para ${source_url}. Esperado: ${expected_checksum} Actual: ${actual_checksum}"
}

download_file() {
    local url="$1"
    local destination="$2"
    local expected_checksum="${3:-}"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$destination"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$destination" "$url"
    else
        fail 'curl o wget es requerido para descargar el instalador.'
    fi

    if [[ -n "$expected_checksum" ]]; then
        verify_download_checksum "$destination" "$expected_checksum" "$url"
    fi
}

run_installer() {
    local installer_path="$1"
    shift

    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        bash "$installer_path" "$@"
        return 0
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        printf 'Error: se requiere root o sudo para continuar.\n' >&2
        return 1
    fi

    sudo --preserve-env="$PRESERVED_ENV_VARS" bash "$installer_path" "$@"
}

run_openvm_post_install() {
    local script_dir="$1"
    shift

    if [[ "$OPENVM_ENABLE_BOOTSTRAP" == "0" ]]; then
        printf 'OpenVM bootstrap deshabilitado por OPENVM_ENABLE_BOOTSTRAP=0\n'
        return 0
    fi

    local openvm_installer=""
    if [[ -f "$script_dir/install_openvm_production.sh" ]]; then
        openvm_installer="$script_dir/install_openvm_production.sh"
    else
        openvm_installer="$TEMP_DIR/install_openvm_production.sh"
        download_file "$REMOTE_OPENVM_INSTALLER_URL" "$openvm_installer" "$REMOTE_OPENVM_INSTALLER_SHA256"
        chmod 700 "$openvm_installer"
    fi

    printf 'Ejecutando post-instalación nativa de OpenVM...\n'
    run_installer "$openvm_installer" "$@"
}

main() {
    local script_source="${BASH_SOURCE[0]-}"
    local script_dir=""
    local local_installer=""

    trap cleanup EXIT INT TERM

    if [[ -n "$script_source" && -f "$script_source" ]]; then
        script_dir="$(CDPATH='' cd -- "$(dirname -- "$script_source")" && pwd)"

        if [[ -f "$script_dir/instalar_webmin_virtualmin.sh" ]]; then
            local_installer="$script_dir/instalar_webmin_virtualmin.sh"
        fi
    fi

    if [[ -n "$local_installer" ]]; then
        run_installer "$local_installer" "$@"
        run_openvm_post_install "$script_dir" "$@"
        return 0
    fi

    if [[ "$ALLOW_REMOTE_BOOTSTRAP" != "1" ]]; then
        fail 'El bootstrap remoto ya no es la ruta soportada para producción. Clona el repositorio y ejecuta install.sh localmente, o exporta ALLOW_REMOTE_BOOTSTRAP=1 para un arranque remoto controlado.'
    fi

    TEMP_DIR="$(mktemp -d /tmp/webmin-virtualmin-bootstrap.XXXXXX)"

    local downloaded_installer="$TEMP_DIR/instalar_webmin_virtualmin.sh"
    download_file "$REMOTE_INSTALLER_URL" "$downloaded_installer" "$REMOTE_INSTALLER_SHA256"
    chmod 700 "$downloaded_installer"

    run_installer "$downloaded_installer" "$@"
    run_openvm_post_install "$TEMP_DIR" "$@"
}

main "$@"
