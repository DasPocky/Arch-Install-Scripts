#!/bin/bash

# Farben für schönen Output
GREEN="\033[1;32m"
BLUE="\033[1;34m"
RED="\033[1;31m"
RESET="\033[0m"

# Hilfsfunktionen
success_msg() { echo -e "${GREEN}✔ $1${RESET}"; }
error_msg() { echo -e "${RED}✖ $1${RESET}"; exit 1; }
prompt_msg() { echo -e "${BLUE}$1${RESET}"; }

# Überprüfen, ob das Skript als root ausgeführt wird
if [ "$(id -u)" -ne 0 ]; then
    error_msg "Bitte führe das Skript als root aus."
fi

# Verfügbare Laufwerke anzeigen und auswählen lassen
select_disk() {
    prompt_msg "Verfügbare Laufwerke:"
    lsblk -d -o NAME,SIZE,TYPE | grep "disk"

    local disk_options=($(lsblk -d -o NAME | grep -v "NAME"))
    local default_disk=${disk_options[0]}

    echo -e "\nWähle ein Laufwerk aus der obigen Liste (Standard: $default_disk):"
    read -rp "Eingabe (z. B. $default_disk): " DISK
    DISK=${DISK:-$default_disk}

    if [[ ! " ${disk_options[@]} " =~ " ${DISK} " ]]; then
        error_msg "Ungültige Auswahl. Bitte erneut ausführen."
    fi
    success_msg "Ausgewähltes Laufwerk: $DISK"
}

# WLAN-SSID auswählen
select_wlan() {
    prompt_msg "Scanne nach verfügbaren WLAN-Netzwerken..."
    iwctl station wlan0 scan
    sleep 2
    AVAILABLE_SSIDS=$(iwctl station wlan0 get-networks | awk 'NR>3 {print $1}')

    echo -e "\nVerfügbare SSIDs:"
    echo "$AVAILABLE_SSIDS" | nl -w2 -s'. '

    read -rp "Wähle die SSID (Nummer) aus: " SSID_INDEX
    SSID=$(echo "$AVAILABLE_SSIDS" | sed -n "${SSID_INDEX}p")
    if [ -z "$SSID" ]; then
        error_msg "Ungültige Auswahl."
    fi

    read -sp "Passwort für $SSID eingeben: " WLAN_PASSWORD
    echo

    success_msg "WLAN-Netzwerk $SSID ausgewählt."
}

# Konfigurationsdatei erstellen
create_config() {
    CONFIG_FILE="config.conf"

    prompt_msg "Willkommen! Wir erstellen jetzt deine Konfigurationsdatei für die automatisierte Arch Linux Installation."
    echo -e "\nBitte gib die folgenden Informationen ein (Drücke Enter, um den Standardwert zu akzeptieren):\n"

    # Allgemeine Einstellungen
    read -rp "Hostname (Standard: archlinux): " HOSTNAME
    HOSTNAME=${HOSTNAME:-archlinux}

    read -rp "Benutzername (Standard: user): " USERNAME
    USERNAME=${USERNAME:-user}

    read -rp "Zeitzone (Standard: Europe/Berlin): " TIMEZONE
    TIMEZONE=${TIMEZONE:-Europe/Berlin}

    read -rp "Locale (Standard: en_US.UTF-8): " LOCALE
    LOCALE=${LOCALE:-en_US.UTF-8}

    # Festplattenauswahl
    select_disk

    # Dateisystem
    echo -e "\nWähle das Dateisystem für die Installation:"
    select FS in "Btrfs" "ext4" "xfs"; do
        case $FS in
            Btrfs) FILESYSTEM="btrfs"; break ;;
            ext4) FILESYSTEM="ext4"; break ;;
            xfs) FILESYSTEM="xfs"; break ;;
            *) error_msg "Ungültige Auswahl! Bitte erneut versuchen." ;;
        esac
    done

    # WLAN-Optionen
    echo -e "\nSoll WLAN konfiguriert werden?"
    select WLAN_OPTION in "Ja" "Nein"; do
        case $WLAN_OPTION in
            Ja) select_wlan; break ;;
            Nein) success_msg "WLAN wird übersprungen."; WLAN_OPTION=false; break ;;
            *) error_msg "Ungültige Auswahl. Bitte erneut versuchen." ;;
        esac
    done

    # Desktop-Umgebung
    echo -e "\nSoll eine Desktop-Umgebung installiert werden?"
    select DESKTOP_CHOICE in "Ja" "Nein"; do
        case $DESKTOP_CHOICE in
            Ja) INSTALL_DESKTOP=true; break ;;
            Nein) INSTALL_DESKTOP=false; break ;;
            *) error_msg "Ungültige Auswahl! Bitte erneut versuchen." ;;
        esac
    done

    if [ "$INSTALL_DESKTOP" = true ]; then
        echo -e "\nWähle die Desktop-Umgebung:"
        select DE in "GNOME" "KDE" "XFCE" "MATE"; do
            case $DE in
                GNOME) DESKTOP_ENV="gnome"; break ;;
                KDE) DESKTOP_ENV="kde"; break ;;
                XFCE) DESKTOP_ENV="xfce"; break ;;
                MATE) DESKTOP_ENV="mate"; break ;;
                *) error_msg "Ungültige Auswahl! Bitte erneut versuchen." ;;
            esac
        done
    fi

    # Grafiktreiber
    echo -e "\nSoll der NVIDIA-Treiber installiert werden?"
    select NVIDIA_CHOICE in "Ja" "Nein"; do
        case $NVIDIA_CHOICE in
            Ja) INSTALL_NVIDIA=true; break ;;
            Nein) INSTALL_NVIDIA=false; break ;;
            *) error_msg "Ungültige Auswahl! Bitte erneut versuchen." ;;
        esac
    done

    if [ "$INSTALL_NVIDIA" = true ]; then
        echo -e "\nSoll die Intel-GPU deaktiviert werden?"
        select INTEL_CHOICE in "Ja" "Nein"; do
            case $INTEL_CHOICE in
                Ja) DISABLE_INTEL=true; break ;;
                Nein) DISABLE_INTEL=false; break ;;
                *) error_msg "Ungültige Auswahl! Bitte erneut versuchen." ;;
            esac
        done
    fi

    # Repository-URL
    echo -e "\nGib die URL deines privaten GitHub-Repositories ein:"
    read -rp "(Standard: https://github.com/DasPocky/arch-install-scripts.git): " GITHUB_REPO_URL
    GITHUB_REPO_URL=${GITHUB_REPO_URL:-https://github.com/DasPocky/arch-install-scripts.git}

    # Konfigurationsdatei schreiben
    cat <<EOF > $CONFIG_FILE
# config.conf - Automatisch generierte Konfigurationsdatei

# Allgemeine Einstellungen
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
TIMEZONE="$TIMEZONE"
LOCALE="$LOCALE"
DISK="/dev/$DISK"
FILESYSTEM="$FILESYSTEM"

# WLAN-Optionen
WLAN_OPTION=$WLAN_OPTION
SSID="$SSID"
WLAN_PASSWORD="$WLAN_PASSWORD"

# Desktop-Einstellungen
INSTALL_DESKTOP=$INSTALL_DESKTOP
DESKTOP_ENV="$DESKTOP_ENV"

# Grafiktreiber
INSTALL_NVIDIA=$INSTALL_NVIDIA
DISABLE_INTEL=$DISABLE_INTEL

# Repository
GITHUB_REPO_URL="$GITHUB_REPO_URL"
EOF

    if [ -f "$CONFIG_FILE" ]; then
        success_msg "Konfigurationsdatei $CONFIG_FILE wurde erfolgreich erstellt!"
    else
        error_msg "Fehler beim Erstellen der Konfigurationsdatei."
    fi
}

# Hauptfunktion
main() {
    echo -e "${GREEN}Start des Konfigurationsassistenten...${RESET}"
    create_config
    echo -e "\nDu kannst die Datei $CONFIG_FILE bei Bedarf manuell bearbeiten."
    success_msg "Die Konfiguration ist abgeschlossen! Fahre mit dem Installationsskript fort."
}

main
