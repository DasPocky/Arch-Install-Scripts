
# Automatisierte Arch Linux Installation

Dieses Repository enthält Skripte für eine vollständig automatisierte Arch Linux Installation. Es unterstützt:
- Btrfs mit Subvolumes für Snapshots
- NVIDIA-Treiber und Konfiguration für Systeme mit dedizierten GPUs
- Installation und Konfiguration einer Desktop-Umgebung (z. B. GNOME, KDE, XFCE)
- Ein interaktives Vorschalt-Skript zur Erstellung einer individuellen Konfigurationsdatei

## Enthaltene Skripte

### 1. `configure.sh`
Ein interaktives Vorschalt-Skript, das eine **Konfigurationsdatei (`config.conf`)** basierend auf deinen Eingaben erstellt.

### 2. `arch_install.sh`
Führt die eigentliche Installation durch:
- Partitionierung und Formatierung der Festplatte
- Installation des Basissystems
- Einrichtung von Btrfs-Subvolumes (falls ausgewählt)
- Klonen dieses Repositories und Kopieren des Post-Installationsskripts ins neue System
- Einrichten eines Systemd-Services, um das Post-Installationsskript nach dem ersten Neustart auszuführen

### 3. `post_install.sh`
Wird nach dem ersten Neustart automatisch ausgeführt:
- Aktualisiert die Pacman-Datenbank
- Installiert und konfiguriert NVIDIA-Treiber
- Installiert die Desktop-Umgebung (falls ausgewählt)
- Konfiguriert X11 oder Wayland für NVIDIA
- Entfernt sich selbst und den zugehörigen Systemd-Service nach Abschluss

---

## Anforderungen

1. **Arch Linux Installationsmedium**:
   - Lade die neueste ISO von [archlinux.org](https://archlinux.org).

2. **Git installiert auf dem Live-System**:
   - Falls nicht installiert, führe aus:
     ```bash
     pacman -S git
     ```

---

## Installation

### 1. Repository klonen

Starte mit dem Arch Linux Installationsmedium und klone dieses Repository:
```bash
git clone git@github.com:<DEIN_GITHUB_USERNAME>/arch-install-scripts.git
cd arch-install-scripts
```

### 2. Konfigurationsdatei erstellen

Führe das Vorschalt-Skript aus, um die `config.conf` zu erstellen:
```bash
bash configure.sh
```

Das Skript führt dich durch die Eingabe aller wichtigen Einstellungen, z. B.:
- Hostname, Benutzername, Passwort
- Ziel-Festplatte (`/dev/sdX`)
- Wahl des Dateisystems (Btrfs oder ext4)
- Wahl einer Desktop-Umgebung (GNOME, KDE, XFCE)
- NVIDIA-Treiber und GPU-Konfiguration

Nach Abschluss wird eine Datei `config.conf` erstellt, die alle Einstellungen speichert.

### 3. Installation starten

Führe das Installationsskript aus:
```bash
bash arch_install.sh
```

Das Skript liest die `config.conf` und installiert Arch Linux entsprechend deinen Angaben.

### 4. Post-Installation (automatisch)

Nach dem ersten Neustart wird das Post-Installationsskript (`post_install.sh`) automatisch ausgeführt. Es installiert und konfiguriert:
- Desktop-Umgebung
- NVIDIA-Treiber
- X11 oder Wayland (abhängig von deiner Auswahl)

---

## Anpassung der Konfigurationsdatei

Falls du Änderungen an der `config.conf` vornehmen möchtest, kannst du diese manuell editieren:
```bash
nano config.conf
```

Beispiel:
```ini
# config.conf - Automatisch generierte Konfigurationsdatei

# Allgemeine Einstellungen
HOSTNAME="archlinux"
USERNAME="user"
PASSWORD="password"
TIMEZONE="Europe/Berlin"
LOCALE="en_US.UTF-8"
DISK="/dev/sda"
FILESYSTEM="btrfs"

# Desktop-Einstellungen
INSTALL_DESKTOP=true
DESKTOP_ENV="gnome"

# Grafiktreiber
INSTALL_NVIDIA=true
DISABLE_INTEL=true

# Repository
GITHUB_REPO_URL="git@github.com:mein-benutzername/arch-install-scripts.git"
```

---

## Unterstützte Funktionen

### Dateisystem
- **Btrfs**: Subvolumes für `/`, `/home`, `/var/log`, und `.snapshots` werden automatisch erstellt.
- **ext4**: Eine einfache ext4-Partition kann alternativ genutzt werden.

### Desktop-Umgebungen
- GNOME
- KDE Plasma
- XFCE

### Grafiktreiber
- NVIDIA (mit Unterstützung für Systeme mit dedizierten GPUs)
- Optionale Deaktivierung der Intel-GPU für Laptops mit Hybrid-Grafik

---

## Troubleshooting

### 1. Fehler während der Installation
Falls das Skript fehlschlägt, überprüfe die Konsolenausgabe. Häufige Ursachen:
- Falsche Angabe der Ziel-Festplatte (`/dev/sdX`).
- GitHub-Repository nicht erreichbar (z. B. falsche URL).

### 2. Nach dem Neustart
Falls das Post-Installationsskript nicht ausgeführt wird:
```bash
journalctl -u post-install.service
```

### 3. Btrfs-Snapshots
Falls du manuelle Snapshots erstellen möchtest:
```bash
btrfs subvolume snapshot /mnt/.snapshots/snapshot-$(date +%F)
```

---

## Lizenz

Dieses Projekt ist unter der **MIT-Lizenz** lizenziert. Siehe die Datei `LICENSE` für weitere Informationen.
