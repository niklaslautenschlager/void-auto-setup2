# shellcheck shell=bash
# lib/catalog.sh: every desktop and window manager the installer knows.
#
# Package names verified against void-packages master (2026-10-11).
# Fields per id:
#   LABEL   menu text
#   NAME    short display name
#   KIND    de | wm
#   TYPE    wayland | x11
#   PKGS    official packages
#   HV      packages from hyprland-void (Hyprland only)
#   EXEC    command the session wrapper runs
#   XDG     XDG_CURRENT_DESKTOP value (portals.conf lookup, toolkits)
#   RICE    rice id (WMs only)
#   DM      display manager service (DEs only)
#   HIDE    upstream session files replaced by our wrapped entries
#   SELFSTART 1 = the WM has no autostart mechanism; void-session runs
#             `rice autostart` for it

declare -A LABEL NAME KIND TYPE PKGS HV EXEC XDG RICE DM HIDE SELFSTART RICE_LABEL=(
  [ember]='Ember' [tidewater]='Tidewater' [moss]='Moss' [dusk]='Dusk'
  [orchard]='Orchard' [circuit]='Circuit' [aurora]='Aurora' [graphite]='Graphite'
  [copper]='Copper' [monolith]='Monolith' [glacier]='Glacier' [bolt]='Bolt'
  [dune]='Dune' [spectrum]='Spectrum' [sakura]='Sakura'
)

_def() { # id kind type label
  KIND[$1]=$2 TYPE[$1]=$3 LABEL[$1]=$4
}

# ---- Full desktop environments (bring their own login manager) -------------
_def gnome    de wayland "GNOME"
PKGS[gnome]="gnome gnome-tweaks gdm xdg-desktop-portal-gnome gnome-keyring"
DM[gnome]=gdm

_def kde      de wayland "KDE Plasma"
PKGS[kde]="kde-plasma kde-baseapps sddm xdg-desktop-portal-kde"
DM[kde]=sddm

_def xfce     de x11 "XFCE"
PKGS[xfce]="xfce4 lightdm lightdm-gtk3-greeter"
DM[xfce]=lightdm

_def mate     de x11 "MATE"
PKGS[mate]="mate mate-extra lightdm lightdm-gtk3-greeter"
DM[mate]=lightdm

_def cinnamon de x11 "Cinnamon"
PKGS[cinnamon]="cinnamon lightdm lightdm-gtk3-greeter"
DM[cinnamon]=lightdm

_def lxqt     de x11 "LXQt"
PKGS[lxqt]="lxqt sddm"
DM[lxqt]=sddm

DE_IDS=(gnome kde xfce mate cinnamon lxqt)

# ---- Wayland compositors (riced) ---------------------------------------------
_def hyprland wm wayland "Hyprland         dynamic tiling   (hyprland-void)"
NAME[hyprland]="Hyprland"
HV[hyprland]="hyprland xdg-desktop-portal-hyprland hyprlock hypridle"
PKGS[hyprland]="xdg-desktop-portal-gtk"
EXEC[hyprland]="start-hyprland"
XDG[hyprland]="Hyprland"
RICE[hyprland]=ember
HIDE[hyprland]="/usr/share/wayland-sessions/hyprland.desktop /usr/share/wayland-sessions/hyprland-uwsm.desktop"

_def sway wm wayland "Sway             manual tiling (i3-like)"
NAME[sway]="Sway"
PKGS[sway]="sway swaylock swayidle swaybg xdg-desktop-portal-wlr xdg-desktop-portal-gtk"
EXEC[sway]="sway"
XDG[sway]="sway"
RICE[sway]=tidewater
HIDE[sway]="/usr/share/wayland-sessions/sway.desktop"

_def river wm wayland "River            dynamic tiling   (rivertile layouts)"
NAME[river]="River"
PKGS[river]="river swaylock swayidle swaybg wlopm xdg-desktop-portal-wlr xdg-desktop-portal-gtk"
EXEC[river]="river"
XDG[river]="river"
RICE[river]=moss
HIDE[river]="/usr/share/wayland-sessions/river.desktop"

_def niri wm wayland "niri             scrollable tiling"
NAME[niri]="niri"
PKGS[niri]="niri xwayland-satellite swaylock swayidle swaybg xdg-desktop-portal-gnome xdg-desktop-portal-gtk"
EXEC[niri]="niri --session"
XDG[niri]="niri"
RICE[niri]=dusk
HIDE[niri]="/usr/share/wayland-sessions/niri.desktop"

_def mango wm wayland "MangoWC          dynamic tiling   (dwl-based)"
NAME[mango]="MangoWC"
PKGS[mango]="mangowc swaylock swayidle swaybg wlopm xdg-desktop-portal-wlr xdg-desktop-portal-gtk"
EXEC[mango]="mango"
XDG[mango]="mango:wlroots"
RICE[mango]=orchard
HIDE[mango]="/usr/share/wayland-sessions/mango.desktop"

_def qtile-wl wm wayland "Qtile (Wayland)  dynamic tiling   (Python)"
NAME[qtile-wl]="Qtile (Wayland)"
PKGS[qtile-wl]="qtile qtile-wayland python3-psutil swaylock swayidle swaybg wlopm xdg-desktop-portal-wlr xdg-desktop-portal-gtk"
EXEC[qtile-wl]="qtile start -b wayland"
XDG[qtile-wl]="qtile:wlroots"
RICE[qtile-wl]=circuit
HIDE[qtile-wl]="/usr/share/wayland-sessions/qtile.desktop"

_def wayfire wm wayland "Wayfire          stacking + effects"
NAME[wayfire]="Wayfire"
PKGS[wayfire]="wayfire swaylock swayidle swaybg wlopm xdg-desktop-portal-wlr xdg-desktop-portal-gtk"
EXEC[wayfire]="wayfire"
XDG[wayfire]="wayfire:wlroots"
RICE[wayfire]=aurora
HIDE[wayfire]="/usr/share/wayland-sessions/wayfire.desktop"

# ---- X11 window managers (riced) ---------------------------------------------
_def i3 wm x11 "i3               manual tiling"
NAME[i3]="i3"
PKGS[i3]="i3"
EXEC[i3]="i3"
XDG[i3]="i3"
RICE[i3]=graphite
HIDE[i3]="/usr/share/xsessions/i3.desktop /usr/share/xsessions/i3-with-shmlog.desktop"

_def awesome wm x11 "awesome          dynamic tiling   (Lua)"
NAME[awesome]="awesome"
PKGS[awesome]="awesome"
EXEC[awesome]="awesome"
XDG[awesome]="awesome"
RICE[awesome]=copper
HIDE[awesome]="/usr/share/xsessions/awesome.desktop"

_def dwm wm x11 "dwm              dynamic tiling   (built from source)"
NAME[dwm]="dwm"
# dwm is configured at compile time: the rice builds a patched copy into
# /usr/local/bin; the Void package stays installed as a fallback.
PKGS[dwm]="dwm base-devel libX11-devel libXft-devel libXinerama-devel freetype-devel fontconfig-devel"
EXEC[dwm]="dwm"
XDG[dwm]="dwm"
RICE[dwm]=monolith
SELFSTART[dwm]=1
HIDE[dwm]="/usr/share/xsessions/dwm.desktop"

_def dk wm x11 "dk               dynamic tiling   (scriptable)"
NAME[dk]="dk"
PKGS[dk]="dk sxhkd"
EXEC[dk]="dk"
XDG[dk]="dk"
RICE[dk]=glacier
HIDE[dk]="/usr/share/xsessions/dk.desktop"

_def frankenwm wm x11 "FrankenWM        dynamic tiling   (built from source)"
NAME[frankenwm]="FrankenWM"
PKGS[frankenwm]="frankenwm base-devel libxcb-devel xcb-util-devel xcb-util-wm-devel xcb-util-keysyms-devel libX11-devel"
EXEC[frankenwm]="frankenwm"
XDG[frankenwm]="frankenwm"
RICE[frankenwm]=bolt
SELFSTART[frankenwm]=1
HIDE[frankenwm]="/usr/share/xsessions/frankenwm.desktop"

_def leftwm wm x11 "LeftWM           dynamic tiling   (Rust)"
NAME[leftwm]="LeftWM"
PKGS[leftwm]="leftwm"
EXEC[leftwm]="leftwm"
XDG[leftwm]="leftwm"
RICE[leftwm]=dune
HIDE[leftwm]="/usr/share/xsessions/leftwm.desktop"

_def qtile-x11 wm x11 "Qtile (X11)      dynamic tiling   (Python)"
NAME[qtile-x11]="Qtile (X11)"
PKGS[qtile-x11]="qtile python3-psutil"
EXEC[qtile-x11]="qtile start -b x11"
XDG[qtile-x11]="qtile"
RICE[qtile-x11]=circuit
HIDE[qtile-x11]="/usr/share/xsessions/qtile.desktop"

_def spectrwm wm x11 "spectrwm         dynamic tiling"
NAME[spectrwm]="spectrwm"
PKGS[spectrwm]="spectrwm"
EXEC[spectrwm]="spectrwm"
XDG[spectrwm]="spectrwm"
RICE[spectrwm]=spectrum
HIDE[spectrwm]="/usr/share/xsessions/spectrwm.desktop"

_def bspwm wm x11 "bspwm            tiling (binary space partitioning)"
NAME[bspwm]="bspwm"
PKGS[bspwm]="bspwm sxhkd"
EXEC[bspwm]="bspwm"
XDG[bspwm]="bspwm"
RICE[bspwm]=sakura
HIDE[bspwm]="/usr/share/xsessions/bspwm.desktop"

WAYLAND_WM_IDS=(hyprland sway river niri mango qtile-wl wayfire)
X11_WM_IDS=(i3 awesome dwm dk frankenwm leftwm qtile-x11 spectrwm bspwm)
WM_IDS=("${WAYLAND_WM_IDS[@]}" "${X11_WM_IDS[@]}")

# Shared by every riced session of a type
RICE_COMMON_PKGS="rofi libnotify brightnessctl playerctl polkit-gnome pavucontrol
 papirus-icon-theme adwaita-icon-theme xdg-utils xdg-user-dirs
 font-ibm-plex-ttf font-fira-ttf font-firacode font-hack-ttf font-inter
 nerd-fonts-symbols-ttf noto-fonts-ttf noto-fonts-emoji dejavu-fonts-ttf"
RICE_WAYLAND_PKGS="Waybar mako foot grim slurp wl-clipboard swaylock swayidle swaybg
 wlopm xorg-server-xwayland xdg-desktop-portal xdg-desktop-portal-gtk qt5-wayland qt6-wayland"
RICE_X11_PKGS="xorg-minimal xinit xauth xrdb xsetroot xrandr setxkbmap xprop
 polybar dunst alacritty picom xwallpaper xss-lock i3lock-color maim slop xclip
 xdotool xorg-fonts"

# Menu entries for menu_many: headings + "id=label"
catalog_menu_entries() {
  local id
  printf '%s\n' "-=Full desktop environments (bring their own login screen)"
  for id in "${DE_IDS[@]}"; do printf '%s=%s\n' "$id" "${LABEL[$id]}"; done
  printf '%s\n' "-=Wayland compositors (each with its own rice)"
  for id in "${WAYLAND_WM_IDS[@]}"; do printf '%s=%s\n' "$id" "${LABEL[$id]}"; done
  printf '%s\n' "-=X11 window managers (each with its own rice)"
  for id in "${X11_WM_IDS[@]}"; do printf '%s=%s\n' "$id" "${LABEL[$id]}"; done
}
