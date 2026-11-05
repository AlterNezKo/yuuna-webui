#!/usr/bin/env bash
# ==============================================================================
# Yuuna WebUI CLI (yuuna-ui) v2.0.0
# Framework ágil, seguro y rootless para desplegar y gestionar Open WebUI
#
# Autor:    Just Nezu (AlterNezKo)
# Repo:     https://gitlab.com/AlterNezKo/yuuna-webui
# Licencia: GNU GPL v3.0 (SPDX-License-Identifier: GPL-3.0-or-later)
# ==============================================================================

set -euo pipefail

readonly YUUNA_CLI_VERSION="2.0.0"
readonly CONTAINER_NAME="yuuna-webui"
readonly IMAGE_REPO="ghcr.io/open-webui/open-webui"
readonly STORAGE_LOCATION="${YUUNA_STORAGE_DIR:-$HOME/.local/yuuna-webui}"
readonly DATA_DIR="$STORAGE_LOCATION/data"
readonly BACKUP_DIR="$STORAGE_LOCATION/backups"
readonly ENV_FILE="$STORAGE_LOCATION/.env"
readonly BIN_DIR="${YUUNA_BIN_DIR:-$HOME/.local/bin}"
readonly BIN_LINK="$BIN_DIR/yuuna-ui"
readonly RAW_SCRIPT_URL="https://gitlab.com/AlterNezKo/yuuna-webui/-/raw/main/scripts/deploy.sh"

readonly DEFAULT_BIND="127.0.0.1"
readonly DEFAULT_PORT="3000"
readonly HEALTH_TIMEOUT=200

ACTION="deploy"
ACTION_SET=false
TARGET_VERSION="main"
CLI_BIND_ADDR=""
CLI_PORT=""
RECONFIGURE=false
DRY_RUN=false
ALLOW_ROOT=false
RESTORE_TARGET=""

FINAL_BIND_ADDR=""
FINAL_PORT=""

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    readonly C_RESET=$'\033[0m'
    readonly C_BOLD=$'\033[1m'
    readonly C_INFO=$'\033[1;34m'
    readonly C_OK=$'\033[1;32m'
    readonly C_WARN=$'\033[1;33m'
    readonly C_ERR=$'\033[1;31m'
    readonly C_CYAN=$'\033[1;36m'
else
    readonly C_RESET=''
    readonly C_BOLD=''
    readonly C_INFO=''
    readonly C_OK=''
    readonly C_WARN=''
    readonly C_ERR=''
    readonly C_CYAN=''
fi

info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }

ok()   { printf "${C_OK}[OK]${C_RESET}   %s\n" "$*"; }

warn() { printf "${C_WARN}[WARN]${C_RESET} %s\n" "$*" >&2; }

err()  { printf "${C_ERR}[ERR]${C_RESET}  %s\n" "$*" >&2; }

die()  { err "$*"; exit 1; }

run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        printf "${C_CYAN}[DRY-RUN]${C_RESET} %s\n" "$*"
        return 0
    fi
    "$@"
}

show_help() {
    cat <<EOF
${C_BOLD}Yuuna WebUI CLI (yuuna-ui)${C_RESET} — Gestor de despliegue seguro para Open WebUI

${C_BOLD}USO:${C_RESET}
  yuuna-ui [COMANDO | VERSIÓN] [OPCIONES]

${C_BOLD}COMANDOS:${C_RESET}
  deploy [VERSIÓN]          Instala o reconfigura Yuuna WebUI (por defecto: 'main')
  update [VERSIÓN]          Actualiza el contenedor existente manteniendo configuración (por defecto: 'main')
  (sin comando)             Equivale a 'deploy main' (o reconfiguración interactiva)
  <VERSIÓN>                 Atajo para fijar versión o hacer rollback (ej: yuuna-ui v0.11.0)
  start                     Inicia el contenedor detenido
  stop                      Detiene el contenedor liberando memoria RAM
  status                    Muestra el estado actual del contenedor y su configuración
  logs                      Muestra los registros (logs) recientes del contenedor
  backup                    Pausa el contenedor, crea un respaldo seguro y lo reanuda
  backup-restore <ARCHIVO>  Pausa el contenedor, restaura un respaldo (.tar.gz) y lo reanuda

${C_BOLD}OPCIONES:${C_RESET}
  --local                   Fuerza el modo Loopback privado (127.0.0.1)
  --network                 Permite acceso desde Red Local / Cloud (0.0.0.0)
  -p, --port <PUERTO>       Define el puerto de acceso (por defecto: 3000)
  -v, --version             Muestra la versión instalada de Yuuna WebUI CLI
  --reconfigure             Vuelve a abrir el menú interactivo de red y actualiza .env
  --dry-run                 Simula las acciones mostrando los comandos sin ejecutarlos
  --allow-root              Permite ejecutar el script como usuario root (para VPS específicos)
  -h, --help                Muestra esta ayuda

${C_BOLD}EJEMPLOS:${C_RESET}
  yuuna-ui                                 # Instalación inicial o reconfiguración interactiva (deploy)
  yuuna-ui deploy v0.11.0                  # Despliega o reconfigura fijando versión específica
  yuuna-ui update                          # Actualiza el contenedor existente a la última versión (main)
  yuuna-ui update v0.11.0                  # Actualiza o rollback del contenedor a versión específica
  yuuna-ui v0.11.0                         # Atajo para fijar versión o rollback
  yuuna-ui --network --port 8080           # Despliega abierto a la red en el puerto 8080
  yuuna-ui backup                          # Genera un respaldo seguro en ~/.local/yuuna-webui/backups/
  yuuna-ui backup-restore <archivo.tar.gz> # Restaura un respaldo previo de forma segura
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            deploy)
                ACTION="deploy"
                ACTION_SET=true
                shift
                if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
                    TARGET_VERSION="$1"
                    shift
                fi
                ;;
            update)
                ACTION="update"
                ACTION_SET=true
                shift
                if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
                    TARGET_VERSION="$1"
                    shift
                fi
                ;;
            start|stop|status|logs|backup)
                ACTION="$1"
                ACTION_SET=true
                shift
                ;;
            backup-restore)
                ACTION="backup-restore"
                ACTION_SET=true
                shift
                if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
                    RESTORE_TARGET="$1"
                    shift
                fi
                ;;
            --local)
                CLI_BIND_ADDR="127.0.0.1"
                shift
                ;;
            --network)
                CLI_BIND_ADDR="0.0.0.0"
                shift
                ;;
            -p|--port)
                [[ $# -ge 2 ]] || die "La opción '$1' requiere un número de puerto."
                validate_port "$2" "cli"
                CLI_PORT="$2"
                shift 2
                ;;
            -v|--version)
                printf "Yuuna WebUI CLI (yuuna-ui) v%s\n" "$YUUNA_CLI_VERSION"
                exit 0
                ;;
            --reconfigure)
                RECONFIGURE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --allow-root)
                ALLOW_ROOT=true
                shift
                ;;
            -h|--help|help)
                show_help
                exit 0
                ;;
            -*)
                die "Opción desconocida: '$1'. Usa 'yuuna-ui --help' para ver las opciones disponibles."
                ;;
            *)
                if [[ "$ACTION_SET" == true ]]; then
                    die "El comando '$ACTION' no acepta argumentos adicionales ('$1'). Usa 'yuuna-ui --help'."
                elif [[ "$1" =~ ^([vV]?[0-9]+(\.[0-9]+)+.*|main|latest|cuda|ollama|slim)$ ]]; then
                    TARGET_VERSION="$1"
                    ACTION="deploy"
                    ACTION_SET=true
                    shift
                else
                    die "Comando u opción desconocida: '$1'. Usa 'yuuna-ui --help' para ver los comandos disponibles."
                fi
                ;;
        esac
    done
}

check_root() {
    local current_uid="${EUID:-$(id -u)}"
    if [[ "$current_uid" -eq 0 ]]; then
        if [[ "$ALLOW_ROOT" == true ]]; then
            warn "Ejecutando como 'root' (--allow-root activado). Se recomienda un usuario estándar para Podman Rootless."
        else
            err "Por seguridad, Yuuna WebUI está diseñado para ejecutarse en modo Rootless (sin sudo/root)."
            err "Ejecuta este script con tu usuario normal. Si estás en un VPS solo-root, añade '--allow-root'."
            exit 1
        fi
    fi
}

validate_version() {
    local version="${1:-$TARGET_VERSION}"
    if ! [[ "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        die "Versión inválida: '$version'. La versión debe comenzar con un carácter alfanumérico y contener únicamente letras, números, puntos, guiones o guiones bajos. Usa 'yuuna-ui <VERSIÓN>', 'yuuna-ui deploy <VERSIÓN>' o 'yuuna-ui update <VERSIÓN>'."
    fi
}

validate_port() {
    local port="$1"
    local source="${2:-cli}"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        if [[ "$source" == "env" ]]; then
            die "Puerto inválido en .env: '$port'. Debe ser un número entre 1 y 65535. Edita ~/.local/yuuna-webui/.env (o $ENV_FILE) o usa '--port <PUERTO>'."
        else
            die "Puerto inválido: '$port'. Debe ser un número entre 1 y 65535."
        fi
    fi
}

print_install_hint() {
    local distro_id=""
    local distro_like=""
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        distro_id="${ID:-}"
        distro_like="${ID_LIKE:-}"
    fi

    echo "" >&2
    printf "${C_BOLD}Instala las dependencias según tu distribución:${C_RESET}\n" >&2

    if [[ "$distro_id" =~ ^(debian|ubuntu|linuxmint|pop)$ ]] || [[ "$distro_like" == *"debian"* || "$distro_like" == *"ubuntu"* ]]; then
        echo "  -> Debian / Ubuntu / Derivados (APT):" >&2
        echo "     sudo apt update && sudo apt install -y podman openssl curl tar" >&2
    elif [[ "$distro_id" =~ ^(arch|cachyos|manjaro|endeavouros)$ ]] || [[ "$distro_like" == *"arch"* ]]; then
        echo "  -> Arch Linux / CachyOS / Derivados (Pacman):" >&2
        echo "     sudo pacman -Syu --needed podman openssl curl tar" >&2
    elif [[ "$distro_id" =~ ^(fedora|rocky|almalinux|rhel)$ ]] || [[ "$distro_like" == *"fedora"* || "$distro_like" == *"rhel"* ]]; then
        echo "  -> Fedora / Rocky Linux (DNF):" >&2
        echo "     sudo dnf install -y podman openssl curl tar" >&2
    elif [[ "$distro_id" == "solus" ]]; then
        echo "  -> Solus (EOPKG):" >&2
        echo "     sudo eopkg it podman openssl curl tar" >&2
    elif [[ "$distro_id" == "void" ]]; then
        echo "  -> Void Linux (XBPS):" >&2
        echo "     sudo xbps-install -S podman openssl curl tar" >&2
    else
        echo "  * APT (Debian/Ubuntu/Mint): sudo apt update && sudo apt install -y podman openssl curl tar" >&2
        echo "  * Pacman (Arch/CachyOS):    sudo pacman -Syu --needed podman openssl curl tar" >&2
        echo "  * DNF (Fedora/Rocky):       sudo dnf install -y podman openssl curl tar" >&2
        echo "  * EOPKG (Solus):            sudo eopkg it podman openssl curl tar" >&2
        echo "  * XBPS (Void Linux):        sudo xbps-install -S podman openssl curl tar" >&2
    fi
    echo "" >&2
}

require_commands() {
    local missing=()
    local cmd
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        err "Faltan herramientas requeridas en el sistema para esta operación: ${missing[*]}"
        print_install_hint
        exit 1
    fi
}

check_dependencies() {
    info "Verificando dependencias del sistema..."
    require_commands podman openssl curl tar

    if ! podman info >/dev/null 2>&1; then
        err "Podman está instalado, pero no pudo inicializar el entorno Rootless ('podman info' falló)."
        err "Verifica que tu usuario tenga rangos subuid/subgid asignados:"
        err "  sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 \"$USER\" && podman system migrate"
        exit 1
    fi

    ok "Dependencias verificadas (podman, openssl, curl, tar) y Podman operativo."
}

check_port_available() {
    local port="$1"
    if podman container exists "$CONTAINER_NAME" 2>/dev/null; then
        local running
        running=$(podman inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo "false")
        if [[ "$running" == "true" ]]; then
            local current_ports
            current_ports=$(podman port "$CONTAINER_NAME" 2>/dev/null || true)
            if grep -qE ":${port}$" <<< "$current_ports"; then
                return 0
            fi
        fi
    fi

    if command -v ss >/dev/null 2>&1; then
        if ss -tlnH "sport = :${port}" 2>/dev/null | grep -q .; then
            die "El puerto ${port} ya está siendo utilizado por otra aplicación. Usa '--port <OTRO_PUERTO>' para elegir uno libre."
        fi
    fi
}

read_env_value() {
    local key="$1"
    if [[ -f "$ENV_FILE" ]]; then
        grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1 | cut -d'=' -f2- | sed -e 's/^["'\'']//; s/["'\'']$//' || true
    fi
    return 0
}

prompt_network_mode() {
    local choice=""
    echo ""
    printf "${C_BOLD}Selecciona el modo de red para Yuuna WebUI:${C_RESET}\n"
    echo "  1) Local / Loopback (127.0.0.1) — Privacidad total, solo accesible en este equipo [Recomendado]"
    echo "  2) Red Local / Cloud (0.0.0.0)  — Accesible desde otros dispositivos en tu LAN o VPS"
    echo ""

    # Leer de /dev/tty porque con curl | bash la entrada estándar es el script
    if [[ -r /dev/tty ]]; then
        printf "Elige una opción [1/2] (Enter = 1): " >/dev/tty
        read -r choice </dev/tty || choice="1"
    else
        warn "No se detectó terminal interactiva (/dev/tty). Seleccionando modo Local (127.0.0.1) por seguridad."
        choice="1"
    fi

    case "${choice:-1}" in
        1|"")
            FINAL_BIND_ADDR="127.0.0.1"
            info "Modo seleccionado: Local / Loopback (127.0.0.1)"
            ;;
        2)
            FINAL_BIND_ADDR="0.0.0.0"
            warn "Modo seleccionado: Red Local / Cloud (0.0.0.0). El servicio será accesible externamente."
            ;;
        *)
            warn "Opción '${choice}' no reconocida. Aplicando modo seguro por defecto: Local (127.0.0.1)."
            FINAL_BIND_ADDR="127.0.0.1"
            ;;
    esac
}

configure_environment() {
    info "Preparando directorios en $STORAGE_LOCATION..."
    run_cmd mkdir -p "$DATA_DIR" "$BACKUP_DIR"

    local saved_secret=""
    local saved_bind=""
    local saved_port=""

    if [[ -f "$ENV_FILE" ]]; then
        saved_secret=$(read_env_value "WEBUI_SECRET_KEY")
        saved_bind=$(read_env_value "YUUNA_BIND_ADDR")
        saved_port=$(read_env_value "YUUNA_PORT")
    fi

    if [[ -z "$saved_secret" ]]; then
        info "Generando nueva WEBUI_SECRET_KEY para proteger las sesiones..."
        saved_secret=$(openssl rand -hex 32)
    else
        info "Llave de sesión WEBUI_SECRET_KEY existente detectada."
    fi

    if [[ -n "$CLI_BIND_ADDR" ]]; then
        FINAL_BIND_ADDR="$CLI_BIND_ADDR"
        info "Modo de red definido por argumento: $FINAL_BIND_ADDR"
    elif [[ "$RECONFIGURE" == true ]]; then
        prompt_network_mode
    elif [[ -n "$saved_bind" ]]; then
        FINAL_BIND_ADDR="$saved_bind"
        info "Reutilizando modo de red guardado en .env: $FINAL_BIND_ADDR (usa --reconfigure para cambiarlo)"
    elif [[ "$ACTION" == "update" ]]; then
        FINAL_BIND_ADDR="$DEFAULT_BIND"
        info "Instalación previa sin modo de red registrado. Aplicando por defecto: $FINAL_BIND_ADDR"
    else
        prompt_network_mode
    fi

    if [[ -n "$CLI_PORT" ]]; then
        FINAL_PORT="$CLI_PORT"
    elif [[ -n "$saved_port" ]]; then
        FINAL_PORT="$saved_port"
    else
        FINAL_PORT="$DEFAULT_PORT"
    fi

    if [[ -z "$CLI_PORT" && -n "$saved_port" ]]; then
        validate_port "$FINAL_PORT" "env"
    else
        validate_port "$FINAL_PORT" "cli"
    fi

    check_port_available "$FINAL_PORT"

    if [[ "$DRY_RUN" == true ]]; then
        printf "${C_CYAN}[DRY-RUN]${C_RESET} Escribir %s (chmod 600) con YUUNA_BIND_ADDR=%s y YUUNA_PORT=%s\n" \
            "$ENV_FILE" "$FINAL_BIND_ADDR" "$FINAL_PORT"
    else
        umask 077
        cat > "$ENV_FILE" <<EOF
WEBUI_SECRET_KEY=$saved_secret
YUUNA_BIND_ADDR=$FINAL_BIND_ADDR
YUUNA_PORT=$FINAL_PORT
EOF
        chmod 600 "$ENV_FILE"
    fi
}

ensure_local_bin_in_path() {
    if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
        return 0
    fi

    export PATH="$BIN_DIR:$PATH"
    if [[ "$BIN_DIR" != "$HOME/.local/bin" ]]; then
        return 0
    fi

    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    local rc_file
    local updated=false

    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc_file" ]]; then
            if ! grep -Fq ".local/bin" "$rc_file" 2>/dev/null; then
                if [[ "$DRY_RUN" == true ]]; then
                    printf "${C_CYAN}[DRY-RUN]${C_RESET} Añadir '%s' en %s\n" "$path_line" "$rc_file"
                else
                    printf "\n# Añadido por Yuuna WebUI\n%s\n" "$path_line" >> "$rc_file"
                fi
                updated=true
            fi
        fi
    done

    if [[ "$updated" == true ]]; then
        info "Se añadió ~/.local/bin a tu PATH. Abre una nueva terminal o ejecuta: export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
}

install_cli() {
    run_cmd mkdir -p "$BIN_DIR"

    if [[ -e "$STORAGE_LOCATION/deploy.sh" || -L "$STORAGE_LOCATION/deploy.sh" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            printf "${C_CYAN}[DRY-RUN]${C_RESET} rm -f %s\n" "$STORAGE_LOCATION/deploy.sh"
        else
            rm -f "$STORAGE_LOCATION/deploy.sh"
        fi
    fi

    local script_source="${BASH_SOURCE[0]:-}"
    local is_already_installed=false

    if [[ -n "$script_source" && -f "$script_source" ]]; then
        if [[ -f "$BIN_LINK" && ! -L "$BIN_LINK" ]]; then
            local src_real dst_real
            src_real=$(readlink -f "$script_source" 2>/dev/null || echo "$script_source")
            dst_real=$(readlink -f "$BIN_LINK" 2>/dev/null || echo "$BIN_LINK")
            if [[ "$src_real" == "$dst_real" ]]; then
                is_already_installed=true
            fi
        fi
    fi

    if [[ "$is_already_installed" == true ]]; then
        ensure_local_bin_in_path
        return 0
    fi

    local tmp_script="${BIN_LINK}.tmp"

    if [[ "$DRY_RUN" == true ]]; then
        if [[ -n "$script_source" && -f "$script_source" ]]; then
            printf "${C_CYAN}[DRY-RUN]${C_RESET} Copiar %s a %s, validar con bash -n y mover a %s\n" \
                "$script_source" "$tmp_script" "$BIN_LINK"
        else
            printf "${C_CYAN}[DRY-RUN]${C_RESET} Descargar %s a %s, validar con bash -n y mover a %s\n" \
                "$RAW_SCRIPT_URL" "$tmp_script" "$BIN_LINK"
        fi
        printf "${C_CYAN}[DRY-RUN]${C_RESET} chmod 755 %s\n" "$BIN_LINK"
        ensure_local_bin_in_path
        return 0
    fi

    rm -f "$tmp_script"

    if [[ -n "$script_source" && -f "$script_source" ]]; then
        info "Instalando ejecutable CLI en $BIN_LINK..."
        if ! cp -f "$script_source" "$tmp_script"; then
            rm -f "$tmp_script"
            die "Error al copiar el script a '$tmp_script'."
        fi
    else
        info "Descargando ejecutable CLI en $BIN_LINK..."
        if ! curl -fsSL "$RAW_SCRIPT_URL" -o "$tmp_script"; then
            rm -f "$tmp_script"
            die "Error al descargar el script desde '$RAW_SCRIPT_URL'."
        fi
    fi

    if [[ ! -s "$tmp_script" ]]; then
        rm -f "$tmp_script"
        die "El script descargado o copiado en '$tmp_script' está vacío."
    fi

    if ! bash -n "$tmp_script" >/dev/null 2>&1; then
        rm -f "$tmp_script"
        die "La verificación de sintaxis ('bash -n') falló para '$tmp_script'."
    fi

    chmod 755 "$tmp_script"
    # Instalación atómica mediante archivo temporal y mv
    if ! mv -f "$tmp_script" "$BIN_LINK"; then
        rm -f "$tmp_script"
        die "Error al mover '$tmp_script' a '$BIN_LINK'."
    fi

    ensure_local_bin_in_path
    ok "Comando 'yuuna-ui' disponible en $BIN_LINK"
}

is_selinux_active() {
    if command -v getenforce >/dev/null 2>&1; then
        local mode
        mode=$(getenforce 2>/dev/null || echo "Disabled")
        if [[ "$mode" == "Enforcing" || "$mode" == "Permissive" ]]; then
            return 0
        fi
    elif [[ -f /sys/fs/selinux/enforce ]]; then
        return 0
    fi
    return 1
}

deploy_container() {
    local pull_mode="${1:---pull=always}"
    local image="${2:-${IMAGE_REPO}:${TARGET_VERSION}}"
    local volume_spec="$DATA_DIR:/app/backend/data"
    # Etiqueta :z del volumen solo si SELinux está activo
    if is_selinux_active; then
        info "SELinux activo detectado: añadiendo etiqueta ':z' al volumen de datos."
        volume_spec="${volume_spec}:z"
    fi

    info "Iniciando ${CONTAINER_NAME} con imagen '${image}'..."
    run_cmd podman run -d \
        --name "$CONTAINER_NAME" \
        --replace \
        "$pull_mode" \
        -p "${FINAL_BIND_ADDR}:${FINAL_PORT}:8080" \
        --env-file "$ENV_FILE" \
        -v "$volume_spec" \
        --restart always \
        "$image"
}

detect_lan_ip() {
    local ip=""
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -n 1 || true)
    fi
    if [[ -z "$ip" ]] && command -v hostname >/dev/null 2>&1; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
    fi
    echo "${ip:-<IP_DE_TU_SERVIDOR>}"
}

show_troubleshooting_logs() {
    echo "" >&2
    err "El servicio no logró responder a tiempo o el contenedor se detuvo."
    err "Mostrando las últimas 25 líneas de 'podman logs $CONTAINER_NAME':"
    echo "----------------------------------------------------------------------" >&2
    podman logs --tail 25 "$CONTAINER_NAME" >&2 || true
    echo "----------------------------------------------------------------------" >&2
}

wait_for_healthy() {
    local port="$1"
    if [[ "$DRY_RUN" == true ]]; then
        printf "${C_CYAN}[DRY-RUN]${C_RESET} Sondear estado del contenedor '%s' y http://127.0.0.1:%s/health (timeout %ss)\n" \
            "$CONTAINER_NAME" "$port" "$HEALTH_TIMEOUT"
        return 0
    fi

    info "Verificando que el contenedor y el backend de Open WebUI estén listos (máx. ${HEALTH_TIMEOUT}s)..."
    local elapsed=0
    local step=2
    local health_url="http://127.0.0.1:${port}/health"

    while (( elapsed < HEALTH_TIMEOUT )); do
        local running
        running=$(podman inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo "false")
        if [[ "$running" != "true" ]]; then
            printf "\n" >&2
            err "El contenedor '$CONTAINER_NAME' se detuvo inesperadamente."
            show_troubleshooting_logs
            exit 1
        fi

        if curl -sf --max-time 2 "$health_url" >/dev/null 2>&1; then
            printf "\r${C_OK}[OK]${C_RESET}   Backend inicializado y respondiendo correctamente (%ds).          \n" "$elapsed"
            return 0
        fi

        printf "\r${C_INFO}[...]${C_RESET}  Inicializando base de datos y servicios de IA... [%ds/%ds]" "$elapsed" "$HEALTH_TIMEOUT"
        sleep "$step"
        elapsed=$(( elapsed + step ))
    done

    printf "\n" >&2
    show_troubleshooting_logs
    exit 1
}

print_access_urls() {
    local bind="$1"
    local port="$2"

    printf "  * ${C_BOLD}Acceso Local:${C_RESET}       http://127.0.0.1:%s\n" "$port"
    if [[ "$bind" == "0.0.0.0" ]]; then
        local lan_ip
        lan_ip=$(detect_lan_ip)
        printf "  * ${C_BOLD}Acceso Red / LAN:${C_RESET}   http://%s:%s\n" "$lan_ip" "$port"
        echo ""
        warn "Aviso de Seguridad: El puerto ${port} está expuesto en 0.0.0.0."
        warn "Si estás en un VPS en la nube, recuerda usar un proxy inverso con HTTPS (Caddy/Nginx) o restringir tu firewall."
    fi
}

print_summary() {
    echo ""
    echo "======================================================================"
    printf "${C_OK}¡Proceso finalizado con éxito! <3${C_RESET}\n"
    echo "Yuuna WebUI está corriendo y verificado."
    echo ""
    print_access_urls "$FINAL_BIND_ADDR" "$FINAL_PORT"
    echo ""
    echo "Comandos rápidos disponibles con 'yuuna-ui':"
    echo "  yuuna-ui status                    # Ver estado del contenedor"
    echo "  yuuna-ui stop / start              # Detener o iniciar para ahorrar RAM"
    echo "  yuuna-ui update                    # Actualizar a la última versión"
    echo "  yuuna-ui v0.11.0                   # Cambiar o volver a una versión específica"
    echo "  yuuna-ui backup                    # Crear copia de seguridad en ~/.local/yuuna-webui/backups/"
    echo "  yuuna-ui backup-restore <archivo>  # Restaurar copia de seguridad"
    echo "======================================================================"
}

require_container_exists() {
    if ! podman container exists "$CONTAINER_NAME" 2>/dev/null; then
        die "El contenedor '$CONTAINER_NAME' aún no existe. Ejecuta 'yuuna-ui deploy' para desplegarlo primero."
    fi
}

cmd_start() {
    require_container_exists
    local bind_addr port
    bind_addr=$(read_env_value "YUUNA_BIND_ADDR")
    bind_addr="${bind_addr:-$DEFAULT_BIND}"
    port=$(read_env_value "YUUNA_PORT")
    if [[ -n "$port" ]]; then
        validate_port "$port" "env"
    fi
    port="${port:-$DEFAULT_PORT}"

    info "Iniciando $CONTAINER_NAME..."
    run_cmd podman start "$CONTAINER_NAME"
    wait_for_healthy "$port"
    ok "Yuuna WebUI está activo."
    print_access_urls "$bind_addr" "$port"
}

cmd_stop() {
    require_container_exists
    info "Deteniendo $CONTAINER_NAME..."
    run_cmd podman stop "$CONTAINER_NAME"
    ok "Contenedor detenido y memoria liberada."
}

cmd_status() {
    if ! podman container exists "$CONTAINER_NAME" 2>/dev/null; then
        warn "Estado: No instalado (el contenedor '$CONTAINER_NAME' no existe)."
        return 0
    fi

    local state image bind_addr port
    state=$(podman inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "desconocido")
    image=$(podman inspect -f '{{.Config.Image}}' "$CONTAINER_NAME" 2>/dev/null || echo "desconocida")
    bind_addr=$(read_env_value "YUUNA_BIND_ADDR")
    bind_addr="${bind_addr:-$DEFAULT_BIND}"
    port=$(read_env_value "YUUNA_PORT")
    if [[ -n "$port" ]]; then
        validate_port "$port" "env"
    fi
    port="${port:-$DEFAULT_PORT}"

    echo "======================================================================"
    printf "${C_BOLD}Estado de Yuuna WebUI${C_RESET}\n"
    echo "----------------------------------------------------------------------"
    echo "  Contenedor : $CONTAINER_NAME ($state)"
    echo "  Imagen     : $image"
    echo "  Red / Bind : ${bind_addr}:${port}"
    echo "  Datos      : $DATA_DIR"
    echo "  Respaldos  : $BACKUP_DIR"

    if [[ "$state" == "running" ]]; then
        if curl -sf --max-time 2 "http://127.0.0.1:${port}/health" >/dev/null 2>&1; then
            printf "  Salud HTTP : ${C_OK}Saludable (200 OK)${C_RESET}\n"
        else
            printf "  Salud HTTP : ${C_WARN}Iniciando o sin respuesta en /health${C_RESET}\n"
        fi
        echo ""
        print_access_urls "$bind_addr" "$port"
    fi
    echo "======================================================================"
}

cmd_logs() {
    require_container_exists
    info "Mostrando registros de '$CONTAINER_NAME' (Ctrl+C para salir)..."
    run_cmd podman logs --tail 50 -f "$CONTAINER_NAME"
}

cmd_backup() {
    if [[ ! -d "$DATA_DIR" ]]; then
        die "No se encontró el directorio de datos ($DATA_DIR) para respaldar."
    fi

    run_cmd mkdir -p "$BACKUP_DIR"
    local timestamp backup_file was_running="false"
    timestamp=$(date +%F_%H%M%S)
    backup_file="$BACKUP_DIR/yuuna-backup-${timestamp}.tar.gz"

    if podman container exists "$CONTAINER_NAME" 2>/dev/null; then
        was_running=$(podman inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo "false")
    fi

    if [[ "$was_running" == "true" ]]; then
        info "Deteniendo temporalmente '$CONTAINER_NAME' para asegurar la integridad de la base de datos..."
        run_cmd podman stop "$CONTAINER_NAME"
    fi

    info "Comprimiendo datos en $backup_file..."
    local items_to_pack=("data")
    [[ -f "$ENV_FILE" ]] && items_to_pack+=(".env")

    run_cmd tar -czf "$backup_file" -C "$STORAGE_LOCATION" "${items_to_pack[@]}"
    if [[ "$DRY_RUN" == false ]]; then
        chmod 600 "$backup_file"
    fi
    ok "Copia de seguridad creada exitosamente: $backup_file"

    if [[ "$was_running" == "true" ]]; then
        info "Volviendo a encender '$CONTAINER_NAME'..."
        run_cmd podman start "$CONTAINER_NAME"
        local port
        port=$(read_env_value "YUUNA_PORT")
        if [[ -n "$port" ]]; then
            validate_port "$port" "env"
        fi
        port="${port:-$DEFAULT_PORT}"
        wait_for_healthy "$port"
    fi
}

cmd_backup_restore() {
    if [[ -z "$RESTORE_TARGET" ]]; then
        err "Debes indicar el archivo de respaldo a restaurar."
        echo "Uso: yuuna-ui backup-restore <ruta-al-archivo.tar.gz>" >&2
        if [[ -d "$BACKUP_DIR" ]]; then
            echo "" >&2
            echo "Respaldos disponibles en $BACKUP_DIR:" >&2
            ls -1t "$BACKUP_DIR"/yuuna-backup-*.tar.gz 2>/dev/null | sed 's/^/  /' >&2 || echo "  (Ninguno)" >&2
        fi
        exit 1
    fi

    local archive_path="$RESTORE_TARGET"
    if [[ ! -f "$archive_path" && -f "$BACKUP_DIR/$RESTORE_TARGET" ]]; then
        archive_path="$BACKUP_DIR/$RESTORE_TARGET"
    fi

    [[ -f "$archive_path" ]] || die "No se encontró el archivo de respaldo: '$RESTORE_TARGET'"

    info "Verificando integridad y estructura del archivo $archive_path..."
    local archive_listing
    if ! archive_listing=$(tar -tzf "$archive_path" 2>/dev/null); then
        die "El archivo '$archive_path' está corrupto o no es un archivo .tar.gz válido."
    fi

    if grep -qE '^/' <<< "$archive_listing" || grep -qE '(^|/)\.\.(/|$)' <<< "$archive_listing"; then
        die "El archivo de respaldo contiene rutas inseguras (rutas absolutas o componentes '..'). Restauración abortada."
    fi

    if ! grep -qE '^(\./)?data/' <<< "$archive_listing"; then
        die "Formato de respaldo antiguo o no soportado (se requiere 'data/' en la raíz). Por favor, extrae manualmente."
    fi

    warn "¡ADVERTENCIA! Esta operación reemplazará todos tus chats y datos actuales en:"
    warn "  $DATA_DIR"
    warn "con el contenido del respaldo:"
    warn "  $archive_path"

    if [[ "$DRY_RUN" == false ]]; then
        if [[ -r /dev/tty ]]; then
            local confirm=""
            printf "¿Estás seguro de que deseas continuar? [s/N]: " >/dev/tty
            read -r confirm </dev/tty || confirm="n"
            if [[ ! "$confirm" =~ ^[sS]([iI])?$ && ! "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
                info "Restauración cancelada por el usuario."
                exit 0
            fi
        else
            die "Se requiere una terminal interactiva para confirmar la restauración."
        fi
    fi

    local container_exists=false
    local was_running=false
    local current_image=""
    if podman container exists "$CONTAINER_NAME" 2>/dev/null; then
        container_exists=true
        current_image=$(podman inspect -f '{{.Config.Image}}' "$CONTAINER_NAME" 2>/dev/null || echo "${IMAGE_REPO}:${TARGET_VERSION}")
        local running_status
        running_status=$(podman inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo "false")
        if [[ "$running_status" == "true" ]]; then
            was_running=true
            info "Deteniendo contenedor '$CONTAINER_NAME'..."
            run_cmd podman stop "$CONTAINER_NAME" || true
        fi
    fi

    if [[ "$DRY_RUN" == true ]]; then
        printf "${C_CYAN}[DRY-RUN]${C_RESET} mktemp -d %s/.restore-XXXXXX\n" "$STORAGE_LOCATION"
        printf "${C_CYAN}[DRY-RUN]${C_RESET} tar -xzf %s -C <temporal> --no-same-owner\n" "$archive_path"
        printf "${C_CYAN}[DRY-RUN]${C_RESET} Validar existencia de <temporal>/data\n"
        if [[ -d "$DATA_DIR" ]]; then
            printf "${C_CYAN}[DRY-RUN]${C_RESET} rm -rf %s\n" "$DATA_DIR"
        fi
        printf "${C_CYAN}[DRY-RUN]${C_RESET} mv <temporal>/data %s\n" "$DATA_DIR"
        if grep -qE '^(\./)?\.env$' <<< "$archive_listing"; then
            printf "${C_CYAN}[DRY-RUN]${C_RESET} cp <temporal>/.env %s && chmod 600 %s\n" "$ENV_FILE" "$ENV_FILE"
        fi
        if [[ "$container_exists" == true ]]; then
            printf "${C_CYAN}[DRY-RUN]${C_RESET} Recrear contenedor %s (imagen %s)\n" "$CONTAINER_NAME" "$current_image"
        fi
        return 0
    fi

    local restore_tmp=""
    local restore_succeeded=false
    cleanup_restore() {
        if [[ -n "$restore_tmp" && -d "$restore_tmp" ]]; then
            rm -rf "$restore_tmp"
        fi
        if [[ "$was_running" == true && "$restore_succeeded" == false ]]; then
            warn "La restauración no se completó. Reiniciando '$CONTAINER_NAME' para evitar dejarlo detenido..."
            podman start "$CONTAINER_NAME" >/dev/null 2>&1 || true
        fi
    }
    trap cleanup_restore EXIT

    # Extraer en temporal y validar antes de reemplazar data
    mkdir -p "$STORAGE_LOCATION"
    restore_tmp=$(mktemp -d "$STORAGE_LOCATION/.restore-XXXXXX")

    info "Extrayendo respaldo en directorio temporal..."
    if ! tar -xzf "$archive_path" -C "$restore_tmp" --no-same-owner; then
        die "Error al extraer el archivo de respaldo '$archive_path'."
    fi

    if [[ ! -d "$restore_tmp/data" ]]; then
        die "El respaldo extraído no contiene el directorio 'data/' requerido. Operación abortada."
    fi

    if [[ -d "$DATA_DIR" ]]; then
        info "Limpiando datos actuales en $DATA_DIR..."
        rm -rf "$DATA_DIR"
    fi

    info "Instalando datos restaurados en $DATA_DIR..."
    mv "$restore_tmp/data" "$DATA_DIR"

    if [[ -f "$restore_tmp/.env" ]]; then
        info "El respaldo incluye configuración (.env). Restaurando en $ENV_FILE..."
        cp "$restore_tmp/.env" "$ENV_FILE"
        chmod 600 "$ENV_FILE"
    fi

    ok "Datos restaurados correctamente."
    restore_succeeded=true

    if [[ "$container_exists" == true ]]; then
        local restored_bind restored_port
        restored_bind=$(read_env_value "YUUNA_BIND_ADDR")
        restored_bind="${restored_bind:-$DEFAULT_BIND}"
        restored_port=$(read_env_value "YUUNA_PORT")
        if [[ -n "$restored_port" ]]; then
            validate_port "$restored_port" "env"
        fi
        FINAL_BIND_ADDR="$restored_bind"
        FINAL_PORT="${restored_port:-$DEFAULT_PORT}"

        info "Recreando contenedor '$CONTAINER_NAME' para aplicar la configuración restaurada..."
        deploy_container "--pull=never" "$current_image"
        wait_for_healthy "$FINAL_PORT"
        ok "Yuuna WebUI restaurado y activo."
        print_access_urls "$FINAL_BIND_ADDR" "$FINAL_PORT"
    else
        info "Para levantar el entorno con una versión específica, ejecuta: yuuna-ui <versión>"
    fi

    cleanup_restore
    trap - EXIT
}

main() {
    parse_args "$@"
    check_root

    if [[ "$ACTION" == "deploy" || "$ACTION" == "update" ]]; then
        validate_version
    fi

    case "$ACTION" in
        deploy)
            check_dependencies
            configure_environment
            install_cli
            deploy_container
            wait_for_healthy "$FINAL_PORT"
            print_summary
            ;;
        update)
            require_container_exists
            check_dependencies
            configure_environment
            deploy_container
            wait_for_healthy "$FINAL_PORT"
            print_summary
            ;;
        start)
            require_commands podman curl
            cmd_start
            ;;
        stop)
            require_commands podman
            cmd_stop
            ;;
        status)
            require_commands podman curl
            cmd_status
            ;;
        logs)
            require_commands podman
            cmd_logs
            ;;
        backup)
            require_commands podman tar
            cmd_backup
            ;;
        backup-restore)
            require_commands podman tar
            cmd_backup_restore
            ;;
        *)
            die "Acción desconocida: '$ACTION'"
            ;;
    esac
}

# Llamada a main al final para evitar ejecución parcial si se corta la descarga
main "$@"
