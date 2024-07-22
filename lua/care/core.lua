---@type care.core
---@diagnostic disable-next-line: missing-fields
local core = {}

function core.new()
    ---@type care.core
    local self = setmetatable({}, { __index = core })
    self.context = require("care.context").new()
    self.menu = require("care.menu").new()
    self.blocked = false
    self.last_opened_at = -1
    return self
end

function core:complete(reason)
    reason = reason or 2
    local sources = require("care.sources").get_sources()
    local entries = {}
    local remaining = #sources
    self.context.reason = reason
    local offset = self.context.cursor.col
    for i, source in ipairs(sources) do
        if source.source.is_available() then
            require("care.sources").complete(self.context, source, function(items, is_incomplete)
                source.incomplete = is_incomplete or false
                source.entries = items
                require("care.sources").sources[i].incomplete = is_incomplete or false
                require("care.sources").sources[i].entries = items
                remaining = remaining - 1
                if not vim.tbl_isempty(items or {}) then
                    local source_offset = source:get_offset(self.context)
                    if source_offset then
                        offset = math.min(offset, source_offset)
                    end

                    vim.list_extend(entries, items)
                    vim.schedule(function()
                        if remaining == 0 then
                            local filtered_entries = vim.iter(entries)
                                :filter(function(entry)
                                    return not entry.score or entry.score > 0
                                end)
                                :totable()
                            -- TODO: source priority and max entries
                            local opened_at = offset
                            if opened_at == self.last_opened_at and self.menu:is_open() then
                                self.menu.entries = filtered_entries
                                self.menu:readjust_win(offset)
                            else
                                self.menu:open(filtered_entries, offset)
                            end
                            self.last_opened_at = opened_at
                        end
                    end)
                end
            end)
        else
            remaining = remaining - 1
        end
    end
end

function core.setup(self)
    vim.api.nvim_create_autocmd("TextChangedI", {
        callback = function()
            self:on_change()
        end,
        group = "care",
    })
end

function core:block()
    self.blocked = true
    return vim.schedule_wrap(function()
        self.blocked = false
    end)
end

function core.on_change(self)
    if self.blocked then
        return
    end
    self.context = require("care.context").new(self.context)
    if not require("care.config").options.enabled() then
        return
    end
    if not self.context:changed() then
        return
    end
    self:complete(1)
end

return core