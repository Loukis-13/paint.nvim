local M = {}

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
  M.pencil(state, row, col)

  local neighbors = { { row - 1, col }, { row + 1, col }, { row, col - 1 }, { row, col + 1 } }
  for _, nb in ipairs(neighbors) do
    local nr, nc = nb[1], nb[2]
    if nr >= 1 and nr <= state.canvas_rows and nc >= 1 and nc <= state.canvas_cols then
      local cell = state.cells[nr][nc]
      if vim.deep_equal(target, cell) then
        M.fill(state, nr, nc)
      end
    end
  end

  state.pen_down = false -- prevent arrow keys from drawing after fill completes
end

return M
