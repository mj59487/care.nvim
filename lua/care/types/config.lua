--- Configuration for care.nvim
---@class care.config
--- Configuration for the ui of care
---@field ui care.config.ui
--- Function used to expand snippets
---@field snippet_expansion fun(string): nil
--- Behavior when selecting entry
---@field selection_behavior "select"|"insert"
--- Configuration for the different sources
---@field sources neocomplete.config.source[]
--- Pattern used to determine keywords
---@field keyword_pattern string
--- Configuration for the ui of care
---@field enabled fun(): boolean
--- The main class for the ui configuration of care.nvim

---@class care.config.ui
--- Configuration of the completion menu of care.nvim
---@field menu care.config.ui.menu
--- Configuration of the documentation view of care.nvim
---@field docs_view care.config.ui.docs
--- The icons for the different compltion item kinds
---@field type_icons care.config.ui.type_icons
--- Configuration of ghost text
---@field ghost_text care.config.ui.ghost_text

--- Configuration for the ghost text
---@class care.config.ui.ghost_text
---@field enabled boolean
---@field position "inline"|"overlay"

--- Configuration of the completion menu of care.nvim
---@class care.config.ui.menu
--- Maximum height of the menu
---@field max_height integer
--- The border of the completion menu
---@field border string|string[]|string[][]
--- Character used for the scrollbar
---@field scrollbar string?
--- Position of the menu
---@field position "auto"|"bottom"|"top"
--- How an entry should be formatted
---@field format_entry fun(entry: care.entry): { [1]: string, [2]: string }[][]
--- How the sections in the menu should be aligned
---@field alignment ("left"|"center"|"right")[]

---@class neocomplete.config.source
--- Whether the source is enabled (default true)
---@field enabled boolean|nil|fun():boolean
--- The maximum amount of entries which can be displayed by this source
---@field max_entries integer?
--- The priority of this source. Is more important than matching score
---@field priority integer?

--- Configuration of the completion menu of care.nvim
---@class care.config.ui.docs
--- Maximum height of the documentation view
---@field max_height integer
--- Maximum width of the documentation view
---@field max_width integer
--- The border of the documentation view
---@field border string|string[]|string[][]
--- Character used for the scrollbar
---@field scrollbar string

--- The icons used for the different completion item types
---@alias care.config.ui.type_icons table<string, string>
