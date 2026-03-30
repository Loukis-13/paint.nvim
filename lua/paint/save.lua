local M = {}

local hl = require("paint.highlight")

--- Resolve a color (ANSI index or "#RRGGBB") to its R, G, B components.
local function to_rgb(c)
  local hex
  if type(c) == "number" then
    hex = hl.ANSI_TO_HEX[c] or "#000000"
  else
    hex = c
  end
  hex = hex:gsub("^#", "")
  return tonumber(hex:sub(1, 2), 16),
         tonumber(hex:sub(3, 4), 16),
         tonumber(hex:sub(5, 6), 16)
end

--- Save the canvas in the native JSON format (.paint).
--- Format: { version=1, rows, cols, cells=[{r,c,ch,fg,bg}, ...] }
--- fg/bg are stored as-is (number 0-15 or "#RRGGBB" string).
--- @param state table
--- @param path  string
--- @return boolean
function M.save_paint(state, path)
  local cells_arr = {}
  for r, row_cells in pairs(state.cells) do
    for c, cell in pairs(row_cells) do
      cells_arr[#cells_arr + 1] = {
        r  = r,
        c  = c,
        ch = cell.char,
        fg = cell.fg,
        bg = cell.bg,
      }
    end
  end

  local data = {
    version = 1,
    rows    = state.canvas_rows,
    cols    = state.canvas_cols,
    cells   = cells_arr,
  }

  local ok, encoded = pcall(vim.fn.json_encode, data)
  if not ok then
    vim.notify("paint: failed to encode JSON: " .. tostring(encoded), vim.log.levels.ERROR)
    return false
  end

  local f, err = io.open(path, "w")
  if not f then
    vim.notify("paint: cannot write " .. path .. ": " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  f:write(encoded)
  f:close()
  vim.notify("paint: saved " .. path, vim.log.levels.INFO)
  return true
end

--- Save the canvas as ANSI escape-code art (.ansi).
--- Uses 24-bit true-color sequences: ESC[38;2;R;G;Bm (fg) and ESC[48;2;R;G;Bm (bg).
--- Trailing empty cells on each row are omitted; ESC[0m resets at row end when needed.
--- @param state table
--- @param path  string
--- @return boolean
function M.save_ansi(state, path)
  local f, err = io.open(path, "w")
  if not f then
    vim.notify("paint: cannot write " .. path .. ": " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  for r = 1, state.canvas_rows do
    local row_cells = state.cells[r]
    local parts     = {}
    local cur_fg    = nil  -- last emitted fg color (for delta encoding)
    local cur_bg    = nil
    local has_color = false

    for c = 1, state.canvas_cols do
      local cell = row_cells and row_cells[c] or nil
      if cell then
        local esc = ""
        if cell.fg ~= cur_fg then
          local r1, g1, b1 = to_rgb(cell.fg)
          esc = esc .. string.format("\x1b[38;2;%d;%d;%dm", r1, g1, b1)
          cur_fg = cell.fg
        end
        if cell.bg ~= cur_bg then
          local r2, g2, b2 = to_rgb(cell.bg)
          esc = esc .. string.format("\x1b[48;2;%d;%d;%dm", r2, g2, b2)
          cur_bg = cell.bg
        end
        parts[#parts + 1] = esc .. cell.char
        has_color = true
      else
        -- Empty cell: reset then space if we had color active
        if cur_fg ~= nil or cur_bg ~= nil then
          parts[#parts + 1] = "\x1b[0m "
          cur_fg, cur_bg = nil, nil
        else
          parts[#parts + 1] = " "
        end
      end
    end

    -- Strip trailing spaces (clean output)
    while #parts > 0 and (parts[#parts] == " " or parts[#parts] == "\x1b[0m ") do
      parts[#parts] = nil
    end

    -- Reset at end of row if color is still active
    if cur_fg ~= nil or cur_bg ~= nil then
      parts[#parts + 1] = "\x1b[0m"
    end

    f:write(table.concat(parts) .. "\n")
  end

  f:close()
  vim.notify("paint: saved " .. path, vim.log.levels.INFO)
  return true
end

return M
