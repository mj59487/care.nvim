---@type care.window
---@diagnostic disable-next-line: missing-fields
local Window = {}

function Window.new(config)
    ---@type care.window
    local self = setmetatable({}, { __index = Window })
    self.winnr = nil
    self.config = require("care.config").options
    self.ns = vim.api.nvim_create_namespace("care_window")
    self.buf = vim.api.nvim_create_buf(false, true)
    self.position = nil
    self.opened_at = {}
    self.scrollbar = {}
    self.scrollbar.win = nil
    self.max_height = nil
    self.current_scroll = 1
    self.scrollbar_config = config.scrollbar
    self.scrollbar.buf = vim.api.nvim_create_buf(false, true)
    return self
end

function Window:open_cursor_relative(width, wanted_height, offset, config)
    if self:is_open() then
        self:close()
    end

    local border_space = (config.border and config.border ~= "none" and 2 or 0)
    local needed_height = wanted_height + border_space

    local cursor = vim.api.nvim_win_get_cursor(0)
    local screenpos = vim.fn.screenpos(0, cursor[1], cursor[2] + 1)

    local row = screenpos.row
    local col = offset

    if screenpos.row ~= cursor[1] then
        -- on a wrapped line
        local delta = cursor[2]
            - offset
            + vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].wincol
            + vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].textoff
            - 1

        col = screenpos.col - delta
    end

    local space_below = vim.o.lines - screenpos.row - vim.o.cmdheight - 1
    local space_above = screenpos.row - 1

    local needed_space = math.min(needed_height, config.max_height)
    local position = "below"
    local config_pos = config.position
    local height
    if config_pos == "auto" then
        if space_below < needed_space then
            position = "above"
            if space_above < needed_space then
                position = space_above > space_below and "above" or "below"
            end
        end
        height = math.min(wanted_height, (position == "below" and space_below or space_above) - border_space)
    elseif config_pos == "below" then
        position = "below"
        height = math.min(wanted_height, space_below - border_space)
    elseif config_pos == "above" then
        position = "above"
        height = math.min(wanted_height, space_above - border_space)
    end
    height = math.min(height, config.max_height - border_space)
    self.max_height = position == "below" and space_below or space_above
    self.max_height = math.min(self.max_height, config.max_height)
    self.position = position

    local columns_left = vim.o.columns - col

    if columns_left < width then
        col = vim.o.columns - width - 2
    end

    self.opened_at = {
        row = row,
        col = col,
    }

    self.winnr = vim.api.nvim_open_win(self.buf, false, {
        relative = "editor",
        height = height,
        width = width,
        anchor = position == "below" and "NW" or "SW",
        style = "minimal",
        border = config.border,
        row = row - (position == "below" and 0 or 1),
        col = col,
        zindex = 1000,
    })
    vim.wo[self.winnr][0].showbreak = ""
    vim.wo[self.winnr][0].scrolloff = 0
    vim.wo[self.winnr][0].smoothscroll = true
    vim.wo[self.winnr][0].winhighlight = "Normal:@care.menu,FloatBorder:@care.border"
    vim.wo[self.winnr][0].breakindent = false
    self:open_scrollbar_win(width, height, offset)
end

function Window:readjust(content_len, width, offset)
    local win_data = self:get_data()

    if not content_len then
        self:close()
        return
    end
    if not self.winnr or not vim.api.nvim_win_is_valid(self.winnr) then
        self:close()
        return
    end
    if width ~= win_data.width_without_border then
        vim.api.nvim_win_set_width(self.winnr, width)
    end
    if content_len ~= win_data.height_without_border then
        vim.api.nvim_win_set_height(
            self.winnr,
            math.min(self.max_height - (win_data.has_border and 2 or 0), content_len)
        )
    end
    self:open_scrollbar_win(width, math.min(win_data.height_without_border, content_len), offset)
end

function Window:scroll(delta)
    self.current_scroll = self.current_scroll + delta
    local win_data = self:get_data()
    self.current_scroll = math.max(self.current_scroll, 1)
    self.current_scroll = math.min(self.current_scroll, win_data.total_lines - win_data.height_without_border + 1)

    vim.api.nvim_win_call(self.winnr, function()
        vim.cmd("normal! gg0")
        if self.current_scroll > 1 then
            vim.cmd("normal! " .. vim.keycode(string.rep("<c-e>", (self.current_scroll - 1))))
        end
    end)
end

function Window:set_scroll(index, direction, reversed)
    if self:scrollbar_is_open() then
        vim.api.nvim_win_set_config(self.scrollbar.win, { hide = true })
    end

    local win_data = self:get_data()

    --- Scrolls to a certain line in the window
    --- This line will be at the top of the window
    ---@param line integer
    local function scroll_to_line(line)
        vim.api.nvim_win_call(self.winnr, function()
            vim.fn.winrestview({ topline = line, lnum = line })
        end)
        self.current_scroll = line
    end
    local selected_line = index
    if selected_line == 0 then
        if reversed then
            scroll_to_line(win_data.total_lines - win_data.height_without_border + 1)
        else
            scroll_to_line(1)
        end
    elseif selected_line >= win_data.first_visible_line and selected_line <= win_data.last_visible_line then
        return
    elseif direction == 1 and selected_line > win_data.last_visible_line then
        scroll_to_line(selected_line - win_data.height_without_border + 1)
    elseif direction == -1 and selected_line < win_data.first_visible_line then
        scroll_to_line(selected_line)
    elseif direction == 1 and selected_line < win_data.first_visible_line then
        scroll_to_line(selected_line)
    elseif direction == -1 and selected_line > win_data.last_visible_line then
        -- wrap around
        scroll_to_line(selected_line - win_data.height_without_border + 1)
    end
end

function Window:get_data()
    local data = {}
    data.first_visible_line = vim.fn.line("w0", self.winnr)
    data.last_visible_line = vim.fn.line("w$", self.winnr)
    data.visible_lines = data.last_visible_line - data.first_visible_line + 1
    data.height_without_border = vim.api.nvim_win_get_height(self.winnr)
    data.width_without_border = vim.api.nvim_win_get_width(self.winnr)
    data.border = vim.api.nvim_win_get_config(self.winnr).border
    data.has_border = data.border and data.border ~= "none"
    data.width_with_border = data.width_without_border + (data.has_border and 2 or 0)
    data.height_with_border = data.height_without_border + (data.has_border and 2 or 0)
    data.total_lines = vim.api.nvim_win_text_height(self.winnr, {}).all
    return data
end

function Window:close()
    pcall(vim.api.nvim_win_close, self.winnr, true)
    self.winnr = nil
    pcall(vim.api.nvim_win_close, self.scrollbar.win, true)
    self.scrollbar.win = nil
    self.current_scroll = 1
    self.opened_at = {}
    self.max_height = nil
    self.position = nil
end

function Window:open_scrollbar_win(width, height)
    if self.scrollbar.win then
        pcall(vim.api.nvim_win_close, self.scrollbar.win, true)
        self.scrollbar.win = nil
    end
    local menu_pos = vim.api.nvim_win_get_position(self.winnr)
    if self.scrollbar_config.enabled then
        self.scrollbar.win = vim.api.nvim_open_win(self.scrollbar.buf, false, {
            height = height,
            relative = "cursor",
            col = self.opened_at.col + width,
            row = menu_pos[1],
            width = 1,
            style = "minimal",
            border = "none",
            hide = true,
            zindex = 2000,
        })
    end
end

function Window:draw_scrollbar()
    if not self:scrollbar_is_open() then
        return
    end
    vim.api.nvim_win_set_config(self.scrollbar.win, { hide = true })
    vim.api.nvim_buf_clear_namespace(self.scrollbar.buf, self.ns, 0, -1)

    local win_data = self:get_data()

    if win_data.height_without_border >= win_data.total_lines then
        vim.api.nvim_win_set_config(self.scrollbar.win, { hide = true })
        return
    end

    local scrollbar_height =
        math.floor(win_data.height_without_border * win_data.height_without_border / win_data.total_lines + 0.5)
    scrollbar_height = math.max(1, scrollbar_height)

    local scrolled_ratio = (win_data.first_visible_line - 1) / (win_data.total_lines - win_data.height_without_border)
    local scrollbar_offset = math.floor(scrolled_ratio * (win_data.height_without_border - scrollbar_height) + 0.5)

    vim.api.nvim_buf_set_lines(self.scrollbar.buf, 0, -1, false, vim.split(string.rep(" ", scrollbar_height), ""))

    for i = 1, scrollbar_height do
        vim.api.nvim_buf_set_extmark(self.scrollbar.buf, self.ns, i - 1, 0, {
            virt_text = { { self.scrollbar_config.character, "@care.scrollbar.thumb" } },
            virt_text_pos = "overlay",
        })
    end

    local menu_pos_NE = {
        self.opened_at.row
            - (self.position == "below" and 0 or 1)
            - (self.position == "above" and win_data.height_with_border or 0),
        self.opened_at.col + win_data.width_with_border - 2,
    }

    vim.api.nvim_win_set_config(self.scrollbar.win, {
        relative = "editor",
        width = 1,
        height = scrollbar_height,
        row = menu_pos_NE[1] + scrollbar_offset + (win_data.has_border and 1 or 0),
        col = menu_pos_NE[2] + self.scrollbar_config.offset + 1,
        hide = false,
    })
end

function Window:is_open()
    return self.winnr ~= nil and vim.api.nvim_win_is_valid(self.winnr)
end

function Window:scrollbar_is_open()
    return self.scrollbar.win ~= nil
end

return Window
