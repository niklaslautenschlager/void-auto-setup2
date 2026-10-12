#!/bin/bash
set -euo pipefail
cfg="$1" palette_sed="$2"

grep -q 'X11/XF86keysym.h' "$cfg" || sed -i '1i #include <X11/XF86keysym.h>' "$cfg"

sed -i \
  -e 's/^#define MASTER_SIZE.*/#define MASTER_SIZE 0.56/' \
  -e 's/^#define SHOW_PANEL.*/#define SHOW_PANEL False/' \
  -e 's/^#define BORDER_WIDTH.*/#define BORDER_WIDTH @@border@@/' \
  -e 's/^#define FOCUS.*/#define FOCUS "@@accent@@"/' \
  -e 's/^#define UNFOCUS.*/#define UNFOCUS "@@bg_hi@@"/' \
  -e 's/^#define SCRATCH.*/#define SCRATCH "@@urgent@@"/' \
  -e 's/^#define USELESSGAP.*/#define USELESSGAP @@gaps_out@@/' \
  -e 's/^#define DESKTOPS.*/#define DESKTOPS 9/' \
  -e 's/^static const char \*termcmd\[\].*/static const char *termcmd[] = { "rice", "term", NULL };/' \
  -e 's/^static const char \*menucmd\[\].*/static const char *menucmd[] = { "rice", "launch", NULL };/' \
  -e 's/{ MOD4, XK_Return, swap_master, {NULL}}/{ MOD4|SHIFT, XK_Return, swap_master, {NULL}}/' \
  -e 's/{ MOD4|SHIFT, XK_Return, spawn, {.com = termcmd}}/{ MOD4, XK_Return, spawn, {.com = termcmd}}/' \
  -e 's/^.*MOD4|SHIFT, XK_h, rotate,.*$/\/\* Super+Shift+H moves a window. *\//' \
  -e 's/^.*MOD4|SHIFT, XK_l, rotate,.*$/\/\* Super+Shift+L moves a window. *\//' \
  -e 's/^.*MOD4|CONTROL, XK_h, rotate_client,.*$/\/\* Workspace rotation disabled. *\//' \
  -e 's/^.*MOD4|CONTROL, XK_l, rotate_client,.*$/\/\* Workspace rotation disabled. *\//' \
  -e 's/^.*MOD4|CONTROL|SHIFT, XK_h, rotate_filled,.*$/\/\* Workspace rotation disabled. *\//' \
  -e 's/^.*MOD4|CONTROL|SHIFT, XK_l, rotate_filled,.*$/\/\* Workspace rotation disabled. *\//' \
  -e 's/^.*MOD4, XK_h, resize_master,.*$/\/\* Super+H focuses left. *\//' \
  -e 's/^.*MOD4, XK_l, resize_master,.*$/\/\* Super+L focuses right. *\//' \
  -e 's/{ MOD4|SHIFT, XK_c, killclient, {NULL}}/{ MOD4, XK_q, killclient, {NULL}}/' \
  "$cfg"

tmp="$cfg.vpi-tmp"
awk '
  { print }
  /static key keys\[\] = \{/ {
    print "{ MOD4, XK_h, prev_win, {NULL}},"
    print "{ MOD4, XK_l, next_win, {NULL}},"
    print "{ MOD4, XK_Left, prev_win, {NULL}},"
    print "{ MOD4, XK_Right, next_win, {NULL}},"
    print "{ MOD4, XK_Up, prev_win, {NULL}},"
    print "{ MOD4, XK_Down, next_win, {NULL}},"
    print "{ MOD4|SHIFT, XK_h, move_up, {NULL}},"
    print "{ MOD4|SHIFT, XK_l, move_down, {NULL}},"
    print "{ MOD4|SHIFT, XK_Left, move_up, {NULL}},"
    print "{ MOD4|SHIFT, XK_Right, move_down, {NULL}},"
    print "{ MOD4|SHIFT, XK_Up, move_up, {NULL}},"
    print "{ MOD4|SHIFT, XK_Down, move_down, {NULL}},"
    print "{ MOD4|CONTROL, XK_h, resize_master, {.i = -10}},"
    print "{ MOD4|CONTROL, XK_l, resize_master, {.i = +10}},"
    print "{ MOD4|CONTROL, XK_Left, resize_master, {.i = -10}},"
    print "{ MOD4|CONTROL, XK_Right, resize_master, {.i = +10}},"
    print "{ MOD4|CONTROL, XK_Up, resize_stack, {.i = -10}},"
    print "{ MOD4|CONTROL, XK_Down, resize_stack, {.i = +10}},"
    print "{ MOD4, XK_d, spawn, {.com = menucmd}},"
    print "{ MOD4, XK_space, spawn, {.com = menucmd}},"
    print "{ MOD4, XK_v, centerwindow, {NULL}},"
    print "{ MOD4, XK_Escape, spawn, SHCMD(\"rice lock\")},"
    print "{ MOD4|SHIFT, XK_Escape, spawn, SHCMD(\"rice power\")},"
    print "{ MOD4|SHIFT, XK_r, spawn, SHCMD(\"rice reload\")},"
    print "{ 0, XK_Print, spawn, SHCMD(\"rice shot full\")},"
    print "{ SHIFT, XK_Print, spawn, SHCMD(\"rice shot area\")},"
    print "{ 0, XF86XK_AudioRaiseVolume, spawn, SHCMD(\"rice vol up\")},"
    print "{ 0, XF86XK_AudioLowerVolume, spawn, SHCMD(\"rice vol down\")},"
    print "{ 0, XF86XK_AudioMute, spawn, SHCMD(\"rice vol mute\")},"
    print "{ 0, XF86XK_AudioMicMute, spawn, SHCMD(\"rice vol mic\")},"
    print "{ 0, XF86XK_MonBrightnessUp, spawn, SHCMD(\"rice light up\")},"
    print "{ 0, XF86XK_MonBrightnessDown, spawn, SHCMD(\"rice light down\")},"
    print "{ 0, XF86XK_AudioPlay, spawn, SHCMD(\"playerctl play-pause\")},"
    print "{ 0, XF86XK_AudioNext, spawn, SHCMD(\"playerctl next\")},"
    print "{ 0, XF86XK_AudioPrev, spawn, SHCMD(\"playerctl previous\")},"
  }
' "$cfg" >"$tmp"
mv "$tmp" "$cfg"
sed -i -f "$palette_sed" "$cfg"
