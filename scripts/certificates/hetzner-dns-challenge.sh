#!/bin/bash
# hetzner-dns-challenge.sh
#
# Nutzung:
#   ./certificate_manager.sh             -> Startet den Zertifikatsabrufprozess
#   ./certificate_manager.sh auth        -> Führt den Authentifizierungshook aus (DNS TXT-Eintrag erstellen)
#   ./certificate_manager.sh cleanup     -> Führt den Cleanup-Hook aus (DNS TXT-Eintrag löschen)
#
# Hinweis: Stelle sicher, dass jq installiert ist (z. B. mit "sudo apt install jq")

set -e

# Überprüfe, ob alle erforderlichen Programme installiert sind
REQUIRED=("sudo" "jq" "certbot" "curl")
MISSING=()

for CMD in "${REQUIRED[@]}"; do
  if ! command -v "$CMD" >/dev/null 2>&1; then
    MISSING+=("$CMD")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "Es fehlen zur Ausführung erforderliche Programme: ${MISSING[*]}"
  echo "Bitte installieren Sie diese, z.B. mit:"
  echo "  sudo apt update && sudo apt install ${MISSING[*]}"
  exit 1
fi

echo "Alle erforderlichen Programme sind installiert."

# Überprüfe und initialisiere sudo-Zugang
echo "Überprüfe sudo-Zugang..."
if ! sudo -n true 2>/dev/null; then
  echo "Fehler: Sie haben keine ausreichenden sudo-Rechte oder sudo erfordert ein Passwort."
  echo "Bitte führen Sie dieses Skript als root aus oder verwenden Sie einen Benutzer mit sudo-Rechten."
  exit 1
fi

# sudo ist verfügbar – initialisiere das Ticket
echo "Sudo-Zugang ist vorhanden."
sudo -v

# Halte das sudo-Ticket im Hintergrund aktiv
echo "Sudo-Ticket wird im Hintergrund aktiv gehalten..."
( while true; do 
    sudo -n true 
    sleep 60 
    kill -0 "$$" || exit; 
  done ) 2>/dev/null &
echo "Sudo-Ticket aktiv."

# Laden der Umgebungsvariablen aus der .env-Datei
ENV_FILE="$(dirname "$0")/.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    echo "Umgebungsvariablen aus $ENV_FILE geladen."
else
    echo "Fehler: .env-Datei nicht gefunden! Bitte erstelle sie anhand von .env.example."
    exit 1
fi

# Setze Standardwerte, falls nicht definiert
EMAIL="${EMAIL:-deine.email@beispiel.com}"
DOMAIN="${DOMAIN:-example.com}"
STAGING="${STAGING:-0}"
HETZNER_DNS_TOKEN="${HETZNER_DNS_TOKEN:-}"

if [ -z "$HETZNER_DNS_TOKEN" ]; then
    echo "Fehler: HETZNER_DNS_TOKEN ist nicht gesetzt. Bitte in der .env definieren."
    exit 1
fi

# Funktion: Authentifizierungshook (DNS TXT-Eintrag erstellen)
auth_hook() {
    echo "-------------------------------------------"
    echo "Starte Authentifizierungshook..."
    if [ -z "$CERTBOT_DOMAIN" ]; then
        echo "Fehler: CERTBOT_DOMAIN ist nicht gesetzt. Dieses Skript sollte von Certbot mit CERTBOT_DOMAIN aufgerufen werden."
        exit 1
    fi
    echo "CERTBOT_DOMAIN: $CERTBOT_DOMAIN"

    # Extrahiere den Zonen-Namen (funktioniert für Domains wie example.com)
    search_name=$(echo "$CERTBOT_DOMAIN" | rev | cut -d'.' -f 1,2 | rev)
    echo "Ermittelter Zonen-Name: $search_name"

    # Zone-ID über die Hetzner DNS API abrufen
    zone_id=$(curl -s -H "Auth-API-Token: ${HETZNER_DNS_TOKEN}" "https://dns.hetzner.com/api/v1/zones?search_name=${search_name}" | \
              jq -r ".zones[] | select(.name==\"${search_name}\") | .id")
    if [ -z "$zone_id" ]; then
        echo "Fehler: Zone-ID für ${search_name} nicht gefunden."
        exit 1
    fi
    echo "Zone-ID gefunden: $zone_id"

    # DNS TXT-Eintrag erstellen
    echo "Erstelle DNS TXT-Eintrag für _acme-challenge.${CERTBOT_DOMAIN}..."
    response=$(curl -s -X POST "https://dns.hetzner.com/api/v1/records" \
         -H "Content-Type: application/json" \
         -H "Auth-API-Token: ${HETZNER_DNS_TOKEN}" \
         -d "{\"value\": \"${CERTBOT_VALIDATION}\", \"ttl\": 300, \"type\": \"TXT\", \"name\": \"_acme-challenge.${CERTBOT_DOMAIN}.\", \"zone_id\": \"${zone_id}\"}")
    echo "Antwort der API: $response"
    echo "Warte 30 Sekunden auf DNS-Propagation..."
    for i in {1..30}; do
      sleep 1
      echo -n "."
    done
    echo ""
    echo "Authentifizierungshook abgeschlossen."
    echo "-------------------------------------------"
}

# Funktion: Cleanup-Hook (DNS TXT-Eintrag löschen)
cleanup_hook() {
    echo "-------------------------------------------"
    echo "Starte Cleanup-Hook..."
    if [ -z "$CERTBOT_DOMAIN" ]; then
        echo "Fehler: CERTBOT_DOMAIN ist nicht gesetzt. Dieses Skript sollte von Certbot mit CERTBOT_DOMAIN aufgerufen werden."
        exit 1
    fi
    echo "CERTBOT_DOMAIN: $CERTBOT_DOMAIN"

    search_name=$(echo "$CERTBOT_DOMAIN" | rev | cut -d'.' -f 1,2 | rev)
    echo "Ermittelter Zonen-Name: $search_name"

    zone_id=$(curl -s -H "Auth-API-Token: ${HETZNER_DNS_TOKEN}" "https://dns.hetzner.com/api/v1/zones?search_name=${search_name}" | \
              jq -r ".zones[] | select(.name==\"${search_name}\") | .id")
    if [ -z "$zone_id" ]; then
        echo "Fehler: Zone-ID für ${search_name} nicht gefunden."
        exit 1
    fi
    echo "Zone-ID gefunden: $zone_id"

    # Abrufen der Record-IDs für den DNS TXT-Eintrag
    record_ids=$(curl -s -H "Auth-API-Token: ${HETZNER_DNS_TOKEN}" "https://dns.hetzner.com/api/v1/records?zone_id=${zone_id}" | \
                 jq -r ".records[] | select(.name==\"_acme-challenge.${CERTBOT_DOMAIN}.\") | .id")
    if [ -z "$record_ids" ]; then
        echo "Keine DNS-Einträge gefunden, die gelöscht werden müssen."
        exit 0
    fi

    # Löschen der gefundenen Einträge
    for record_id in $record_ids; do
        echo "Lösche DNS-Eintrag mit ID: $record_id"
        curl -s -X DELETE -H "Auth-API-Token: ${HETZNER_DNS_TOKEN}" "https://dns.hetzner.com/api/v1/records/${record_id}"
    done
    echo "Cleanup-Hook abgeschlossen."
    echo "-------------------------------------------"
}

# Funktion: Hauptprozess für den Zertifikatsabruf
main_certificate() {
    echo "-------------------------------------------"
    echo "Starte Zertifikatsabruf..."

    # Prüfen, ob der Staging-Modus aktiviert ist
    STAGING_OPTION=""
    if [ "$STAGING" -eq 1 ]; then
        STAGING_OPTION="--staging"
        echo "Staging-Modus ist aktiviert."
    else
        echo "Staging-Modus ist deaktiviert. Produktivzertifikat wird angefordert."
    fi

    # Prüfe, ob bereits ein Zertifikat existiert
    # Hier wird angenommen, dass für die Basis-Domain eine Renewal-Konfigurationsdatei vorhanden ist
    CERT_RENEWAL_CONF="/etc/letsencrypt/renewal/$DOMAIN.conf"
    if [ -f "$CERT_RENEWAL_CONF" ]; then
        echo "Vorhandenes Zertifikat gefunden (Datei: $CERT_RENEWAL_CONF)."
        echo "Füge --expand hinzu, um das bestehende Zertifikat zu erweitern."
        EXPAND="--expand"
    else
        EXPAND=""
    fi

    echo "Rufe Certbot mit den folgenden Parametern auf:"
    echo "  E-Mail: $EMAIL"
    echo "  Domain: $DOMAIN und *.$DOMAIN"
    echo "  Staging-Option: $STAGING_OPTION"
    echo "  Expand-Option: $EXPAND"
    
    # Certbot aufrufen. Dabei wird dieses Skript als Auth- und Cleanup-Hook genutzt.
    sudo certbot certonly \
      --non-interactive \
      --agree-tos \
      --email "$EMAIL" \
      --manual \
      --preferred-challenges=dns \
      --manual-auth-hook "$(realpath "$0") auth" \
      --manual-cleanup-hook "$(realpath "$0") cleanup" \
      $STAGING_OPTION \
      $EXPAND \
      -d "$DOMAIN" \
      -d "*.$DOMAIN"
    
    echo "Zertifikatserstellung abgeschlossen."
    echo "-------------------------------------------"
}


# Modus basierend auf dem ersten Parameter auswählen
# Dieses Skript ruft sich selbst mit unterschiedlichen Parametern auf:
# - Ohne Parameter: startet der Hauptprozess (main_certificate)
# - Mit "auth": wird der Authentifizierungshook ausgeführt
# - Mit "cleanup": wird der Cleanup-Hook ausgeführt
case "$1" in
    auth)
        auth_hook
        ;;
    cleanup)
        cleanup_hook
        ;;
    *)
        main_certificate
        ;;
esac
