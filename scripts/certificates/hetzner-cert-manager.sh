#!/usr/bin/env bash
# =================================================================
#        Hetzner Let's Encrypt Certificate Manager (venv-Edition)
# =================================================================
#
# Version: 5.3 (Stabil & Venv-basiert, korrigierter Router)
# Zweck:   Ein robuster Wrapper zur Anforderung von Zertifikaten,
#          der Certbot und seine Plugins sicher in einer isolierten
#          Python Virtual Environment (venv) verwaltet und die
#          automatische Erneuerung selbstständig einrichten kann.
#
# =================================================================

set -e
set -o pipefail

# --- Feste Pfade & Konfiguration ---
CONFIG_FILE="/etc/hetzner-cert-manager/config.conf"

# --- Funktionen ---
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "FEHLER: Konfigurationsdatei nicht gefunden: $CONFIG_FILE" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
}

setup_logging() {
    LOG_FILE="${LOG_FILE:-/var/log/hetzner-cert-manager.log}"
    if [ "$(id -u)" -eq 0 ]; then
        touch "$LOG_FILE" && chown root:root "$LOG_FILE"
    fi
    # Leite stdout/stderr an die Log-Datei und die Konsole weiter
    exec &> >(tee -a "$LOG_FILE")
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] => $1"
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
      log "FEHLER: Dieses Skript muss mit sudo oder als root ausgeführt werden." >&2
      exit 1
    fi
}

setup_venv() {
    log "Prüfe Python Virtual Environment (venv)..."
    VENV_PATH="${VENV_PATH:-/opt/certbot-venv}"
    CERTBOT_EXEC="$VENV_PATH/bin/certbot"

    if ! dpkg -s python3-venv >/dev/null 2>&1; then
        log "Paket 'python3-venv' fehlt. Installiere es..."
        apt-get update
        apt-get install -y python3-venv
    fi

    if [ ! -f "$CERTBOT_EXEC" ]; then
        log "Erstelle neue venv in '$VENV_PATH'..."
        python3 -m venv "$VENV_PATH"
        log "Installiere certbot und das Hetzner-Plugin in der venv (das kann einen Moment dauern)..."
        "$VENV_PATH/bin/pip" install --upgrade pip
        "$VENV_PATH/bin/pip" install certbot certbot-dns-hetzner
        log "Venv-Setup abgeschlossen."
    else
        log "Venv bereits vorhanden."
    fi
}

setup_renewal_service() {
    log "Richte den systemd-Timer für die automatische Erneuerung ein..."
    VENV_PATH="${VENV_PATH:-/opt/certbot-venv}" # Stelle sicher, dass der Pfad bekannt ist
    CERTBOT_EXEC="$VENV_PATH/bin/certbot"
    SERVICE_FILE="/etc/systemd/system/certbot-renew.service"
    TIMER_FILE="/etc/systemd/system/certbot-renew.timer"

    log "Erstelle Service-Datei: $SERVICE_FILE"
    cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Renew Let's Encrypt certificates using venv certbot

[Service]
Type=oneshot
ExecStart=$CERTBOT_EXEC renew --quiet
EOF

    log "Erstelle Timer-Datei: $TIMER_FILE"
    cat << EOF > "$TIMER_FILE"
[Unit]
Description=Run certbot-renew.service twice daily

[Timer]
OnCalendar=*-*-* 00/12:00:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF

    log "Lade systemd neu und aktiviere den Timer..."
    systemctl daemon-reload
    systemctl enable --now certbot-renew.timer

    log "Prüfe auf konfliktreiche Standard-Timer..."
    if systemctl list-timers | grep -q 'certbot.timer'; then
        log "Konfliktreicher 'certbot.timer' gefunden. Deaktiviere ihn..."
        systemctl disable --now certbot.timer
    else
        log "Kein konfliktreicher Timer gefunden."
    fi

    log "Einrichtung der automatischen Erneuerung abgeschlossen."
    log "Aktueller Timer-Status:"
    systemctl list-timers | grep 'certbot-renew.timer'
}

main_get_cert() {
    # HINWEIS: Die Initialisierungsfunktionen (load_config etc.) werden jetzt VOR diesem Aufruf ausgeführt.
    log "Starte den Zertifikats-Manager..."
    setup_venv

    if [ ! -f "$HETZNER_CREDENTIALS_PATH" ]; then
        log "FEHLER: Hetzner Zugangsdaten-Datei nicht gefunden unter '$HETZNER_CREDENTIALS_PATH'" >&2
        exit 1
    fi
    log "Hetzner-Zugangsdaten-Datei gefunden."

    staging_option=""
    if [ "$STAGING" -eq 1 ]; then
        staging_option="--staging"
        log "STAGING-Modus ist aktiviert."
    fi

    force_renewal_option=""
    if [[ " $@ " =~ " --force-renewal " ]]; then
        log "ERZWUNGENE ERNEUERUNG: --force-renewal Flag wurde erkannt."
        force_renewal_option="--force-renewal"
    fi

    domain_flags=()
    for d in "${DOMAINS[@]}"; do
        domain_flags+=(-d "$d")
    done

    log "Rufe Certbot aus der venv auf für: ${DOMAINS[*]}"
    VENV_PATH="${VENV_PATH:-/opt/certbot-venv}"
    CERTBOT_EXEC="$VENV_PATH/bin/certbot"
    
    "$CERTBOT_EXEC" certonly \
      --authenticator dns-hetzner \
      --dns-hetzner-credentials "$HETZNER_CREDENTIALS_PATH" \
      --non-interactive \
      --agree-tos \
      -m "$EMAIL" \
      "${domain_flags[@]}" \
      $staging_option \
      $force_renewal_option

    log "-------------------------------------------"
    log "Zertifikatsprozess erfolgreich abgeschlossen!"
    log "-------------------------------------------"
}

# --- Skript-Router (Haupteinstiegspunkt) ---

# Initialisierung wird immer zuerst ausgeführt.
load_config
setup_logging
check_root

# Prüfe auf spezielle Kommandos. Wenn keines gegeben ist, wird die Standardaktion ausgeführt.
case "$1" in
    setup-renewal)
        setup_renewal_service
        ;;
    *)
        # Standardaktion: Zertifikat abrufen. Übergibt alle Argumente (z.B. --force-renewal).
        main_get_cert "$@"
        ;;
esac
