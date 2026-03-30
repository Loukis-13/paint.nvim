local M = {}

--- Dispatch to the current tool.
function M.apply(state, row, col)
  if state.tool == "pencil" then
    M.pencil(state, row, col)
  elseif state.tool == "eraser" then
    M.eraser(state, row, col)
  end
end

--- Draw the current char+color at (row, col).
function M.pencil(state, row, col)
  if row < 1 or row > state.canvas_rows then return end
  if col < 1 or col > state.canvas_cols then return end
  if not state.cells[row] then state.cells[row] = {} end
  state.cells[row][col] = {
    char = state.char,
    fg   = state.fg,
    bg   = state.bg,
  }
end

--- Erase the cell at (row, col).
function M.eraser(state, row, col)
  if row < 1 or row > state.canvas_rows then return end
  if col < 1 or col > state.canvas_cols then return end
  if not state.cells[row] then return end
  state.cells[row][col] = nil
  -- Keep the sparse table clean
  if next(state.cells[row]) == nil then
    state.cells[row] = nil
  end
end

return M
