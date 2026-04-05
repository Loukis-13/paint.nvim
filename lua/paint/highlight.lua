local M = {}

-- Cache of already-created highlight group names
local _cache = {}

--- Normalize a color value to a cache key segment.
--- @param c string
--- @return string
local function color_key(c)
  return c:gsub("^#", ""):upper()
end

--- Return the hex string for a color.
--- @param c string
--- @return string
local function to_hex(c)
  return c:gsub("^#?", "#"):upper()
end

--- Lazily create and return a highlight group name for the given fg/bg pair.
--- @param fg string  "#RRGGBB"
--- @param bg string  "#RRGGBB"
--- @return string  highlight group name
function M.ensure_hl(fg, bg)
  local key = "fg" .. color_key(fg) .. "bg" .. color_key(bg)
  if _cache[key] then return _cache[key] end

  local name = "PaintCell_" .. key
  vim.api.nvim_set_hl(0, name, {
    fg = to_hex(fg),
    bg = to_hex(bg),
  })
  _cache[key] = name
  return name
end

--- Get the fg/bg colors of the cell at cursor or given position by inspecting extmarks.
--- @param buf number|nil buffer number (default: current buffer)
--- @param row number|nil (0-based)
--- @param col number|nil (0-based)
--- @return table|nil { fg = "#RRGGBB", bg = "#RRGGBB" } or nil if no cell highlight found
function M.get_highlight(buf, row, col)
  local extmark = vim.inspect_pos(buf, row, col).extmarks[1]

  if extmark then
    local hl = vim.api.nvim_get_hl(0, { name = extmark.opts.hl_group })
    return {
      fg = string.format("#%06X", hl.fg),
      bg = string.format("#%06X", hl.bg)
    }
  end
end

--- Validate and normalize hex color.
--- @param input string "#RRGGBB" or "RRGGBB"
--- @return string|nil
function M.parse_color(input)
  if not input or input == "" then return nil end
  input = vim.trim(input)

  -- 6-char hex (with or without #)
  local hex = input:match("^#?([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])$")
  if hex then
    return "#" .. hex:upper()
  end
end

--- Clear the highlight cache (call when colorscheme changes).
function M.clear_cache()
  _cache = {}
end

return M
