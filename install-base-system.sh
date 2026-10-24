#!/bin/sh
# ==============================================================================
# SCRIPT 1: install-base.sh (BASÉ SUR 4.1-SGI-FreeBSD 15 M4000 workstation.txt)
# TARGET OS: FreeBSD 15.1-RELEASE
# HARDWARE: HP Z4 G4 / Xeon W-2140B / NVIDIA Quadro M4000 (Driver 470)
# DISPLAY: ASUS PB278 (2560x1440)
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Ce script doit être exécuté en root."
    exit 1
fi

####################################################
# install sudo access & BASE CONFIG
####################################################

pkg update -y
pkg install -y sudo

mkdir -p /usr/local/etc/sudoers.d
echo "%wheel ALL=(ALL:ALL) ALL" > /usr/local/etc/sudoers.d/wheel
chmod 0440 /usr/local/etc/sudoers.d/wheel

sysrc sshd_enable="YES"
sed -i '' 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sh /etc/rc.d/sshd restart

####################################################
# some tips and silent boot
####################################################

sysrc -f /boot/loader.conf boot_mute="YES"
sysrc splash_changer_enable="YES"

if ! grep -q " > /dev/null" /etc/rc; then
    sed -i '' 's/run_rc_script ${_rc_elem} ${_boot}/run_rc_script ${_rc_elem} ${_boot} > \/dev\/null/g' /etc/rc
fi
sysrc rc_startmsgs="NO"

sysrc -f /boot/loader.conf autoboot_delay="3"

grep -q "kern.sched.preempt_thresh" /etc/sysctl.conf || echo "kern.sched.preempt_thresh=224" >> /etc/sysctl.conf
grep -q "kern.ipc.shm_allow_removed" /etc/sysctl.conf || echo "kern.ipc.shm_allow_removed=1" >> /etc/sysctl.conf

sysrc -f /boot/loader.conf tmpfs_load="YES"
sysrc -f /boot/loader.conf aio_load="YES"

sysctl net.local.stream.recvspace=65536
sysctl net.local.stream.sendspace=65536

####################################################
# for Intel CPU (Xeon W-2140B)
####################################################

pkg install -y cpu-microcode sensors
sysrc -f /boot/loader.conf coretemp_load="YES"
sysrc -f /boot/loader.conf cpu_microcode_name="/boot/firmware/intel-ucode.bin"

####################################################
# enable Linux for Nvidia driver and other things
####################################################

sysrc linux_enable="YES"
sysrc linux64_enable="YES"
kldload linux 2>/dev/null || true
kldload linux64 2>/dev/null || true
service linux start
sysrc linux_mounts_enable="YES"

pkg install -y linux-rl9

####################################################
# configuration base and utilities
####################################################

pkg install -y doas unzip libzip wget git
pkg install -y htop neofetch python3 bashtop
pkg install -y ImageMagick7

# configuration powermanagement
pkg install -y smartmontools
sysrc smartd_enable="YES"
[ -f /usr/local/etc/smartd.conf ] || cp /usr/local/etc/smartd.conf.sample /usr/local/etc/smartd.conf
service smartd start

####################################################
# install french class
####################################################

sed -i '' '/^french|/,/:tc=default:/d' /etc/login.conf 2>/dev/null
echo "  " >> /etc/login.conf
echo 'french|French Users Accounts:\' >> /etc/login.conf
echo '     :charset=UTF-8:\' >> /etc/login.conf
echo '     :lang=fr_FR.UTF-8:\' >> /etc/login.conf
echo '      lc_all=fr_FR:\' >> /etc/login.conf
echo '      lc_collate=fr_FR:\' >> /etc/login.conf
echo '      lc_ctype=fr_FR:\' >> /etc/login.conf
echo '      lc_messages=fr_FR:\' >> /etc/login.conf
echo '     :tc=default:' >> /etc/login.conf
echo '   ' >> /etc/login.conf

cap_mkdb /etc/login.conf
echo 'defaultclass=french' > /etc/adduser.conf

pw usermod administrateur -G wheel,operator,video -L french
pw usermod root -L french

####################################################
# install printer manager cups and usb support
####################################################

cat > /etc/devfs.rules << 'EOF'
[localrules=5]
add path 'da*' mode 0660 group operator
add path 'cd*' mode 0660 group operator
add path 'uscanner*' mode 0660 group operator
add path 'xpt*' mode 660 group operator
add path 'pass*' mode 660 group operator
add path 'md*' mode 0660 group operator
add path 'msdosfs/*' mode 0660 group operator
add path 'ext2fs/*' mode 0660 group operator
add path 'ntfs/*' mode 0660 group operator
add path 'usb/*' mode 0660 group operator
add path 'unlpt*' mode 0660 group cups
add path 'lpt*' mode 0660 group cups
EOF

pkg install -y cups gutenprint cups-filters hplip system-config-printer
sysrc cupsd_enable="YES"
sysrc devfs_system_ruleset="localrules"
service devfs restart

# install USB support
pkg install -y fusefs-ntfs fusefs-ext2 fusefs-hfsfuse
sysrc kld_list+="fusefs ext2fs"
kldload fusefs 2>/dev/null || true
kldload ext2fs 2>/dev/null || true
grep -q "vfs.usermount=1" /etc/sysctl.conf || echo "vfs.usermount=1" >> /etc/sysctl.conf

####################################################
# install audio
####################################################

pkg install -y pulseaudio pipewire wireplumber
pkg install -y audio/freedesktop-sound-theme

sysrc sound_load="YES"
sysrc snd_hda_load="YES"
sysctl hw.snd.default_unit=1

####################################################
# install xorg, applications, xfce and tools
####################################################

pkg install -y xorg dbus avahi signal-cli seatd xfce xfce4-goodies \
firefox vlc ffmpeg libva-vdpau-driver libva-utils libdvdread libdvdnav \
xdg-user-dirs octopkg multimedia/mpv \
gstreamer1-plugins-all gstreamer1-libav libbluray

sysrc dbus_enable="YES"
sysrc avahi_enable="YES"
grep -q "procfs" /etc/fstab || echo "proc       /proc       procfs       rw       0       0" >> /etc/fstab
grep -q "fdescfs" /etc/fstab || echo "fdesc      /dev/fd     fdescfs      rw       0       0" >> /etc/fstab

sysrc seatd_enable="YES"

####################################################
# set swiss french keyboard on X11 config
####################################################

mkdir -p /usr/local/etc/X11/xorg.conf.d
cat > /usr/local/etc/X11/xorg.conf.d/20-keyboards.conf << 'EOF'
Section "ServerFlags"
    Option "DontZap" "false"
EndSection

Section "InputClass"
    Identifier      "All Keyboards"
    MatchIsKeyboard "yes"
    Option          "XkbLayout" "ch"
    Option          "XkbVariant" "fr"
    Option          "XkbOptions" "terminate:ctrl_alt_bksp"
EndSection
EOF

####################################################
# setup xorg nvidia and 27" screen (2560x1440)
####################################################

cat > /usr/local/etc/X11/xorg.conf.d/10-nvidia.conf << 'EOF'
Section "Device"
    Identifier     "NVIDIA Card"
    Driver         "nvidia"
    Option         "ModeValidation" "NoMaxResolutionCheck"
EndSection

Section "Monitor"
    Identifier     "Monitor0"
    VendorName     "Unknown"
    ModelName      "Unknown"
EndSection

Section "Screen"
    Identifier     "Screen0"
    Device         "NVIDIA Card"
    Monitor        "Monitor0"
    DefaultDepth    24
    Option         "MetaModes" "2560x1440 +0+0"
    SubSection "Display"
        Depth       24
        Modes      "2560x1440"
    EndSubSection
EndSection
EOF

sysrc -f /boot/loader.conf efi_max_resolution="1440p"
sysrc -f /boot/loader.conf kern.vt.fb.default_mode="2560x1440"

####################################################
# install Nvidia driver 470 for Quadro M4000 (SANS DRM-KMOD)
####################################################

pciconf -lv | grep -B4 "VGA"

pkg install -y nvidia-driver-470 linux-nvidia-libs-470 nvidia-kmod-470 libc6-shim
pkg install -y nvidia-settings nvidia-xconfig

sysrc -f /boot/loader.conf hw.nvidiadrm.modeset="1"
sysrc -f /boot/loader.conf nvidia-drm.modeset="1"

sysrc kld_list+="nvidia-modeset"
sysrc nvidia_modeset_enable="YES"

nvidia-xconfig

####################################################
# install sddm, theme sgi_irix and splash
####################################################

pkg install -y sddm

sysrc sddm_enable="YES"
sysrc sddm_lang="ch_FR"

if ! grep -q "setxkbmap ch fr" /usr/local/share/sddm/scripts/Xsetup 2>/dev/null; then
    echo "setxkbmap ch fr" >> /usr/local/share/sddm/scripts/Xsetup
fi

cat > /usr/local/etc/sddm.conf << 'EOF'
# Disable virtual keyboard by default
InputMethod=""
EOF

IMG_DIR="/boot/images"
mkdir -p "$IMG_DIR"
SGI_WALLPAPER_URL="https://raw.githubusercontent.com/msartor99/FreeBSD15-Maxxdesktop/main/sgi_desktop.jpg"
SGI_SPLASH_URL="https://raw.githubusercontent.com/msartor99/FreeBSD15-Maxxdesktop/main/SGI_splash.jpg"

fetch -qo "$IMG_DIR/SGI_splash.jpg" "$SGI_SPLASH_URL" 2>/dev/null || true
fetch -qo "$IMG_DIR/sgi_desktop.jpg" "$SGI_WALLPAPER_URL" 2>/dev/null || true

cd /boot/images
magick "SGI_splash.jpg" -resize 1920x1080^ -gravity center -extent 1920x1080 -alpha set -define png:color-type=6 "png32:SGI_splash.png"
cd /root

# Activation de l'image au démarrage et à l'extinction
sysrc splash_changer_enable="YES"
sysrc -f /boot/loader.conf splash="/boot/images/SGI_splash.png"
sysrc -f /boot/loader.conf shutdown_splash="/boot/images/SGI_splash.png"

# Création du thème SDDM sgi_irix
mkdir -p /usr/local/share/sddm/themes/sgi_irix
cp -R /usr/local/share/sddm/themes/maldives/* /usr/local/share/sddm/themes/sgi_irix/
rm -f /usr/local/share/sddm/themes/sgi_irix/background.jpg
cp /boot/images/sgi_desktop.jpg /usr/local/share/sddm/themes/sgi_irix/background.jpg

mkdir -p /usr/local/etc/sddm.conf.d
cat > /usr/local/etc/sddm.conf.d/10-theme.conf << 'EOF'
[Theme]
Current=sgi_irix
EOF

echo "=========================================================="
echo " Installation de base terminée avec succès !"
echo " Vous pouvez redémarrer avec : reboot"
echo "=========================================================="