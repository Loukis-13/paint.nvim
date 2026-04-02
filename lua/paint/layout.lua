local M = {}

local function apply_win_opts(win)
  local opts = {
    number         = false,
    relativenumber = false,
    signcolumn     = "no",
    wrap           = false,
    cursorline     = false,
    cursorcolumn   = false,
    foldenable     = false,
    spell          = false,
    list           = false,
    statusline     = "",
  }
  for k, v in pairs(opts) do
    vim.api.nvim_win_set_option(win, k, v)
  end
end

local function apply_buf_opts(buf)
  local opts = {
    buftype    = "nofile",
    swapfile   = false,
    buflisted  = false,
    filetype   = "paint",
    undolevels = -1,
    modifiable = true,
  }
  for k, v in pairs(opts) do
    vim.api.nvim_buf_set_option(buf, k, v)
  end
end

function M.open(opts)
  local state       = require("paint.state").new(opts)
  local canvas      = require("paint.canvas")
  local palette     = require("paint.palette")

  -- Create namespaces
  state.ns_canvas   = vim.api.nvim_create_namespace("paint_canvas")
  state.ns_palette  = vim.api.nvim_create_namespace("paint_palette")

  -- Create scratch buffers (buflisted=false keeps them out of bufferline plugins)
  state.canvas_buf  = vim.api.nvim_create_buf(false, true)
  state.palette_buf = vim.api.nvim_create_buf(false, true)

  apply_buf_opts(state.canvas_buf)
  apply_buf_opts(state.palette_buf)

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
  vim.api.nvim_win_set_option(state.palette_win, "winfixheight", true)

  -- Window options
  apply_win_opts(state.canvas_win)
  apply_win_opts(state.palette_win)

  -- Canvas needs virtualedit so cursor can freely reach any column
  vim.api.nvim_win_set_option(state.canvas_win, "virtualedit", "all")

  -- Enable mouse globally if not already enabled
  if vim.o.mouse == "" then
    vim.o.mouse = "a"
  elseif not vim.o.mouse:find("a") then
    vim.o.mouse = vim.o.mouse .. "a"
  end
  vim.o.mousemoveevent = true

  -- Initial render
  canvas.init_lines(state)
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
