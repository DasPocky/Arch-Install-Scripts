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

# Auswahl einer Option aus einer Liste
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    local default_index=0

    echo -e "\n$prompt"
    for i in "${!options[@]}"; do
        echo "$((i + 1)). ${options[i]}"
    done

    read -rp "Wähle eine Option (Standard: ${options[default_index]}): " choice
    choice=${choice:-$((default_index + 1))}

    if [[ $choice -ge 1 && $choice -le ${#options[@]} ]]; then
        echo "${options[choice-1]}"
    else
        error_msg "Ungültige Auswahl. Bitte erneut versuchen."
        select_option "$prompt" "${options[@]}"
    fi
}

# Zeitzonenauswahl
select_timezone() {
    local timezones=("Europe/Berlin" "America/New_York" "Asia/Tokyo" "UTC")
    TIMEZONE=$(select_option "Wähle deine Zeitzone:" "${timezones[@]}")
    success_msg "Ausgewählte Zeitzone: $TIMEZONE"
}

# Locale-Auswahl
select_locale() {
    local locales=("de_DE.UTF-8" "en_US.UTF-8")
    LOCALE=$(select_option "Wähle deine Locale:" "${locales[@]}")
    success_msg "Ausgewählte Locale: $LOCALE"
}

# Verfügbare Festplatten anzeigen und auswählen lassen
select_disk() {
    prompt_msg "Verfügbare Laufwerke:"
    lsblk -d -o NAME,SIZE,TYPE | grep "disk"

    local disks=($(lsblk -d -o NAME | grep -v "NAME"))
    DISK=$(select_option "Wähle ein Laufwerk aus:" "${disks[@]}")
    success_msg "Ausgewähltes Laufwerk: $DISK"
}

# WLAN-SSID auswählen
select_wlan() {
    prompt_msg "Scanne nach verfügbaren WLAN-Netzwerken..."
    iwctl station wlan0 scan
    sleep 2
    AVAILABLE_SSIDS=$(iwctl station wlan0 get-networks | awk 'NR>3 {print $1}')

    if [ -z "$AVAILABLE_SSIDS" ]; then
        error_msg "Keine WLAN-Netzwerke gefunden."
        return 1
    fi

    echo -e "\nVerfügbare SSIDs:"
    echo "$AVAILABLE_SSIDS" | nl -w2 -s'. '

    read -rp "Wähle die SSID (Nummer) aus: " SSID_INDEX
    SSID=$(echo "$AVAILABLE_SSIDS" | sed -n "${SSID_INDEX}p")
    if [ -z "$SSID" ]; then
        error_msg "Ungültige Auswahl."
        return 1
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

    # Zeitzone
    select_timezone

    # Locale
    select_locale

    # Festplattenauswahl
    select_disk

    # Dateisystem
    local filesystems=("Btrfs" "ext4" "xfs")
    FILESYSTEM=$(select_option "Wähle das Dateisystem für die Installation:" "${filesystems[@]}")

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
    local desktop_envs=("GNOME" "KDE" "XFCE" "MATE" "Keine")
    DESKTOP_ENV=$(select_option "Wähle eine Desktop-Umgebung (oder Keine):" "${desktop_envs[@]}")

    # Grafiktreiber
    echo -e "\nSoll der NVIDIA-Treiber installiert werden?"
    select NVIDIA_CHOICE in "Ja" "Nein"; do
        case $NVIDIA_CHOICE in
            Ja) INSTALL_NVIDIA=true; break ;;
            Nein) INSTALL_NVIDIA=false; break ;;
            *) error_msg "Ungültige Auswahl. Bitte erneut versuchen." ;;
        esac
    done

    if [ "$INSTALL_NVIDIA" = true ]; then
        echo -e "\nSoll die Intel-GPU deaktiviert werden?"
        select INTEL_CHOICE in "Ja" "Nein"; do
            case $INTEL_CHOICE in
                Ja) DISABLE_INTEL=true; break ;;
                Nein) DISABLE_INTEL=false; break ;;
                *) error_msg "Ungültige Auswahl. Bitte erneut versuchen." ;;
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
TIMEZONE="$TIMEZONE"
LOCALE="$LOCALE"
DISK="/dev/$DISK"
FILESYSTEM="$FILESYSTEM"

# WLAN-Optionen
WLAN_OPTION=$WLAN_OPTION
SSID="$SSID"
WLAN_PASSWORD="$WLAN_PASSWORD"

# Desktop-Einstellungen
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
        exit 1
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
