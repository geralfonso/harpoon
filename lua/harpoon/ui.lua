local Buffer = require("harpoon.buffer")
local Logger = require("harpoon.logger")
local Extensions = require("harpoon.extensions")

---@class HarpoonToggleOptions
---@field border? any this value is directly passed to nvim_open_win
---@field title_pos? any this value is directly passed to nvim_open_win
---@field title? string this value is directly passed to nvim_open_win
---@field ui_fallback_width? number used if we can't get the current window
---@field ui_width_ratio? number this is the ratio of the editor window to use
---@field ui_max_width? number this is the max width the window can be

---@return HarpoonToggleOptions
local function toggle_config(config)
    return vim.tbl_extend("force", {
        ui_fallback_width = 69,
        ui_width_ratio = 0.62569,
    }, config or {})
end

---@class HarpoonUI
---@field win_id number
---@field bufnr number
---@field settings HarpoonSettings
---@field active_list HarpoonList
local HarpoonUI = {}

---@param list HarpoonList
---@return string
local function list_name(list)
    return list and list.name or "nil"
end

HarpoonUI.__index = HarpoonUI

---@param settings HarpoonSettings
---@return HarpoonUI
function HarpoonUI:new(settings)
    return setmetatable({
        win_id = nil,
        bufnr = nil,
        active_list = nil,
        settings = settings,
    }, self)
end

function HarpoonUI:close_menu()
    if self.closing then
        return
    end

    local curr_file = utils.normalize_path(vim.api.nvim_buf_get_name(0))
    vim.cmd(
        string.format(
            "autocmd Filetype harpoon "
                .. "let path = '%s' | call clearmatches() | "
                -- move the cursor to the line containing the current filename
                .. "call search('\\V'.path.'\\$') | "
                -- add a hl group to that line
                .. "call matchadd('HarpoonCurrentFile', '\\V'.path.'\\$')",
            curr_file:gsub("\\", "\\\\")
        )
    )

    local win_info = create_window()
    local contents = {}
    local global_config = harpoon.get_global_settings()

    if self.bufnr ~= nil and vim.api.nvim_buf_is_valid(self.bufnr) then
        vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end

    if self.win_id ~= nil and vim.api.nvim_win_is_valid(self.win_id) then
        vim.api.nvim_win_close(self.win_id, true)
    end

    self.active_list = nil
    self.win_id = nil
    self.bufnr = nil

    self.closing = false
end

--- TODO: Toggle_opts should be where we get extra style and border options
--- and we should create a nice minimum window
---@param toggle_opts HarpoonToggleOptions
---@return number,number
function HarpoonUI:_create_window(toggle_opts)
    local win = vim.api.nvim_list_uis()

    local width = toggle_opts.ui_fallback_width

    if #win > 0 then
        -- no ackshual reason for 0.62569, just looks complicated, and i want
        -- to make my boss think i am smart
        width = math.floor(win[1].width * toggle_opts.ui_width_ratio)
    end

    if toggle_opts.ui_max_width and width > toggle_opts.ui_max_width then
        width = toggle_opts.ui_max_width
    end

    local mark = Marked.get_marked_file(idx)
    local filename = vim.fs.normalize(mark.filename)
    local buf_id = get_or_create_buffer(filename)
    local set_row = not vim.api.nvim_buf_is_loaded(buf_id)

    vim.api.nvim_set_current_buf(buf_id)
    vim.api.nvim_buf_set_option(buf_id, "buflisted", true)
    if set_row and mark.row and mark.col then
        vim.cmd(string.format(":call cursor(%d, %d)", mark.row, mark.col))
        log.debug(
            string.format(
                "nav_file(): Setting cursor to row: %d, col: %d",
                mark.row,
                mark.col
            )
        )
    end
end

function M.location_window(options)
    local default_options = {
        relative = "editor",
        title = toggle_opts.title or "Harpoon",
        title_pos = toggle_opts.title_pos or "left",
        row = math.floor(((vim.o.lines - height) / 2) - 1),
        col = math.floor((vim.o.columns - width) / 2),
        width = width,
        height = height,
        style = "minimal",
        border = toggle_opts.border or "single",
    })

    if win_id == 0 then
        Logger:log(
            "ui#_create_window failed to create window, win_id returned 0"
        )
        self.bufnr = bufnr
        self:close_menu()
        error("Failed to create window")
    end

    Buffer.setup_autocmds_and_keymaps(bufnr)

    self.win_id = win_id
    vim.api.nvim_set_option_value("number", true, {
        win = win_id,
    })

    return win_id, bufnr
end

---@param list? HarpoonList
---TODO: @param opts? HarpoonToggleOptions
function HarpoonUI:toggle_quick_menu(list, opts)
    opts = toggle_config(opts)
    if list == nil or self.win_id ~= nil then
        Logger:log("ui#toggle_quick_menu#closing", list and list.name)
        if self.settings.save_on_toggle then
            self:save()
        end
        self:close_menu()
        return
    end

    -- grab the current file before opening the quick menu
    local current_file = vim.api.nvim_buf_get_name(0)

    Logger:log("ui#toggle_quick_menu#opening", list and list.name)
    local win_id, bufnr = self:_create_window(opts)

    self.win_id = win_id
    self.bufnr = bufnr
    self.active_list = list

    local contents = self.active_list:display()
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, contents)

    Extensions.extensions:emit(Extensions.event_names.UI_CREATE, {
        win_id = win_id,
        bufnr = bufnr,
        current_file = current_file,
    })
end

---@param options? any
function HarpoonUI:select_menu_item(options)
    local idx = vim.fn.line(".")

    -- must first save any updates potentially made to the list before
    -- navigating
    local list = Buffer.get_contents(self.bufnr)
    self.active_list:resolve_displayed(list)

    Logger:log(
        "ui#select_menu_item selecting item",
        idx,
        "from",
        list,
        "options",
        options
    )

    list = self.active_list
    self:close_menu()
    list:select(idx, options)
end

function HarpoonUI:save()
    local list = Buffer.get_contents(self.bufnr)
    Logger:log("ui#save", list)
    self.active_list:resolve_displayed(list)
    if self.settings.sync_on_ui_close then
        require("harpoon"):sync()
    end
end

---@param settings HarpoonSettings
function HarpoonUI:configure(settings)
    self.settings = settings
end

return HarpoonUI
