local M = {}

--- Create a fresh plugin state table.
--- @return table
function M.new()
  return {
    -- buffer / window handles (set by layout.lua)
    canvas_buf  = nil,
    canvas_win  = nil,
    palette_buf = nil,
    palette_win = nil,

    -- extmark namespaces (set by layout.lua)
    ns_canvas  = nil,
    ns_palette = nil,

    -- canvas dimensions
    canvas_rows = 40,
    canvas_cols = 120,

    -- sparse cell grid: cells[row][col] = { char, fg, bg }
    -- row/col are 1-indexed to match Neovim buffer lines
    cells = {},

    -- current drawing state
    -- fg/bg: number (ANSI 0-15) or string ("#RRGGBB")
    tool = "pencil",
    fg   = 15,   -- white
    bg   = 0,    -- black
    char = "█",

    -- palette geometry: list of { row, col_start, col_end, color }
    -- populated on every palette render; used to map mouse clicks → colors
    palette_swatches = {},

    -- keyboard pen state: true = pen down, arrows draw; false = arrows only move
    pen_down = false,

    -- re-entrancy guard for render()
    rendering = false,
  }
end

return M
