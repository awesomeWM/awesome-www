--[[

        Licensed under GNU General Public License v2
        * (c) 2021, bzgec


# Wireless status widget/watcher

Get wireless Quality link (converted to percentages) and wireless status.

Data is taken from `/proc/net/wireless`.

According to [this](https://www.hpl.hp.com/personal/Jean_Tourrilhes/Linux/Linux.Wireless.Extensions.html)
website `/proc/net/wireless` has the following information:

- Status: Its current state. This is a device dependent information.

- Quality - link: general quality of the reception.

- Quality - level: signal strength at the receiver.

- Quality - noise: silence level (no packet) at the receiver.

- Discarded - nwid: number of discarded packets due to invalid network id.

- Discarded - crypt: number of packet unable to decrypt.

- Discarded - misc: unused (for now).

This widget uses `Quality - link` and converts it to percentages (`perc=Quality_link*10/7`).
The above equation is taken from [this](https://superuser.com/a/1360447) forum answer.

It also stores `Status` information (note that this is presumably device dependent).

## Requirements

- `iw`

## Usage

- Download [wirelessStatus.lua](https://awesomewm.org/recipes/wirelessStatus.lua) file and put it
  into awesome's folder (like `~/.config/awesome/widgets/wirelessStatus.lua`)

- Add widget to `theme.lua`:

```lua
local widgets = {
    wirelessStatus = require("widgets/wirelessStatus"),
}
-- Wireless status widget (`status` is presumably device dependent)
theme.wirelessStatus = widgets.wirelessStatus({
    notification_preset = { font = "Mononoki Nerd Font 10", fg = theme.fg_normal },
    timeout = 10,
    settings = function(self)
        if self.status == "1" or self.status == "" then
            self.widget:set_image(theme.wifidisc)
        else
            if self.perc <= 5 then
                self.widget:set_image(theme.wifinone)
            elseif self.perc <= 25 then
                self.widget:set_image(theme.wifilow)
            elseif self.perc <= 50 then
                self.widget:set_image(theme.wifimed)
            elseif self.perc <= 75 then
                self.widget:set_image(theme.wifihigh)
            else
                self.widget:set_image(theme.wififull)
            end
        end
    end,
})
local widget_wirelessStatus = wibox.widget { nil, theme.wirelessStatus.widget, layout = wibox.layout.align.horizontal }
```

- Set which application to run on widget press (add to `rc.lua`):

```lua
-- wirelessStatus widget pressed function - open terminal and start `nmtui`
beautiful.wirelessStatus.pressed = function(self, button)
    if button == 1 then  -- left mouse click
        awful.spawn(terminal.." -e nmtui")
    end
end
```

--]]


local wibox    = require("wibox")
local naughty  = require("naughty")
local awful    = require("awful")
local gears    = require("gears")

local function factory(args)
    local args     = args or {}

    local wirelessStatus = {
        widget    = args.widget or wibox.widget.imagebox(),
        settings  = args.settings or function(self) end,
        timeout   = args.timeout or 10,
        pressed   = args.pressed or function(self, button) end,
        followtag = args.followtag or false,
        notification_preset = args.notification_preset or {},
        showpopup = args.showpopup or "on",  -- Show notification popup while hovering above widget
        timer     = gears.timer,
        interface = "",
        perc      = 0,
        status    = "",
        notification_text = "No connection",
    }

    -- Reset to default values
    function wirelessStatus:reset()
        wirelessStatus.interface = ""
        wirelessStatus.perc = 0
        wirelessStatus.status = ""
        wirelessStatus.notification_text = "No connection"
    end

    -- Show notification popup
    function wirelessStatus:show(seconds)
        self:hide()

        -- Update every time
        self:update()

        if self.followtag then
            self.notification_preset.screen = focused()
        end

        self.notification = naughty.notify {
            preset  = self.notification_preset,
            text    = self.notification_text,
            timeout = type(seconds) == "number" and seconds or self.notification_preset.timeout
        }
    end

    -- Hide notification popup
    function wirelessStatus:hide()
        if self.notification then
            naughty.destroy(self.notification)
            self.notification = nil
        end
    end

    function wirelessStatus:attach()
        self.widget:connect_signal("mouse::enter", function()
            self:show(0)
        end)
        self.widget:connect_signal("mouse::leave", function()
            self:hide()
        end)
    end

    -- Get name of wireless interface
    function wirelessStatus:getInterface()
        awful.spawn.easy_async_with_shell(
            "awk 'NR==3 {printf(\"%s\\n\", $1)}' /proc/net/wireless",
            function(stdout, exitcode)
                -- Store interface name
                -- Remove last character/s from string ("wlp4s0:"" -> "wlp4s0")
                self.interface = stdout:sub(0, -3)

                -- Check in case interface is now equal to "" (we don't want to cause recursive
                -- calls)
                if self.interface ~= "" then
                    self:update()
                end
            end
        )
    end

    function wirelessStatus:update()
        self.timer:emit_signal("timeout")
    end

    -- Get status and Quality link (convert quality link to percentages)
    wirelessStatus, wirelessStatus.timer = awful.widget.watch(
        { 'awk', 'NR==3 {printf("%d-%.0f\\n", $2, $3*10/7)}', '/proc/net/wireless' },
        wirelessStatus.timeout,
        function(self, stdout, stderr, exitreason, exitcode)
            if stdout == "" then
                -- No output from command above -> reset internal values to default
                self:reset()
            else
                -- Status and Quality link received
                local status, perc = stdout:match("(%d)-(%d+)")
                perc = tonumber(perc)
                self.perc = perc
                self.status = status

                if self.interface == "" then
                    -- Get interface name
                    self:getInterface()
                else
                    -- Get information about active connection
                    local cmd_getInfo = "iw dev "..self.interface.." link"
                    awful.spawn.easy_async_with_shell(cmd_getInfo, function(stdout, exitcode)
                        self.notification_text = stdout
                    end)
                end
            end

            -- Call user/theme defined function
            self:settings()
        end,
        wirelessStatus  -- base_widget (passed in callback function as first parameter)
    )

    -- Show notification popup while hovering above widget
    if wirelessStatus.showpopup == "on" then wirelessStatus:attach(wirelessStatus.widget) end

    wirelessStatus.widget:connect_signal("button::press", function(c, _, _, button)
        wirelessStatus:pressed(button)
    end)

    return wirelessStatus
end

return factory
