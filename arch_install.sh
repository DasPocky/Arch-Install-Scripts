#!/bin/bash

# Farben für schönen Output
GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
RESET="\033[0m"

# Hilfsfunktionen
success_msg() { echo -e "${GREEN}✔ $1${RESET}"; }
error_exit() { echo -e "${RED}✖ $1${RESET}"; exit 1; }
step_msg() { echo -e "${BLUE}==> $1${RESET}"; }

# Konfigurationsdatei einlesen
CONFIG_FILE="config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    error_exit "Konfigurationsdatei $CONFIG_FILE wurde nicht gefunden!"
fi
source "$CONFIG_FILE"

# Spiegelserver aktualisieren
update_mirrorlist() {
    step_msg "Aktualisiere die Pacman-Spiegelserver für Deutschland (HTTPS)..."
    reflector --country Germany --protocol https --latest 5 --sort rate --save /etc/pacman.d/mirrorlist || error_exit "Fehler beim Aktualisieren der Spiegelserver."
    success_msg "Pacman-Spiegelserver aktualisiert."
}

# Partitionieren und formatieren
partition_disk() {
    step_msg "Partitioniere Festplatte $DISK..."
    wipefs -a "$DISK" || error_exit "Fehler beim Löschen der alten Partitionstabelle."
    parted "$DISK" --script mklabel gpt || error_exit "Fehler beim Erstellen der GPT-Partitionstabelle."
    parted "$DISK" --script mkpart ESP fat32 1MiB 512MiB || error_exit "Fehler beim Erstellen der EFI-Partition."
    parted "$DISK" --script set 1 esp on || error_exit "Fehler beim Setzen der ESP-Markierung."
    parted "$DISK" --script mkpart primary 512MiB 100% || error_exit "Fehler beim Erstellen der Root-Partition."
    success_msg "Partitionierung abgeschlossen."

    step_msg "Formatiere Partitionen..."
    mkfs.fat -F32 "${DISK}1" || error_exit "Fehler beim Formatieren der EFI-Partition."
    if [ "$FILESYSTEM" == "btrfs" ]; then
        mkfs.btrfs "${DISK}2" || error_exit "Fehler beim Formatieren der Root-Partition als Btrfs."
        success_msg "Root-Partition als Btrfs formatiert."
    else
        mkfs.ext4 "${DISK}2" || error_exit "Fehler beim Formatieren der Root-Partition als ext4."
        success_msg "Root-Partition als ext4 formatiert."
    fi
}

# Btrfs-Subvolumes erstellen und mounten
setup_btrfs() {
    if [ "$FILESYSTEM" == "btrfs" ]; then
        step_msg "Erstelle Btrfs-Subvolumes..."
        mount "${DISK}2" /mnt
        btrfs subvolume create /mnt/@ || error_exit "Fehler beim Erstellen des @-Subvolumes."
        btrfs subvolume create /mnt/@home || error_exit "Fehler beim Erstellen des @home-Subvolumes."
        btrfs subvolume create /mnt/@snapshots || error_exit "Fehler beim Erstellen des @snapshots-Subvolumes."
        btrfs subvolume create /mnt/@var_log || error_exit "Fehler beim Erstellen des @var_log-Subvolumes."
        umount /mnt

        step_msg "Mount Subvolumes..."
        mount -o noatime,compress=zstd,subvol=@ "${DISK}2" /mnt
        mkdir -p /mnt/{boot,home,.snapshots,var/log}
        mount -o noatime,compress=zstd,subvol=@home "${DISK}2" /mnt/home
        mount -o noatime,compress=zstd,subvol=@snapshots "${DISK}2" /mnt/.snapshots
        mount -o noatime,compress=zstd,subvol=@var_log "${DISK}2" /mnt/var/log
        mount "${DISK}1" /mnt/boot
        success_msg "Subvolumes gemountet."
    fi
}

# Basissystem installieren
install_base_system() {
    step_msg "Installiere Basissystem..."
    pacstrap /mnt base linux linux-firmware networkmanager btrfs-progs || error_exit "Fehler beim Installieren des Basissystems."
    genfstab -U /mnt >> /mnt/etc/fstab || error_exit "Fehler beim Generieren der fstab."
    success_msg "Basissystem installiert."
}

# Grundlegende Systemkonfiguration
configure_system() {
    step_msg "Wechsle ins neue System und führe grundlegende Konfiguration durch..."
    arch-chroot /mnt /bin/bash <<EOF
        ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
        hwclock --systohc
        echo "KEYMAP=de-latin1" > /etc/vconsole.conf
        echo "$HOSTNAME" > /etc/hostname
        echo -e "127.0.0.1   localhost\n::1         localhost\n127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts
        sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
        useradd -m -G wheel -s /bin/bash "$USERNAME"
        echo "$USERNAME:$PASSWORD" | chpasswd
        echo "root:$PASSWORD" | chpasswd
        systemctl enable NetworkManager
EOF
    success_msg "Systemkonfiguration abgeschlossen."
}

# GitHub-Repository klonen
clone_repo() {
    step_msg "Klonen des privaten GitHub-Repositories..."
    mkdir -p /mnt/root/arch-install-scripts
    cp -R ./ /mnt/root/arch-install-scripts || error_exit "Fehler beim Kopieren des Repositories."
    success_msg "Repository kopiert."
}

# Systemd-Service für Post-Install erstellen
setup_post_install_service() {
    step_msg "Erstelle Systemd-Service für automatisches Post-Installationsskript..."
    cat <<EOF > /mnt/etc/systemd/system/post-install.service
[Unit]
Description=Post-Installationsskript
After=multi-user.target
ConditionPathExists=/root/arch-install-scripts/post_install.sh

[Service]
Type=simple
ExecStart=/root/arch-install-scripts/post_install.sh
StandardInput=tty
TTYPath=/dev/tty1

[Install]
WantedBy=multi-user.target
EOF
    arch-chroot /mnt systemctl enable post-install.service || error_exit "Fehler beim Aktivieren des Post-Installations-Services."
    success_msg "Post-Installations-Service erstellt und aktiviert."
}

# Hauptfunktion
main() {
    echo -e "${GREEN}Starte automatisierte Arch Linux Installation...${RESET}"
    update_mirrorlist
    partition_disk
    if [ "$FILESYSTEM" == "btrfs" ]; then
        setup_btrfs
    fi
    install_base_system
    configure_system
    clone_repo
    setup_post_install_service
    success_msg "Installation abgeschlossen. Starte das System neu, um das Post-Installationsskript auszuführen."
}

main
