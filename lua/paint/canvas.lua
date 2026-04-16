local M = {}

local highlight = require("paint.highlight")

--- Full canvas rerender: rebuild all lines and all extmarks.
local function _render_full(state)
  local buf = state.canvas_buf
  local ns  = state.ns_canvas

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local all_lines     = {}
  local pending_marks = {}

  for r = 1, state.canvas_rows do
    local row_cells  = state.cells[r]
    local chars      = {}
    local byte_start = {}
    local byte       = 0

    for c = 1, state.canvas_cols do
      local cell    = row_cells and row_cells[c] or nil
      local ch      = (cell and cell.char) or " "
      byte_start[c] = byte
      chars[c]      = ch
      byte          = byte + #ch
    end

    all_lines[r] = table.concat(chars)

    if row_cells then
      for c, cell in pairs(row_cells) do
        local bs = byte_start[c]
        pending_marks[#pending_marks + 1] = {
          r - 1, bs, bs + #cell.char, highlight.ensure_hl(cell.fg, cell.bg)
        }
      end
    end
  end

  -- Write text first, then extmarks (set_lines invalidates existing marks).
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)

  for _, m in ipairs(pending_marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, m[1], m[2], {
      end_col  = m[3],
      hl_group = m[4],
      priority = 100,
    })
  end
end

--- Incremental rerender: update only the rows listed in the dirty set.
--- Replacing exactly one line at a time keeps extmarks in other rows intact.
local function _render_rows(state, dirty)
  local buf = state.canvas_buf
  local ns  = state.ns_canvas

  for r in pairs(dirty) do
    local row_cells  = state.cells[r]
    local chars      = {}
    local byte_start = {}
    local byte       = 0

    for c = 1, state.canvas_cols do
      local cell    = row_cells and row_cells[c] or nil
      local ch      = (cell and cell.char) or " "
      byte_start[c] = byte
      chars[c]      = ch
      byte          = byte + #ch
    end

    -- Replace only this row (same line count → extmarks in other rows unaffected).
    vim.api.nvim_buf_set_lines(buf, r - 1, r, false, { table.concat(chars) })
    vim.api.nvim_buf_clear_namespace(buf, ns, r - 1, r)

    if row_cells then
      for c, cell in pairs(row_cells) do
        local bs = byte_start[c]
        vim.api.nvim_buf_set_extmark(buf, ns, r - 1, bs, {
          end_col  = bs + #cell.char,
          hl_group = highlight.ensure_hl(cell.fg, cell.bg),
          priority = 100,
        })
      end
    end
  end
end

--- Render the canvas.
--- When state.dirty_rows is a non-nil table, only those rows are updated
--- (incremental path). When nil, the full canvas is redrawn.
function M.render(state)
  if state.rendering then return end
  state.rendering  = true

  local dirty      = state.dirty_rows
  state.dirty_rows = nil -- reset before any early return

  if dirty ~= nil then
    if next(dirty) then _render_rows(state, dirty) end
  else
    _render_full(state)
  end

  state.rendering = false
end

--- Register all canvas buffer keymaps.
function M.register_keymaps(state)
  local tools   = require("paint.tools")
  local palette = require("paint.palette")
  local buf     = state.canvas_buf
  local o       = { noremap = true, silent = true, buffer = buf }

  local function get_pos(mark)
    mark = mark or "."
    local pos = vim.fn.getcharpos(mark)
    return { row = pos[2], col = pos[3] }
  end

  local function draw_at(row, col)
    tools.apply(state, row, col)
    -- Pencil/eraser touch exactly one row; mark it dirty for incremental render.
    -- Fill leaves dirty_rows = nil → full render (spans unpredictable rows).
    if state.tool == "pencil" or state.tool == "eraser" then
      state.dirty_rows = state.dirty_rows or {}
      state.dirty_rows[row] = true
    end
    M.render(state)
  end

  local function draw_at_mouse()
    local pos = vim.fn.getmousepos()
    if pos.winid ~= state.canvas_win then return end
    -- Ignore clicks on the right/bottom border characters
    if pos.winrow > state.canvas_rows then return end
    if pos.wincol > state.canvas_cols then return end
    draw_at(pos.winrow, pos.wincol)
    vim.fn.setcharpos(".", { 0, pos.winrow, pos.wincol, 0 })
  end

  -- ── Mouse ────────────────────────────────────────────────────────────────
  local last_mouse_pos = nil

  vim.keymap.set("n", "<LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid == state.palette_win then
      local hl = highlight.get_highlight(state.palette_buf, pos.line - 1, pos.column - 1)
      if hl then
        state.fg = hl.fg
        palette.render(state)
      end
    else
      tools.push_history(state)
      last_mouse_pos = { row = pos.winrow, col = pos.wincol }
      draw_at_mouse()
    end
  end, o)

  vim.keymap.set("n", "<LeftDrag>", function()
    local pos = vim.fn.getmousepos()

    if pos.winid ~= state.canvas_win or pos.winrow > state.canvas_rows or pos.wincol > state.canvas_cols then
      last_mouse_pos = nil
      return
    end

    if not last_mouse_pos then
      draw_at_mouse()
    else
      -- Mark only the rows spanned by this line segment as dirty.
      state.dirty_rows = {}
      for r = math.min(last_mouse_pos.row, pos.winrow), math.max(last_mouse_pos.row, pos.winrow) do
        state.dirty_rows[r] = true
      end

      tools.shape.line(state, last_mouse_pos, { row = pos.winrow, col = pos.wincol })

      M.render(state)
    end

    last_mouse_pos = { row = pos.winrow, col = pos.wincol }
  end, o)

  vim.keymap.set("n", "<RightMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid == state.palette_win then
      local hl = highlight.get_highlight(state.palette_buf, pos.line - 1, pos.column - 1)
      if hl then
        state.bg = hl.bg
        palette.render(state)
      end
    else
      local row = math.min(pos.winrow, state.canvas_rows) -- clamp to avoid invalid line index
      local col = math.min(pos.wincol, state.canvas_cols) -- clamp to avoid invalid char index
      vim.fn.setcharpos(".", { 0, row, col, 0 })
      vim.cmd('normal! \22')
    end
  end, o)

  vim.keymap.set("v", "<RightDrag>", function()
    local pos = vim.fn.getmousepos()
    local row = math.min(pos.winrow, state.canvas_rows) -- clamp to avoid invalid line index
    local col = math.min(pos.wincol, state.canvas_cols) -- clamp to avoid invalid char index
    vim.fn.setcharpos(".", { 0, row, col, 0 })
  end, o)

  vim.keymap.set("v", "<RightRelease>", "<Esc>", o)

  -- ── Keyboard ─────────────────────────────────────────────────────────────
  -- Block insert-mode entry
  for _, k in ipairs({ "i", "I", "a", "A", "o", "O", "s", "S", "r", "R" }) do
    vim.keymap.set("n", k, "<Nop>", o)
  end

  -- Space: pen down → draw at current cell position.
  vim.keymap.set("n", "<Space>", function()
    tools.push_history(state)
    state.pen_down = true
    local pos = vim.fn.getcursorcharpos()
    draw_at(pos[2], pos[3])
    palette.render(state)
  end, o)

  -- Esc: lift pen.
  vim.keymap.set("n", "<Esc>", function()
    if state.pen_down then
      state.pen_down = false
      palette.render(state)
    end
  end, o)

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      local pos = vim.fn.getcursorcharpos()
      local row = math.min(pos[2], state.canvas_rows) -- clamp to avoid invalid line index
      local col = math.min(pos[3], state.canvas_cols) -- clamp to avoid invalid char index

      vim.fn.setcharpos(".", { 0, row, col, 0 })      -- prevent cursor from moving to invalid char offset

      if state.pen_down then draw_at(row, col) end
    end,
  })

  -- Draw straight lines with PgUp/PgDown/Home/End.
  vim.keymap.set("n", "<PageUp>", function()
    local pos = get_pos()
    if state.pen_down then
      tools.shape.line(state, pos, { row = 1, col = pos.col })
      M.render(state)
    end
    vim.fn.setcursorcharpos(1, pos.col)
  end, o)
  vim.keymap.set("n", "<PageDown>", function()
    local pos = get_pos()
    if state.pen_down then
      tools.shape.line(state, pos, { row = state.canvas_rows, col = pos.col })
      M.render(state)
    end
    vim.fn.setcursorcharpos(state.canvas_rows, pos.col)
  end, o)
  vim.keymap.set("n", "<Home>", function()
    local pos = get_pos()
    if state.pen_down then
      tools.shape.line(state, pos, { row = pos.row, col = 1 })
      M.render(state)
    end
    vim.fn.setcursorcharpos(pos.row, 1)
  end, o)
  vim.keymap.set("n", "<End>", function()
    local pos = get_pos()
    if state.pen_down then
      tools.shape.line(state, pos, { row = pos.row, col = state.canvas_cols })
      M.render(state)
    end
    vim.fn.setcursorcharpos(pos.row, state.canvas_cols)
  end, o)
  vim.keymap.set("n", "<D-Up>", "<PageUp>", { buffer = buf, remap = true })
  vim.keymap.set("n", "<D-Down>", "<PageDown>", { buffer = buf, remap = true })
  vim.keymap.set("n", "<D-Left>", "<Home>", { buffer = buf, remap = true })
  vim.keymap.set("n", "<D-Right>", "<End>", { buffer = buf, remap = true })

  -- Shapes drawing with visual blocks
  vim.api.nvim_create_autocmd("ModeChanged", {
    -- buffer = buf,
    pattern = "\x16:n", -- V-BLOCK to NORMAL
    callback = function()
      tools.push_history(state)
      tools.shape.apply(state, get_pos("'<"), get_pos("'>"))
      M.render(state)
    end,
  })

  -- ── Tool & color keymaps ─────────────────────────────────────────────────
  vim.keymap.set("n", "p", function()
    state.tool = "pencil"
    palette.render(state)
  end, o)

  vim.keymap.set("n", "e", function()
    state.tool = "eraser"
    palette.render(state)
  end, o)

  vim.keymap.set("n", "F", function()
    state.tool = "fill"
    palette.render(state)
  end, o)

  vim.keymap.set("n", "f", function()
    vim.ui.input({ prompt = "FG color #(RRGGBB): " }, function(input)
      local c = highlight.parse_color(input)
      if c ~= nil then
        state.fg = c
        palette.render(state)
      end
    end)
  end, o)

  vim.keymap.set("n", "b", function()
    vim.ui.input({ prompt = "BG color #(RRGGBB): " }, function(input)
      local c = highlight.parse_color(input)
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
  vim.keymap.set("n", "Pf", function()
    local hl = highlight.get_highlight()

    if hl then
      state.fg = hl.fg
      palette.render(state)
    end
  end, o)

  vim.keymap.set("n", "Pb", function()
    local hl = highlight.get_highlight()

    if hl then
      state.bg = hl.bg
      palette.render(state)
    end
  end, o)

  vim.keymap.set("n", "C", function()
    tools.select_char(state)
    palette.render(state)
  end, o)

  vim.keymap.set("n", "s", function()
    tools.shape.select(state)
    palette.render(state)
  end, o)

  vim.keymap.set("n", "u", function()
    tools.undo(state)
    M.render(state)
    palette.render(state)
  end, o)

  vim.keymap.set("n", "<C-r>", function()
    tools.redo(state)
    M.render(state)
    palette.render(state)
  end, o)

  -- Save: prompt for filename; dispatch on extension (.ansi vs .json default)
  vim.keymap.set("n", "w", function()
    vim.ui.input({ prompt = "Save to (.json / .ansi): " }, function(path)
      if not path or path == "" then return end
      local save = require("paint.save")
      if path:match("%.ansi$") then
        save.save_ansi(state, path)
      else
        if not path:match("%.json$") then path = path .. ".json" end
        save.save_json(state, path)
      end
    end)
  end, o)
end

return M
