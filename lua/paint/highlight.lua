local M = {}

-- Standard xterm/VTE 16-color palette hex values
M.ANSI_TO_HEX = {
  [0]  = "#000000", -- Black
  [1]  = "#CC0000", -- Dark Red
  [2]  = "#4E9A06", -- Dark Green
  [3]  = "#C4A000", -- Dark Yellow
  [4]  = "#3465A4", -- Dark Blue
  [5]  = "#75507B", -- Dark Magenta
  [6]  = "#06989A", -- Dark Cyan
  [7]  = "#D3D7CF", -- Light Gray
  [8]  = "#555753", -- Dark Gray
  [9]  = "#EF2929", -- Bright Red
  [10] = "#8AE234", -- Bright Green
  [11] = "#FCE94F", -- Bright Yellow
  [12] = "#729FCF", -- Bright Blue
  [13] = "#AD7FA8", -- Bright Magenta
  [14] = "#34E2E2", -- Bright Cyan
  [15] = "#EEEEEC", -- White
}

-- Cache of already-created highlight group names
local _cache = {}

--- Normalize a color value to a cache key segment.
--- @param c number|string
--- @return string
local function color_key(c)
  if type(c) == "number" then
    return tostring(c)
  end
  -- strip leading #
  return c:gsub("^#", ""):upper()
end

--- Return the GUI hex string for a color (ANSI index or hex string).
--- @param c number|string
--- @return string
local function to_hex(c)
  if type(c) == "number" then
    return M.ANSI_TO_HEX[c] or "#000000"
  end
  -- ensure # prefix and uppercase
  local s = c:gsub("^#", "")
  return "#" .. s:upper()
end

--- Lazily create and return a highlight group name for the given fg/bg pair.
--- @param fg number|string  ANSI index (0-15) or "#RRGGBB"
--- @param bg number|string  ANSI index (0-15) or "#RRGGBB"
--- @return string  highlight group name
function M.ensure_hl(fg, bg)
  local key = "fg" .. color_key(fg) .. "bg" .. color_key(bg)
  if _cache[key] then return _cache[key] end

  local name = "PaintCell_" .. key
  vim.api.nvim_set_hl(0, name, {
    ctermfg = type(fg) == "number" and fg or nil,
    ctermbg = type(bg) == "number" and bg or nil,
    fg      = to_hex(fg),
    bg      = to_hex(bg),
  })
  _cache[key] = name
  return name
end

--- Parse a user-supplied color string into the internal representation.
--- Accepts:
---   "0"-"f" or "0"-"9","a"-"f"  → ANSI index number (0-15)
---   "#RRGGBB" or "RRGGBB"       → normalized "#RRGGBB" string
--- @param input string
--- @return number|string|nil
function M.parse_color(input)
  if not input or input == "" then return nil end
  input = vim.trim(input)

  -- Single hex digit → ANSI index
  if #input == 1 then
    local n = tonumber(input, 16)
    if n and n >= 0 and n <= 15 then return n end
  end

  -- 6-char hex (with or without #)
  local hex = input:match("^#?([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])$")
  if hex then
    return "#" .. hex:upper()
  end

  return nil
end

--- Clear the highlight cache (call when colorscheme changes).
function M.clear_cache()
  _cache = {}
end

return M
