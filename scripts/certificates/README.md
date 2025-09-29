# Certbot Hetzner DNS Setup Script

Automatisches Setup-Skript für Let's Encrypt SSL-Zertifikate mit Hetzner DNS API Validierung in einer isolierten Python Virtual Environment.

## 🎯 Features

- ✅ Vollautomatische Einrichtung von Certbot mit Hetzner DNS Plugin
- ✅ Isolierte Python Virtual Environment (keine Systemkonflikte)
- ✅ Wildcard-Zertifikate (`*.domain.de`)
- ✅ ECDSA-Schlüssel für bessere Performance
- ✅ Automatische Erneuerung via systemd Timer
- ✅ Backup bestehender Zertifikate
- ✅ Automatisches Neuladen des Webservers nach Erneuerung
- ✅ Farbige Konsolen-Ausgabe für bessere Übersicht

## 📋 Voraussetzungen

- Ubuntu/Debian Linux Server mit root-Zugriff
- Domain bei Hetzner DNS verwaltet
- Hetzner DNS API Token ([Anleitung](#hetzner-api-token-erstellen))
- Nginx oder Apache2 Webserver

## 🚀 Installation

### 1. Skript herunterladen
```bash
wget https://raw.githubusercontent.com//AlfaAlfMedia/HomeLab/new/main/scripts/certificates/main/certbot-hetzner-setup.sh
# oder
curl -O https://raw.githubusercontent.com//AlfaAlfMedia/HomeLab/new/main/scripts/certificates/main/certbot-hetzner-setup.sh
