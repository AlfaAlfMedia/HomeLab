Let's Encrypt Wildcard-Zertifikate mit Hetzner DNSDieses Repository enthält ein Bash-Skript zur vollautomatischen Anforderung von Let's Encrypt Wildcard-Zertifikaten. Es nutzt die DNS-01-Challenge und interagiert direkt mit der Hetzner DNS API, um die benötigten TXT-Einträge zu erstellen und zu löschen.Dieses Projekt entstand, um einen robusten, sicheren und standardkonformen Weg für die Zertifikatsautomatisierung auf Debian-basierten Systemen zu bieten, bei dem Code und Konfiguration sauber getrennt sind.FeaturesVollautomatisch: Fordert Wildcard- (*.example.com) und Standardzertifikate an.Sicher: Trennt den ausführbaren Code von der Konfigurationsdatei, die geheime API-Tokens enthält.Standardkonform: Orientiert sich am Filesystem Hierarchy Standard (FHS) für die Ablage von Skripten und Konfigurationen.Robust: Prüft auf notwendige Abhängigkeiten (curl, jq, certbot) und bietet deren automatische Installation an.Flexibel: Alle wichtigen Parameter (Domains, E-Mail, Token) werden in einer separaten Konfigurationsdatei verwaltet.Transparent: Schreibt detaillierte Logs in eine eigene Log-Datei mit integrierter Unterstützung für logrotate.Zukunftssicher: Kompatibel mit dem automatischen Erneuerungsprozess von Certbot via systemd timer.FunktionsweiseDas Skript dient als manual-auth-hook und manual-cleanup-hook für Certbot. Wenn certbot ein Zertifikat anfordert oder erneuert, ruft es dieses Skript auf:Auth-Hook: Das Skript empfängt den Challenge-Token von Certbot und erstellt über die Hetzner DNS API den geforderten _acme-challenge TXT-Eintrag.Cleanup-Hook: Nachdem Let's Encrypt den DNS-Eintrag erfolgreich validiert hat, ruft Certbot das Skript erneut auf, um den temporären TXT-Eintrag wieder zu löschen und die DNS-Zone sauber zu halten.VoraussetzungenDas Skript ist für Debian-basierte Systeme (wie Debian, Ubuntu) optimiert. Folgende Pakete werden benötigt und bei Bedarf automatisch installiert:certbotcurljqInstallation und KonfigurationFolge diesen Schritten, um das Skript auf deinem Server einzurichten.1. Repository klonenKlone dieses Repository auf deinen Server, z.B. in das Home-Verzeichnis deines Benutzers.git clone <deine-repository-url>
cd <dein-repository-name>
2. Dateien an die richtigen Orte verschiebenWir platzieren das Skript und die Konfiguration an den systemweiten, standardkonformen Speicherorten.# Skript nach /usr/local/sbin verschieben
sudo mv ./hetzner-dns-certificate.sh /usr/local/sbin/

# Skript ausführbar machen
sudo chmod +x /usr/local/sbin/hetzner-dns-certificate.sh
3. Konfiguration einrichtenDie Konfigurationsdatei enthält alle deine persönlichen Daten und wird sicher in /etc abgelegt.# Verzeichnis für die Konfiguration erstellen
sudo mkdir -p /etc/hetzner-dns

# Konfigurationsvorlage kopieren
sudo cp ./hetzner-dns.conf.example /etc/hetzner-dns/hetzner-dns.conf

# Konfigurationsdatei bearbeiten
sudo nano /etc/hetzner-dns/hetzner-dns.conf
Fülle in dieser Datei mindestens die folgenden Variablen aus:HETZNER_DNS_TOKENEMAILDOMAINSWICHTIG: Setze strikte Berechtigungen, damit nur root die Datei mit deinem API-Token lesen kann:sudo chmod 600 /etc/hetzner-dns/hetzner-dns.conf
4. Skript für den neuen Konfigurationspfad anpassenÖffne das Skript und stelle sicher, dass es den korrekten, festen Pfad zur Konfigurationsdatei verwendet.sudo nano /usr/local/sbin/hetzner-dns-certificate.sh
Ändere die Zeile CONFIG_FILE=... am Anfang des Skripts zu:CONFIG_FILE="/etc/hetzner-dns/hetzner-dns.conf"
5. Logging einrichten (Empfohlen)Das Skript loggt standardmäßig nach /var/log/hetzner-cert.log. Um zu verhindern, dass diese Datei unendlich wächst, richte logrotate ein.Erstelle die logrotate-Konfigurationsdatei:sudo nano /etc/logrotate.d/hetzner-cert
Füge folgenden Inhalt ein:/var/log/hetzner-cert.log {
    monthly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
BenutzungNachdem alles konfiguriert ist, kannst du den ersten Zertifikatsabruf starten.sudo /usr/local/sbin/hetzner-dns-certificate.sh
Das Skript prüft die Abhängigkeiten und startet dann Certbot. Folge den Anweisungen auf dem Bildschirm.Automatische ErneuerungDu musst keinen eigenen Cronjob einrichten. Das offizielle certbot-Paket installiert einen systemd timer, der zweimal täglich prüft, ob Zertifikate erneuert werden müssen. Wenn eine Erneuerung ansteht, ruft Certbot automatisch dein Skript als Werkzeug auf.Du kannst den Status des Timers überprüfen mit:sudo systemctl list-timers | grep certbot
Dateien in diesem Repositoryhetzner-dns-certificate.sh: Das ausführbare Hauptskript.hetzner-dns.conf.example: Eine Vorlage für die Konfigurationsdatei..gitignore: Stellt sicher, dass deine lokale hetzner-dns.conf niemals versehentlich in Git landet.README.md: Diese Anleitung.LizenzDieses Projekt steht unter der MIT-Lizenz.
