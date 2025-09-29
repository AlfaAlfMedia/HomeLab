#!/bin/bash
# certbot-hetzner-setup.sh
# Vollständige Einrichtung von Certbot mit Hetzner DNS in venv

set -e  # Bei Fehler abbrechen

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Konfiguration
DOMAIN="alfaalf-media.de"
EMAIL="deine@email.de"
HETZNER_API_TOKEN="DEIN_TOKEN_HIER"
VENV_DIR="/opt/certbot"
CREDENTIALS_DIR="/etc/letsencrypt/hetzner"
WEBSERVER="nginx"  # oder "apache2"

echo -e "${GREEN}=== Certbot Hetzner DNS Setup ===${NC}"
echo ""

# 1. Prüfen ob als root ausgeführt
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Bitte als root ausführen (sudo)${NC}"
    exit 1
fi

# 2. Alte systemd Dienste stoppen (falls vorhanden)
echo -e "${YELLOW}Stoppe alte certbot Dienste...${NC}"
systemctl stop certbot.timer 2>/dev/null || true
systemctl stop certbot-renew.timer 2>/dev/null || true
systemctl disable certbot.timer 2>/dev/null || true
systemctl disable certbot-renew.timer 2>/dev/null || true
echo -e "${GREEN}✓ Alte Dienste gestoppt${NC}"
echo ""

# 3. Python3 und venv installieren (falls nicht vorhanden)
echo -e "${YELLOW}Prüfe Python3 Installation...${NC}"
if ! command -v python3 &> /dev/null; then
    apt-get update
    apt-get install -y python3 python3-venv python3-pip
fi
echo -e "${GREEN}✓ Python3 verfügbar${NC}"
echo ""

# 4. Verzeichnisse erstellen
echo -e "${YELLOW}Erstelle Verzeichnisse...${NC}"
mkdir -p "$VENV_DIR"
mkdir -p "$CREDENTIALS_DIR"
mkdir -p /var/log/certbot
echo -e "${GREEN}✓ Verzeichnisse erstellt${NC}"
echo ""

# 5. Virtuelle Umgebung erstellen
echo -e "${YELLOW}Erstelle virtuelle Python-Umgebung...${NC}"
cd "$VENV_DIR"
if [ -d "certbot-venv" ]; then
    echo -e "${YELLOW}venv existiert bereits, wird übersprungen${NC}"
else
    python3 -m venv certbot-venv
    echo -e "${GREEN}✓ venv erstellt${NC}"
fi
echo ""

# 6. Certbot und Plugin installieren
echo -e "${YELLOW}Installiere Certbot und Hetzner Plugin...${NC}"
$VENV_DIR/certbot-venv/bin/pip install --upgrade pip --quiet
$VENV_DIR/certbot-venv/bin/pip install certbot certbot-dns-hetzner --quiet
echo -e "${GREEN}✓ Certbot installiert${NC}"
echo ""

# 7. Hetzner Credentials erstellen
echo -e "${YELLOW}Erstelle Hetzner API Credentials...${NC}"
if [ "$HETZNER_API_TOKEN" = "DEIN_TOKEN_HIER" ]; then
    echo -e "${RED}FEHLER: Bitte HETZNER_API_TOKEN im Skript anpassen!${NC}"
    exit 1
fi

cat > "$CREDENTIALS_DIR/credentials.ini" << EOF
dns_hetzner_api_token = $HETZNER_API_TOKEN
EOF

chmod 600 "$CREDENTIALS_DIR/credentials.ini"
chown root:root "$CREDENTIALS_DIR/credentials.ini"
echo -e "${GREEN}✓ Credentials erstellt${NC}"
echo ""

# 8. Backup altes Zertifikat (falls vorhanden)
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo -e "${YELLOW}Sichere altes Zertifikat...${NC}"
    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
    cp -r "/etc/letsencrypt/live/$DOMAIN" "/etc/letsencrypt/live/${DOMAIN}.backup-${BACKUP_DATE}" 2>/dev/null || true
    cp -r "/etc/letsencrypt/archive/$DOMAIN" "/etc/letsencrypt/archive/${DOMAIN}.backup-${BACKUP_DATE}" 2>/dev/null || true
    echo -e "${GREEN}✓ Backup erstellt${NC}"
    echo ""
fi

# 9. Zertifikat erstellen
echo -e "${YELLOW}Erstelle neues Let's Encrypt Zertifikat...${NC}"
echo -e "${YELLOW}Dies kann 1-2 Minuten dauern...${NC}"
$VENV_DIR/certbot-venv/bin/certbot certonly \
  -a dns-hetzner \
  --dns-hetzner-credentials "$CREDENTIALS_DIR/credentials.ini" \
  --dns-hetzner-propagation-seconds 60 \
  -d "$DOMAIN" \
  -d "*.$DOMAIN" \
  --key-type ecdsa \
  --email "$EMAIL" \
  --agree-tos \
  --non-interactive

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Zertifikat erfolgreich erstellt${NC}"
else
    echo -e "${RED}✗ Fehler bei Zertifikatserstellung${NC}"
    exit 1
fi
echo ""

# 10. Systemd Service erstellen
echo -e "${YELLOW}Erstelle systemd Service...${NC}"
cat > /etc/systemd/system/certbot-renew.service << 'EOF'
[Unit]
Description=Certbot Renewal
After=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/certbot/certbot-venv/bin/certbot renew --quiet
ExecStartPost=/bin/systemctl reload nginx.service
EOF

echo -e "${GREEN}✓ Service erstellt${NC}"
echo ""

# 11. Systemd Timer erstellen
echo -e "${YELLOW}Erstelle systemd Timer...${NC}"
cat > /etc/systemd/system/certbot-renew.timer << 'EOF'
[Unit]
Description=Certbot Renewal Timer

[Timer]
OnCalendar=daily
RandomizedDelaySec=12h
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo -e "${GREEN}✓ Timer erstellt${NC}"
echo ""

# 12. Systemd neu laden und Timer aktivieren
echo -e "${YELLOW}Aktiviere systemd Timer...${NC}"
systemctl daemon-reload
systemctl enable certbot-renew.timer
systemctl start certbot-renew.timer
echo -e "${GREEN}✓ Timer aktiviert${NC}"
echo ""

# 13. Webserver neu laden
echo -e "${YELLOW}Lade $WEBSERVER neu...${NC}"
systemctl reload "$WEBSERVER"
echo -e "${GREEN}✓ $WEBSERVER neu geladen${NC}"
echo ""

# 14. Status anzeigen
echo -e "${GREEN}=== Setup abgeschlossen! ===${NC}"
echo ""
echo -e "${GREEN}Zertifikat-Informationen:${NC}"
$VENV_DIR/certbot-venv/bin/certbot certificates
echo ""
echo -e "${GREEN}Timer-Status:${NC}"
systemctl status certbot-renew.timer --no-pager
echo ""
echo -e "${GREEN}Nächste Ausführung:${NC}"
systemctl list-timers certbot-renew.timer --no-pager
echo ""
echo -e "${YELLOW}Hinweis: Das Zertifikat wird automatisch täglich auf Erneuerung geprüft.${NC}"
