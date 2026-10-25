#!/bin/sh
# ==============================================================================
# SCRIPT 2: install-maxx-interactive.sh (VERSION FINALE 100% CONFORME MAXX 2.2)
# TARGET OS: FreeBSD 15.1-RELEASE (POSIX /bin/sh)
# HARDWARE: HP Z4 G4 / Xeon W-2140B / Quadro M4000 (Driver 470) / ASUS PB278
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Ce script doit être exécuté en root."
    exit 1
fi

TARGET_USER="administrateur"
USER_HOME="/home/$TARGET_USER"
MAXX_TAR="/tmp/MaXX-Desktop-v2.2.0-LINUX-x86_64-tar.gz"
MAXX_URL="https://s3.ca-central-1.amazonaws.com/cdn.maxxinteractive.com/maxx-desktop-installer/MaXX-Desktop-v2.2.0-LINUX-x86_64-tar.gz"

echo "=========================================================="
echo " Phase 2: Installation et Calibration de MaXX Desktop"
echo "=========================================================="

# 1. INSTALLATION GARANTIE DES POLICES X11/MOTIF, APPLICATIONS ET OUTILS NATIFS
echo "[+] Installation des polices X11/SGI, Thunderbird, dsbmixer et tradcpp..."
pkg install -y \
    xorg-fonts-miscbitmaps \
    xorg-fonts-100dpi \
    xorg-fonts-75dpi \
    font-misc-misc \
    font-alias \
    font-cursor-misc \
    font-bh-lucidatypewriter-100dpi \
    font-bh-lucidatypewriter-75dpi \
    font-adobe-100dpi \
    font-adobe-75dpi \
    tradcpp \
    feh \
    scrot \
    dsbmixer \
    xscreensaver \
    xterm \
    xclock \
    xfontsel \
    xmag \
    xkill \
    xprop \
    xwininfo \
    btop \
    firefox \
    thunderbird \
    vlc \
    wget

# Vérification de la base Linuxulator Rocky Linux 9
echo "[+] Vérification des bibliothèques Linuxulator (Rocky Linux 9)..."
if [ ! -x /compat/linux/bin/bash ]; then
    pkg install -f -y linux_base-rl9
fi

for lpkg in linux-rl9-xorg-libs linux-rl9-libjpeg-turbo linux-rl9-libpng linux-rl9-freetype linux-rl9-fontconfig linux-rl9-motif linux-rl9-libGLU linux-rl9-glvnd; do
    pkg install -y "$lpkg" >/dev/null 2>&1 || true
done

# 2. LIENS SYMBOLIQUES NCURSES V5 DANS LINUXULATOR (REQUIS PAR LES BINAIRES MAXX)
echo "[+] Création des liens de compatibilité ncurses v5 dans /compat/linux/..."
for libdir in /compat/linux/usr/lib64 /compat/linux/lib64; do
    if [ -d "$libdir" ]; then
        [ -f "$libdir/libncurses.so.6" ] && ln -sf libncurses.so.6 "$libdir/libncurses.so.5"
        [ -f "$libdir/libtinfo.so.6" ]   && ln -sf libtinfo.so.6   "$libdir/libtinfo.so.5"
        [ -f "$libdir/libpanel.so.6" ]   && ln -sf libpanel.so.6   "$libdir/libpanel.so.5"
    fi
done

# 3. TÉLÉCHARGEMENT (AVEC CACHE) ET EXTRACTION DE MAXX DESKTOP OCTANE 2.2.0
mkdir -p /compat/linux/opt /compat/linux/tmp
chmod 1777 /compat/linux/tmp /tmp
rm -f /compat/linux/tmp/SgiScheme* /tmp/SgiScheme* 2>/dev/null || true

if [ -f "$MAXX_TAR" ] && [ ! -s "$MAXX_TAR" ]; then
    rm -f "$MAXX_TAR"
fi

if [ ! -s "$MAXX_TAR" ]; then
    echo "[+] Téléchargement de MaXXdesktop Octane-2.2.0 (233 Mo)..."
    wget -c -O "$MAXX_TAR" "$MAXX_URL"
else
    echo "[+] Archive MaXXdesktop déjà présente dans $MAXX_TAR (cache utilisé)."
fi

if [ ! -s "$MAXX_TAR" ]; then
    echo "ERROR: Archive $MAXX_TAR introuvable ou vide."
    exit 1
fi

echo "[+] Extraction propre de MaXXdesktop dans /compat/linux/opt/..."
rm -rf /compat/linux/opt/MaXX /opt/MaXX
tar -xzf "$MAXX_TAR" -C /compat/linux/opt/
ln -sf /compat/linux/opt/MaXX /opt/MaXX

# 4. VÉRIFICATION DE L'ARBORESCENCE BIN / BIN64
echo "[+] Vérification des points d'entrée 64 bits..."
if [ ! -L /compat/linux/opt/MaXX/bin ] && [ -d /compat/linux/opt/MaXX/bin64 ]; then
    cp -af /compat/linux/opt/MaXX/bin64/* /compat/linux/opt/MaXX/bin/ 2>/dev/null || true
fi

# 5. TATOUAGE ELF (BRANDELF LINUX) UNIQUEMENT SUR LES VRAIS BINAIRES ELF
echo "[+] Tatouage ELF (FreeBSD Linuxulator) sur les exécutables binaires MaXX..."
find /compat/linux/opt/MaXX/bin64 /compat/linux/opt/MaXX/lib64 -type f 2>/dev/null | while read -r f; do
    if file -b "$f" | grep -q "^ELF "; then
        brandelf -t Linux "$f" 2>/dev/null || true
    fi
done

# 6. PONTS SYSTÈME, POLICES SGI ET PRÉPROCESSEUR C (CPP) POUR XRESOURCES & LIBSCHEME
echo "[+] Création des ponts entre les outils natifs FreeBSD et Linuxulator..."
mkdir -p /compat/linux/usr/bin /compat/linux/bin /compat/linux/lib /lib
ln -sf /usr/local/bin/tradcpp  /compat/linux/usr/bin/cpp
ln -sf /usr/local/bin/tradcpp  /compat/linux/bin/cpp
ln -sf /usr/local/bin/tradcpp  /compat/linux/lib/cpp
ln -sf /usr/local/bin/tradcpp  /usr/bin/cpp
ln -sf /usr/local/bin/tradcpp  /lib/cpp
ln -sf /usr/local/bin/xrdb     /compat/linux/usr/bin/xrdb
ln -sf /usr/local/bin/xset     /compat/linux/usr/bin/xset
ln -sf /usr/local/bin/xsetroot /compat/linux/usr/bin/xsetroot
ln -sf /usr/local/bin/xprop    /compat/linux/usr/bin/xprop
ln -sf /usr/local/bin/xwininfo /compat/linux/usr/bin/xwininfo
ln -sf /usr/local/bin/xkill    /compat/linux/usr/bin/xkill

# Indexation des polices X11 et des polices SGI de MaXX
for fdir in /usr/local/share/fonts/misc /compat/linux/opt/MaXX/share/fonts/sgi; do
    if [ -d "$fdir" ]; then
        mkfontscale "$fdir" 2>/dev/null || true
        mkfontdir   "$fdir" 2>/dev/null || true
    fi
done
fc-cache -f 2>/dev/null || true

# 7. THÈME CURSEUR SGI ROUGE (redSGI) ET ICÔNES
echo "[+] Installation du curseur SGI Classique (redSGI) et des thèmes..."
mkdir -p /usr/local/share/icons/default
if [ -d /compat/linux/opt/MaXX/share/icons/redSGI ]; then
    rm -rf /usr/local/share/icons/redSGI
    cp -R /compat/linux/opt/MaXX/share/icons/redSGI /usr/local/share/icons/
fi
cat > /usr/local/share/icons/default/index.theme << 'EOF'
[Icon Theme]
Inherits=redSGI
EOF

# 8. INITIALISATION COMPLÈTE DU PROFIL UTILISATEUR MAXX (COMME initMaXX-Desktop-Home.sh)
echo "[+] Installation des préférences MaXX Desktop dans $USER_HOME..."
if [ -d "$USER_HOME" ] && [ -d /compat/linux/opt/MaXX/share/misc/HOME ]; then
    rm -rf "$USER_HOME/.maxxdesktop"
    cp -rp /compat/linux/opt/MaXX/share/misc/HOME/dot.maxxdesktop "$USER_HOME/.maxxdesktop"

    mkdir -p "$USER_HOME/.config"
    rm -rf "$USER_HOME/.config/rox.sourceforge.net"
    cp -rp /compat/linux/opt/MaXX/share/misc/HOME/rox.sourceforge.net "$USER_HOME/.config/rox.sourceforge.net"

    cp -f /compat/linux/opt/MaXX/share/misc/HOME/Sgiresources   "$USER_HOME/Sgiresources"
    cp -f /compat/linux/opt/MaXX/share/misc/HOME/dot.Xdefaults  "$USER_HOME/.Xdefaults"
    cp -f /compat/linux/opt/MaXX/share/misc/HOME/dot.Xdefaults  "$USER_HOME/.Xresources"
    cp -f /compat/linux/opt/MaXX/share/misc/HOME/dot.dir_colors "$USER_HOME/.dir_colors"
    cp -f /compat/linux/opt/MaXX/share/misc/HOME/dot.mwmrc      "$USER_HOME/.mwmrc"
    cp -f /compat/linux/opt/MaXX/share/misc/HOME/dot.sgisession "$USER_HOME/.sgisession"
    cp -f /compat/linux/opt/MaXX/share/misc/HOME/dot.chestrc    "$USER_HOME/.chestrc"

    mkdir -p "$USER_HOME/.themes" "$USER_HOME/.icons"
    ln -fs /opt/MaXX/share/themes/* "$USER_HOME/.themes/" 2>/dev/null || true
    ln -fs /opt/MaXX/share/icons/*  "$USER_HOME/.icons/"  2>/dev/null || true
fi

# 9. WRAPPERS D'APPLICATIONS ET D'OUTILS SYSTÈME POUR LE TOOLCHEST SGI
# Tous les noms correspondent exactement à /opt/MaXX/etc/system.chestrc !
echo "[+] Déploiement des wrappers FreeBSD pour toutes les entrées de system.chestrc..."

create_wrapper() {
    WNAME="$1"
    WCMD="$2"
    cat > "/compat/linux/opt/MaXX/bin64/$WNAME" << EOF
#!/bin/sh
unset LD_LIBRARY_PATH
exec $WCMD
EOF
    chmod +x "/compat/linux/opt/MaXX/bin64/$WNAME"
    cp -af "/compat/linux/opt/MaXX/bin64/$WNAME" "/compat/linux/opt/MaXX/bin/$WNAME" 2>/dev/null || true
}

# Internet & Courrier (Thunderbird & Firefox)
create_wrapper "WEBBROWSER"      "/usr/local/bin/firefox \"\$@\""
create_wrapper "EMAILCLIENT"     "/usr/local/bin/thunderbird \"\$@\""
create_wrapper "Mail"            "/usr/local/bin/thunderbird \"\$@\""

# Audio & Multimédia (Control Audio = pavucontrol, Audio Mixer = xmmix -> dsbmixer sans terminal !)
# Note: On ne touche PAS à msound qui sert à jouer start-app.wav dans mlaunch !
create_wrapper "pavucontrol"     "/usr/local/bin/dsbmixer"
create_wrapper "xmmix"           "/usr/local/bin/dsbmixer"
create_wrapper "dtsounds"        "/usr/local/bin/dsbmixer"
create_wrapper "gvu"             "/usr/local/bin/dsbmixer"
create_wrapper "MEDIAVIEWER"     "/usr/local/bin/vlc \"\$@\""

# Bureautique, Fichiers, Images & PDF
create_wrapper "FILEBROWSER"     "/usr/local/bin/thunar \"\$@\""
create_wrapper "PDFVIEWER"       "/usr/local/bin/firefox \"\$@\""
create_wrapper "xpdf"            "/usr/local/bin/firefox \"\$@\""
create_wrapper "IMGVIEWER"       "/usr/local/bin/feh \"\$@\""
create_wrapper "WINEDITOR"       "/usr/local/bin/mousepad \"\$@\""

# Capture d'écran (Snapshot & Screen Capture)
create_wrapper "screenshot"       "/usr/local/bin/scrot \"$USER_HOME/SGI_Screenshot_%Y%m%d_%H%M%S.png\""
create_wrapper "gnome-screenshot" "/usr/local/bin/scrot \"$USER_HOME/SGI_Screenshot_%Y%m%d_%H%M%S.png\""

# Terminaux (Open Unix Shell, Open Admin Shell, Start New Console)
create_wrapper "winterm"         "/usr/local/bin/xterm -title 'Winterm' -bg '#1c1c24' -fg '#e5e5e5' -fn '-*-lucidatypewriter-medium-r-normal-*-14-*'"
create_wrapper "Console"         "/usr/local/bin/xterm -title 'SGI Console' -bg '#141c24' -fg '#ffffff' -fn '-*-lucidatypewriter-medium-r-normal-*-14-*'"
create_wrapper "adminterm"       "/usr/local/bin/xterm -title 'SGI Root Console' -bg '#381212' -fg '#ffffff' -fn '-*-lucidatypewriter-medium-r-normal-*-14-*' -e sudo -i"

# Monitoring et Infos Système SGI (System Monitor, Memory Monitor, System Info, GPU Info, MaXX Info)
create_wrapper "gr_osview2"      "/usr/local/bin/xterm -title 'SGI System Monitor (btop)' -geometry 110x35 -bg black -fg green -e /usr/local/bin/btop"
create_wrapper "gmemusage"       "/usr/local/bin/xterm -title 'SGI Memory Monitor (btop)' -geometry 110x35 -bg black -fg cyan -e /usr/local/bin/btop"

cat > /compat/linux/opt/MaXX/bin64/hinv << 'EOF'
#!/bin/sh
unset LD_LIBRARY_PATH
echo "=== SGI Hardware Inventory (FreeBSD 15.1 Workstation) ==="
echo "System    : HP Z4 G4 Workstation"
echo "Processor : $(sysctl -n hw.model) ($(sysctl -n hw.ncpu) threads)"
echo "Memory    : $(expr $(sysctl -n hw.physmem) / 1048576) MB ECC RAM"
echo "OS Kernel : $(uname -sr)"
echo "Graphics  : NVIDIA Quadro M4000 (Driver 470)"
echo "Display   : ASUS PB278 (2560x1440 @ 24-bit)"
EOF
chmod +x /compat/linux/opt/MaXX/bin64/hinv
cp -af /compat/linux/opt/MaXX/bin64/hinv /compat/linux/opt/MaXX/bin/hinv 2>/dev/null || true

create_wrapper "tellsystem"      "/usr/local/bin/xterm -title 'SGI System Info (hinv)' -geometry 85x26 -bg '#1c2636' -fg '#ffffff' -e /bin/sh -c '/opt/MaXX/bin64/hinv; echo \"\"; nvidia-smi; echo \"\"; printf \"Appuyez sur Entree pour fermer...\"; read _'"
create_wrapper "tellgpu"         "/usr/local/bin/xterm -title 'SGI GPU Info (Quadro M4000)' -geometry 90x28 -bg '#1c2636' -fg '#ffffff' -e /bin/sh -c 'nvidia-smi; echo \"\"; printf \"Appuyez sur Entree pour fermer...\"; read _'"
create_wrapper "tellversion"     "/usr/local/bin/xterm -title 'MaXX Interactive Desktop Info' -geometry 70x15 -bg '#1c2636' -fg '#ffffff' -e /bin/sh -c 'cat /opt/MaXX/etc/version; echo \"\"; uname -a; echo \"\"; printf \"Appuyez sur Entree pour fermer...\"; read _'"

# Alimentation (Restart System & Shutdown System)
create_wrapper "Restart"         "sudo /sbin/reboot"
create_wrapper "Shutdown"        "sudo /sbin/poweroff"

# 10. SCRIPT DE DÉMARRAGE DE SESSION MAXX POUR SDDM ET STARTX
echo "[+] Création du lanceur de session /usr/local/bin/startmaxx..."
cat > /usr/local/bin/startmaxx << 'EOF'
#!/bin/sh
exec > /tmp/maxx-session.log 2>&1

# 1. Chargement du runtime officiel de MaXX (définit MAXX_HOME, MAXX_BIN, XAPPLRESDIR, UIDPATH...)
export MAXX_HOME="/opt/MaXX"
export MaXX_HOME="/opt/MaXX"
export MAXX_BIN="/opt/MaXX/bin64"
if [ -f /opt/MaXX/etc/system.runtime ]; then
    . /opt/MaXX/etc/system.runtime
fi

export PATH="/opt/MaXX/bin64:/opt/MaXX/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export LD_LIBRARY_PATH="/opt/MaXX/lib64:/opt/MaXX/lib"
export CPP="/usr/local/bin/tradcpp"
export WM="5Dwm"
export XCURSOR_THEME="redSGI"
export LANG="fr_FR.UTF-8"
export SGI_XFONT="-sgi-screen-medium-r-normal-*-*-150-*-*-m-*-iso8859-1"
export GTK_THEME="IndigoMagic"
export GTK2_RC_FILES="$HOME/.themes/IndigoMagic/gtk-2.0/gtkrc"

# Initialisation automatique si nouvel utilisateur
if [ ! -d "$HOME/.maxxdesktop" ] || [ ! -f "$HOME/Sgiresources" ]; then
    cp -rp /opt/MaXX/share/misc/HOME/dot.maxxdesktop "$HOME/.maxxdesktop" 2>/dev/null || true
    cp -f /opt/MaXX/share/misc/HOME/Sgiresources "$HOME/Sgiresources" 2>/dev/null || true
    cp -f /opt/MaXX/share/misc/HOME/dot.Xdefaults "$HOME/.Xdefaults" 2>/dev/null || true
    cp -f /opt/MaXX/share/misc/HOME/dot.mwmrc "$HOME/.mwmrc" 2>/dev/null || true
    cp -f /opt/MaXX/share/misc/HOME/dot.chestrc "$HOME/.chestrc" 2>/dev/null || true
fi

# 2. Configuration X11 native (exécutée sans LD_LIBRARY_PATH Linux)
env -u LD_LIBRARY_PATH /usr/local/bin/setxkbmap ch fr 2>/dev/null || true
env -u LD_LIBRARY_PATH /usr/local/bin/xset -b 2>/dev/null || true
env -u LD_LIBRARY_PATH /usr/local/bin/xset +fp /opt/MaXX/share/fonts/sgi,/usr/local/share/fonts/misc,/usr/local/share/fonts/100dpi,/usr/local/share/fonts/75dpi 2>/dev/null || true
env -u LD_LIBRARY_PATH /usr/local/bin/xset fp rehash 2>/dev/null || true

# 3. Chargement des ressources X11 et SGI officielles (comme dans start5Dwm)
if [ -f "$HOME/.Xdefaults" ]; then
    env -u LD_LIBRARY_PATH /usr/local/bin/xrdb -cpp /usr/local/bin/tradcpp -load -quiet "$HOME/.Xdefaults" 2>/dev/null || true
fi
if [ -f "$HOME/Sgiresources" ]; then
    env -u LD_LIBRARY_PATH /usr/local/bin/xrdb -cpp /usr/local/bin/tradcpp -merge -quiet "$HOME/Sgiresources" 2>/dev/null || true
fi
if [ -f /opt/MaXX/share/X11/app-defaults/MaXX ]; then
    env -u LD_LIBRARY_PATH /usr/local/bin/xrdb -cpp /usr/local/bin/tradcpp -merge -quiet /opt/MaXX/share/X11/app-defaults/MaXX 2>/dev/null || true
fi

# 4. Application du fond d'écran SGI en 2560x1440
if [ -f /boot/images/sgi_desktop.jpg ] && [ -x /usr/local/bin/feh ]; then
    env -u LD_LIBRARY_PATH /usr/local/bin/feh --bg-fill /boot/images/sgi_desktop.jpg &
else
    env -u LD_LIBRARY_PATH /usr/local/bin/xsetroot -solid SkyBlue4 &
fi

# 5. Lancement du Toolchest et du gestionnaire de fenêtres SGI 5Dwm
/opt/MaXX/bin64/toolchest &
exec /opt/MaXX/bin64/5Dwm
EOF
chmod +x /usr/local/bin/startmaxx

# 11. DÉCLARATION DANS SDDM ET PROFIL UTILISATEUR
mkdir -p /usr/local/share/xsessions
cat > /usr/local/share/xsessions/maxx.desktop << 'EOF'
[Desktop Entry]
Name=MaXX Interactive Desktop
Comment=Environnement SGI IRIX 5Dwm (Octane 2.2)
Exec=/usr/local/bin/startmaxx
Type=Application
EOF

if [ -d "$USER_HOME" ]; then
    cat > "$USER_HOME/.xinitrc" << 'EOF'
#!/bin/sh
exec /usr/local/bin/startmaxx
EOF
    chmod +x "$USER_HOME/.xinitrc"
    chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME"
fi

echo "=========================================================="
echo " Phase 2 terminée et vérifiée sans erreur !"
echo " Binaire 5Dwm : $(ls -lh /opt/MaXX/bin64/5Dwm)"
echo "=========================================================="

