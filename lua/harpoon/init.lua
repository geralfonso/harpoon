local Log = require("harpoon.logger")
local Ui = require("harpoon.ui")
local Data = require("harpoon.data")
local Config = require("harpoon.config")
local List = require("harpoon.list")
local Extensions = require("harpoon.extensions")
local HarpoonGroup = require("harpoon.autocmd")

---@class Harpoon
---@field config HarpoonConfig
---@field ui HarpoonUI
---@field _extensions HarpoonExtensions
---@field data HarpoonData
---@field logger HarpoonLog
---@field lists {[string]: {[string]: HarpoonList}}
---@field hooks_setup boolean
local Harpoon = {}

Harpoon.__index = Harpoon

local the_primeagen_harpoon = vim.api.nvim_create_augroup(
    "THE_PRIMEAGEN_HARPOON",
    { clear = true }
)

vim.api.nvim_create_autocmd({ "BufLeave", "VimLeave" }, {
    callback = function()
        require("harpoon.mark").store_offset()
    end,
    group = the_primeagen_harpoon,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "harpoon",
    group = the_primeagen_harpoon,

    callback = function()
        -- Open harpoon file choice in useful ways
        --
        -- vertical split (control+v)
        vim.keymap.set("n", "<C-V>", function()
            local curline = vim.api.nvim_get_current_line()
            local working_directory = vim.fn.getcwd() .. "/"
            vim.cmd("vs")
            vim.cmd("e " .. working_directory .. curline)
        end, { buffer = true, noremap = true, silent = true })

        -- horizontal split (control+x)
        vim.keymap.set("n", "<C-x>", function()
            local curline = vim.api.nvim_get_current_line()
            local working_directory = vim.fn.getcwd() .. "/"
            vim.cmd("sp")
            vim.cmd("e " .. working_directory .. curline)
        end, { buffer = true, noremap = true, silent = true })

        -- new tab (control+t)
        vim.keymap.set("n", "<C-t>", function()
            local curline = vim.api.nvim_get_current_line()
            local working_directory = vim.fn.getcwd() .. "/"
            vim.cmd("tabnew")
            vim.cmd("e " .. working_directory .. curline)
        end, { buffer = true, noremap = true, silent = true })
    end,
})
--[[
{
    projects = {
        ["/path/to/director"] = {
            term = {
                cmds = {
                }
                ... is there anything that could be options?
            },
            mark = {
                marks = {
                }
                ... is there anything that could be options?
            }
        }
    },
    ... high level settings
}
--]]
HarpoonConfig = HarpoonConfig or {}

---@param name string?
---@return HarpoonList
function Harpoon:list(name)
    name = name or Config.DEFAULT_LIST

    local key = self.config.settings.key()
    local lists = self.lists[key]

    if not lists then
        lists = {}
        self.lists[key] = lists
    end

    local existing_list = lists[name]

    if existing_list then
        if not self.data.seen[key] then
            self.data.seen[key] = {}
        end
        self.data.seen[key][name] = true
        self._extensions:emit(Extensions.event_names.LIST_READ, existing_list)
        return existing_list
    end

    local data = self.data:data(key, name)
    local list_config = Config.get_config(self.config, name)

    local list = List.decode(list_config, name, data)
    self._extensions:emit(Extensions.event_names.LIST_CREATED, list)
    lists[name] = list

    return list
end

---@param cb fun(list: HarpoonList, config: HarpoonPartialConfigItem, name: string)
function Harpoon:_for_each_list(cb)
    local key = self.config.settings.key()
    local seen = self.data.seen[key]
    local lists = self.lists[key]

    if not seen then
        return
    end

    for list_name, _ in pairs(seen) do
        local list_config = Config.get_config(self.config, list_name)
        cb(lists[list_name], list_config, list_name)
    end
end

function Harpoon:sync()
    local key = self.config.settings.key()
    self:_for_each_list(function(list, _, list_name)
        if list.config.encode == false then
            return
        end

        local encoded = list:encode()
        self.data:update(key, list_name, encoded)
    end)
    self.data:sync()
end

local function expand_dir(config)
    log.trace("_expand_dir(): Config pre-expansion:", config)

    local projects = config.projects or {}
    for k in pairs(projects) do
        local expanded_path = Path.new(k):expand()
        projects[expanded_path] = projects[k]
        if expanded_path ~= k then
            projects[k] = nil
        end
    end

    log.trace("_expand_dir(): Config post-expansion:", config)
    return config
end

function M.save()
    -- first refresh from disk everything but our project
    M.refresh_projects_b4update()

    log.trace("save(): Saving cache config to", cache_config)
    Path:new(cache_config):write(vim.fn.json_encode(HarpoonConfig), "w")
end

local function read_config(local_config)
    log.trace("_read_config():", local_config)
    return vim.json.decode(Path:new(local_config):read())
end

-- 1. saved.  Where do we save?
function M.setup(config)
    log.trace("setup(): Setting up...")

    if not config then
        config = {}
    end

    local ok, u_config = pcall(read_config, user_config)

    if not ok then
        log.debug("setup(): No user config present at", user_config)
        u_config = {}
    end

    local ok2, c_config = pcall(read_config, cache_config)

    if not ok2 then
        log.debug("setup(): No cache config present at", cache_config)
        c_config = {}
    end

    local complete_config = merge_tables({
        projects = {},
        global_settings = {
            ["save_on_toggle"] = false,
            ["save_on_change"] = true,
            ["enter_on_sendcmd"] = false,
            ["tmux_autoclose_windows"] = false,
            ["excluded_filetypes"] = { "harpoon" },
            ["mark_branch"] = false,
            ["tabline"] = false,
            ["tabline_suffix"] = "   ",
            ["tabline_prefix"] = "   ",
        },
    }, expand_dir(c_config), expand_dir(u_config), expand_dir(config))

    -- There was this issue where the vim.loop.cwd() didn't have marks or term, but had
    -- an object for vim.loop.cwd()
    ensure_correct_config(complete_config)

    if complete_config.tabline then
        require("harpoon.tabline").setup(complete_config)
    end

    HarpoonConfig = complete_config

    log.debug("setup(): Complete config", HarpoonConfig)
    log.trace("setup(): log_key", Dev.get_log_key())
end

function M.get_global_settings()
    log.trace("get_global_settings()")
    return HarpoonConfig.global_settings
end

-- refresh all projects from disk, except our current one
function M.refresh_projects_b4update()
    log.trace(
        "refresh_projects_b4update(): refreshing other projects",
        cache_config
    )
    -- save current runtime version of our project config for merging back in later
    local cwd = mark_config_key()
    local current_p_config = {
        projects = {
            [cwd] = ensure_correct_config(HarpoonConfig).projects[cwd],
        },
    }
end

--- PLEASE DONT USE THIS OR YOU WILL BE FIRED
function Harpoon:dump()
    return self.data._data
end

---@param extension HarpoonExtension
function Harpoon:extend(extension)
    self._extensions:add_listener(extension)
end

function Harpoon:__debug_reset()
    require("plenary.reload").reload_module("harpoon")
end

local the_harpoon = Harpoon:new()

---@param self Harpoon
---@param partial_config HarpoonPartialConfig
---@return Harpoon
function Harpoon.setup(self, partial_config)
    if self ~= the_harpoon then
        ---@diagnostic disable-next-line: cast-local-type
        partial_config = self
        self = the_harpoon
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    self.config = Config.merge_config(partial_config, self.config)
    self.ui:configure(self.config.settings)
    self._extensions:emit(Extensions.event_names.SETUP_CALLED, self.config)

    ---TODO: should we go through every seen list and update its config?

    if self.hooks_setup == false then
        vim.api.nvim_create_autocmd({ "BufLeave", "VimLeavePre" }, {
            group = HarpoonGroup,
            pattern = "*",
            callback = function(ev)
                self:_for_each_list(function(list, config)
                    local fn = config[ev.event]
                    if fn ~= nil then
                        fn(ev, list)
                    end

                    if ev.event == "VimLeavePre" then
                        self:sync()
                    end
                end)
            end,
        })

        self.hooks_setup = true
    end

    return self
end

return the_harpoon
