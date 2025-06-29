#!/usr/bin/env bash

# =================================================================
#         Hetzner DNS-01 Challenge Automatisierungsskript
# =================================================================
#
# Autor: Gemini (basierend auf Nutzeranforderungen)
# Version: 2.1
# Zweck: Automatisches Anfordern von Let's Encrypt Zertifikaten
#        via DNS-01 Challenge mit der Hetzner DNS API.
#
# =================================================================

# Stoppt das Skript sofort bei Fehlern
set -e
set -o pipefail

# --- Konfiguration und Initialisierung ---

# Fester Pfad zur Konfigurationsdatei für maximale Robustheit
CONFIG_FILE="/etc/hetzner-dns/hetzner-dns.conf"

# Lade zuerst die Konfiguration, um den LOG_FILE Pfad zu erhalten
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Setze einen Standard-Logpfad, falls nicht in der Config definiert
LOG_FILE="${LOG_FILE:-/var/log/hetzner-cert.log}"

# Stelle sicher, dass die Log-Datei existiert und für root schreibbar ist,
# da Certbot und seine Hooks als root laufen.
if [ "$(id -u)" -eq 0 ]; then
    touch "$LOG_FILE"
    chown root:root "$LOG_FILE"
fi

# Leite alle Ausgaben (stdout und stderr) in die Log-Datei um
# und zeige sie gleichzeitig auf dem Bildschirm an (dank tee).
# Diese Zeile wird nur ausgeführt, wenn das Skript als root läuft.
if [ "$(id -u)" -eq 0 ]; then
    exec &> >(tee -a "$LOG_FILE")
fi

# Funktion zum Ausgeben von formatierten Nachrichten
log() {
    # Fügt einen Zeitstempel hinzu
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] => $1"
}

# Funktion zum Laden der Konfiguration
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
        echo "!! FEHLER: Konfigurationsdatei nicht gefunden!    !!" >&2
        echo "!! Erwartet: $CONFIG_FILE  !!" >&2
        echo "!! Bitte die Installationsanleitung in der README.md befolgen. !!" >&2
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
        exit 1
    fi
    # Konfiguration ist bereits am Anfang des Skripts geladen worden.
    log "Konfiguration aus $CONFIG_FILE geladen."

    # Überprüfen, ob wichtige Variablen gesetzt sind
    if [ -z "$HETZNER_DNS_TOKEN" ] || [ -z "$EMAIL" ] || [ ${#DOMAINS[@]} -eq 0 ]; then
        echo "FEHLER: HETZNER_DNS_TOKEN, EMAIL oder DOMAINS sind in der Konfigurationsdatei nicht gesetzt." >&2
        exit 1
    fi
}

# Funktion zur Überprüfung von Abhängigkeiten
check_dependencies() {
    log "Prüfe Abhängigkeiten..."
    REQUIRED_CMDS=("curl" "jq" "certbot")
    MISSING_CMDS=()

    for CMD in "${REQUIRED_CMDS[@]}"; do
        if ! command -v "$CMD" >/dev/null 2>&1; then
            MISSING_CMDS+=("$CMD")
        fi
    done

    if [ ${#MISSING_CMDS[@]} -gt 0 ]; then
        echo "WARNUNG: Folgende Pakete fehlen: ${MISSING_CMDS[*]}"
        
        if [[ "$AUTO_INSTALL_DEPENDENCIES" == "TRUE" ]]; then
            log "AUTO_INSTALL_DEPENDENCIES=TRUE: Installiere fehlende Pakete automatisch."
            sudo apt-get update && sudo apt-get install -y "${MISSING_CMDS[@]}"
        else
            read -p "Sollen die fehlenden Pakete installiert werden? (j/N) " -n 1 -r REPLY
            echo
            if [[ $REPLY =~ ^[Jj]$ ]]; then
                sudo apt-get update && sudo apt-get install -y "${MISSING_CMDS[@]}"
            else
                echo "Installation abgebrochen. Bitte installieren Sie die Pakete manuell."
                exit 1
            fi
        fi
    else
        log "Alle Abhängigkeiten sind erfüllt."
    fi
}


# --- Hetzner API Funktionen ---

# Funktion, die robust die Zone-ID für eine Domain findet
find_zone_id() {
    local domain_to_check="$1"
    # Entferne Wildcard-Präfix für die Zonensuche
    domain_to_check=${domain_to_check#"\*."}
    
    while true; do
        response=$(curl -s -H "Auth-API-Token: ${HETZNER_DNS_TOKEN}" \
            "https://dns.hetzner.com/api/v1/zones?name=${domain_to_check}")
        
        zone_id=$(echo "$response" | jq -r ".zones[] | select(.name == \"${domain_to_check}\") | .id")

        if [[ -n "$zone_id" ]]; then
            echo "$zone_id"
            return 0
        fi

        if [[ "$domain_to_check" != *.* ]]; then
            break
        fi
        domain_to_check="${domain_to_check#*.}"
    done

    echo "FEHLER: Konnte keine passende Zone-ID für die Domain $1 finden." >&2
    return 1
}

# --- Certbot Hooks ---

auth_hook() {
    log "Auth-Hook für Domain: $CERTBOT_DOMAIN"
    ZONE_ID=$(find_zone_id "$CERTBOT_DOMAIN")
    if [ -z "$ZONE_ID" ]; then exit 1; fi
    log "Gefundene Zone-ID: $ZONE_ID"

    # Der Name des TXT-Records ist _acme-challenge, nicht _acme-challenge.domain.com
    # Hetzner fügt den Domainnamen automatisch hinzu.
    RECORD_NAME="_acme-challenge"

    log "Erstelle TXT-Eintrag '$RECORD_NAME'..."
    curl -s -X POST "https://dns.hetzner.com/api/v1/records" \
         -H "Content-Type: application/json" \
         -H "Auth-API-Token: ${HETZNER_DNS_TOKEN}" \
         -d "{\"value\":\"${CERTBOT_VALIDATION}\",\"ttl\":60,\"type\":\"TXT\",\"name\":\"${RECORD_NAME}\",\"zone_id\":\"${ZONE_ID}\"}"

    log "Warte 60 Sekunden auf DNS-Propagation..."
    sleep 60
    log "Auth-Hook abgeschlossen."
}

cleanup_hook() {
    log "Cleanup-Hook für Domain: $CERTBOT_DOMAIN"
    ZONE_ID=$(find_zone_id "$CERTBOT_DOMAIN")
    if [ -z "$ZONE_ID" ]; then exit 1; fi
    log "Gefundene Zone-ID: $ZONE_ID"

    RECORD_NAME="_acme-challenge"

    log "Suche nach zu löschenden TXT-Einträgen mit Namen '$RECORD_NAME'..."
    RECORD_IDS=$(curl -s -H "Auth-API-Token: ${HETZNER_DNS_TOKEN}" \
        "https://dns.hetzner.com/api/v1/records?zone_id=${ZONE_ID}" | \
        jq -r ".records[] | select(.type == \"TXT\" and .name == \"${RECORD_NAME}\") | .id")

    if [ -z "$RECORD_IDS" ]; then
        log "Keine passenden TXT-Einträge zum Löschen gefunden."
        return
    fi

    for RECORD_ID in $RECORD_IDS; do
        log "Lösche TXT-Eintrag mit ID: $RECORD_ID"
        curl -s -X DELETE -H "Auth-API-Token: ${HETZNER_DNS_TOKEN}" \
             "https://dns.hetzner.com/api/v1/records/${RECORD_ID}"
    done
    log "Cleanup-Hook abgeschlossen."
}

# --- Hauptprozess ---

main_cert_process() {
    load_config
    check_dependencies

    log "Starte den Zertifikatsabruf..."

    local staging_option=""
    if [ "$STAGING" -eq 1 ]; then
        staging_option="--staging"
        log "STAGING-Modus ist aktiviert."
    else
        log "PRODUKTIV-Modus: Echte Zertifikate werden angefordert."
    fi

    local certbot_domains=()
    for d in "${DOMAINS[@]}"; do
        certbot_domains+=(-d "$d")
    done

    log "Rufe Certbot für folgende Domains auf: ${DOMAINS[*]}"
    sudo certbot certonly \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --manual \
        --preferred-challenges=dns \
        --manual-auth-hook "$(realpath "$0") auth" \
        --manual-cleanup-hook "$(realpath "$0") cleanup" \
        --manual-public-ip-logging-ok \
        --expand \
        $staging_option \
        "${certbot_domains[@]}"

    log "Zertifikatsprozess abgeschlossen."
}

# --- Skript-Router ---

case "$1" in
    auth)
        auth_hook
        ;;
    cleanup)
        cleanup_hook
        ;;
    *)
        main_cert_process
        ;;
esac
