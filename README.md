<div align="center">

# Harpoon
##### Getting you where you want with the fewest keystrokes.

[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.8+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)

<img alt="Harpoon Man" height="280" src="/assets/harpoon-icon.png" />
</div>

## ⇁ TOC
* [The Problems](#-The-Problems)
* [The Solutions](#-The-Solutions)
* [Installation](#-Installation)
* [Getting Started](#-Getting-Started)
* [API](#-API)
    * [Config](#config)
    * [Settings](#settings)
* [Contribution](#-Contribution)
* [Social](#-Social)
* [Note to legacy Harpoon 1 users](#-Note-to-legacy-Harpoon-1-users)

## ⇁ The Problems
1. You're working on a codebase. medium, large, tiny, whatever. You find
yourself frequenting a small set of files and you are tired of using a fuzzy finder,
`:bnext` & `:bprev` are getting too repetitive, alternate file doesn't quite cut it, etc etc.
1. You want to execute some project specific commands, have any number of
persistent terminals that can be easily navigated to, send commands to other
tmux windows, or dream up your own custom action and execute with a single key

## ⇁ The Solutions
1. Specify either by altering a ui or by adding via hot key files
1. Unlimited lists and items within the lists

## ⇁ Installation
* neovim 0.8.0+ required
* install using your favorite plugin manager (i am using `packer` in this case)
```lua
use "nvim-lua/plenary.nvim" -- don't forget to add this one if you don't have it yet!
use {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    requires = { {"nvim-lua/plenary.nvim"} }
}
```
* install using [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
:lua require("harpoon.ui").toggle_quick_menu()
```
you can go up and down the list, enter, delete or reorder. `q` and `<ESC>` exit and save the menu

you also can switch to any mark without bringing up the menu, use the below with the desired mark index
```lua
:lua require("harpoon.ui").nav_file(3)                  -- navigates to file 3
```
you can also cycle the list in both directions
```lua
:lua require("harpoon.ui").nav_next()                   -- navigates to next mark
:lua require("harpoon.ui").nav_prev()                   -- navigates to previous mark
```
from the quickmenu, open a file in: 
a vertical split with control+v,
a horizontal split with control+x, 
a new tab with control+t

### Terminal Navigation
this works like file navigation except that if there is no terminal at the specified index
a new terminal is created.
```lua
lua require("harpoon.term").gotoTerminal(1)             -- navigates to term 1
```

### Commands to Terminals
commands can be sent to any terminal
```lua
lua require("harpoon.term").sendCommand(1, "ls -La")    -- sends ls -La to tmux window 1
```
further more commands can be stored for later quick
```lua
lua require('harpoon.cmd-ui').toggle_quick_menu()       -- shows the commands menu
lua require("harpoon.term").sendCommand(1, 1)           -- sends command 1 to term 1
```

### Tmux Support
tmux is supported out of the box and can be used as a drop-in replacement to normal terminals
by simply switching `'term' with 'tmux'` like so

```lua
lua require("harpoon.tmux").gotoTerminal(1)             -- goes to the first tmux window
lua require("harpoon.tmux").sendCommand(1, "ls -La")    -- sends ls -La to tmux window 1
lua require("harpoon.tmux").sendCommand(1, 1)           -- sends command 1 to tmux window 1
```

`sendCommand` and `goToTerminal` also accept any valid [tmux pane identifier](https://man7.org/linux/man-pages/man1/tmux.1.html#COMMANDS).
```lua
lua require("harpoon.tmux").gotoTerminal("{down-of}")   -- focus the pane directly below
lua require("harpoon.tmux").sendCommand("%3", "ls")     -- send a command to the pane with id '%3'
```

Once you switch to a tmux window you can always switch back to neovim, this is a
little bash script that will switch to the window which is running neovim.

In your `tmux.conf` (or anywhere you have keybinds), add this
```bash
bind-key -r G run-shell "path-to-harpoon/harpoon/scripts/tmux/switch-back-to-nvim"
```

### Telescope Support
1st register harpoon as a telescope extension
```lua
require("telescope").load_extension('harpoon')
```
currently only marks are supported in telescope
```
:Telescope harpoon marks
```

## ⇁ Configuration
if configuring harpoon is desired it must be done through harpoons setup function
```lua
require("harpoon").setup({ ... })
```

### Global Settings
here are all the available global settings with their default values
```lua
global_settings = {
    -- sets the marks upon calling `toggle` on the ui, instead of require `:w`.
    save_on_toggle = false,

    -- saves the harpoon file upon every change. disabling is unrecommended.
    save_on_change = true,

    -- sets harpoon to run the command immediately as it's passed to the terminal when calling `sendCommand`.
    enter_on_sendcmd = false,

    -- closes any tmux windows harpoon that harpoon creates when you close Neovim.
    tmux_autoclose_windows = false,

    -- filetypes that you want to prevent from adding to the harpoon list menu.
    excluded_filetypes = { "harpoon" },

    -- set marks specific to each git branch inside git repository
    mark_branch = false,

    -- enable tabline with harpoon marks
    tabline = false,
    tabline_prefix = "   ",
    tabline_suffix = "   ",
}
```

## ⇁ Getting Started

### Quick Note
You will want to add your style of remaps and such to your neovim dotfiles with
the shortcuts you like.  My shortcuts are for me.  Me alone.  Which also means
they are designed with dvorak in mind (My layout btw, I use dvorak btw).

### harpoon:setup() IS REQUIRED
it is a requirement to call `harpoon:setup()`.  This is required due to
autocmds setup.

### Basic Setup
Here is my basic setup

```lua
local harpoon = require("harpoon")

-- REQUIRED
harpoon:setup()
-- REQUIRED

vim.keymap.set("n", "<leader>a", function() harpoon:list():append() end)
vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)

vim.keymap.set("n", "<C-h>", function() harpoon:list():select(1) end)
vim.keymap.set("n", "<C-t>", function() harpoon:list():select(2) end)
vim.keymap.set("n", "<C-n>", function() harpoon:list():select(3) end)
vim.keymap.set("n", "<C-s>", function() harpoon:list():select(4) end)

-- Toggle previous & next buffers stored within Harpoon list
vim.keymap.set("n", "<C-S-P>", function() harpoon:list():prev() end)
vim.keymap.set("n", "<C-S-N>", function() harpoon:list():next() end)
```

### Telescope

In order to use [Telescope](https://github.com/nvim-telescope/telescope.nvim) as a UI, 
make sure to add `telescope` to your dependencies and paste this following snippet into your configuration.

```lua
local harpoon = require('harpoon')
harpoon:setup({})

-- basic telescope configuration
local conf = require("telescope.config").values
local function toggle_telescope(harpoon_files)
    local file_paths = {}
    for _, item in ipairs(harpoon_files.items) do
        table.insert(file_paths, item.value)
    end

    require("telescope.pickers").new({}, {
        prompt_title = "Harpoon",
        finder = require("telescope.finders").new_table({
            results = file_paths,
        }),
        previewer = conf.file_previewer({}),
        sorter = conf.generic_sorter({}),
    }):find()
end

vim.keymap.set("n", "<C-e>", function() toggle_telescope(harpoon:list()) end,
    { desc = "Open harpoon window" })
```

## ⇁ API
You can define custom behavior of a harpoon list by providing your own calls.

Here is a simple example where i create a list named `cmd` that takes the
current line in the editor and adds it to harpoon menu.  When
`list:select(...)` is called, we take the contents of the line and execute it
as a vim command

I don't think this is a great use of harpoon, but its meant to show how to add
your own custom lists.  You could imagine that a terminal list would be just as
easy to create.

```lua
local harpoon = require("harpoon")

harpoon:setup({
    -- Setting up custom behavior for a list named "cmd"
    "cmd" = {

        -- When you call list:append() this function is called and the return
        -- value will be put in the list at the end.
        --
        -- which means same behavior for prepend except where in the list the
        -- return value is added
        --
        -- @param possible_value string only passed in when you alter the ui manual
        add = function(possible_value)
            -- get the current line idx
            local idx = vim.fn.line(".")

            -- read the current line
            local cmd = vim.api.nvim_buf_get_lines(0, idx - 1, idx, false)[1]
            if cmd == nil then
                return nil
            end

            return {
                value = cmd,
                context = { ... any data you want ... },
            }
        end,

        --- This function gets invoked with the options being passed in from
        --- list:select(index, <...options...>)
        --- @param list_item {value: any, context: any}
        --- @param list { ... }
        --- @param option any
        select = function(list_item, list, option)
            -- WOAH, IS THIS HTMX LEVEL XSS ATTACK??
            vim.cmd(list_item.value)
        end

    }
})

```

### Config
There is quite a bit of behavior you can configure via `harpoon:setup()`

* `settings`: is the global settings.  as of now there isn't a global setting in use, but once we have some custom behavior i'll put them here
* `default`: the default configuration for any list.  it is simply a file harpoon
* `[name] = HarpoonPartialConfigItem`: any named lists config.  it will be merged with `default` and override any behavior

**HarpoonPartialConfigItem Definition**
```
---@class HarpoonPartialConfigItem
---@field select_with_nil? boolean defaults to false
---@field encode? (fun(list_item: HarpoonListItem): string) | boolean
---@field decode? (fun(obj: string): any)
---@field display? (fun(list_item: HarpoonListItem): string)
---@field select? (fun(list_item?: HarpoonListItem, list: HarpoonList, options: any?): nil)
---@field equals? (fun(list_line_a: HarpoonListItem, list_line_b: HarpoonListItem): boolean)
---@field create_list_item? fun(config: HarpoonPartialConfigItem, item: any?): HarpoonListItem
---@field BufLeave? fun(evt: any, list: HarpoonList): nil
---@field VimLeavePre? fun(evt: any, list: HarpoonList): nil
---@field get_root_dir? fun(): string
```

**Detailed Definitions**
* `select_with_nil`: allows for a list to call select even if the provided item is nil
* `encode`: how to encode the list item to the harpoon file.  if encode is `false`, then the list will not be saved to disk (think terminals)
* `decode`: how to decode the list
* `display`: how to display the list item in the ui menu
* `select`: the action taken when selecting a list item. called from `list:select(idx, options)`
* `equals`: how to compare two list items for equality
* `create_list_item`: called when `list:append()` or `list:prepend()` is called.  called with an item, which will be a string, when adding through the ui menu
* `BufLeave`: this function is called for every list on BufLeave.  if you need custom behavior, this is the place
* `VimLeavePre`: this function is called for every list on VimLeavePre.
* `get_root_dir`: used for creating relative paths.  defaults to `vim.loop.cwd()`

### Settings
Settings can alter the experience of harpoon

**Definition**
```lua
---@class HarpoonSettings
---@field save_on_toggle boolean defaults to false
---@field sync_on_ui_close boolean defaults to false
---@field key (fun(): string)

```

**Descriptions**
* `save_on_toggle`: any time the ui menu is closed then we will save the state back to the backing list, not to the fs
* `sync_on_ui_close`: any time the ui menu is closed then the state of the list will be sync'd back to the fs
* `key` how the out list key is looked up.  This can be useful when using worktrees and using git remote instead of file path

**Defaults**
```lua
settings = {
    save_on_toggle = false,
    sync_on_ui_close = false,
    key = function()
        return vim.loop.cwd()
    end,
},
```

### Extend
The 'extend' functionality can be used to add keymaps for opening files in splits & tabs.

```lua
harpoon:extend({
  UI_CREATE = function(cx)
    vim.keymap.set("n", "<C-v>", function()
      harpoon.ui:select_menu_item({ vsplit = true })
    end, { buffer = cx.bufnr })

    vim.keymap.set("n", "<C-x>", function()
      harpoon.ui:select_menu_item({ split = true })
    end, { buffer = cx.bufnr })

    vim.keymap.set("n", "<C-t>", function()
      harpoon.ui:select_menu_item({ tabedit = true })
    end, { buffer = cx.bufnr })
  end,
})
```


#### Tabline

By default, the tabline will use the default theme of your theme.  You can customize by editing the following highlights:

* HarpoonInactive
* HarpoonActive
* HarpoonNumberActive
* HarpoonNumberInactive

Example to make it cleaner:

```lua
vim.cmd('highlight! HarpoonInactive guibg=NONE guifg=#63698c')
vim.cmd('highlight! HarpoonActive guibg=NONE guifg=white')
vim.cmd('highlight! HarpoonNumberActive guibg=NONE guifg=#7aa2f7')
vim.cmd('highlight! HarpoonNumberInactive guibg=NONE guifg=#7aa2f7')
vim.cmd('highlight! TabLineFill guibg=NONE guifg=white')
```

Result: 
![tabline](https://i.imgur.com/8i8mKJD.png) 

## ⇁ Social
For questions about Harpoon, there's a #harpoon channel on [the Primeagen's Discord](https://discord.gg/theprimeagen) server.
* [Discord](https://discord.gg/theprimeagen)
* [Twitch](https://www.twitch.tv/theprimeagen)
* [Twitter](https://twitter.com/ThePrimeagen)

## ⇁ Note to legacy Harpoon 1 users
Original Harpoon will remain in a frozen state and i will merge PRs in with _no
code review_ for those that wish to remain on that.  Harpoon 2 is significantly
better and allows for MUCH greater control.  Please migrate to that (will
become `master` within the next few months).
