#!/bin/sh
# ==============================================================================
# POST-INSTALL MAXX DESKTOP SGI - FREEBSD 15 RELEASE (PURE SH / MASTER V75)
# FONDATION : Locale/Keyboard Auto-Detect, English TUI, Complete Screensaver
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Root privileges required. Please execute this script as root."
    exit 1
fi

BACKTITLE="MaXX Desktop SGI - FreeBSD 15 Installer"

# --- AUTO-DETECT SYSTEM DEFAULTS ---
# Extract base keymap from rc.conf (e.g., 'ch.kbd' -> 'ch', 'fr.kbd' -> 'fr')
SYS_KBD=$(sysrc -n keymap 2>/dev/null | grep -Eo '^[a-z]{2}' || echo "us")

DEFAULT_LANG="en_US.UTF-8"
DEFAULT_X11_KBD="us"

case "$SYS_KBD" in
    fr) DEFAULT_LANG="fr_FR.UTF-8"; DEFAULT_X11_KBD="fr" ;;
    ch) DEFAULT_LANG="fr_CH.UTF-8"; DEFAULT_X11_KBD="ch-fr" ;;
    de) DEFAULT_LANG="de_DE.UTF-8"; DEFAULT_X11_KBD="de" ;;
    uk|gb) DEFAULT_LANG="en_GB.UTF-8"; DEFAULT_X11_KBD="gb" ;;
    es) DEFAULT_LANG="es_ES.UTF-8"; DEFAULT_X11_KBD="es" ;;
    it) DEFAULT_LANG="it_IT.UTF-8"; DEFAULT_X11_KBD="it" ;;
esac

# --- DISCLAIMER AND CREDITS ---
show_disclaimer() {
    local msg="DISCLAIMER OF LIABILITY\n\n\
This script deeply modifies your FreeBSD system configuration. \
It is provided 'as is', without any express or implied warranty. \
By using it, you agree that the author cannot be held responsible \
for any data loss, system breakage, or other damage.\n\n\
ACKNOWLEDGEMENTS\n\n\
A huge thanks to Silicon Graphics fandom computer website \
for providing their beautiful public domain images, used here to enhance \
the login theme and boot splash screen.\n\n\
Do you accept these conditions to continue?"

    if ! bsddialog --backtitle "$BACKTITLE" --title "Warning & Credits" --yesno "$msg" 18 75; then
        clear
        echo "Installation cancelled by the user. No changes have been made."
        exit 1
    fi
}

# --- INTERACTIVE PHASES (bsddialog) ---

show_disclaimer

# 1. Language & Region Selection
USER_LOCALE=$(bsddialog --backtitle "$BACKTITLE" --title "Language & Region" --default-item "$DEFAULT_LANG" --menu "Select your system language and region:" 15 60 8 \
    "en_US.UTF-8" "English (US)" \
    "en_GB.UTF-8" "English (UK)" \
    "fr_FR.UTF-8" "French (France)" \
    "fr_CH.UTF-8" "French (Switzerland)" \
    "de_DE.UTF-8" "German (Germany)" \
    "de_CH.UTF-8" "German (Switzerland)" \
    "es_ES.UTF-8" "Spanish (Spain)" \
    "it_IT.UTF-8" "Italian (Italy)" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then clear; echo "Installation cancelled."; exit 1; fi

# 2. Keyboard Selection
X11_KBD=$(bsddialog --backtitle "$BACKTITLE" --title "Keyboard Layout" --default-item "$DEFAULT_X11_KBD" --menu "Select your X11 Keyboard Layout:" 15 60 8 \
    "us" "US English" \
    "gb" "UK English" \
    "fr" "French (AZERTY)" \
    "ch-fr" "Swiss French (QWERTZ)" \
    "ch-de" "Swiss German (QWERTZ)" \
    "de" "German (QWERTZ)" \
    "es" "Spanish (QWERTY)" \
    "it" "Italian (QWERTY)" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then clear; echo "Installation cancelled."; exit 1; fi

# Parse Keyboard Layout and Variant
case "$X11_KBD" in
    *-*) XKBLAYOUT="${X11_KBD%%-*}"; XKBVARIANT="${X11_KBD##*-}" ;;
    *)   XKBLAYOUT="$X11_KBD"; XKBVARIANT="" ;;
esac

# 3. Target User Configuration
while true; do
    TARGET_USER=$(bsddialog --backtitle "$BACKTITLE" --title "Target User" --inputbox "Enter the target username (e.g., administrator):" 10 60 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ] || [ -z "$TARGET_USER" ]; then
        clear; echo "Installation cancelled."; exit 1
    fi
    if id "$TARGET_USER" >/dev/null 2>&1; then
        break
    else
        bsddialog --backtitle "$BACKTITLE" --title "Error" --msgbox "User '$TARGET_USER' does not exist. Please create it first." 8 50
    fi
done

# 4. MaXX Desktop Download Strategy
if bsddialog --backtitle "$BACKTITLE" --title "MaXX Desktop Download" --yesno "Do you want to (re)download and install MaXX Desktop from scratch?" 8 65; then
    FORCE_DL="y"
else
    FORCE_DL="n"
fi

# 5. GPU Selection
GPU_CHOICE=$(bsddialog --backtitle "$BACKTITLE" --title "GPU Selection" --menu "Select your graphics card vendor:" 12 50 3 \
    1 "AMD" \
    2 "NVIDIA" \
    3 "Intel" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then clear; echo "Installation cancelled."; exit 1; fi

if [ "$GPU_CHOICE" = "2" ]; then
    NV_VER=$(bsddialog --backtitle "$BACKTITLE" --title "NVIDIA Driver Version" --menu "Select the NVIDIA driver branch (FreeBSD 15):" 12 60 3 \
        1 "Latest (595+ for Pascal and newer)" \
        2 "Legacy 580 Series" \
        3 "Legacy 470 (Kepler)" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then clear; echo "Installation cancelled."; exit 1; fi
fi

# Clear screen before starting the automated process
clear

step_start() { 
    printf "\n\033[1;30m================================================================================\033[0m\n"
    printf "\033[1;30m %s \033[0m\n" "$1"
    printf "\033[1;30m================================================================================\033[0m\n"
}

step_done() { 
    printf "\n\033[1;32m[ DONE ] %s\033[0m\n" "$1"
}

# --- STEP 1 : PACKAGES AND SERVICES (FreeBSD 15) ---
step_start "1/10: Bootstrap pkg, Services and Dependencies"

sysrc dbus_enable="YES"
sysrc sddm_enable="YES"
sysrc linux_enable="YES"
sysrc rpcbind_enable="YES"

env ASSUME_ALWAYS_YES=YES pkg bootstrap
env ASSUME_ALWAYS_YES=YES pkg update -f

pkg install -y xorg
pkg install -y bash sddm xfe firefox thunderbird xterm pulseaudio pavucontrol alsa-utils alsa-plugins xpdf xorg-apps nedit linux_base-rl9 linux-rl9 xprop pciutils usbutils scrot vlc ImageMagick7 feh sudo unzip libzip wget git htop neofetch python3 bashtop smartmontools xscreensaver xmountains xdaliclock xlockmore

if [ -d "/compat/linux/usr/lib64" ]; then
    [ -f "/compat/linux/usr/lib64/libtinfo.so.6" ] && ln -sf /compat/linux/usr/lib64/libtinfo.so.6 /compat/linux/usr/lib64/libtinfo.so.5
    [ -f "/compat/linux/usr/lib64/libncurses.so.6" ] && ln -sf /compat/linux/usr/lib64/libncurses.so.6 /compat/linux/usr/lib64/libncurses.so.5
fi

case $GPU_CHOICE in
    2)
        GPU_NAME="NVIDIA"; KMOD_DRIVER="nvidia-modeset"
        case $NV_VER in
            2) NV_BASE="nvidia-driver-580"; NV_LIN="linux-nvidia-libs-580" ;;
            3) NV_BASE="nvidia-driver-470"; NV_LIN="linux-nvidia-libs-470" ;;
            *) NV_BASE="nvidia-driver"; NV_LIN="linux-nvidia-libs" ;;
        esac
        pkg install -y "$NV_BASE" "$NV_LIN" nvidia-xconfig
        GPU_ENV="export __GLX_VENDOR_LIBRARY_NAME=nvidia"
        ;;
    3) GPU_NAME="Intel"; KMOD_DRIVER="i915kms"; pkg install -y drm-kmod libva-intel-driver; GPU_ENV="export LIBGL_ALWAYS_SOFTWARE=1" ;;
    *) GPU_NAME="AMD"; KMOD_DRIVER="amdgpu"; pkg install -y drm-kmod; GPU_ENV="export LIBGL_ALWAYS_SOFTWARE=1" ;;
esac

CURRENT_KMODS=$(sysrc -n kld_list)
case "$CURRENT_KMODS" in
    *"$KMOD_DRIVER"*) ;;
    *) sysrc kld_list+="$KMOD_DRIVER" ;;
esac
kldload "$KMOD_DRIVER" 2>/dev/null

# --- STEP 2 : MOUNT POINTS & ALIASES ---
step_start "2/10: Linux Mount Points & Aliases"

[ -L /usr/share/icons ] && unlink /usr/share/icons
[ -L /usr/share/xsessions ] && unlink /usr/share/xsessions
[ -L /usr/local/share/xsessions ] && unlink /usr/local/share/xsessions

add_fstab() { grep -q "$2" /etc/fstab || printf "%s %s %s %s %s %s\n" "$1" "$2" "$3" "$4" "$5" "$6" >> /etc/fstab; }
add_fstab "fdescfs"   "/dev/fd"             "fdescfs"  "rw"           "0" "0"
add_fstab "procfs"    "/proc"               "procfs"   "rw"           "0" "0"
add_fstab "linprocfs" "/compat/linux/proc"  "linprocfs" "rw,late"     "0" "0"
add_fstab "linsysfs"  "/compat/linux/sys"   "linsysfs" "rw,late"      "0" "0"
add_fstab "devfs"     "/compat/linux/dev"   "devfs"    "rw,late"      "0" "0"
mount -a 2>/dev/null

[ ! -L /bin/bash ] && ln -sf /usr/local/bin/bash /bin/bash
[ ! -L /usr/bin/arch ] && ln -sf /usr/bin/uname /usr/bin/arch
mkdir -p /usr/local/share/icons /usr/local/share/xsessions
[ ! -L /usr/share/icons ] && ln -sf /usr/local/share/icons /usr/share/icons
[ ! -L /usr/share/xsessions ] && ln -sf /usr/local/share/xsessions /usr/share/xsessions

# --- STEP 3 : TUNING KERNEL & SILENT BOOT ---
step_start "3/10: System Tuning & Silent Boot"

sysrc -f /boot/loader.conf boot_mute="YES"
sysrc -f /boot/loader.conf autoboot_delay="3"
sysrc -f /boot/loader.conf tmpfs_load="YES"
sysrc -f /boot/loader.conf aio_load="YES"

if ! grep -q "> \/dev\/null" /etc/rc; then
    sed -i '' 's/run_rc_script ${_rc_elem} ${_boot}/run_rc_script ${_rc_elem} ${_boot} > \/dev\/null/g' /etc/rc
fi
sysrc rc_startmsgs="NO"

add_sysctl() { grep -q "^$1" /etc/sysctl.conf || echo "$1=$2" >> /etc/sysctl.conf; sysctl $1=$2 >/dev/null 2>&1; }
add_sysctl "kern.sched.preempt_thresh" "224"
add_sysctl "kern.ipc.shm_allow_removed" "1"
add_sysctl "net.local.stream.recvspace" "65536"
add_sysctl "net.local.stream.sendspace" "65536"

sysrc smartd_enable="YES"
[ ! -f /usr/local/etc/smartd.conf ] && cp /usr/local/etc/smartd.conf.sample /usr/local/etc/smartd.conf
service smartd start 2>/dev/null

# --- STEP 4 : GRAPHICS STACK (XORG, SDDM, NVIDIA, KEYBOARD) ---
step_start "4/10: Unified Graphics & Keyboard Configuration"

# Set SDDM Language dynamically
SDDM_LANG="${USER_LOCALE%%.*}"
sysrc sddm_lang="$SDDM_LANG"

mkdir -p /usr/local/etc/X11/xorg.conf.d

# Generate dynamic X11 Keyboard config
cat > /usr/local/etc/X11/xorg.conf.d/00-keyboard.conf << EOF
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "$XKBLAYOUT"
        Option "XkbVariant" "$XKBVARIANT"
EndSection
EOF

cat > /usr/local/etc/X11/xorg.conf.d/20-keyboards.conf << EOF
Section "ServerFlags"
                 Option "DontZap" "false"
EndSection
Section     "InputClass"
           Identifier     "All Keyboards"
           MatchIsKeyboard    "yes"
           Option     "XkbLayout" "$XKBLAYOUT"
           Option     "XkbVariant" "$XKBVARIANT"
           Option     "XkbOptions" "terminate:ctrl_alt_bksp" 
EndSection
EOF

# Force Keyboard in SDDM Xsetup
XSETUP="/usr/local/share/sddm/scripts/Xsetup"
if [ -f "$XSETUP" ]; then
    if ! grep -q "setxkbmap" "$XSETUP"; then
        if [ -n "$XKBVARIANT" ]; then
            echo "setxkbmap -layout $XKBLAYOUT -variant $XKBVARIANT" >> "$XSETUP"
        else
            echo "setxkbmap -layout $XKBLAYOUT" >> "$XSETUP"
        fi
    fi
fi

if [ "$GPU_NAME" = "NVIDIA" ]; then
    printf "\nðŸ‘‰ Configuring Xorg for NVIDIA...\n"
    if [ -f /usr/local/bin/nvidia-xconfig ]; then
        nvidia-xconfig
    else
        echo "Warning: nvidia-xconfig not found."
    fi
fi

# --- STEP 5 : SUDO, SSH ROOT & USER LOCALE ---
step_start "5/10: Security and Localization"

mkdir -p /usr/local/etc/sudoers.d
echo "%wheel ALL=(ALL) ALL" > /usr/local/etc/sudoers.d/wheel
chmod 0440 /usr/local/etc/sudoers.d/wheel

sysrc sshd_enable="YES"
if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
    sed -i '' 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
else
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
fi
service sshd restart >/dev/null 2>&1 || true

# Dynamic login.conf generation based on user choice
CLASS_NAME="custom_${USER_LOCALE%%.*}"
sed -i '' "/^${CLASS_NAME}|/,/:tc=default:/d" /etc/login.conf 2>/dev/null
printf "%s|Custom User Class:\n\t:charset=UTF-8:\n\t:lang=%s:\n\t:tc=default:\n" "$CLASS_NAME" "$USER_LOCALE" >> /etc/login.conf
cap_mkdb /etc/login.conf
echo "defaultclass=$CLASS_NAME" > /etc/adduser.conf

pw usermod "$TARGET_USER" -G wheel,operator,video -L "$CLASS_NAME" 2>/dev/null

# --- STEP 6 : MAXX DESKTOP & ROOTFS INVERSION ---
step_start "6/10: MaXX Desktop Installation (Linux RootFS)"

MAXX_LINUX="/compat/linux/opt/MaXX"
MAXX_HOST="/opt/MaXX"

[ -L "$MAXX_LINUX" ] && unlink "$MAXX_LINUX"
[ -L "$MAXX_HOST" ] && unlink "$MAXX_HOST"
rm -rf "$MAXX_HOST" 2>/dev/null

if [ "$FORCE_DL" = "y" ] || [ "$FORCE_DL" = "Y" ]; then
    rm -rf "$MAXX_LINUX"
    mkdir -p "$MAXX_LINUX"
    
    cd /tmp || exit 1
    TARBALL="MaXX-Desktop-v2.2.0-LINUX-x86_64-tar.gz"
    [ ! -f "$TARBALL" ] && fetch https://s3.ca-central-1.amazonaws.com/cdn.maxxinteractive.com/maxx-desktop-installer/$TARBALL
    tar -xzf "$TARBALL" --strip-components=1 -C "$MAXX_LINUX"

    if [ -d "$MAXX_LINUX/bin64" ]; then
        cp -af "$MAXX_LINUX"/bin64/* "$MAXX_LINUX"/bin/
    fi
    find "$MAXX_LINUX" -type f -executable -exec brandelf -t Linux {} \; 2>/dev/null
fi

ln -sf "$MAXX_LINUX" "$MAXX_HOST"

mkdir -p /compat/linux/etc/ld.so.conf.d
echo "/opt/MaXX/lib64" > /compat/linux/etc/ld.so.conf.d/maxx.conf
echo "/opt/MaXX/lib" >> /compat/linux/etc/ld.so.conf.d/maxx.conf
chroot /compat/linux /sbin/ldconfig

# --- STEP 7 : SPLASH SCREEN, BOOT LOGO AND SDDM ---
step_start "7/10: Generating SGI Splash (RGBA), Boot Logo and SDDM"

IMG_DIR="/boot/images"
mkdir -p "$IMG_DIR"

SGI_WALLPAPER_URL="https://raw.githubusercontent.com/msartor99/FreeBSD15-Maxxdesktop/main/sgi_desktop.jpg"
SGI_MENU_LOGO_URL="https://raw.githubusercontent.com/msartor99/FreeBSD15-Maxxdesktop/main/sgilogo.png"

cd "$IMG_DIR" || exit 1

# 1. Boot Menu Logo
wget -q -U "Mozilla/5.0" -O "sgi_menu_src.png" "$SGI_MENU_LOGO_URL"
if [ -f "sgi_menu_src.png" ]; then
    cp "sgi_menu_src.png" "freebsd-brand-rev.png"
    cp "sgi_menu_src.png" "freebsd-brand.png"
    rm -f "sgi_menu_src.png"
    
    sed -i '' '/loader_logo/d' /boot/loader.conf 2>/dev/null
    sed -i '' '/loader_brand/d' /boot/loader.conf 2>/dev/null
fi

# 2. Splash Screen and SDDM Background
wget -q -U "Mozilla/5.0" -O "sgi_desktop.jpg" "$SGI_WALLPAPER_URL"
if [ -f "sgi_desktop.jpg" ]; then
    PATH="/usr/local/bin:$PATH"
    
    magick sgi_desktop.jpg -resize 1920x1200^ -gravity center -extent 1920x1200 -alpha set -define png:color-type=6 "png32:sgi_boot.png"
    
    if [ -f "sgi_boot.png" ]; then
        sysrc -f /boot/loader.conf splash="/boot/images/sgi_boot.png"
    fi
    
    # SDDM Theme creation
    SDDM_BASE="/usr/local/share/sddm/themes"
    if [ -d "$SDDM_BASE/maldives" ]; then
        rm -rf "$SDDM_BASE/sgi_irix"
        cp -R "$SDDM_BASE/maldives" "$SDDM_BASE/sgi_irix"
        cp "sgi_desktop.jpg" "$SDDM_BASE/sgi_irix/sgi_desktop.jpg"
        sed -i '' "s|^background=.*|background=sgi_desktop.jpg|" "$SDDM_BASE/sgi_irix/theme.conf"
        mkdir -p /usr/local/etc/sddm.conf.d
        cat > /usr/local/etc/sddm.conf.d/10-theme.conf << 'EOF'
[Theme]
Current=sgi_irix
EOF
    fi
fi
cd - >/dev/null

# --- STEP 8 : BINARY HIJACKING (WRAPPERS & POWER) ---
step_start "8/10: Hijacking MaXX binaries (Wrappers & Power Management)"

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
exec $2 "\$@"
EOF
    chmod +x "$WD/$1"
}

# App Wrappers
create_wrapper "firefox" "/usr/local/bin/firefox"
create_wrapper "thunderbird" "/usr/local/bin/thunderbird"
create_wrapper "xfe" "/usr/local/bin/xfe"
create_wrapper "unix_shell" "/usr/local/bin/xterm -name UnixShell -title 'Unix Shell' -sb -sl 1000"
create_wrapper "admin_shell" "/usr/local/bin/xterm -name AdminShell -title 'Admin Shell' -bg '#4d0000' -fg white -e sudo -i"
create_wrapper "sysinfo" "/usr/local/bin/xterm -title 'System Info' -e htop"
create_wrapper "top" "/usr/local/bin/xterm -title 'Process Monitor' -e bashtop"
create_wrapper "pavucontrol" "/usr/local/bin/pavucontrol"

# Power Management Wrappers
create_wrapper "sys_reboot" "sudo /sbin/reboot"
create_wrapper "sys_poweroff" "sudo /sbin/poweroff"

# Replacing symbolic links
rm -f "$MAXX_HOST/bin/WEBBROWSER"; ln -sf "$WD/firefox" "$MAXX_HOST/bin/WEBBROWSER"
rm -f "$MAXX_HOST/bin/EMAILCLIENT"; ln -sf "$WD/thunderbird" "$MAXX_HOST/bin/EMAILCLIENT"
rm -f "$MAXX_HOST/bin/winterm"; ln -sf "$WD/unix_shell" "$MAXX_HOST/bin/winterm"
rm -f "$MAXX_HOST/bin/adminterm"; ln -sf "$WD/admin_shell" "$MAXX_HOST/bin/adminterm"
rm -f "$MAXX_HOST/bin/fm"; ln -sf "$WD/xfe" "$MAXX_HOST/bin/fm"
rm -f "$MAXX_HOST/bin/tellsystem"; ln -sf "$WD/sysinfo" "$MAXX_HOST/bin/tellsystem"
rm -f "$MAXX_HOST/bin/gr_osview2"; ln -sf "$WD/sysinfo" "$MAXX_HOST/bin/gr_osview2"
rm -f "$MAXX_HOST/bin/gmemusage"; ln -sf "$WD/top" "$MAXX_HOST/bin/gmemusage"
rm -f "$MAXX_HOST/bin/msound"; ln -sf "$WD/pavucontrol" "$MAXX_HOST/bin/msound"

# Hijacking Toolchest Power Commands
rm -f "$MAXX_HOST/bin/reboot"; ln -sf "$WD/sys_reboot" "$MAXX_HOST/bin/reboot"
rm -f "$MAXX_HOST/bin/maxx-reboot"; ln -sf "$WD/sys_reboot" "$MAXX_HOST/bin/maxx-reboot"
rm -f "$MAXX_HOST/bin/poweroff"; ln -sf "$WD/sys_poweroff" "$MAXX_HOST/bin/poweroff"
rm -f "$MAXX_HOST/bin/maxx-poweroff"; ln -sf "$WD/sys_poweroff" "$MAXX_HOST/bin/maxx-poweroff"
rm -f "$MAXX_HOST/bin/shutdown"; ln -sf "$WD/sys_poweroff" "$MAXX_HOST/bin/shutdown"
rm -f "$MAXX_HOST/bin/halt"; ln -sf "$WD/sys_poweroff" "$MAXX_HOST/bin/halt"

# --- STEP 9 : START_MAXX ---
step_start "9/10: Session Script & SDDM Configuration"

# We dynamically generate the start_maxx script using the selected USER_LOCALE
cat > /usr/local/bin/start_maxx << EOF
#!/usr/local/bin/bash
export LANG="$USER_LOCALE"
export LC_ALL="$USER_LOCALE"

USER_ID=\$(id -u)
export XDG_RUNTIME_DIR="/tmp/runtime-\${USER}"
mkdir -p "\$XDG_RUNTIME_DIR"
chmod 700 "\$XDG_RUNTIME_DIR"

unset LD_LIBRARY_PATH

xprop -root -remove _XROOTPMAP_ID 2>/dev/null
xprop -root -remove ESETROOT_PMAP_ID 2>/dev/null

if [ -f "/boot/images/sgi_desktop.jpg" ]; then
    feh --bg-fill /boot/images/sgi_desktop.jpg &
else
    xsetroot -solid "#395E79" &
fi
xset b off 2>/dev/null

pulseaudio --start --exit-idle-time=-1 2>/dev/null &

# Motif Screensaver with standard X11 demos
xscreensaver -nosplash &

$GPU_ENV
export MAXX_HOME=/opt/MaXX
export MAXX_BIN=\$MAXX_HOME/bin
export MAXX_SHARE=\$MAXX_HOME/share
export PATH=\$MAXX_BIN:/usr/local/bin:/usr/bin:/bin

export XAPPLRESDIR="\$MAXX_SHARE/X11/app-defaults/%N"
export XUSERSEARCHPATH="\$MAXX_SHARE/X11/app-defaults/%N"

if [ -f "\$MAXX_BIN/ttsession" ]; then
    \$MAXX_BIN/ttsession -s &
    sleep 1
fi

\$MAXX_BIN/toolchest &
exec \$MAXX_BIN/5Dwm
EOF
chmod +x /usr/local/bin/start_maxx

mkdir -p /usr/local/share/xsessions
cat > /usr/local/share/xsessions/maxx.desktop << 'EOF'
[Desktop Entry]
Name=MaXX Desktop (SGI IRIX)
Exec=/usr/local/bin/start_maxx
Type=Application
EOF

step_done "Installation completed successfully. Please reboot your system."

