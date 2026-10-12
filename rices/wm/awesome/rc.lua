-- @@name@@: Copper Awesome setup with a compact custom wibar.
local awful = require("awful")
require("awful.autofocus")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")

beautiful.init(gears.filesystem.get_configuration_dir() .. "theme.lua")
local modkey = "Mod4"
local terminal = "rice term"
local tags = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }

awful.layout.layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.fair,
    awful.layout.suit.max,
    awful.layout.suit.floating,
}

local function spawn(command)
    awful.spawn.with_shell(command)
end

local globalkeys = gears.table.join(
    awful.key({ modkey }, "Return", function() spawn(terminal) end, { description = "terminal", group = "launcher" }),
    awful.key({ modkey }, "d", function() spawn("rice launch") end, { description = "launcher", group = "launcher" }),
    awful.key({ modkey }, "space", function() spawn("rice launch") end, { description = "launcher", group = "launcher" }),
    awful.key({ modkey }, "Escape", function() spawn("rice lock") end, { description = "lock", group = "session" }),
    awful.key({ modkey, "Shift" }, "Escape", function() spawn("rice power") end, { description = "power menu", group = "session" }),
    awful.key({ modkey, "Shift" }, "r", function() spawn("rice autostart"); awesome.restart() end, { description = "reload", group = "awesome" }),
    awful.key({}, "Print", function() spawn("rice shot full") end, { description = "screenshot", group = "session" }),
    awful.key({ "Shift" }, "Print", function() spawn("rice shot area") end, { description = "area screenshot", group = "session" }),
    awful.key({ modkey }, "h", function() awful.client.focus.bydirection("left"); if client.focus then client.focus:raise() end end),
    awful.key({ modkey }, "j", function() awful.client.focus.bydirection("down"); if client.focus then client.focus:raise() end end),
    awful.key({ modkey }, "k", function() awful.client.focus.bydirection("up"); if client.focus then client.focus:raise() end end),
    awful.key({ modkey }, "l", function() awful.client.focus.bydirection("right"); if client.focus then client.focus:raise() end end),
    awful.key({ modkey, "Shift" }, "h", function() awful.client.swap.bydirection("left") end),
    awful.key({ modkey, "Shift" }, "j", function() awful.client.swap.bydirection("down") end),
    awful.key({ modkey, "Shift" }, "k", function() awful.client.swap.bydirection("up") end),
    awful.key({ modkey, "Shift" }, "l", function() awful.client.swap.bydirection("right") end),
    awful.key({ modkey, "Control" }, "h", function() awful.client.incwfact(-0.05) end),
    awful.key({ modkey, "Control" }, "l", function() awful.client.incwfact(0.05) end),
    awful.key({ modkey }, "Tab", function() awful.client.focus.history.previous(); if client.focus then client.focus:raise() end end),
    awful.key({}, "XF86AudioRaiseVolume", function() spawn("rice vol up") end),
    awful.key({}, "XF86AudioLowerVolume", function() spawn("rice vol down") end),
    awful.key({}, "XF86AudioMute", function() spawn("rice vol mute") end),
    awful.key({}, "XF86AudioMicMute", function() spawn("rice vol mic") end),
    awful.key({}, "XF86MonBrightnessUp", function() spawn("rice light up") end),
    awful.key({}, "XF86MonBrightnessDown", function() spawn("rice light down") end),
    awful.key({}, "XF86AudioPlay", function() spawn("playerctl play-pause") end),
    awful.key({}, "XF86AudioNext", function() spawn("playerctl next") end),
    awful.key({}, "XF86AudioPrev", function() spawn("playerctl previous") end)
)

for i = 1, #tags do
    globalkeys = gears.table.join(globalkeys,
        awful.key({ modkey }, tags[i], function()
            local s = awful.screen.focused()
            local t = s.tags[i]
            if t then t:view_only() end
        end, { description = "view tag " .. tags[i], group = "tag" }),
        awful.key({ modkey, "Shift" }, tags[i], function()
            if client.focus and client.focus.screen.tags[i] then client.focus:move_to_tag(client.focus.screen.tags[i]) end
        end, { description = "move to tag " .. tags[i], group = "tag" })
    )
end
root.keys(globalkeys)

awful.screen.connect_for_each_screen(function(s)
    awful.tag(tags, s, awful.layout.layouts[1])
    if beautiful.wallpaper and gears.filesystem.file_readable(beautiful.wallpaper) then
        gears.wallpaper.maximized(beautiful.wallpaper, s, true)
    end
    local taglist = awful.widget.taglist {
        screen = s,
        filter = awful.widget.taglist.filter.all,
        buttons = gears.table.join(
            awful.button({}, 1, function(t) t:view_only() end),
            awful.button({ modkey }, 1, function(t) if client.focus then client.focus:move_to_tag(t) end end)
        ),
    }
    local tasklist = awful.widget.tasklist {
        screen = s,
        filter = awful.widget.tasklist.filter.currenttags,
        buttons = gears.table.join(
            awful.button({}, 1, function(c) c:activate { context = "tasklist", action = "toggle_minimization" } end),
            awful.button({}, 3, function() awful.menu.client_list { theme = { width = 300 } } end)
        ),
    }
    local clock = wibox.widget.textclock("  %H:%M  ")
    s.wibar = awful.wibar({ position = "top", height = @@bar_h@@, bg = beautiful.bg_normal, fg = beautiful.fg_normal, screen = s })
    s.wibar:setup {
        layout = wibox.layout.align.horizontal,
        { layout = wibox.layout.fixed.horizontal,
          wibox.widget.textbox(" <b>VOID</b> "), taglist, awful.widget.layoutbox(s) },
        tasklist,
        { layout = wibox.layout.fixed.horizontal,
          awful.widget.systray(), clock,
          wibox.widget.textbox(" <span foreground='@@urgent@@'>●</span> ") },
    }
end)

clientkeys = gears.table.join(
    awful.key({ modkey }, "q", function(c) c:kill() end),
    awful.key({ modkey }, "f", function(c) c.fullscreen = not c.fullscreen; c:raise() end),
    awful.key({ modkey }, "v", function(c) c.floating = not c.floating end)
)
awful.rules.rules = {
    { rule = {}, properties = { border_width = beautiful.border_width, border_color = beautiful.border_normal,
        focus = awful.client.focus.filter, raise = true, keys = clientkeys,
        size_hints_honor = false, screen = awful.screen.preferred, placement = awful.placement.no_overlap + awful.placement.no_offscreen } },
    { rule_any = { type = { "dialog" }, class = { "Pavucontrol", "Nm-connection-editor", "Blueman-manager" } }, properties = { floating = true } },
}

client.connect_signal("manage", function(c)
    if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then awful.placement.no_offscreen(c) end
end)
client.connect_signal("mouse::enter", function(c) if awful.client.focus.filter(c) then client.focus = c end end)
client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
awful.spawn.with_shell("rice autostart")
