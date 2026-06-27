#!/bin/sh
# ==============================================================================
# SCRIPT 2: install-maxx-interactive.sh
# TARGET OS: FreeBSD 15.0-RELEASE (or later)
# AUTHOR: msartor99
# PURPOSE: Installation of MaXX Interactive Desktop (IRIX Clone) via Linuxulator
# ==============================================================================

# --- 1. PRIVILEGE CHECK ---
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root (doas / sudo)."
    exit 1
fi

# --- 2. BSDDIALOG INTERFACE: USER SELECTION ---
exec 3>&1
TARGET_USER=$(bsddialog --title "MaXX Desktop Configuration" --clear \
    --inputbox "Enter the target username (who will use MaXX):" \
    10 60 "administrateur" 2>&1 1>&3)
DIALOG_EXIT=$?
exec 3>&-

if [ $DIALOG_EXIT -ne 0 ] || [ -z "$TARGET_USER" ]; then
    clear
    echo "Installation cancelled by user."
    exit 1
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    clear
    echo "ERROR: User '$TARGET_USER' does not exist on this FreeBSD system."
    exit 1
fi

USER_HOME=$(eval echo "~$TARGET_USER")
clear

echo "=========================================================="
echo " Phase 2: Installing MaXX Desktop for '$TARGET_USER'"
echo "=========================================================="

# --- 3. LINUXULATOR DEPENDENCIES & HARDWARE ACCELERATION ---
echo "[+] Installing X11 libraries, OpenGL drivers, and Image Decoders..."
pkg install -y linux-rl9 linux-rl9-xorg-libs linux-nvidia-libs-470 wget bash

# Installing Linux image decoders for ROX-Filer
pkg install -y linux-rl9-gdk-pixbuf2 linux-rl9-png linux-rl9-jpeg linux-rl9-librsvg2 linux-rl9-gtk2 2>/dev/null || true

if [ ! -e /bin/bash ]; then
    ln -sf /usr/local/bin/bash /bin/bash
fi

if [ ! -f /compat/linux/etc/machine-id ]; then
    mkdir -p /compat/linux/etc
    dbus-uuidgen > /compat/linux/etc/machine-id
fi

# Silence harmless Linuxulator warnings
if ! grep -q "^compat.linux.print_warnings=0" /etc/sysctl.conf; then
    echo "compat.linux.print_warnings=0" >> /etc/sysctl.conf
fi
sysctl compat.linux.print_warnings=0 >/dev/null 2>&1

# --- 4. PATH PREPARATION ---
echo "[+] Preparing the target virtual environment..."
rm -rf /compat/linux/opt/MaXX /opt/MaXX
mkdir -p /compat/linux/opt /opt
ln -sf /compat/linux/opt/MaXX /opt/MaXX

# --- 5. DIRECT DOWNLOAD AND EXTRACTION ---
mkdir -p /compat/linux/tmp
ARCHIVE_URL="https://s3.ca-central-1.amazonaws.com/cdn.maxxinteractive.com/maxx-desktop-installer/MaXX-Desktop-v2.2.0-LINUX-x86_64-tar.gz"
ARCHIVE_PATH="/compat/linux/tmp/maxx-binaries.tar.gz"

if [ ! -f "/compat/linux/opt/MaXX/etc/skel/Xsession.dt" ]; then
    echo "[+] Downloading the main MaXX archive (233 MB, please wait)..."
    wget --show-progress -O "$ARCHIVE_PATH" "$ARCHIVE_URL"
    
    FILE_SIZE=$(stat -f%z "$ARCHIVE_PATH" 2>/dev/null || stat -c%s "$ARCHIVE_PATH" 2>/dev/null)
    if [ -z "$FILE_SIZE" ] || [ "$FILE_SIZE" -lt 100000000 ]; then
        echo "CRITICAL ERROR: Download failed."
        exit 1
    fi

    echo "[+] Safely extracting the IRIX/MaXX ecosystem..."
    tar -xzf "$ARCHIVE_PATH" -C /compat/linux/opt/
    rm -f "$ARCHIVE_PATH"
else
    echo "[.] MaXX Interactive Desktop is already extracted."
fi

# --- 6. MAXX ENVIRONMENT HOTFIXES ---
echo "[+] Applying MaXX system fixes, caches, and integrating libraries..."

# Fix 1: Resolve missing bin32 folder
ln -sf /compat/linux/opt/MaXX/bin /compat/linux/opt/MaXX/bin32

# Fix 2: Teach Linuxulator where MaXX native libraries are
mkdir -p /compat/linux/etc/ld.so.conf.d
echo "/opt/MaXX/lib" > /compat/linux/etc/ld.so.conf.d/maxx.conf
echo "/opt/MaXX/lib64" >> /compat/linux/etc/ld.so.conf.d/maxx.conf
ln -sf /compat/linux/lib64 /compat/linux/usr/lib64
/compat/linux/sbin/ldconfig

# Fix 3: Force GTK configuration for target user (Icons visibility)
mkdir -p "$USER_HOME/.config/gtk-3.0"
cat << 'EOF' > "$USER_HOME/.gtkrc-2.0"
gtk-icon-theme-name="MaXX"
gtk-theme-name="MaXX"
EOF
cat << 'EOF' > "$USER_HOME/.config/gtk-3.0/settings.ini"
[Settings]
gtk-icon-theme-name=MaXX
gtk-theme-name=MaXX
EOF
chown -R "$TARGET_USER":"$TARGET_USER" "$USER_HOME/.gtkrc-2.0" "$USER_HOME/.config"

# Fix 4: Force Cache generation for Linux Image Decoders
chroot /compat/linux /bin/sh -c "/usr/bin/gdk-pixbuf-query-loaders-64 > /usr/lib64/gdk-pixbuf-2.0/2.10.0/loaders.cache" 2>/dev/null || true

# Fix 5: Copy icons to system and user directories
mkdir -p /compat/linux/usr/share/icons /usr/local/share/icons
rm -f /compat/linux/usr/share/icons/* 2>/dev/null
cp -a /compat/linux/opt/MaXX/share/icons/* /compat/linux/usr/share/icons/ 2>/dev/null || true
cp -a /compat/linux/opt/MaXX/share/icons/* /usr/local/share/icons/ 2>/dev/null || true

mkdir -p "$USER_HOME/.icons"
cp -a /compat/linux/opt/MaXX/share/icons/* "$USER_HOME/.icons/" 2>/dev/null || true
chown -R "$TARGET_USER":"$TARGET_USER" "$USER_HOME/.icons"

chroot /compat/linux /bin/sh -c "/usr/bin/gtk-update-icon-cache -f -t /usr/share/icons/MaXX" 2>/dev/null || true

# --- 7. MAXX STARTUP SCRIPT ---
echo "[+] Deploying secure startup script for SDDM..."
mkdir -p /usr/local/share/xsessions
cat << 'EOF' > /usr/local/share/xsessions/maxx.desktop
[Desktop Entry]
Name=MaXX Interactive Desktop
Comment=Interface style IRIX Silicon Graphics
Exec=/usr/local/bin/start-maxx.sh
Type=Application
EOF

cat << 'EOF' > /usr/local/bin/start-maxx.sh
#!/bin/sh
export MAXX_HOME=/opt/MaXX
export PATH=$MAXX_HOME/bin:$MAXX_HOME/bin64:$PATH
export LANG=fr_CH.UTF-8
export LC_ALL=fr_CH.UTF-8

# Provide XDG paths so ROX-Filer finds the IRIX icons
export XDG_DATA_DIRS=$MAXX_HOME/share:/compat/linux/usr/share:/usr/local/share:/usr/share

# PipeWire / D-Bus Runtime fix
export XDG_RUNTIME_DIR=/tmp/runtime-$(id -u)
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"

LOGFILE="$HOME/maxx-session.log"
echo "========================================" > "$LOGFILE"
echo " Starting MaXX Desktop Session " >> "$LOGFILE"
date >> "$LOGFILE"
echo "========================================" >> "$LOGFILE"

if command -v pipewire >/dev/null; then
    killall pipewire wireplumber 2>/dev/null
    sleep 1
    pipewire >> "$LOGFILE" 2>&1 &
    wireplumber >> "$LOGFILE" 2>&1 &
fi

if [ -d "$MAXX_HOME/share/fonts/X11/pcf" ]; then
    xset fp+ "$MAXX_HOME/share/fonts/X11/pcf" >> "$LOGFILE" 2>&1
    xset fp rehash >> "$LOGFILE" 2>&1
fi

exec bash $MAXX_HOME/etc/skel/Xsession.dt >> "$LOGFILE" 2>&1
EOF
chmod +x /usr/local/bin/start-maxx.sh

# --- 8. TARGET USER INTEGRATION ---
echo "[+] Setting MaXX as the default desktop for $TARGET_USER..."
cat << 'EOF' > "$USER_HOME/.xinitrc"
#!/bin/sh
exec /usr/local/bin/start-maxx.sh
EOF
chown "$TARGET_USER":"$TARGET_USER" "$USER_HOME/.xinitrc"
chmod +x "$USER_HOME/.xinitrc"

echo "=========================================================="
echo " Phase 2 Completed successfully!"
echo " The MaXX environment is physically installed and ready."
echo " Select 'MaXX Interactive Desktop' on the SDDM login screen."
echo "=========================================================="
