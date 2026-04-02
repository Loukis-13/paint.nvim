local M = {}

local highlight = require("paint.highlight")

--- Fill the canvas buffer with blank lines + right/bottom border.
function M.init_lines(state)
  local blank  = string.rep(" ", state.canvas_cols) .. "│"
  local bottom = string.rep("─", state.canvas_cols) .. "┘"
  local lines  = {}
  for i = 1, state.canvas_rows do
    lines[i] = blank
  end
  lines[state.canvas_rows + 1] = bottom
  vim.api.nvim_buf_set_lines(state.canvas_buf, 0, -1, false, lines)
end

--- Render the full canvas: text + per-cell highlight extmarks.
--- Byte offsets for extmarks are computed by walking each row's char sizes,
--- so multi-byte characters (e.g. "█" = 3 bytes) are handled correctly.
function M.render(state)
  if state.rendering then return end
  state.rendering = true

  local buf       = state.canvas_buf
  local ns        = state.ns_canvas

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  -- Build lines and collect extmark data in one pass per row.
  local all_lines = {}
  local pending_marks = {} -- { row0, byte_start, byte_end, hl_name }

  for r = 1, state.canvas_rows do
    local row_cells  = state.cells[r]
    local chars      = {}
    local byte_start = {} -- byte_start[c] = 0-indexed byte offset of cell c
    local byte       = 0

    for c = 1, state.canvas_cols do
      local cell    = row_cells and row_cells[c] or nil
      local ch      = (cell and cell.char) or " "
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

  local function draw_at_mouse()
    local pos = vim.fn.getmousepos()
    if pos.winid ~= state.canvas_win then return end
    -- Ignore clicks on the right/bottom border characters
    if pos.winrow > state.canvas_rows then return end
    if pos.wincol > state.canvas_cols then return end
    draw_at(pos.winrow, pos.wincol)
    palette.render(state)
  end

  -- ── Mouse ────────────────────────────────────────────────────────────────
  vim.keymap.set("n", "<LeftMouse>", function()
    draw_at_mouse()
  end, o)

  vim.keymap.set("n", "<LeftDrag>", function()
    draw_at_mouse()
  end, o)

  -- ── Block insert-mode entry ───────────────────────────────────────────────
  for _, k in ipairs({ "i", "I", "a", "A", "o", "O", "s", "S", "R" }) do
    vim.keymap.set("n", k, "<Nop>", o)
  end

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      local pos = vim.fn.getcursorcharpos()
      local row = math.min(pos[2], state.canvas_rows) -- clamp to avoid invalid line index
      local col = math.min(pos[3], state.canvas_cols) -- clamp to avoid invalid byte offset

      vim.fn.setcharpos(".", { 0, row, col, 0 })      -- prevent cursor from moving to invalid byte offset

      if state.pen_down then draw_at(row, col) end
    end,
  })

  vim.keymap.set("n", "<PageUp>", "gg", o)
  vim.keymap.set("n", "<PageDown>", "G", o)
  vim.keymap.set("n", "<D-Up>", "gg", o)
  vim.keymap.set("n", "<D-Down>", "G", o)

  -- Space: pen down → draw at current cell position.
  vim.keymap.set("n", "<Space>", function()
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
    local pos = vim.fn.getcursorcharpos()
    local cell = (state.cells[pos[2]] or {})[pos[3]]
    if cell then
      state.fg   = cell.fg
      state.bg   = cell.bg
      state.char = cell.char
      palette.render(state)
    end
  end, o)

  vim.keymap.set("n", "q", function()
    vim.cmd("qall")
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
