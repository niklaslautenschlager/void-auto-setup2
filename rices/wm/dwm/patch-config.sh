#!/bin/bash
set -euo pipefail
cfg="$1" palette_sed="$2"

grep -q 'X11/XF86keysym.h' "$cfg" || sed -i '1i #include <X11/XF86keysym.h>' "$cfg"

sed -i \
  -e 's/^#define MODKEY Mod1Mask/#define MODKEY Mod4Mask/' \
  -e 's/^static const unsigned int borderpx.*/static const unsigned int borderpx = @@border@@;/' \
  -e 's/^static const char \*fonts.*/static const char *fonts[] = { "@@font_ui@@:size=@@font_px@@" };/' \
  -e 's/^static const char dmenufont.*/static const char dmenufont[] = "@@font_ui@@:size=@@font_px@@";/' \
  -e 's/^static const char col_gray1.*/static const char col_gray1[] = "@@bg@@";/' \
  -e 's/^static const char col_gray2.*/static const char col_gray2[] = "@@bg_hi@@";/' \
  -e 's/^static const char col_gray3.*/static const char col_gray3[] = "@@fg_dim@@";/' \
  -e 's/^static const char col_gray4.*/static const char col_gray4[] = "@@fg@@";/' \
  -e 's/^static const char col_cyan.*/static const char col_cyan[] = "@@accent@@";/' \
  -e 's/\[SchemeNorm\].*/[SchemeNorm] = { col_gray4, col_gray1, col_gray2 },/' \
  -e 's/\[SchemeSel\].*/[SchemeSel]  = { col_gray1, col_cyan, col_cyan },/' \
  -e 's/^static const char \*dmenucmd\[\].*/static const char *dmenucmd[] = { "rice", "launch", NULL };/' \
  -e 's/^static const char \*termcmd.*/static const char *termcmd[] = { "rice", "term", NULL };/' \
  -e 's/^.*XK_d, *incnmaster,.*$/\t{ MODKEY|ShiftMask, XK_d, incnmaster, {.i = -1} },/' \
  -e 's/^.*XK_Return, *zoom,.*$/\t\/\* Super+Return launches rice term. *\//' \
  -e 's/{ MODKEY, *XK_h, setmfact, *{.f = -0.05} }/{ MODKEY, XK_h, focusstack, {.i = -1} }/' \
  -e 's/{ MODKEY, *XK_l, setmfact, *{.f = +0.05} }/{ MODKEY, XK_l, focusstack, {.i = +1} }/' \
  -e 's/{ MODKEY, *XK_f, setlayout, *{.v = &layouts\[1\]} }/{ MODKEY|ShiftMask, XK_f, setlayout, {.v = \&layouts[1]} }/' \
  -e 's/^.*XK_space, *setlayout,.*$/\t\/\* Super+Space is the launcher. \*\//' \
  -e 's/^.*XK_space, *togglefloating,.*$/\t{ MODKEY|ControlMask, XK_space, togglefloating, {0} },/' \
  "$cfg"

tmp="$cfg.vpi-tmp"
awk '
  { print }
  /static const Key keys\[\] = \{/ {
    print "\t{ MODKEY, XK_Return, spawn, SHCMD(\"rice term\") },"
    print "\t{ MODKEY, XK_d, spawn, SHCMD(\"rice launch\") },"
    print "\t{ MODKEY, XK_space, spawn, SHCMD(\"rice launch\") },"
    print "\t{ MODKEY, XK_q, killclient, {0} },"
    print "\t{ MODKEY, XK_f, spawn, SHCMD(\"xdotool getactivewindow windowstate --toggle FULLSCREEN\") },"
    print "\t{ MODKEY, XK_v, togglefloating, {0} },"
    print "\t{ MODKEY, XK_Left, focusstack, {.i = -1} },"
    print "\t{ MODKEY, XK_Right, focusstack, {.i = +1} },"
    print "\t{ MODKEY, XK_Up, focusstack, {.i = -1} },"
    print "\t{ MODKEY, XK_Down, focusstack, {.i = +1} },"
    print "\t{ MODKEY|ShiftMask, XK_h, zoom, {0} },"
    print "\t{ MODKEY|ShiftMask, XK_j, zoom, {0} },"
    print "\t{ MODKEY|ShiftMask, XK_k, zoom, {0} },"
    print "\t{ MODKEY|ShiftMask, XK_l, zoom, {0} },"
    print "\t{ MODKEY|ShiftMask, XK_Left, zoom, {0} },"
    print "\t{ MODKEY|ShiftMask, XK_Right, zoom, {0} },"
    print "\t{ MODKEY|ShiftMask, XK_Up, zoom, {0} },"
    print "\t{ MODKEY|ShiftMask, XK_Down, zoom, {0} },"
    print "\t{ MODKEY|ControlMask, XK_h, setmfact, {.f = -0.05} },"
    print "\t{ MODKEY|ControlMask, XK_l, setmfact, {.f = +0.05} },"
    print "\t{ MODKEY|ControlMask, XK_Left, setmfact, {.f = -0.05} },"
    print "\t{ MODKEY|ControlMask, XK_Right, setmfact, {.f = +0.05} },"
    print "\t{ MODKEY|ControlMask, XK_Up, incnmaster, {.i = +1} },"
    print "\t{ MODKEY|ControlMask, XK_Down, incnmaster, {.i = -1} },"
    print "\t{ MODKEY, XK_Escape, spawn, SHCMD(\"rice lock\") },"
    print "\t{ MODKEY|ShiftMask, XK_Escape, spawn, SHCMD(\"rice power\") },"
    print "\t{ MODKEY|ShiftMask, XK_r, spawn, SHCMD(\"rice reload\") },"
    print "\t{ 0, XK_Print, spawn, SHCMD(\"rice shot full\") },"
    print "\t{ ShiftMask, XK_Print, spawn, SHCMD(\"rice shot area\") },"
    print "\t{ 0, XF86XK_AudioRaiseVolume, spawn, SHCMD(\"rice vol up\") },"
    print "\t{ 0, XF86XK_AudioLowerVolume, spawn, SHCMD(\"rice vol down\") },"
    print "\t{ 0, XF86XK_AudioMute, spawn, SHCMD(\"rice vol mute\") },"
    print "\t{ 0, XF86XK_AudioMicMute, spawn, SHCMD(\"rice vol mic\") },"
    print "\t{ 0, XF86XK_MonBrightnessUp, spawn, SHCMD(\"rice light up\") },"
    print "\t{ 0, XF86XK_MonBrightnessDown, spawn, SHCMD(\"rice light down\") },"
    print "\t{ 0, XF86XK_AudioPlay, spawn, SHCMD(\"playerctl play-pause\") },"
    print "\t{ 0, XF86XK_AudioNext, spawn, SHCMD(\"playerctl next\") },"
    print "\t{ 0, XF86XK_AudioPrev, spawn, SHCMD(\"playerctl previous\") },"
  }
' "$cfg" >"$tmp"
mv "$tmp" "$cfg"
sed -i -f "$palette_sed" "$cfg"
