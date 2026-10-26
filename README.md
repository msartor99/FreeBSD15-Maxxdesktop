# MaXX Interactive Desktop (SGI IRIX Indigo Magic) on FreeBSD 15.1-RELEASE

This repository provides a turnkey, automated, and **100% idempotent** solution (written in pure POSIX `/bin/sh`) to transform a fresh installation of **FreeBSD 15.1-RELEASE** into a complete graphical workstation running **MaXX Interactive Desktop v2.2.0 (Octane)** — the faithful recreation of the legendary **Silicon Graphics (SGI) IRIX Indigo Magic** environment (`5Dwm`, `toolchest`, `tellsystem`, `gr_osview`, `rox-filer`).

---

## What's New: Audited & Merged Single-Script Installer

Previously, the installation was split into two separate phases (`install-base-system.sh` and `install-maxx-interactive.sh`), requiring an intermediate reboot and suffering from configuration overwrite conflicts between the two scripts.

**Both scripts have now been audited, fixed, and merged into a single unified installer: `install-freebsd-maxx.sh`.**

### Changelog & Key Fixes
1. **Single-Pass Deployment (Zero-Touch after configuration)**: No more running a first script, rebooting, and launching the second one. Kernel modules (`linux`, `linux64`) and virtual filesystems (`linprocfs`, `linsysfs`, `fdescfs`, `tmpfs`) are loaded and mounted on the fly during installation.
2. **Dynamic Propagation of `bsddialog` Choices**:
   * The previous Phase 2 script hardcoded the locale (`fr_FR.UTF-8`), keyboard layout (`ch fr`), target user (`administrateur`), and NVIDIA driver branch (`linux-nvidia-libs-470`).
   * Now, all parameters selected interactively at startup (e.g., `fr_CH.UTF-8` locale, Swiss French `ch-fr` keyboard, AMD/Intel/NVIDIA GPU across all driver branches) are dynamically injected into Xorg, SDDM, `winterm`, `startmaxx`, and `Xsession.dt`.
3. **Unified UEFI Splash Screen (`/boot/loader.conf`)**:
   * Resolved the conflict where the second script overwrote `/boot/loader.conf` by forcing `1080p`.
   * The SGI boot and shutdown splash screen (`sgi_splash.png`), the SDDM login screen (`sgi_irix`), and the desktop wallpaper are now all calibrated via ImageMagick to the native resolution selected in the menu (Full HD, WUXGA, QHD `2560x1440`, or 4K UHD).
4. **Fixed Privilege Elevation (`sudoers` & GUI Wrappers)**:
   * Added `/usr/local/bin/octopkg` and `/usr/local/bin/system-config-printer` to the `%wheel` `NOPASSWD` rules, allowing them to launch seamlessly from the SGI *Toolchest* via the `qt-sudo` / `gksu` / `pkexec` wrappers.
5. **Strict POSIX `/bin/sh` Idempotency**:
   * Replaced `ln -sf` with `ln -shf` on directory symlinks (`/opt/MaXX`, fonts, `/tmp`, `/compat/linux/usr/local`) to prevent recursive sub-links from being created when re-running the script multiple times.

---

## Included Features

* **Core System & Performance**:
  * Kernel tuning (`sysctl`) optimized for graphical workstations (scheduler preemption, X11/IPC shared memory, local stream sockets).
  * CPU microcode updates (Intel Xeon/Core or AMD).
  * Quiet startup and shutdown (*Silent Boot*) featuring a high-resolution **SGI** splash screen.
* **Graphics Stack & Binary Compatibility**:
  * Automated installation of **NVIDIA** drivers (Latest Production, Legacy 580, or Legacy 470 for Maxwell/Kepler Quadro cards + matching `linux-nvidia-libs`), **AMD** (`amdgpu`), or **Intel** (`i915kms`).
  * Full **Linuxulator (Rocky Linux 9 / `linux_base-rl9`)** setup, including Motif, GTK2/GTK3, OpenGL/GLX, and targeted ELF branding (`brandelf -t Linux`)[cite: 1].
  * Fail-safe mechanism: installs **SDDM** (with a custom SGI IRIX theme) alongside a fallback **XFCE4** desktop environment.
* **Full MaXX Interactive Desktop v2.2.0 Calibration**:
  * Pre-compiled SGI color schemes and font palettes (`IndigoMagic`, `Base`) using `tradcpp` for authentic Motif/ViewKit rendering[cite: 1].
  * Classic SGI red cursor theme (`redSGI`)[cite: 1].
  * Native integration of SGI system utilities: `tellsystem` (`hinv` powered by `dmidecode`/`lspci`/`lsusb`), `tellversion`, `tellgpu` (`nvidia-smi`), `gr_osview2` (`xosview2`), `winterm`, and `adminterm`[cite: 1].
  * Seamless application wrappers linking the SGI *Toolchest* to native FreeBSD applications: Firefox, Thunderbird, LibreOffice (forced into classic X11/Motif SGI look via `SAL_USE_VCLPLUGIN=gen`), GIMP, Inkscape, VLC, Thunar, Ristretto, Mousepad, Xpdf, FileZilla, DSBMixer, CUPS, and OctoPkg[cite: 1].

---

## Prerequisites

1. A fresh base installation of **FreeBSD 15.1-RELEASE** (`amd64` architecture)[cite: 1, 2].
2. An active Internet connection.
3. A standard user account already created (defaults to `administrateur`, which will automatically be added to the `wheel`, `operator`, and `video` groups)[cite: 2].

---

## Installation

Log in as `root` on your freshly installed FreeBSD system, clone the repository, and run the unified installer:

```sh
pkg install -y git curl wget
git clone [https://github.com/msartor99/FreeBSD15-Maxxdesktop.git](https://github.com/msartor99/FreeBSD15-Maxxdesktop.git)
cd FreeBSD15-Maxxdesktop
chmod +x install-freebsd-maxx.sh
./install-freebsd-maxx.sh
