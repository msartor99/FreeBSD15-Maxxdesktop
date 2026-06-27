#!/bin/sh
# ==============================================================================
# SCRIPT 1: install-base-xfce.sh
# TARGET OS: FreeBSD 15.0-RELEASE (or later)
# AUTHOR: msartor99
# PURPOSE: Core FreeBSD System, X11, SDDM, and base utilities for MaXX
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root (doas / sudo)."
    exit 1
fi

echo "=========================================================="
echo " Phase 1: Core System & Display Manager Installation"
echo "=========================================================="

# 1. Update pkg and install core packages (including MaXX Toolchest utilities)
pkg update
pkg install -y doas unzip libzip wget git htop python3 bashtop smartmontools dbus \
               xorg xorg-server xinit xauth xf86-input-libinput \
               xterm xscreensaver xkill xprop xwininfo gnome-system-monitor gnome-screenshot \
               nvidia-driver-470 nvidia-settings \
               sddm firefox vlc xfce xfce4-goodies \
               cups gutenprint cups-filters hplip system-config-printer avahi \
               fusefs-ntfs fusefs-ext2 fusefs-hfsfuse \
               pulseaudio pipewire wireplumber audio/freedesktop-sound-theme

# 2. Enable essential services
sysrc dbus_enable="YES"
sysrc sddm_enable="YES"
sysrc cupsd_enable="YES"
sysrc avahi_daemon_enable="YES"

# 3. Mount tmpfs for user runtime directories (fixes PipeWire)
if ! grep -q "tmpfs /tmp" /etc/fstab; then
    echo "tmpfs /tmp tmpfs rw,mode=1777 0 0" >> /etc/fstab
fi

# 4. Load NVIDIA kernel module on boot
if ! grep -q "nvidia-modeset" /boot/loader.conf; then
    echo 'nvidia_load="YES"' >> /boot/loader.conf
    echo 'nvidia-modeset_load="YES"' >> /boot/loader.conf
fi

echo "=========================================================="
echo " Phase 1 Completed successfully!"
echo " Please REBOOT your machine before running Script 2."
echo "=========================================================="
