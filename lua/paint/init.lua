local M = {}

local config = {}

function M.setup(conf)
  config = conf
end

local function apply_win_opts(win)
  vim.wo[win].cursorcolumn   = false
  vim.wo[win].cursorline     = false
  vim.wo[win].foldenable     = false
  vim.wo[win].list           = false
  vim.wo[win].number         = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn     = "no"
  vim.wo[win].spell          = false
  vim.wo[win].statusline     = ""
  vim.wo[win].wrap           = false
end

local function apply_buf_opts(buf)
  vim.bo[buf].buflisted  = false
  vim.bo[buf].buftype    = "nofile"
  vim.bo[buf].filetype   = "paint"
  vim.bo[buf].modifiable = true
  vim.bo[buf].swapfile   = false
  vim.bo[buf].undolevels = -1
end

function M.open()
  local state       = require("paint.state").new(config)
  local canvas      = require("paint.canvas")
  local palette     = require("paint.palette")

  -- Create namespaces
  state.ns_canvas   = vim.api.nvim_create_namespace("paint_canvas")
  state.ns_palette  = vim.api.nvim_create_namespace("paint_palette")

  -- Create scratch buffers (buflisted=false keeps them out of bufferline plugins)
  state.canvas_buf  = vim.api.nvim_create_buf(false, true)
  state.palette_buf = vim.api.nvim_create_buf(false, true)

  -- Open a new tab. tabnew creates an extra empty buffer; capture and delete it.
  vim.cmd("tabnew")
  local orphan_buf = vim.api.nvim_get_current_buf()
  state.canvas_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.canvas_win, state.canvas_buf)
  pcall(vim.api.nvim_buf_delete, orphan_buf, { force = true })

  -- Open palette as a horizontal split ABOVE the canvas (MS Paint style)
  vim.cmd("leftabove split")
  state.palette_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.palette_win, state.palette_buf)
  vim.api.nvim_win_set_height(state.palette_win, palette.HEIGHT)
  vim.wo[state.palette_win].winfixheight = true

  -- Init cells
  if not state.canvas_cols then
    state.canvas_cols = vim.api.nvim_win_get_width(state.canvas_win) - 1
  end
  if not state.canvas_rows then
    state.canvas_rows = vim.api.nvim_win_get_height(state.canvas_win)
  end
  require("paint.state").init_cells(state)

  -- Apply options
  apply_buf_opts(state.canvas_buf)
  apply_buf_opts(state.palette_buf)
  apply_win_opts(state.canvas_win)
  apply_win_opts(state.palette_win)
  vim.o.mousescroll = "ver:0,hor:0"

  -- Adjust visual selection color for better visualition of selected area
  vim.api.nvim_set_hl(state.ns_canvas, 'Visual', { bg = '#0055FF', fg = '#0055FF' })

  -- Enable mouse globally if not already enabled
  if vim.o.mouse == "" then
    vim.o.mouse = "a"
  elseif not vim.o.mouse:find("a") then
    vim.o.mouse = vim.o.mouse .. "a"
  end
  vim.o.mousemoveevent = true

  -- Initial render
  canvas.render(state)
  palette.render(state)

  -- Register keymaps
  canvas.register_keymaps(state)
  palette.register_keymaps(state)

  -- Focus canvas
  vim.api.nvim_set_current_win(state.canvas_win)

  -- Clean up when the canvas buffer is wiped
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer   = state.canvas_buf,
    once     = true,
    callback = function()
      pcall(vim.api.nvim_buf_delete, state.palette_buf, { force = true })
    end,
  })
end

return M
