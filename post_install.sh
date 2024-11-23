#!/bin/bash

# Farben für schöneren Output
GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
RESET="\033[0m"

# Hilfsfunktionen
success_msg() { echo -e "${GREEN}✔ $1${RESET}"; }
error_exit() { echo -e "${RED}FEHLER: $1${RESET}"; exit 1; }
step_msg() { echo -e "${BLUE}==> $1${RESET}"; }

# Konfigurationsdatei einlesen
CONFIG_FILE="/root/arch-install-scripts/config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    error_exit "Konfigurationsdatei $CONFIG_FILE wurde nicht gefunden!"
fi
source "$CONFIG_FILE"

# Pacman-Datenbank aktualisieren
update_pacman() {
    step_msg "Aktualisiere Pacman-Datenbank..."
    pacman -Syu --noconfirm || error_exit "Fehler beim Aktualisieren der Pacman-Datenbank."
    success_msg "Pacman-Datenbank aktualisiert."
}

# NVIDIA-Treiber installieren
install_nvidia_drivers() {
    if [ "$INSTALL_NVIDIA" = true ]; then
        step_msg "Installiere NVIDIA-Treiber..."
        pacman -S --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils || error_exit "Fehler beim Installieren der NVIDIA-Treiber."
        success_msg "NVIDIA-Treiber installiert."
    fi
}

# GNOME-Desktop installieren
install_gnome() {
    if [ "$INSTALL_DESKTOP" = true ] && [ "$DESKTOP_ENV" = "gnome" ]; then
        step_msg "Installiere GNOME-Desktop..."
        pacman -S --noconfirm gnome gdm xorg || error_exit "Fehler beim Installieren von GNOME."
        sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm/custom.conf || error_exit "Fehler beim Konfigurieren von GDM."
        systemctl enable gdm || error_exit "Fehler beim Aktivieren von GDM."
        success_msg "GNOME-Desktop installiert und GDM aktiviert."
    fi
}

# Cleanup
cleanup() {
    step_msg "Entferne Post-Installationsskript und zugehörigen Service..."
    rm -f /root/arch-install-scripts/post_install.sh
    systemctl disable post-install.service
    rm -f /etc/systemd/system/post-install.service
    success_msg "Post-Installationsskript und Systemd-Service entfernt."
}

# Hauptfunktion
main() {
    echo -e "${GREEN}Starte Post-Installationsskript...${RESET}"
    update_pacman
    install_nvidia_drivers
    install_gnome
    cleanup
    success_msg "Post-Installation abgeschlossen! Bitte starte dein System neu."
}

main
