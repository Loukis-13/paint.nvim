local M = { shape = {} }

-- ── Tools ────────────────────────────────────────────────────────────────
--- Dispatch to the current tool.
function M.apply(state, row, col)
  if row < 1 or row > state.canvas_rows then return end
  if col < 1 or col > state.canvas_cols then return end

  if state.tool == "pencil" then
    M.pencil(state, row, col)
  elseif state.tool == "eraser" then
    M.eraser(state, row, col)
  elseif state.tool == "fill" then
    M.fill(state, row, col)
  end
end

--- Draw the current char+color at (row, col).
function M.pencil(state, row, col)
  state.cells[row][col] = {
    char = state.char,
    fg   = state.fg,
    bg   = state.bg,
  }
end

--- Erase the cell at (row, col).
function M.eraser(state, row, col)
  state.cells[row][col] = {
    char = " ",
    fg   = "#FFFFFF",
    bg   = "#FFFFFF",
  }
end

--- Flood-fill from (row, col) replacing all connected matching cells.
function M.fill(state, row, col)
  local target = state.cells[row][col]

  -- Early exit: start cell already matches the drawing state (nothing to change)
  if target.char == state.char and target.fg == state.fg and target.bg == state.bg then
    return
  end

  local visited = {}
  local queue = { { row, col } }

  while #queue > 0 do
    local current = table.remove(queue, 1)
    local r, c = current[1], current[2]

    if visited[r] and visited[r][c] then
      goto continue
    end

    if r < 1 or r > state.canvas_rows or c < 1 or c > state.canvas_cols then
      goto continue
    end

    local cell = state.cells[r][c]
    if not vim.deep_equal(target, cell) then
      goto continue
    end

    visited[r] = visited[r] or {}
    visited[r][c] = true

    M.pencil(state, r, c)

    queue[#queue + 1] = { r - 1, c }
    queue[#queue + 1] = { r + 1, c }
    queue[#queue + 1] = { r, c - 1 }
    queue[#queue + 1] = { r, c + 1 }

    ::continue::
  end

  state.pen_down = false -- prevent arrow keys from drawing after fill completes
end

-- ── Shapes ────────────────────────────────────────────────────────────────
function M.shape.apply(state, cell_start, cell_end)
  if state.shape == "line" then
    M.shape.line(state, cell_start, cell_end)
  elseif state.shape == "rectangle" then
    M.shape.rectangle(state, cell_start, cell_end)
  elseif state.shape == "ellipse" then
    M.shape.ellipse(state, cell_start, cell_end)
  elseif state.shape == "triangle" then
    M.shape.triangle(state, cell_start, cell_end)
  end
end

-- Draw a straight line from cel_start to cel_end using Bresenham's algorithm.
function M.shape.line(state, cel_start, cel_end)
  local r1, c1 = cel_start.row, cel_start.col
  local r2, c2 = cel_end.row, cel_end.col

  local dr = math.abs(r2 - r1)
  local dc = math.abs(c2 - c1)
  local step_r = (r1 < r2) and 1 or -1
  local step_c = (c1 < c2) and 1 or -1
  local err = dr - dc

  while true do
    M.pencil(state, r1, c1)

    if r1 == r2 and c1 == c2 then break end

    local err2 = err * 2
    if err2 > -dc then
      err = err - dc
      r1 = r1 + step_r
    end
    if err2 < dr then
      err = err + dr
      c1 = c1 + step_c
    end
  end
end

-- Draw a rectangle defined by cell_start and cell_end.
function M.shape.rectangle(state, cell_start, cell_end)
  local r1, c1 = cell_start.row, cell_start.col
  local r2, c2 = cell_end.row, cell_end.col

  for c = math.min(c1, c2), math.max(c1, c2) do
    M.pencil(state, r1, c)
    M.pencil(state, r2, c)
  end
  for r = math.min(r1, r2), math.max(r1, r2) do
    M.pencil(state, r, c1)
    M.pencil(state, r, c2)
  end
end

-- Draw an ellipse defined by cell_start and cell_end.
function M.shape.ellipse(state, cell_start, cell_end)
  local r1, c1 = cell_start.row, cell_start.col
  local r2, c2 = cell_end.row, cell_end.col

  local center_r = (r1 + r2) / 2
  local center_c = (c1 + c2) / 2

  local radius_r = math.abs(r2 - r1) / 2
  local radius_c = math.abs(c2 - c1) / 2

  local steps = math.ceil(2 * math.pi * math.sqrt((radius_r ^ 2 + radius_c ^ 2) / 2))

  for i = 0, steps - 1 do
    local angle = (i / steps) * 2 * math.pi
    local r = math.floor(center_r + radius_r * math.sin(angle) + 0.5)
    local c = math.floor(center_c + radius_c * math.cos(angle) + 0.5)
    M.pencil(state, r, c)
  end
end

-- Draw a triagle defined by cell_start and cell_end.
function M.shape.triangle(state, cell_start, cell_end)
  local r1, c1 = cell_start.row, cell_start.col
  local r2, c2 = cell_end.row, cell_end.col

  local p1 = { row = r2, col = c1 }
  local p2 = { row = r2, col = c2 }
  local p3 = { row = r1, col = (c1 + c2) / 2 }

  M.shape.line(state, p1, p2)
  M.shape.line(state, p1, p3)
  M.shape.line(state, p2, p3)
end

-- Shape selection
function M.shape.select(state)
  vim.ui.select({
      "line",
      "rectangle",
      "ellipse",
      "triangle"
    },
    {},
    function(choice)
      if choice then
        state.shape = choice
      end
    end)
end

-- ── Select options ────────────────────────────────────────────────────────────────
-- Unicode char selection.
function M.select_char(state)
  vim.ui.select(state.char_list or {
    { '█', 'Full Block' },
    { '▓', 'Dark Shade' },
    { '▒', 'Medium Shade' },
    { '░', 'Light Shade' },
    { '▔', 'Upper One Eighth Block' },
    { '▀', 'Upper Half Block' },
    { '▁', 'Lower One Eighth Block' },
    { '▂', 'Lower One Quarter Block' },
    { '▃', 'Lower Three Eighths Block' },
    { '▄', 'Lower Half Block' },
    { '▅', 'Lower Five Eighths Block' },
    { '▆', 'Lower Three Quarters Block' },
    { '▇', 'Lower Seven Eighths Block' },
    { '▉', 'Left Seven Eighths Block' },
    { '▊', 'Left Three Quarters Block' },
    { '▋', 'Left Five Eighths Block' },
    { '▌', 'Left Half Block' },
    { '▍', 'Left Three Eighths Block' },
    { '▎', 'Left One Quarter Block' },
    { '▏', 'Left One Eighth Block' },
    { '▐', 'Right Half Block' },
    { '▕', 'Right One Eighth Block' },
    { '▖', 'Quadrant Lower Left' },
    { '▗', 'Quadrant Lower Right' },
    { '▘', 'Quadrant Upper Left' },
    { '▙', 'Quadrant Upper Left and Lower Left and Lower Right' },
    { '▚', 'Quadrant Upper Left and Lower Right' },
    { '▛', 'Quadrant Upper Left and Upper Right and Lower Left' },
    { '▜', 'Quadrant Upper Left and Upper Right and Lower Right' },
    { '▝', 'Quadrant Upper Right' },
    { '▞', 'Quadrant Upper Right and Lower Left' },
    { '▟', 'Quadrant Upper Right and Lower Left and Lower Right' },
  }, {
    format_item = function(item)
      if type(item) == "table" then
        return ('%s - %s'):format(item[1], item[2])
      else
        return item
      end
    end,
  }, function(choice)
    if choice then
      state.char = choice[1]
    end
  end)
end

return M
