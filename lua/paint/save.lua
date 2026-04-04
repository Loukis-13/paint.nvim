local M = {}

--- Resolve a color to its R, G, B components.
local function to_rgb(hex)
  hex = hex:gsub("^#", "")
  return tonumber(hex:sub(1, 2), 16),
         tonumber(hex:sub(3, 4), 16),
         tonumber(hex:sub(5, 6), 16)
end

--- Save the canvas in the JSON format.
--- @param state table
--- @param path  string
--- @return boolean
function M.save_json(state, path)
  local json = vim.json.encode({
    rows  = state.canvas_rows,
    cols  = state.canvas_cols,
    cells = state.cells,
  })

  local f, err = io.open(path, "w")
  if not f then
    vim.notify("paint: cannot write " .. path .. ": " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  f:write(json)
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
    local cur_fg    = nil -- last emitted fg color (for delta encoding)
    local cur_bg    = nil

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

--- Load a canvas from a JSON file.
--- @param path string
--- @return table|nil  { cells, rows, cols } or nil on error
function M.load_json(path)
  local f, err = io.open(path, "r")
  if not f then
    vim.notify("paint: cannot read " .. path .. ": " .. tostring(err), vim.log.levels.ERROR)
    return nil
  end
  local content = f:read("*a")
  f:close()

  local ok, data = pcall(vim.json.decode, content, { luanil = { object = true, array = true } })
  if not ok or type(data) ~= "table" then
    vim.notify("paint: failed to parse " .. path, vim.log.levels.ERROR)
    return nil
  end

  return data
end

return M
