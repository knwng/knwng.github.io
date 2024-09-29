---
title: 'Make Your Win Behave Like Mac: Use Mac Magic TracePad and HHKB on a ThinkPad'
tags:
  - mac
  - ease-of-use
categories:
  - tech
date: 2024-09-29 15:41:26
---


Recently, for some reason(sadly), I have to use ThinkPad and Windows for work. It has been a long time since my last time using a Windows laptop. But with some plugins and key remapping, I managed to imitate a mac-like experience on Windows.

# Use Mac Magic TracePad on Windows
## mac-precision-touchpad
[mac-precision-touchpad](https://github.com/imbushuo/mac-precision-touchpad) is a great plugin to use tracepad on windows.

You can easily install it by following the instruction on Github and no further configuration is needed.

## Change Touchpad Gestures
Although we can use TracePad now, the gestures on Windows are still slightly different from macos.

To change that, we can go to `Settings->Bluetooth & devices->Touchpad`, then you can change the gestures to fit your habit.

For example, we typically use three-fingers-swipes to switch between desktops. So we can go to `Gestures & interaction->Three-finger gestures->Swipes` and change the behavior to `Switch desktops and show desktop`.

# Spotlight Alternative
I'm an avid user of spotlight. I'm using it not only as an app launcher, but also as a visualized clipboard.

Fortunately, Microsoft has an open-sourced project called [PowerToys](https://github.com/microsoft/PowerToys) which has many useful tools, including PowerToys Run a spotlight alternative.

Again, you can easily install it from Github. Then you can use `Alt + Space` to bring up PowerToys Run.

There are other useful tools you can explore on your own.

# Keyboard Remapping
There are many differences between thinkpad keyboard, macbook keyboard and HHKB, so keyboard remapping is essential to imitate macbook on thinkpad.

Many softwares can do this, like [SharpKeys](https://github.com/randyrants/sharpkeys), [AutoHotkey](https://www.autohotkey.com/), [PowerToys Keyboard Manager utility for Windows](https://learn.microsoft.com/en-us/windows/powertoys/keyboard-manager), etc.

I have two keyboards, HHKB and thinkpad's builtin keyboard, so I personally chose AutoHotkey, but first, let's go though these options to see the difference.

## SharpKeys
- pro
  - GUI interface, easy to use
  - Multiple profiles
- con
  - Don't support hot reload, which means you need to logout/restart the system to make the change effective
  - Can only remap keystrokes, but can't remap hotkeys/shortcuts(a combination of keystrokes)

## PowerToys Keyboard Manager
- pro
  - GUI interface, easy to use
  - Can remap both keystrokes and hotkeys
- con
  - Don't support multiple profiles for different keyboards

## AutoHotkey
- pro
  - Richer syntax to support complex tasks
  - hot reload without logout/restart the system
  - Multiple profiles
- con
  - No GUI, need to write scripts

### Tutorials and Documentations
Since AutoHotkey uses scripts, you need to first learn the syntax.

Fortunately, AutoHotkey provides comprehensive tutorials and documentations, like, [Beginner Tutorial | AutoHotkey v2](https://www.autohotkey.com/docs/v2/Tutorial.htm), [How to Write Hotkeys | AutoHotkey v2](https://www.autohotkey.com/docs/v2/howto/WriteHotkeys.htm), etc.

I will also post the scripts I'm using for reference.

### Remapping Script for ThinkPad Builtin Keyboard
```ahk
#Requires AutoHotkey v2.0

LAlt::LCtrl
LCtrl::LAlt
```

Updated version: [Thinkpad Keyboard Mapping](https://gist.github.com/knwng/9619494c29ae00334270fc87b923e35b)

### Remapping Script for HHKB Builtin Keyboard
```ahk
#Requires AutoHotkey v2.0

; Switch between tabs
; Ctrl + Alt + L/R => Ctrl + PgDn/PgUp
^!Right::Send '^{PgDn}'
^!Left::Send '^{PgUp}'

; Jump a word
; Alt + L/R => Ctrl + L/R
!Left::Send '^{Left}'
!Right::Send '^{Right}'

; Delete a word
; Alt + Backspace => Ctrl + Backspace
!Backspace::Send '^{Backspace}'

; Switch between virtual desktops
; Ctrl + L/R => Win + Ctrl + L/R
^Left::Send '#^{Left}'
^Right::Send '#^{Right}'

; CMD/Win => Ctrl
LWin::LCtrl
```

Updated version: [HHKB keyboard mapping using AutoHotKey](https://gist.github.com/knwng/b98b72232e98950eb0f9ef293b4ca55f)

### Compile Scripts to Executables
After writing the scripts, you need to use AutoHotkey to compile it into executable. Then you can apply the remapping by run the executable without logout/restart.

# Terminal and Shell
## WSL
WSL becomes pretty mature on Windows 11. You can just setup according to the doc: [Install WSL | Microsoft Learn](https://learn.microsoft.com/en-us/windows/wsl/install).

## WezTerm
Regarding the terminal, I'm using [WezTerm](https://wezfurlong.org/wezterm/index.html), a cross-platform terminal so that I can have similar experience on ThinkPad and Macbook.

We need to apply some configurations to make it easier for use. To do so, you need to create a config file located at `C:\Users\<username>\.wezterm.lua`(in WSL, it's `/mnt/c/Users/<username>/.wezterm.lua`).

Here's my configuration:
```lua
local wezterm = require 'wezterm'
local act = wezterm.action

local config = {}
if wezterm.config_builder then
  config = wezterm.config_builder()
end

config.color_scheme = 'AdventureTime'

local dimmer = { brightness = 0.1 }

config.term = "xterm-256color"
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"

-- scroll bar
config.enable_scroll_bar = true
config.min_scroll_bar_height = "3cell"
config.colors = {
    scrollbar_thumb = "#CCCCCC",
}

-- tab bar
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = true
config.tab_max_width = 25
config.show_tab_index_in_tab_bar = true
config.switch_to_last_active_tab_when_closing_tab = true

-- cursor
config.default_cursor_style = "BlinkingBlock"
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"
config.cursor_blink_rate = 700

-- window
config.window_close_confirmation = "NeverPrompt"
config.window_padding = { left = 0, right = 15, top = 0, bottom = 0 }


-- change config now
config.default_domain = 'WSL:Ubuntu'

config.keys = {
  -- paste from the clipboard
  { key = 'V', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },

  -- paste from the primary selection
  { key = 'V', mods = 'CTRL', action = act.PasteFrom 'PrimarySelection' },

  -- close current tab with Ctrl + w
  {
    key = 'w',
    mods = 'CTRL',
    action = act.CloseCurrentTab { confirm = false },
  },

  -- create new tab with Ctrl + t
  {
    key = 't',
    mods = 'CTRL',
    action = act.SpawnTab 'CurrentPaneDomain',
  },

  -- split current tab into 2 panes horizontally with Ctrl + Shift + Alt + %
  {
    key = '%',
    mods = 'CTRL|SHIFT|ALT',
    action = act.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },

  -- split current tab into 2 panes vertically with Ctrl + Shift + Alt + "
  {
    key = '"',
    mods = 'CTRL|SHIFT|ALT',
    action = act.SplitVertical { domain = 'CurrentPaneDomain' },
  },

  -- navigate between tabs
  { key = '[', mods = 'CTRL', action = act.ActivateTabRelative(-1) },
  { key = ']', mods = 'CTRL', action = act.ActivateTabRelative(1) },

  -- change font size
  { key = '+', mods = 'SHIFT|CTRL', action = act.IncreaseFontSize },
  { key = '_', mods = 'SHIFT|CTRL', action = act.DecreaseFontSize },
}

return config
```

You can get the updated configuration from here: [My Wez Term config for windows](https://gist.github.com/knwng/4e8f58f15cf9f383547d12fb3f178d0e).

## Zsh && oh-my-zsh
I use zsh and oh-my-zsh shell. There are also some useful shortcuts to ease your life.

You can put these lines into your `~/.zshrc`:
```bash
# jump a word forward/backward with Alt + <-/->
bindkey "^[[1;3C" forward-word
bindkey "^[[1;3D" backward-word

# delete a word with Alt + Backspace
bindkey "^H" backward-kill-word
```

Don't forget to `source ~/.zshrc` to activate.

# Multiple Desktops
The multi-desktop in macos is extremely convenient. There is also multi-desktop feature on recent Windows distribution(I'm using Win 11, not sure if it exists in Win 10 or prior.), but the behavior is quite different.

There are two things I'm the most uncomfortable with when I'm using multi-desktop on Windows, but I still have to work them around.

## No singleton instance
One is that it can't keep a singleton instance of application in all the desktops.

For example, on MacOS, if you click a link on other desktop, it will jump to the desktop containing web browser to open it, instead of create a new browser. But on Windows, it will create a new web browser on current desktop to open the link. So now you have 2 browsers, which makes it fragmental.

## Multi-desktop + multiple monitors
The other thing is, when you are using multi-desktop on multiple monitors(let's say monitor A, B, C) and you want to switch to another desktop on monitor A, the desktops on monitor B and C will be switched jointly! Surprise!

Let's revise what will happen on MacOS. If you switch the desktop on one monitor, you switch the desktop only on that monitor and others remains unchanged.

I don't know why it's designed like that. A possible explanation can be someone needs different combinations of desktops to work on different tasks. For example, they have 1 combination of vscode + terminal + browser, another is movie player + note + music player and they never ever need to use browser + movie player at the same time. Maybe? I don't know.

But what I know is, if you want to only change the desktop on 1 monitor and keep others unchanged, you have to mark the other applications `Show this window on all desktops`. You can find this option by `Win + Tab` to bring up desktop manager and right-click on the application.

It's kind of ugly, personally, but we have to get used to it. If you have better solution, please let me know.

# Other Useful Shortcuts
1. Lock the screen: `Win + L`
2. Regional screenshot(like `CMD + SHIFT + 4` on MacOS): `Win + SHIFT + S`
3. Full-screen screenshot(like `CMD + SHIFT + 3` on MacOS): `Win + PrintScreen`
4. Copy/Paste on WSL: `CTRL + SHIFT + C/V`
5. Emoji list(like `CMD + CTRL + Space`): `Win + .(period)`
6. Switch between virtual desktops: `Win + CTRL + <-/->`

# In the end
Hopefully I will keep updating this post as I keep optimizing the workflow and exploring new tools. Someone suggested we shouldn't expect same experience on MacOS and Windows, instead, we need to get used to having different workflows. But I still want to know how far it can go.
