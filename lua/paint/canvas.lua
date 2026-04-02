local M = {}

local highlight = require("paint.highlight")

--- Compute the 0-indexed byte offset of cell `col` in row `row`.
--- Each cell may hold a multi-byte UTF-8 character, so we sum #char of all
--- preceding cells rather than assuming 1 byte = 1 cell.
local function cell_to_byte(state, row, col)
  local byte = 0
  local row_cells = state.cells[row]
  for c = 1, col - 1 do
    local cell = row_cells and row_cells[c] or nil
    byte = byte + #((cell and cell.char) or " ")
  end
  return byte
end

--- Move the Neovim cursor to the given cell position.
local function set_cursor(state, row, col)
  local byte = cell_to_byte(state, row, col)
  pcall(vim.api.nvim_win_set_cursor, state.canvas_win, { row, byte })
end

--- Fill the canvas buffer with blank lines + right/bottom border.
function M.init_lines(state)
  local blank = string.rep(" ", state.canvas_cols) .. "│"
  local bot   = string.rep("─", state.canvas_cols) .. "┘"
  local lines = {}
  for i = 1, state.canvas_rows do
    lines[i] = blank
  end
  lines[state.canvas_rows + 1] = bot
  vim.api.nvim_buf_set_lines(state.canvas_buf, 0, -1, false, lines)
end

--- Render the full canvas: text + per-cell highlight extmarks.
--- Byte offsets for extmarks are computed by walking each row's char sizes,
--- so multi-byte characters (e.g. "█" = 3 bytes) are handled correctly.
function M.render(state)
  if state.rendering then return end
  state.rendering = true

  local buf = state.canvas_buf
  local ns  = state.ns_canvas

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  -- Build lines and collect extmark data in one pass per row.
  local all_lines = {}
  local pending_marks = {} -- { row0, byte_start, byte_end, hl_name }

  for r = 1, state.canvas_rows do
    local row_cells = state.cells[r]
    local chars      = {}
    local byte_start = {} -- byte_start[c] = 0-indexed byte offset of cell c
    local byte       = 0

    for c = 1, state.canvas_cols do
      local cell = row_cells and row_cells[c] or nil
      local ch   = (cell and cell.char) or " "
      byte_start[c] = byte
      chars[c]      = ch
      byte          = byte + #ch
    end

    all_lines[r] = table.concat(chars) .. "│"

    if row_cells then
      for c, cell in pairs(row_cells) do
        local bs = byte_start[c]
        local be = bs + #cell.char
        pending_marks[#pending_marks + 1] = {
          r - 1, bs, be, highlight.ensure_hl(cell.fg, cell.bg)
        }
      end
    end
  end

  all_lines[state.canvas_rows + 1] = string.rep("─", state.canvas_cols) .. "┘"

  -- Write text first, then extmarks (set_lines invalidates existing marks).
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)

  for _, m in ipairs(pending_marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, m[1], m[2], {
      end_col  = m[3],
      hl_group = m[4],
      priority = 100,
    })
  end

  state.rendering = false
end

--- Register all canvas buffer keymaps.
function M.register_keymaps(state)
  local tools   = require("paint.tools")
  local palette = require("paint.palette")
  local hl      = require("paint.highlight")
  local buf     = state.canvas_buf
  local o       = { noremap = true, silent = true, buffer = buf }

  local function draw_at(row, col)
    tools.apply(state, row, col)
    M.render(state)
  end

  -- Mouse: getmousepos().column is the 1-indexed SCREEN column.
  -- For single-width chars (all block/box-drawing chars), screen col = cell col.
  local function draw_at_mouse()
    local pos = vim.fn.getmousepos()
    if pos.winid ~= state.canvas_win then return end
    -- Ignore clicks on the right/bottom border characters
    if pos.winrow > state.canvas_rows then return end
    if pos.wincol > state.canvas_cols then return end
    state.cursor_row = pos.winrow
    state.cursor_col = pos.wincol
    -- Move cursor using correct byte offset (not the raw screen col).
    set_cursor(state, state.cursor_row, state.cursor_col)
    draw_at(state.cursor_row, state.cursor_col)
    palette.render(state)
  end

  -- ── Mouse ────────────────────────────────────────────────────────────────
  vim.keymap.set("n", "<LeftMouse>", function()
    state.is_dragging = true
    draw_at_mouse()
  end, o)

  vim.keymap.set("n", "<LeftDrag>", function()
    if state.is_dragging then draw_at_mouse() end
  end, o)

  vim.keymap.set("n", "<LeftRelease>", function()
    state.is_dragging = false
  end, o)

  -- ── Block insert-mode entry ───────────────────────────────────────────────
  for _, k in ipairs({ "i", "I", "a", "A", "o", "O", "s", "S", "R" }) do
    vim.keymap.set("n", k, "<Nop>", o)
  end

  -- ── Keyboard navigation + drawing ────────────────────────────────────────
  -- We track cursor_row/col in state (cell coordinates) and derive byte offsets
  -- via cell_to_byte only when calling nvim_win_set_cursor.
  local function move_fn(dr, dc)
    return function()
      state.cursor_row = math.max(1, math.min(state.canvas_rows, state.cursor_row + dr))
      state.cursor_col = math.max(1, math.min(state.canvas_cols, state.cursor_col + dc))
      set_cursor(state, state.cursor_row, state.cursor_col)
      if state.pen_down then draw_at(state.cursor_row, state.cursor_col) end
    end
  end

  vim.keymap.set("n", "<Up>",    move_fn(-1,  0), o)
  vim.keymap.set("n", "<Down>",  move_fn( 1,  0), o)
  vim.keymap.set("n", "<Left>",  move_fn( 0, -1), o)
  vim.keymap.set("n", "<Right>", move_fn( 0,  1), o)
  vim.keymap.set("n", "k",       move_fn(-1,  0), o)
  vim.keymap.set("n", "j",       move_fn( 1,  0), o)
  vim.keymap.set("n", "h",       move_fn( 0, -1), o)
  vim.keymap.set("n", "l",       move_fn( 0,  1), o)

  local function jump_fn(row, col)
    return function()
      if row ~= nil then state.cursor_row = row end
      if col ~= nil then state.cursor_col = col end
      set_cursor(state, state.cursor_row, state.cursor_col)
      if state.pen_down then draw_at(state.cursor_row, state.cursor_col) end
    end
  end

  vim.keymap.set("n", "<Home>",  jump_fn(nil, 1),                   o)
  vim.keymap.set("n", "<End>",   jump_fn(nil, state.canvas_cols),   o)
  vim.keymap.set("n", "<PageUp>",   jump_fn(1, nil),                o)
  vim.keymap.set("n", "<PageDown>", jump_fn(state.canvas_rows, nil), o)

  -- Space: pen down → draw at current cell position.
  vim.keymap.set("n", "<Space>", function()
    state.pen_down = true
    draw_at(state.cursor_row, state.cursor_col)
    palette.render(state)
  end, o)

  -- Esc: lift pen.
  vim.keymap.set("n", "<Esc>", function()
    if state.pen_down then
      state.pen_down = false
      palette.render(state)
    end
  end, o)

  -- ── Tool & color keymaps ─────────────────────────────────────────────────
  vim.keymap.set("n", "p", function()
    state.tool = "pencil"
    palette.render(state)
  end, o)

  vim.keymap.set("n", "e", function()
    state.tool = "eraser"
    palette.render(state)
  end, o)

  vim.keymap.set("n", "f", function()
    vim.ui.input({ prompt = "FG color (0-f or #RRGGBB): " }, function(input)
      local c = hl.parse_color(input)
      if c ~= nil then
        state.fg = c
        palette.render(state)
      end
    end)
  end, o)

  vim.keymap.set("n", "b", function()
    vim.ui.input({ prompt = "BG color (0-f or #RRGGBB): " }, function(input)
      local c = hl.parse_color(input)
      if c ~= nil then
        state.bg = c
        palette.render(state)
      end
    end)
  end, o)

  vim.keymap.set("n", "c", function()
    vim.ui.input({ prompt = "Draw char: " }, function(input)
      if input and #input >= 1 then
        state.char = vim.fn.strcharpart(input, 0, 1)
        palette.render(state)
      end
    end)
  end, o)

  -- Eyedropper: pick from cell at current cursor position.
  vim.keymap.set("n", "r", function()
    local cell = (state.cells[state.cursor_row] or {})[state.cursor_col]
    if cell then
      state.fg   = cell.fg
      state.bg   = cell.bg
      state.char = cell.char
      palette.render(state)
    end
  end, o)

  vim.keymap.set("n", "q", function()
    vim.cmd("tabclose")
  end, o)

  -- Save: prompt for filename; dispatch on extension (.ansi vs .paint default)
  vim.keymap.set("n", "w", function()
    vim.ui.input({ prompt = "Save to (.paint / .ansi): " }, function(path)
      if not path or path == "" then return end
      local save = require("paint.save")
      if path:match("%.ansi$") then
        save.save_ansi(state, path)
      else
        if not path:match("%.paint$") then path = path .. ".paint" end
        save.save_paint(state, path)
      end
    end)
  end, o)
end

return M
