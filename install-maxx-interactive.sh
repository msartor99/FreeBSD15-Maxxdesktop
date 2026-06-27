#!/bin/sh
# ==============================================================================
# SCRIPT 2: install-maxx-interactive.sh
# TARGET OS: FreeBSD 15.0-RELEASE (or later)
# AUTHOR: msartor99
# PURPOSE: MaXX Installer, System Hotfixes & Binary Hijacking Wrappers
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Root privileges required. Please execute this script as root."
    exit 1
fi

BACKTITLE="MaXX Desktop SGI - Environment Deployer"

# --- INTERACTIVE STRATEGY ---
exec 3>&1
TARGET_USER=$(bsddialog --backtitle "$BACKTITLE" --title "Target User" --inputbox "Confirm the target username:" 10 60 "administrateur" 2>&1 1>&3)
if [ $? -ne 0 ] || [ -z "$TARGET_USER" ]; then clear; echo "Cancelled."; exit 1; fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    clear; echo "ERROR: User '$TARGET_USER' does not exist."; exit 1;
fi
USER_HOME=$(eval echo "~$TARGET_USER")

if bsddialog --backtitle "$BACKTITLE" --title "Extraction Strategy" --yesno "Do you want to force extraction/redownload of the MaXX ecosystem?" 8 65; then
    FORCE_EXTRACT="y"
else
    FORCE_EXTRACT="n"
fi
exec 3>&-
clear

echo "=========================================================="
echo " Phase 2: Installing and Tuning the MaXX Environment"
echo "=========================================================="

# --- 1. LINUX INTERPRETATION LAYER ---
echo "[+] Extracting additional Linux compatibility decoders..."
# Note: linux-rl9-png and linux-rl9-jpeg are now natively bundled in linux_base-rl9 on FreeBSD 15
pkg install -y linux_base-rl9 linux-rl9 linux-rl9-xorg-libs linux-rl9-gdk-pixbuf2 linux-rl9-librsvg2 linux-rl9-gtk2 pipewire wireplumber audio/freedesktop-sound-theme

[ ! -e /bin/bash ] && ln -sf /usr/local/bin/bash /bin/bash

if [ ! -f /compat/linux/etc/machine-id ]; then
    mkdir -p /compat/linux/etc
    dbus-uuidgen > /compat/linux/etc/machine-id
fi

# Deactivate Linuxulator setsockopt kernel console noise
if ! grep -q "^compat.linux.print_warnings=0" /etc/sysctl.conf; then
    echo "compat.linux.print_warnings=0" >> /etc/sysctl.conf
fi
sysctl compat.linux.print_warnings=0 >/dev/null 2>&1

# --- 2. EXTRACTION & HYBRID SYNCHRONIZATION ---
MAXX_LINUX="/compat/linux/opt/MaXX"
MAXX_HOST="/opt/MaXX"

if [ "$FORCE_EXTRACT" = "y" ] || [ ! -f "$MAXX_LINUX/etc/skel/Xsession.dt" ]; then
    echo "[+] Cleaning target paths..."
    rm -rf "$MAXX_LINUX" "$MAXX_HOST" /opt/MaXX
    mkdir -p "$MAXX_LINUX" /opt
    
    ARCHIVE_PATH="/compat/linux/tmp/maxx-binaries.tar.gz"
    if [ ! -f "$ARCHIVE_PATH" ]; then
        echo "[+] Fetching core repository archive (233 MB)..."
        mkdir -p /compat/linux/tmp
        wget -q --show-progress -O "$ARCHIVE_PATH" "https://s3.ca-central-1.amazonaws.com/cdn.maxxinteractive.com/maxx-desktop-installer/MaXX-Desktop-v2.2.0-LINUX-x86_64-tar.gz"
    fi
    
    echo "[+] Unpacking structural layers..."
    tar -xzf "$ARCHIVE_PATH" -C /compat/linux/opt/
    rm -f "$ARCHIVE_PATH"
    
    # Critical Sync: Merge missing architecture components from bin64 to bin
    if [ -d "$MAXX_LINUX/bin64" ]; then
        echo "[+] Synchronizing 64-bit hybrid entrypoints..."
        cp -af "$MAXX_LINUX"/bin64/* "$MAXX_LINUX"/bin/
    fi
    find "$MAXX_LINUX" -type f -executable -exec brandelf -t Linux {} \; 2>/dev/null
fi

ln -sf "$MAXX_LINUX" "$MAXX_HOST"

# --- 3. PATH INTEGRATION & LIBRARY CHROOT SCAN ---
echo "[+] Linking missing system pathways..."
ln -sf /compat/linux/opt/MaXX/bin /compat/linux/opt/MaXX/bin32
ln -sf /compat/linux/lib64 /compat/linux/usr/lib64

mkdir -p /compat/linux/etc/ld.so.conf.d
echo "/opt/MaXX/lib64" > /compat/linux/etc/ld.so.conf.d/maxx.conf
echo "/opt/MaXX/lib" >> /compat/linux/etc/ld.so.conf.d/maxx.conf

if [ -x "/compat/linux/sbin/ldconfig" ]; then
    chroot /compat/linux /sbin/ldconfig
fi

# --- 4. ROX-FILER VISUAL ENGINE CORRECTIONS ---
echo "[+] Resolving ROX-Filer icon sets and image loaders cache..."

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

chroot /compat/linux /bin/sh -c "/usr/bin/gdk-pixbuf-query-loaders-64 > /usr/lib64/gdk-pixbuf-2.0/2.10.0/loaders.cache" 2>/dev/null || true

mkdir -p /compat/linux/usr/share/icons /usr/local/share/icons
rm -f /compat/linux/usr/share/icons/* 2>/dev/null
cp -a /compat/linux/opt/MaXX/share/icons/* /compat/linux/usr/share/icons/ 2>/dev/null || true
cp -a /compat/linux/opt/MaXX/share/icons/* /usr/local/share/icons/ 2>/dev/null || true

mkdir -p "$USER_HOME/.icons"
cp -a /compat/linux/opt/MaXX/share/icons/* "$USER_HOME/.icons/" 2>/dev/null || true
chown -R "$TARGET_USER":"$TARGET_USER" "$USER_HOME/.icons"

chroot /compat/linux /bin/sh -c "/usr/bin/gtk-update-icon-cache -f -t /usr/share/icons/MaXX" 2>/dev/null || true

# --- 5. BINARY HIJACKING SYSTEM (WRAPPERS & POWER CODES) ---
echo "[+] Deploying routing wrappers to replace dysfunctional entrypoints..."
WD="$MAXX_HOST/bin/wrappers"
mkdir -p "$WD"

create_wrapper() {
    cat > "$WD/$1" << EOF
#!/usr/local/bin/bash
unset LD_LIBRARY_PATH
export DISPLAY=:0
export PATH="/usr/local/bin:/usr/bin:/bin"
export GDK_BACKEND=x11
export MOZ_ENABLE_WAYLAND=0
export LANG=fr_FR.UTF-8
export LC_ALL=fr_FR.UTF-8
exec $2 "\$@"
EOF
    chmod +x "$WD/$1"
}

cat << 'EOF' > "$WD/sys_reboot"
#!/usr/local/bin/bash
/sbin/shutdown -r now
EOF
cat << 'EOF' > "$WD/sys_poweroff"
#!/usr/local/bin/bash
/sbin/shutdown -p now
EOF
chmod +x "$WD/sys_reboot" "$WD/sys_poweroff"

create_wrapper "firefox" "/usr/local/bin/firefox"
create_wrapper "thunderbird" "/usr/local/bin/thunderbird"
create_wrapper "xfe" "/usr/local/bin/xfe"
create_wrapper "sysinfo" "/usr/local/bin/xterm -title 'System Info' -e htop"
create_wrapper "top" "/usr/local/bin/xterm -title 'Process Monitor' -e bashtop"
create_wrapper "pavucontrol" "/usr/local/bin/pavucontrol"
create_wrapper "gnome-screenshot" "/usr/local/bin/gnome-screenshot -i"

# Wrapper foolproof pour xkill (Force le DISPLAY et attend la fermeture du menu)
cat << 'EOF' > "$WD/xkill"
#!/usr/local/bin/bash
export DISPLAY=:0
export PATH="/usr/local/bin:/usr/bin:/bin"
sleep 1
exec /usr/local/bin/xkill
EOF
chmod +x "$WD/xkill"

# Extraction de la configuration du clavier pour injection dynamique dans les terminaux
XKBLAYOUT=$(grep 'Option "XkbLayout"' /usr/local/etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null | awk '{print $3}' | tr -d '"')
XKBVARIANT=$(grep 'Option "XkbVariant"' /usr/local/etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null | awk '{print $3}' | tr -d '"')

for BIN_DIR in "$MAXX_HOST/bin" "$MAXX_HOST/bin32" "$MAXX_HOST/bin64"; do
    [ ! -d "$BIN_DIR" ] && continue
    
    # Basic App Links
    rm -f "$BIN_DIR/WEBBROWSER"; ln -sf "$WD/firefox" "$BIN_DIR/WEBBROWSER"
    rm -f "$BIN_DIR/EMAILCLIENT"; ln -sf "$WD/thunderbird" "$BIN_DIR/EMAILCLIENT"
    rm -f "$BIN_DIR/fm"; ln -sf "$WD/xfe" "$BIN_DIR/fm"
    
    # Native X11 Utilities Injection (with Xkill variations)
    rm -f "$BIN_DIR/xkill" "$BIN_DIR/Xkill"
    ln -sf "$WD/xkill" "$BIN_DIR/xkill"
    ln -sf "$WD/xkill" "$BIN_DIR/Xkill"

    rm -f "$BIN_DIR/xterm"; ln -sf "$WD/xterm" "$BIN_DIR/xterm"
    rm -f "$BIN_DIR/xprop"; ln -sf /usr/local/bin/xprop "$BIN_DIR/xprop"
    rm -f "$BIN_DIR/xwininfo"; ln -sf /usr/local/bin/xwininfo "$BIN_DIR/xwininfo"
    
    # Direct Shell Script Wrappers with Keyboard Layout enforcement
    cat << EOF > "$BIN_DIR/winterm"
#!/bin/sh
[ -n "$XKBLAYOUT" ] && /usr/local/bin/setxkbmap $XKBLAYOUT ${XKBVARIANT:+-variant $XKBVARIANT}
exec /usr/local/bin/xterm -name UnixShell -title "Unix Shell" -sb -sl 1000
EOF

    cat << EOF > "$BIN_DIR/adminterm"
#!/bin/sh
[ -n "$XKBLAYOUT" ] && /usr/local/bin/setxkbmap $XKBLAYOUT ${XKBVARIANT:+-variant $XKBVARIANT}
exec /usr/local/bin/xterm -name AdminShell -title "Admin Shell" -bg "#4d0000" -fg white -e sudo -i
EOF

    cat << EOF > "$BIN_DIR/xsensors"
#!/bin/sh
[ -n "$XKBLAYOUT" ] && /usr/local/bin/setxkbmap $XKBLAYOUT ${XKBVARIANT:+-variant $XKBVARIANT}
exec /usr/local/bin/xterm -title "System Monitor" -e htop
EOF
    chmod +x "$BIN_DIR/winterm" "$BIN_DIR/adminterm" "$BIN_DIR/xsensors"
    
    # Diagnostic Engine Bindings
    rm -f "$BIN_DIR/tellsystem" "$BIN_DIR/gr_osview2" "$BIN_DIR/xosview2" "$BIN_DIR/xosview"
    ln -sf "$WD/sysinfo" "$BIN_DIR/tellsystem"; ln -sf "$WD/sysinfo" "$BIN_DIR/gr_osview2"
    ln -sf "$WD/sysinfo" "$BIN_DIR/xosview2"; ln -sf "$WD/sysinfo" "$BIN_DIR/xosview"
    rm -f "$BIN_DIR/gmemusage"; ln -sf "$WD/top" "$BIN_DIR/gmemusage"
    rm -f "$BIN_DIR/msound"; ln -sf "$WD/pavucontrol" "$BIN_DIR/msound"
    rm -f "$BIN_DIR/ScreenShot"; ln -sf "$WD/gnome-screenshot" "$BIN_DIR/ScreenShot"

    # System Power Management
    rm -f "$BIN_DIR/reboot" "$BIN_DIR/maxx-reboot" "$BIN_DIR/Restart"
    ln -sf "$WD/sys_reboot" "$BIN_DIR/reboot"; ln -sf "$WD/sys_reboot" "$BIN_DIR/maxx-reboot"; ln -sf "$WD/sys_reboot" "$BIN_DIR/Restart"
    rm -f "$BIN_DIR/poweroff" "$BIN_DIR/maxx-poweroff" "$BIN_DIR/shutdown" "$BIN_DIR/halt" "$BIN_DIR/Shutdown"
    ln -sf "$WD/sys_poweroff" "$BIN_DIR/poweroff"; ln -sf "$WD/sys_poweroff" "$BIN_DIR/maxx-poweroff"
    ln -sf "$WD/sys_poweroff" "$BIN_DIR/shutdown"; ln -sf "$WD/sys_poweroff" "$BIN_DIR/Shutdown"
done

# Infiltration locale dans le wrapper global xterm pour couvrir ROX-Filer et appels annexes
cat << EOF > "$WD/xterm"
#!/bin/sh
[ -n "$XKBLAYOUT" ] && /usr/local/bin/setxkbmap $XKBLAYOUT ${XKBVARIANT:+-variant $XKBVARIANT}
exec /usr/local/bin/xterm "\$@"
EOF
chmod +x "$WD/xterm"

# --- 6. SECURE STARTUP ENGINE WITH CLEAN CHANNELS ---
echo "[+] Locking unified startup routines..."
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

# 1. Activation indispensable de D-Bus (pour Firefox, le son et les langues)
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
    export DBUS_SESSION_BUS_ADDRESS
fi

# 2. Forçage propre de l'environnement linguistique fr_FR
export LANG=fr_FR.UTF-8
export LC_ALL=fr_FR.UTF-8

# Map the pathing so ROX-Filer reads vector graphics
export XDG_DATA_DIRS=$MAXX_HOME/share:/compat/linux/usr/share:/usr/local/share:/usr/share

export XDG_RUNTIME_DIR=/tmp/runtime-$(id -u)
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"

unset LD_LIBRARY_PATH

LOGFILE="$HOME/maxx-session.log"
echo "========================================" > "$LOGFILE"
echo " Starting Modern MaXX Session " >> "$LOGFILE"
date >> "$LOGFILE"
echo "========================================" >> "$LOGFILE"

if command -v pipewire >/dev/null; then
    killall pipewire wireplumber 2>/dev/null
    sleep 1
    pipewire >> "$LOGFILE" 2>&1 &
    wireplumber >> "$LOGFILE" 2>&1 &
fi

if [ -d "/boot/images" ] && [ -f "/boot/images/sgi_desktop.jpg" ]; then
    feh --bg-fill /boot/images/sgi_desktop.jpg &
else
    xsetroot -solid SkyBlue4 &
fi

if [ -d "$MAXX_HOME/share/fonts/X11/pcf" ]; then
    xset fp+ "$MAXX_HOME/share/fonts/X11/pcf" >> "$LOGFILE" 2>&1
    xset fp rehash >> "$LOGFILE" 2>&1
fi

xscreensaver -nosplash &

exec bash $MAXX_HOME/etc/skel/Xsession.dt >> "$LOGFILE" 2>&1
EOF
chmod +x /usr/local/bin/start-maxx.sh

# --- 7. HOME ROOT PATH STABILITY ---
echo "[+] Establishing execution paths into target user profile..."
cat << 'EOF' > "$USER_HOME/.xinitrc"
#!/bin/sh
exec /usr/local/bin/start-maxx.sh
EOF
chown "$TARGET_USER":"$TARGET_USER" "$USER_HOME/.xinitrc"
chmod +x "$USER_HOME/.xinitrc"

echo "=========================================================="
echo " Phase 2 Execution Completed Successfully!"
echo " The system is calibrated, robust, and visually restored."
echo " Select 'MaXX Interactive Desktop' from the SDDM menu."
echo "=========================================================="
