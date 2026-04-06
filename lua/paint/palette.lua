local M              = {}

local highlight      = require("paint.highlight")
local tools          = require("paint.tools")

-- Height of the palette panel (2 rows: one per color row)
M.HEIGHT             = 2

-- 28 MS Paint-style colors: 14 per row.
-- Row 1: primary/mid tones.  Row 2: lighter/darker variants.
local PALETTE_COLORS = {
  "#000000", "#FFFFFF", "#7F7F7F", "#C3C3C3", "#880015", "#ED1C24", "#FF7F27", "#FFF200", "#22B14C", "#00A2E8", "#3F48CC", "#A349A4", "#B97A57", "#FFAEC9",
  "#1F1F1F", "#EFEFEF", "#4C4C4C", "#9A9A9A", "#9C0007", "#FF6A6A", "#FFC680", "#FFFC9E", "#5FBF5F", "#99D9EA", "#7092BE", "#C879C8", "#D4A574", "#FFD7E7",
}

-- Char  Tool   Shape FG BG |[color 1..14 × 2 chars]| <f>g <Pf>pick-fg <Spc>pen  <p>encil <c>har <C>har-select <w>rite(save)
--  X   pencil↓ rect  XX XX |[color 1..14 × 2 chars]| <b>g <Pg>pick-bg <Esc>lift <e>raser <F>ill <s>hape
function M.render(state)
  local buf      = state.palette_buf
  local ns       = state.ns_palette
  local swatch_w = 2
  local lines    = {
    string.format(
      "Char  Tool   Shape FG BG |%s| <f>g <Pf>pick-fg <Spc>pen  <p>encil <c>har <C>har-select <w>rite(save)",
      string.rep("SS", 14)
    ),
    string.format(
      " %s   %s%s %s  FF BB |%s| <b>g <Pg>pick-bg <Esc>lift <e>raser <F>ill <s>hape",
      state.char,
      string.format("%-6s", state.tool):sub(1, 6),
      state.pen_down and "↓" or " ",
      string.format("%-4s", state.shape):sub(1, 4),
      string.rep("SS", 14)
    )
  }

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- FG/BG status swatches
  local FG_CS = string.find(lines[2], "FF") - 1
  vim.api.nvim_buf_set_extmark(buf, ns, 1, FG_CS, {
    end_col  = FG_CS + swatch_w,
    hl_group = highlight.ensure_hl(state.fg, state.fg),
    priority = 100,
  })

  local BG_CS = string.find(lines[2], "BB") - 1
  vim.api.nvim_buf_set_extmark(buf, ns, 1, BG_CS, {
    end_col  = BG_CS + swatch_w,
    hl_group = highlight.ensure_hl(state.bg, state.bg),
    priority = 100,
  })

  -- swatches
  local CLR_START_1 = string.find(lines[1], "SS") - 1
  local CLR_START_2 = string.find(lines[2], "SS") - 1
  for i = 1, 14 do
    local cs1 = CLR_START_1 + (i - 1) * swatch_w
    vim.api.nvim_buf_set_extmark(buf, ns, 0, cs1, {
      end_col  = cs1 + swatch_w,
      hl_group = highlight.ensure_hl(PALETTE_COLORS[i], PALETTE_COLORS[i]),
      priority = 100,
    })

    local cs2 = CLR_START_2 + (i - 1) * swatch_w
    vim.api.nvim_buf_set_extmark(buf, ns, 1, cs2, {
      end_col  = cs2 + swatch_w,
      hl_group = highlight.ensure_hl(PALETTE_COLORS[14 + i], PALETTE_COLORS[14 + i]),
      priority = 100,
    })
  end
end

--- Register palette buffer keymaps (left-click = set fg, right-click = set bg).
function M.register_keymaps(state)
  local buf = state.palette_buf
  local o   = { noremap = true, silent = true, buffer = buf }

  vim.keymap.set("n", "<LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    local hl = highlight.get_highlight(nil, pos.line - 1, pos.column - 1)
    if hl then
      state.fg = hl.fg
      M.render(state)
    end
  end, o)

  vim.keymap.set("n", "<RightMouse>", function()
    local pos = vim.fn.getmousepos()
    local hl = highlight.get_highlight(nil, pos.line - 1, pos.column - 1)
    if hl then
      state.bg = hl.bg
      M.render(state)
    end
  end, o)

  -- Eyedropper: pick from cell at current cursor position.
  vim.keymap.set("n", "Pf", function()
    local hl = highlight.get_highlight()

    if hl then
      state.fg = hl.fg
      M.render(state)
    end
  end, o)

  vim.keymap.set("n", "Pb", function()
    local hl = highlight.get_highlight()

    if hl then
      state.bg = hl.bg
      M.render(state)
    end
  end, o)

  vim.keymap.set("n", "C", function()
    tools.select_char(state)
    M.render(state)
  end, o)

  vim.keymap.set("n", "s", function()
    tools.shape.select(state)
    M.render(state)
  end, o)
end

return M
