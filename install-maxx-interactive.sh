#!/bin/sh
# ==============================================================================
# SCRIPT 2 : install-maxx-interactive.sh (VERSION FINALE COMPLETE & IDEMPOTENTE)
# TARGET OS: FreeBSD 15.1-RELEASE (POSIX /bin/sh)
# HARDWARE : HP Z4 G4 / Xeon W-2140B / NVIDIA Quadro M4000 (Driver 470) / ASUS PB278
# REPO     : https://github.com/msartor99/FreeBSD-Maxxdesktop
# ==============================================================================

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Ce script doit etre execute en root."
    exit 1
fi

TARGET_USER="administrateur"
USER_HOME="/home/${TARGET_USER}"
MAXX_FILENAME="MaXX-Desktop-v2.2.0-LINUX-x86_64-tar.gz"
MAXX_TAR="${USER_HOME}/${MAXX_FILENAME}"
MAXX_URL="https://s3.ca-central-1.amazonaws.com/cdn.maxxinteractive.com/maxx-desktop-installer/${MAXX_FILENAME}"
GITHUB_RAW="https://raw.githubusercontent.com/msartor99/FreeBSD-Maxxdesktop/main"

echo "=== Phase 2 : Installation et Calibration Integrale de MaXX Interactive Desktop ==="

# ------------------------------------------------------------------------------
# 1. INSTALLATION DES POLICES X11/MOTIF, APPLICATIONS, SONDES MATERIELLES & LINUXULATOR
# ------------------------------------------------------------------------------
echo "-> [1/11] Verification des polices X11/SGI, outils materiels et Linuxulator..."
pkg install -y \
    xorg-fonts font-alias font-misc-misc font-bh-75dpi font-bh-100dpi \
    font-bh-lucidatypewriter-75dpi font-bh-lucidatypewriter-100dpi \
    font-adobe-75dpi font-adobe-100dpi font-ibm-type1 font-dec-misc \
    font-sun-misc font-cursor-misc dejavu noto-basic \
    tradcpp xrdb xset xsetroot xprop xwininfo xkill setxkbmap xclock \
    mkfontscale mkfontdir feh dunst alttab scrot xterm wget curl ImageMagick7 \
    mesa-demos nvidia-settings dmidecode pciutils usbutils \
    firefox thunderbird vlc pavucontrol dsbmixer ristretto mousepad thunar \
    btop shared-mime-info 2>/dev/null || true

sysrc linux_enable="YES"
sysrc linux_mounts_enable="YES"
service linux start 2>/dev/null || true

for lpkg in \
    linux_base-rl9 \
    linux-rl9-xorg-libs \
    linux-rl9-libjpeg-turbo \
    linux-rl9-libpng \
    linux-rl9-freetype \
    linux-rl9-fontconfig \
    linux-rl9-gtk2 \
    linux-rl9-gtk3 \
    linux-rl9-gdk-pixbuf2 \
    linux-rl9-pango \
    linux-rl9-cairo \
    linux-rl9-harfbuzz \
    linux-rl9-atk \
    linux-rl9-alsa-lib \
    linux-rl9-dbus-libs \
    linux-rl9-libGLU \
    linux-rl9-libglvnd \
    linux-rl9-motif \
    linux-nvidia-libs-470; do
    pkg install -y "$lpkg" 2>/dev/null || true
done

# ------------------------------------------------------------------------------
# 2. UNIFICATION DE /TMP ET LIENS DE COMPATIBILITE LINUXULATOR (NCURSES V5)
# ------------------------------------------------------------------------------
echo "-> [2/11] Unification de /compat/linux/tmp -> /tmp et bibliotheques Linuxulator..."
rm -rf /compat/linux/tmp
ln -s /tmp /compat/linux/tmp
chmod 1777 /tmp
ln -sf /usr/local /compat/linux/usr/local

if [ ! -f /compat/linux/etc/machine-id ]; then
    /bin/uuidgen > /compat/linux/etc/machine-id
fi

ln -sf libtinfo.so.6 /compat/linux/usr/lib64/libtinfo.so.5
ln -sf libncurses.so.6 /compat/linux/usr/lib64/libncurses.so.5

# ------------------------------------------------------------------------------
# 3. TELECHARGEMENT (AVEC CACHE) ET EXTRACTION DE MAXX DESKTOP OCTANE 2.2.0
# ------------------------------------------------------------------------------
echo "-> [3/11] Verification et telechargement de l'archive MaXX Desktop Octane 2.2.0..."
mkdir -p /compat/linux/opt /opt

if [ -f "/root/${MAXX_FILENAME}" ] && [ ! -f "$MAXX_TAR" ]; then
    cp -f "/root/${MAXX_FILENAME}" "$MAXX_TAR"
fi

if [ -f "$MAXX_TAR" ] && [ ! -s "$MAXX_TAR" ]; then
    rm -f "$MAXX_TAR"
fi

if [ ! -f "$MAXX_TAR" ]; then
    echo "-> Telechargement de ${MAXX_FILENAME} (233 Mo)..."
    wget -c -O "$MAXX_TAR" "$MAXX_URL" || fetch -o "$MAXX_TAR" "$MAXX_URL"
    chown "${TARGET_USER}:${TARGET_USER}" "$MAXX_TAR"
fi

if [ ! -x /compat/linux/opt/MaXX/bin64/5Dwm ]; then
    echo "-> Extraction propre de MaXX Desktop dans /compat/linux/opt/MaXX..."
    rm -rf /compat/linux/opt/MaXX /opt/MaXX
    tar -xzf "$MAXX_TAR" -C /compat/linux/opt
fi
ln -sf /compat/linux/opt/MaXX /opt/MaXX

# ------------------------------------------------------------------------------
# 4. TELECHARGEMENT ET CALIBRATION DES SPLASH SCREENS SGI (BOOT UEFI, SDDM, BUREAU)
# ------------------------------------------------------------------------------
echo "-> [4/11] Telechargement et calibration des images Splash SGI (msartor99/FreeBSD-Maxxdesktop)..."
mkdir -p /boot/images

curl -s "https://api.github.com/repos/msartor99/FreeBSD-Maxxdesktop/contents" | grep '"download_url"' | cut -d'"' -f4 | grep -iE "\.jpg|\.png" | while read -r img_url; do
    fname=$(basename "$img_url")
    fetch -q -o "/boot/images/$fname" "$img_url" 2>/dev/null || true
done

if [ ! -s /boot/images/SGI_splash.jpg ]; then
    fetch -q -o /boot/images/SGI_splash.jpg "${GITHUB_RAW}/SGI_splash.jpg" 2>/dev/null || \
    fetch -q -o /boot/images/SGI_splash.jpg "${GITHUB_RAW}/sgi_splash.jpg" 2>/dev/null || true
fi
if [ ! -s /boot/images/sgi_desktop.jpg ]; then
    fetch -q -o /boot/images/sgi_desktop_orig.jpg "${GITHUB_RAW}/sgi_desktop.jpg" 2>/dev/null || \
    fetch -q -o /boot/images/sgi_desktop_orig.jpg "${GITHUB_RAW}/SGI_desktop.jpg" 2>/dev/null || true
else
    cp -f /boot/images/sgi_desktop.jpg /boot/images/sgi_desktop_orig.jpg
fi

if [ -f /boot/images/SGI_splash.jpg ] && [ ! -f /boot/images/sgi_splash.jpg ]; then
    cp -f /boot/images/SGI_splash.jpg /boot/images/sgi_splash.jpg
elif [ -f /boot/images/sgi_splash.jpg ] && [ ! -f /boot/images/SGI_splash.jpg ]; then
    cp -f /boot/images/sgi_splash.jpg /boot/images/SGI_splash.jpg
fi

if [ -s /boot/images/SGI_splash.jpg ]; then
    /usr/local/bin/magick /boot/images/SGI_splash.jpg \
        -resize 1920x1080^ -gravity center -extent 1920x1080 \
        -strip -depth 8 -alpha set -define png:color-type=6 \
        "png32:/boot/images/sgi_splash.png"
    cp -f /boot/images/sgi_splash.png /boot/images/freebsd-logo-rev.png 2>/dev/null || true
fi

if [ -s /boot/images/sgi_desktop_orig.jpg ]; then
    /usr/local/bin/magick /boot/images/sgi_desktop_orig.jpg \
        -resize 2560x1440^ -gravity center -extent 2560x1440 \
        /boot/images/sgi_desktop.jpg
elif [ -s /boot/images/SGI_splash.jpg ]; then
    /usr/local/bin/magick /boot/images/SGI_splash.jpg \
        -resize 2560x1440^ -gravity center -extent 2560x1440 \
        /boot/images/sgi_desktop.jpg
fi

if [ -s /boot/images/sgi_desktop.jpg ] && [ -d /usr/local/share/sddm/themes/sgi_irix ]; then
    cp -f /boot/images/sgi_desktop.jpg /usr/local/share/sddm/themes/sgi_irix/background.jpg
    chmod 644 /usr/local/share/sddm/themes/sgi_irix/background.jpg
fi

sed -i '' '/^boot_mute=/d; /^beastie_disable=/d; /^loader_logo=/d; /^splash=/d; /^shutdown_splash=/d; /^efi_max_resolution=/d' /boot/loader.conf
cat >> /boot/loader.conf << 'EOF'
efi_max_resolution="1080p"
boot_mute="YES"
beastie_disable="YES"
loader_logo="none"
splash="/boot/images/sgi_splash.png"
shutdown_splash="/boot/images/sgi_splash.png"
EOF

# ------------------------------------------------------------------------------
# 5. ENREGISTREMENT LDCONFIG, CACHES GDK-PIXBUF & MIME (ICONES ROX-FILER)
# ------------------------------------------------------------------------------
echo "-> [5/11] Configuration du cache ldconfig, GDK-Pixbuf et MIME dans Linuxulator..."
mkdir -p /compat/linux/etc/ld.so.conf.d
printf "/opt/MaXX/lib64\n/opt/MaXX/lib\n" > /compat/linux/etc/ld.so.conf.d/maxx.conf
/compat/linux/sbin/ldconfig 2>/dev/null || chroot /compat/linux /sbin/ldconfig 2>/dev/null || true

mkdir -p /compat/linux/usr/share/mime
cp -af /usr/local/share/mime/* /compat/linux/usr/share/mime/ 2>/dev/null || true
chroot /compat/linux /usr/bin/update-mime-database /usr/share/mime 2>/dev/null || true
chroot /compat/linux /usr/bin/gdk-pixbuf-query-loaders-64 --update-cache 2>/dev/null || true

# ------------------------------------------------------------------------------
# 6. TATOUAGE ELF (BRANDELF LINUX) UNIQUEMENT SUR LES VRAIS BINAIRES ELF
# ------------------------------------------------------------------------------
echo "-> [6/11] Tatouage ELF (brandelf Linux) sur les binaires MaXX..."
find /compat/linux/opt/MaXX/bin64 /compat/linux/opt/MaXX/bin /compat/linux/opt/MaXX/lib64 \
    -type f ! -name "*.sh" ! -name "*.py" ! -name "*.pl" ! -name "*.conf" ! -name "*.ad" 2>/dev/null | while read -r f; do
    if file -b "$f" 2>/dev/null | grep -q "^ELF "; then
        brandelf -t Linux "$f" 2>/dev/null || true
    fi
done

# ------------------------------------------------------------------------------
# 7. PONTS SYSTEME, OUTILS HINV (DMIDECODE/LSPCI/LSUSB), POLICES SGI & TRADCPP
# ------------------------------------------------------------------------------
echo "-> [7/11] Creation des ponts systeme, sondes materielles SGI et tradcpp..."
mkdir -p /compat/linux/usr/bin /compat/linux/usr/sbin /compat/linux/bin /compat/linux/lib

chflags noschg /usr/bin/cpp 2>/dev/null || true
if [ -f /usr/bin/cpp ] && [ ! -L /usr/bin/cpp ]; then
    mv -f /usr/bin/cpp /usr/bin/cpp.clang.bak 2>/dev/null || true
fi
ln -sf /usr/local/bin/tradcpp /usr/bin/cpp
ln -sf /usr/local/bin/tradcpp /lib/cpp
rm -f /compat/linux/lib/cpp /compat/linux/usr/bin/cpp /compat/linux/bin/cpp
ln -sf /usr/local/bin/tradcpp /compat/linux/lib/cpp
ln -sf /usr/local/bin/tradcpp /compat/linux/usr/bin/cpp
ln -sf /usr/local/bin/tradcpp /compat/linux/bin/cpp

for xtool in xrdb xset xsetroot xprop xwininfo xkill setxkbmap xclock feh; do
    rm -f "/compat/linux/usr/bin/$xtool" "/compat/linux/bin/$xtool"
    if [ -x "/usr/local/bin/$xtool" ]; then
        ln -sf "/usr/local/bin/$xtool" "/compat/linux/usr/bin/$xtool"
    fi
done

ln -sf /compat/linux/bin/bash      /bin/bash
ln -sf /usr/bin/killall            /compat/linux/usr/bin/killall
ln -sf /usr/bin/which              /compat/linux/usr/bin/which
ln -sf /usr/local/bin/nvidia-smi   /usr/bin/nvidia-smi
ln -sf /usr/local/bin/nvidia-smi   /compat/linux/usr/bin/nvidia-smi
ln -sf /usr/local/sbin/dmidecode   /compat/linux/usr/sbin/dmidecode
ln -sf /usr/local/sbin/dmidecode   /compat/linux/usr/bin/dmidecode
ln -sf /usr/local/bin/lspci        /compat/linux/usr/bin/lspci
ln -sf /usr/local/sbin/lsusb       /compat/linux/usr/bin/lsusb
ln -sf /compat/linux/opt/MaXX/bin64/xosview2 /xosview2
ln -sf /compat/linux/opt/MaXX/bin64/xconfirm /xconfirm

mkdir -p /compat/linux/usr/share/fonts
ln -sf /usr/local/share/fonts/dejavu /compat/linux/usr/share/fonts/dejavu
ln -sf /usr/local/share/fonts/noto   /compat/linux/usr/share/fonts/noto
if [ -d /compat/linux/opt/MaXX/share/fonts ]; then
    for fdir in /compat/linux/opt/MaXX/share/fonts/*; do
        if [ -d "$fdir" ]; then
            /usr/local/bin/mkfontscale "$fdir" 2>/dev/null || true
            /usr/local/bin/mkfontdir "$fdir" 2>/dev/null || true
        fi
    done
fi

# ------------------------------------------------------------------------------
# 8. THEME CURSEUR SGI ROUGE (redSGI), THEMES GTK ET COMPILATION INDIGOMAGIC
# ------------------------------------------------------------------------------
echo "-> [8/11] Installation du curseur SGI (redSGI), themes GTK et palette IndigoMagic..."
mkdir -p /usr/local/share/icons /usr/local/share/icons/default /usr/local/share/themes
mkdir -p /compat/linux/usr/share/icons /compat/linux/usr/share/themes

if [ -d /compat/linux/opt/MaXX/share/icons ]; then
    cp -af /compat/linux/opt/MaXX/share/icons/* /usr/local/share/icons/ 2>/dev/null || true
    cp -af /compat/linux/opt/MaXX/share/icons/* /compat/linux/usr/share/icons/ 2>/dev/null || true
fi
if [ -d /compat/linux/opt/MaXX/share/themes ]; then
    cp -af /compat/linux/opt/MaXX/share/themes/* /usr/local/share/themes/ 2>/dev/null || true
    cp -af /compat/linux/opt/MaXX/share/themes/* /compat/linux/usr/share/themes/ 2>/dev/null || true
fi

printf "[Icon Theme]\nName=Default\nComment=Default SGI Cursor Theme\nInherits=redSGI\n" > /usr/local/share/icons/default/index.theme

sed -i '' 's/\*darkScheme:.*/\*darkScheme: FALSE/g' /compat/linux/opt/MaXX/etc/Xdefaults.d/* "${USER_HOME}/.maxxdesktop/Xdefaults.d/"* 2>/dev/null || true

mkdir -p /compat/linux/opt/MaXX/share/X11/app-defaults
cat > /tmp/build_sgi_theme.xrm << 'EOF'
#define GAMMA_1_7
#define USE_COLORS
#define USE_SPACING
#define USE_FONTS
#include "/opt/MaXX/share/X11/schemes/Base/FontPalette"
#include "/opt/MaXX/share/X11/schemes/IndigoMagic/BaseColorPalette"
#include "/opt/MaXX/share/X11/schemes/Base/Base"
#include "/opt/MaXX/etc/Xdefaults.d/Xdefaults.init"
#include "/opt/MaXX/etc/Xdefaults.d/Xdefaults.classic"
#include "/opt/MaXX/etc/Xdefaults.d/Xdefaults.bitmapFont"
#include "/opt/MaXX/etc/Xdefaults.d/Xdefaults.5dwm"
#include "/opt/MaXX/etc/Xdefaults.d/Xdefaults.toolchest"
EOF
/usr/local/bin/tradcpp -P /tmp/build_sgi_theme.xrm > /compat/linux/opt/MaXX/share/X11/app-defaults/SgiIndigoMagic.ad 2>/dev/null || true
rm -f /tmp/build_sgi_theme.xrm

cat >> /compat/linux/opt/MaXX/share/X11/app-defaults/SgiIndigoMagic.ad << 'EOF'
*scheme: IndigoMagic
*darkScheme: FALSE
*chest_orientation: XmVERTICAL
*modernLookandFeel: false
*desktopStyle: Classic
*smoothText: false
5Dwm*keyboardFocusPolicy: pointer
*background: #c1c1c1
*foreground: #000000
*basicBackground: #c1c1c1
*textForeground: #000000
*textBackground: #8e8e8e
*buttonBackground: #999999
*scrollBarTroughColor: #999999
*scrollBarControlBackground: #999999
*topShadowColor: #e1e1e1
*bottomShadowColor: #4c4c4c
*selectColor: #8e8e8e
*highlightColor: #c1c1c1
*armColor: #8e8e8e
*troughColor: #8e8e8e
Toolchest*background: #c1c1c1
Toolchest*foreground: #000000
Toolchest*XmPushButton*background: #c1c1c1
Toolchest*XmPushButton*foreground: #000000
Toolchest*XmCascadeButton*background: #c1c1c1
Toolchest*XmCascadeButton*foreground: #000000
Toolchest*XmLabel*background: #c1c1c1
Toolchest*XmLabel*foreground: #000000
Toolchest*XmRowColumn*background: #c1c1c1
Toolchest*XmRowColumn*foreground: #000000
Toolchest*XmSeparator*background: #c1c1c1
5Dwm*background: #c1c1c1
5Dwm*foreground: #000000
5Dwm*topShadowColor: #e1e1e1
5Dwm*bottomShadowColor: #4c4c4c
5Dwm*selectColor: #8e8e8e
5Dwm*menu*background: #c1c1c1
5Dwm*menu*foreground: #000000
5Dwm*menu*topShadowColor: #e1e1e1
5Dwm*menu*bottomShadowColor: #4c4c4c
5Dwm*menu*XmPushButton*background: #c1c1c1
5Dwm*menu*XmPushButton*foreground: #000000
5Dwm*menu*XmCascadeButton*background: #c1c1c1
5Dwm*menu*XmCascadeButton*foreground: #000000
5Dwm*menu*XmLabel*background: #c1c1c1
5Dwm*menu*XmLabel*foreground: #000000
5Dwm*menu*XmSeparator*background: #c1c1c1
5Dwm*feedback*background: #c1c1c1
5Dwm*feedback*foreground: #000000
5Dwm*icon*background: #c1c1c1
5Dwm*icon*foreground: #000000
5DWm*background: #c1c1c1
5DWm*foreground: #000000
5DWm*menu*background: #c1c1c1
5DWm*menu*foreground: #000000
Mwm*background: #c1c1c1
Mwm*foreground: #000000
Mwm*menu*background: #c1c1c1
Mwm*menu*foreground: #000000
xconfirm*background: #c1c1c1
xconfirm*foreground: #000000
xconfirm*topShadowColor: #e1e1e1
xconfirm*bottomShadowColor: #4c4c4c
xconfirm*XmForm*background: #c1c1c1
xconfirm*XmForm*foreground: #000000
xconfirm*XmLabel*background: #c1c1c1
xconfirm*XmLabel*foreground: #000000
xconfirm*XmPushButton*background: #999999
xconfirm*XmPushButton*foreground: #000000
xconfirm*XmText*background: #c1c1c1
xconfirm*XmText*foreground: #000000
xconfirm*XmTextField*background: #c1c1c1
xconfirm*XmTextField*foreground: #000000
Xconfirm*background: #c1c1c1
Xconfirm*foreground: #000000
*XmDialogShell*background: #c1c1c1
*XmDialogShell*foreground: #000000
*XmMessageBox*background: #c1c1c1
*XmMessageBox*foreground: #000000
Toolchest*fontList: -*-helvetica-bold-o-normal-*-14-*-*-*-*-*-iso8859-1
*fontList: -*-helvetica-medium-r-normal-*-12-*-*-*-*-*-iso8859-1
EOF

# ------------------------------------------------------------------------------
# 9. OUTILS SYSTEME SGI D'ORIGINE (XCONFIRM, HINV, GR_OSVIEW2, WINTERM, ADMINTERM)
# ------------------------------------------------------------------------------
echo "-> [9/11] Configuration des outils SGI (tellsystem, tellversion, tellgpu, gr_osview2, winterm, adminterm)..."

create_wrapper() {
    cat > "/compat/linux/opt/MaXX/bin64/$1" << EOF
#!/bin/sh
unset LD_LIBRARY_PATH
export PATH="/usr/local/bin:/usr/bin:/bin:\$PATH"
exec $2 "\$@" &
EOF
    chmod +x "/compat/linux/opt/MaXX/bin64/$1"
}

create_wrapper "WEBBROWSER"  "/usr/local/bin/firefox"
create_wrapper "EMAILCLIENT" "/usr/local/bin/thunderbird"
create_wrapper "MAIL"        "/usr/local/bin/thunderbird"
create_wrapper "MEDIAVIEWER" "/usr/local/bin/vlc"
create_wrapper "AUDIOPLAYER" "/usr/local/bin/vlc"
create_wrapper "FILEBROWSER" "/usr/local/bin/thunar"
create_wrapper "TEXTEDITOR"  "/usr/local/bin/mousepad"
create_wrapper "IMAGEEDITOR" "/usr/local/bin/ristretto"
create_wrapper "PDFVIEWER"   "/usr/local/bin/firefox"
create_wrapper "pavucontrol" "/usr/local/bin/dsbmixer"
create_wrapper "Restart"     "sudo /sbin/reboot"
create_wrapper "Shutdown"    "sudo /sbin/poweroff"

printf "#!/bin/sh\nexit 0\n" > /compat/linux/opt/MaXX/bin64/sound
chmod +x /compat/linux/opt/MaXX/bin64/sound

# Terminaux SGI IRIX : winterm / Console (Open Unix Shell) et adminterm (Open Admin Shell)
cat > /compat/linux/opt/MaXX/bin64/winterm << 'EOF'
#!/bin/sh
unset LD_LIBRARY_PATH
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/MaXX/bin64"
export LANG="fr_FR.UTF-8"
exec /usr/local/bin/xterm \
    -name winterm -class winterm-color \
    -title "UNIX Shell ($(whoami)@$(hostname -s))" \
    -geometry 100x32 \
    -bg "#1e2638" -fg "#ffffff" -cr "#ff0000" \
    -sb -rightbar -sl 5000 \
    -fn "-*-lucidatypewriter-medium-r-normal-*-14-*-*-*-*-*-iso8859-1" &
EOF
chmod +x /compat/linux/opt/MaXX/bin64/winterm
cp -af /compat/linux/opt/MaXX/bin64/winterm /compat/linux/opt/MaXX/bin64/Console
cp -af /compat/linux/opt/MaXX/bin64/winterm /compat/linux/opt/MaXX/bin64/TERMINAL

cat > /compat/linux/opt/MaXX/bin64/adminterm << 'EOF'
#!/bin/sh
unset LD_LIBRARY_PATH
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/MaXX/bin64"
export LANG="fr_FR.UTF-8"
exec /usr/local/bin/xterm \
    -name adminterm -class adminterm-color \
    -title "ADMIN ROOT SHELL (root@$(hostname -s))" \
    -geometry 100x32 \
    -bg "#4a151b" -fg "#ffffff" -cr "#ffff00" \
    -sb -rightbar -sl 5000 \
    -fn "-*-lucidatypewriter-medium-r-normal-*-14-*-*-*-*-*-iso8859-1" \
    -e /usr/local/bin/sudo -i &
EOF
chmod +x /compat/linux/opt/MaXX/bin64/adminterm
cp -af /compat/linux/opt/MaXX/bin64/adminterm /compat/linux/opt/MaXX/bin64/RootConsole

for term_cmd in winterm Console TERMINAL adminterm RootConsole; do
    ln -sf "/compat/linux/opt/MaXX/bin64/$term_cmd" "/usr/local/bin/$term_cmd"
    ln -sf "/compat/linux/opt/MaXX/bin64/$term_cmd" "/$term_cmd"
done

cat > /compat/linux/opt/MaXX/bin64/tellsystem << 'EOF'
#!/compat/linux/bin/bash
export MAXX_BIN="/opt/MaXX/bin64"
export PATH="/opt/MaXX/bin64:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:$PATH"
HINV_OUT=$("$MAXX_BIN/hinv" 2>/dev/null)
"$MAXX_BIN/xconfirm" -c -icon info -t "$HINV_OUT" -header HINV >/dev/null 2>&1 &
EOF
chmod +x /compat/linux/opt/MaXX/bin64/tellsystem

cat > /compat/linux/opt/MaXX/bin64/tellversion << 'EOF'
#!/compat/linux/bin/bash
env -u LD_LIBRARY_PATH /usr/local/bin/xset b off 2>/dev/null || true
version=$(cat /opt/MaXX/etc/version 2>/dev/null || echo "Octane 2.2.0")
arch=$(/bin/uname -m)
fbsd_ver=$(/bin/freebsd-version -u 2>/dev/null || /usr/bin/uname -sr)
linux_ver=$(cat /compat/linux/etc/redhat-release 2>/dev/null || echo "Rocky Linux 9")

/opt/MaXX/bin64/xconfirm -icon info -c -C -t "Congratulations!

You are running MaXX Interactive Desktop
($arch / x86_64) Edition

Version: $version
Host OS: FreeBSD $fbsd_ver
Linuxulator: $linux_ver" -header "Tell version" >/dev/null 2>&1 &
EOF
chmod +x /compat/linux/opt/MaXX/bin64/tellversion

cat > /compat/linux/opt/MaXX/bin64/tellgpu << 'EOF'
#!/compat/linux/bin/bash
if [ -x /usr/local/bin/nvidia-smi ]; then
    GPU_OUT=$(env -u LD_LIBRARY_PATH /usr/local/bin/nvidia-smi --query --display=MEMORY,UTILIZATION,TEMPERATURE 2>/dev/null)
    /opt/MaXX/bin64/xconfirm -c -icon info -t "$GPU_OUT" -header "tell gpu" >/dev/null 2>&1 &
else
    /opt/MaXX/bin64/xconfirm -c -icon info -t "Unknown GPU - Not NVIDIA, sorry!" -header "tell gpu" >/dev/null 2>&1 &
fi
EOF
chmod +x /compat/linux/opt/MaXX/bin64/tellgpu

for cfg in \
    /compat/linux/opt/MaXX/etc/Xdefaults.d/Xdefaults.Gr_osview.dark \
    /compat/linux/opt/MaXX/etc/Xdefaults.d/Xdefaults.Gr_osview.light \
    "${USER_HOME}/.maxxdesktop/Xdefaults.d/Xdefaults.Gr_osview.dark" \
    "${USER_HOME}/.maxxdesktop/Xdefaults.d/Xdefaults.Gr_osview.light"; do
    if [ -f "$cfg" ]; then
        sed -i '' 's/xosview\*disk:[[:space:]]*True/xosview*disk: False/g' "$cfg"
        sed -i '' 's/xosview\*page:[[:space:]]*True/xosview*page: False/g' "$cfg"
        sed -i '' 's/xosview\*int:[[:space:]]*True/xosview*int: False/g' "$cfg"
        sed -i '' 's/xosview\*ints:[[:space:]]*True/xosview*ints: False/g' "$cfg"
        sed -i '' 's/xosview\*codecs:[[:space:]]*True/xosview*codecs: False/g' "$cfg"
        grep -q "xosview\*disk:" "$cfg" || echo "xosview*disk: False" >> "$cfg"
        grep -q "xosview\*page:" "$cfg" || echo "xosview*page: False" >> "$cfg"
        grep -q "xosview\*int:"  "$cfg" || echo "xosview*int: False" >> "$cfg"
        grep -q "xosview\*ints:" "$cfg" || echo "xosview*ints: False" >> "$cfg"
    fi
done

cat > /compat/linux/opt/MaXX/bin64/gr_osview2 << 'EOF'
#!/compat/linux/bin/bash
export MAXX_HOME="/opt/MaXX"
export MAXX_BIN="/opt/MaXX/bin64"
export PATH="/opt/MaXX/bin64:/usr/local/bin:/usr/bin:/bin:$PATH"

font_size=$(cat "$HOME/.maxxdesktop/SmallFontSize" 2>/dev/null || echo "10")
font_name=$(cat "$HOME/.maxxdesktop/SmallFontName" 2>/dev/null || echo "Sans")
font_face="${font_name}:weight=200:slant=italic:size=${font_size}"

isDark=$(env -u LD_LIBRARY_PATH /usr/local/bin/xrdb -q 2>/dev/null | grep darkScheme | cut -d ':' -f2 | awk '{print $1}')
if [ "$isDark" = "FALSE" ]; then
    CFG="$HOME/.maxxdesktop/Xdefaults.d/Xdefaults.Gr_osview.light"
else
    CFG="$HOME/.maxxdesktop/Xdefaults.d/Xdefaults.Gr_osview.dark"
fi
[ ! -f "$CFG" ] && CFG="/opt/MaXX/etc/Xdefaults.d/Xdefaults.Gr_osview.dark"

env -u LD_LIBRARY_PATH /usr/local/bin/xrdb -nocpp -merge "$CFG" 2>/dev/null || true
exec "$MAXX_BIN/xosview2" --config "$CFG" -font "$font_face" "$@" >/dev/null 2>&1 &
EOF
chmod +x /compat/linux/opt/MaXX/bin64/gr_osview2
cp -af /compat/linux/opt/MaXX/bin64/gr_osview2 /compat/linux/opt/MaXX/bin64/gr_osview

# ------------------------------------------------------------------------------
# 10. INITIALISATION DU PROFIL UTILISATEUR ET DU SCRIPT OFFICIEL XSESSION.DT
# ------------------------------------------------------------------------------
echo "-> [10/11] Configuration de system.runtime, Xsession.dt et du profil de ${TARGET_USER}..."

grep -q "export MAXX_BIN" /compat/linux/opt/MaXX/etc/system.runtime || cat >> /compat/linux/opt/MaXX/etc/system.runtime << 'EOF'
export MAXX_HOME="/opt/MaXX"
export MaXX_HOME="/opt/MaXX"
export MAXX_BIN="/opt/MaXX/bin64"
export MAXX_LIBS="/opt/MaXX/lib64"
export MAXX_SHARE="/opt/MaXX/share"
export MAXX_ETC="/opt/MaXX/etc"
export MAXX_SETTINGS="/opt/MaXX/share/msettings"
EOF

cat > /compat/linux/opt/MaXX/etc/skel/Xsession.dt << 'EOF'
#!/bin/bash
ver="2.2"
export USER=${USER:-$(whoami)}
export USERNAME="$USER"
rm -f /tmp/MaXXisRunning-$USERNAME > /dev/null 2>&1
d=`date +%F_%T`
[ -f "$HOME/.console" ] && mv "$HOME/.console" "$HOME/.console-$d"
echo "[`date`] Starting MaXX Interactive Desktop" > "$HOME/.console"

env -u LD_LIBRARY_PATH /usr/local/bin/xset m 0 0
env -u LD_LIBRARY_PATH /usr/local/bin/xset -b
env -u LD_LIBRARY_PATH /usr/local/bin/xset +fp /opt/MaXX/share/fonts/sgi,/usr/local/share/fonts/misc,/usr/local/share/fonts/100dpi,/usr/local/share/fonts/75dpi 2>/dev/null || true
env -u LD_LIBRARY_PATH /usr/local/bin/xset fp rehash 2>/dev/null || true
env -u LD_LIBRARY_PATH /usr/local/bin/xsetroot -solid SkyBlue4

. /opt/MaXX/etc/system.runtime
. $MAXX_HOME/etc/system.desktopenv
export XDG_DATA_DIRS="/opt/MaXX/share:/usr/local/share:/usr/share"

if [ ! -d "$HOME/.maxxdesktop" ]; then
    cd "$HOME"
    $MAXX_HOME/share/misc/HOME/initMaXX-Desktop-Home.sh >> "$HOME/.console" 2>&1
    for cfg in "$HOME/.maxxdesktop/Xdefaults.d/Xdefaults.Gr_osview."*; do
        if [ -f "$cfg" ]; then
            sed -i '' 's/xosview\*disk:[[:space:]]*True/xosview*disk: False/g; s/xosview\*page:[[:space:]]*True/xosview*page: False/g; s/xosview\*codecs:[[:space:]]*True/xosview*codecs: False/g' "$cfg" 2>/dev/null || true
        fi
    done
fi

mkdir -p "$HOME/.icons"
ln -sf /opt/MaXX/share/ROX-Filer/ROX "$HOME/.icons/ROX"
echo "ch" > "$HOME/.maxxdesktop/KeyboardInput.Choice"
echo "fr_FR.UTF-8" > "$HOME/.maxxdesktop/Language.Choice"

$MAXX_BIN/telldesktop load
env -u LD_LIBRARY_PATH /usr/local/bin/xrdb -nocpp -load /opt/MaXX/share/X11/app-defaults/SgiIndigoMagic.ad 2>/dev/null || true
env -u LD_LIBRARY_PATH /usr/local/bin/setxkbmap ch fr 2>/dev/null || true

$MAXX_BIN/telldesktop start

if [ -f /boot/images/sgi_desktop.jpg ]; then
    env -u LD_LIBRARY_PATH /usr/local/bin/feh --bg-fill /boot/images/sgi_desktop.jpg &
    (sleep 2 && env -u LD_LIBRARY_PATH /usr/local/bin/feh --bg-fill /boot/images/sgi_desktop.jpg) &
fi

$MAXX_BIN/5Dwm -multiscreen >> "$HOME/.console" 2>&1
$MAXX_BIN/telldesktop stop
EOF
chmod +x /compat/linux/opt/MaXX/etc/skel/Xsession.dt

mkdir -p "${USER_HOME}/.icons" "${USER_HOME}/.config"
ln -sf /opt/MaXX/share/ROX-Filer/ROX "${USER_HOME}/.icons/ROX"

# ------------------------------------------------------------------------------
# 11. LANCEUR /USR/LOCAL/BIN/STARTMAXX ET DECLARATION SDDM
# ------------------------------------------------------------------------------
echo "-> [11/11] Creation de /usr/local/bin/startmaxx et session SDDM..."

cat > /usr/local/bin/startmaxx << 'EOF'
#!/bin/sh
export USER=${USER:-$(id -un)}
export USERNAME="$USER"
export HOME=${HOME:-/home/$USER}
export LANG="fr_FR.UTF-8"
export XCURSOR_THEME="redSGI"
export MAXX_HOME="/opt/MaXX"
export MAXX_BIN="/opt/MaXX/bin64"
export PATH="/opt/MaXX/bin64:/opt/MaXX/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:$PATH"
exec /compat/linux/bin/bash /opt/MaXX/etc/skel/Xsession.dt > "$HOME/.maxx-session.log" 2>&1
EOF
chmod +x /usr/local/bin/startmaxx

mkdir -p /usr/local/share/xsessions
cat > /usr/local/share/xsessions/maxx.desktop << 'EOF'
[Desktop Entry]
Name=MaXX Interactive Desktop (SGI IRIX)
Comment=Silicon Graphics IRIX Indigo Magic Desktop Environment (Octane 2.2)
Exec=/usr/local/bin/startmaxx
TryExec=/usr/local/bin/startmaxx
Type=Application
DesktopNames=MaXX
EOF

printf "#!/bin/sh\nexec /usr/local/bin/startmaxx\n" > "${USER_HOME}/.xinitrc"
chmod +x "${USER_HOME}/.xinitrc"
chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}"

echo "======================================================================"
echo "=== Phase 2 terminee avec succes ! MaXX Desktop Octane 2.2 est pret. ==="
echo "======================================================================"
exit 0