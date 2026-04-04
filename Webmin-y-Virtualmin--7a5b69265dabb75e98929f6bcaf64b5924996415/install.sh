#!/bin/bash
set -euo pipefail

readonly REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/yunyminaya/Webmin-y-Virtualmin-/main}"
readonly REMOTE_INSTALLER_URL="${REMOTE_INSTALLER_URL:-${REPO_RAW_BASE}/instalar_webmin_virtualmin.sh}"
readonly OPENVM_ENABLE_BOOTSTRAP="${OPENVM_ENABLE_BOOTSTRAP:-1}"
readonly REMOTE_OPENVM_INSTALLER_URL="${REMOTE_OPENVM_INSTALLER_URL:-${REPO_RAW_BASE}/install_openvm_production.sh}"
readonly PRESERVED_ENV_VARS="VIRTUALMIN_HOSTNAME,VIRTUALMIN_TYPE,VIRTUALMIN_BUNDLE,VIRTUALMIN_DISABLE_HOSTNAME_SSL,VIRTUALMIN_ALLOW_PRECONFIGURED,VIRTUALMIN_ALLOW_GRADE_B,VIRTUALMIN_INSTALL_URL,INSTALL_LOG,REPORT_PATH,VIRTUALMIN_SKIP_REPO_PROFILE,REPO_RAW_BASE,REPO_INSTALLER_URL,REPO_PROFILE_STATUS_FILE,OPENVM_ENABLE_BOOTSTRAP,REMOTE_OPENVM_INSTALLER_URL"

TEMP_DIR=""

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

download_file() {
    local url="$1"
    local destination="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$destination"
        return 0
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -qO "$destination" "$url"
        return 0
    fi

    printf 'Error: curl o wget es requerido para descargar el instalador.\n' >&2
    return 1
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
        download_file "$REMOTE_OPENVM_INSTALLER_URL" "$openvm_installer"
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

    TEMP_DIR="$(mktemp -d /tmp/webmin-virtualmin-bootstrap.XXXXXX)"

    local downloaded_installer="$TEMP_DIR/instalar_webmin_virtualmin.sh"
    download_file "$REMOTE_INSTALLER_URL" "$downloaded_installer"
    chmod 700 "$downloaded_installer"

    run_installer "$downloaded_installer" "$@"
    run_openvm_post_install "$TEMP_DIR" "$@"
}

main "$@"
