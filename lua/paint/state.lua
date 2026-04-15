local M = {}

--- Create a fresh plugin state table.
--- @return table
function M.new(opts)
  local cells = opts.cells or {}
  local rows = tonumber(opts.rows)
  local cols = tonumber(opts.cols)

  return {
    -- buffer / window handles (set by layout.lua)
    canvas_buf  = nil,
    canvas_win  = nil,
    palette_buf = nil,
    palette_win = nil,

    -- extmark namespaces (set by layout.lua)
    ns_canvas   = nil,
    ns_palette  = nil,

    -- canvas dimensions
    canvas_rows = rows,
    canvas_cols = cols,

    -- cells[row][col] = { char, fg, bg }
    cells       = cells,

    -- current drawing state
    tool        = "pencil",
    shape       = "line",
    fg          = "#000000",
    bg          = "#FFFFFF",
    char        = "█",

    -- keyboard pen state: true = pen down, arrows draw; false = arrows only move
    pen_down    = false,

    -- re-entrancy guard for render()
    rendering   = false,

    -- chars for the select prompt
    char_list   = opts.char_list,

    -- undo / redo stacks (list of cells snapshots)
    history     = {},
    future      = {},
  }
end

function M.init_cells(state)
  local cells = state.cells

  if next(cells) == nil then
    for row = 1, state.canvas_rows do
      cells[row] = {}
      for col = 1, state.canvas_cols do
        cells[row][col] = {
          fg = "#FFFFFF",
          bg = "#FFFFFF",
          char = " ",
        }
      end
    end
  end
end

return M
