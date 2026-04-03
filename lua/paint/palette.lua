local M              = {}

local highlight      = require("paint.highlight")

-- Height of the palette panel (2 rows: one per color row)
M.HEIGHT             = 2

-- 28 MS Paint-style colors: 14 per row.
-- Row 1: primary/mid tones.  Row 2: lighter/darker variants.
local PALETTE_COLORS = {
  -- Row 1 (indices 1-14)
  "#000000", "#FFFFFF", "#7F7F7F", "#C3C3C3",
  "#880015", "#ED1C24", "#FF7F27", "#FFF200",
  "#22B14C", "#00A2E8", "#3F48CC", "#A349A4",
  "#B97A57", "#FFAEC9",
  -- Row 2 (indices 15-28)
  "#1F1F1F", "#EFEFEF", "#4C4C4C", "#9A9A9A",
  "#9C0007", "#FF6A6A", "#FFC680", "#FFFC9E",
  "#5FBF5F", "#99D9EA", "#7092BE", "#C879C8",
  "#D4A574", "#FFD7E7",
}

-- Layout constants (all byte-based; everything before the color swatches is ASCII)
--
-- Line 1:  "FG:XX BG:XX  [color 1..14 × 2 chars]  Char:C  Tool:T  PEN↓"
--           0123456789...
--           FG: = 3 bytes, swatch = 2 bytes (cs=3,ce=5)
--           " BG:" = 4 bytes, swatch = 2 bytes (cs=9,ce=11)
--           "  " = 2 bytes → colors start at byte 13
--
-- Line 2:  "             [color 15..28 × 2 chars]  <hints>"
--           13-byte indent, then colors at same offset as line 1

local SWATCH_W       = 2 -- bytes per color swatch (two spaces)
local FG_CS          = 3
local FG_CE          = 5
local BG_CS          = 9
local BG_CE          = 11
local CLR_START      = 13 -- byte offset where color swatches begin (both rows)

--- Build the 2 palette lines and swatch geometry list.
--- Returns lines (string[]) and swatches ({row,cs,ce,color,kind}[]).
local function build_palette(state)
  local lines             = {}
  local swatches          = {}

  -- Status values
  local pen_str           = state.pen_down and " PEN\xe2\x86\x93" or "      " -- ↓ = U+2193

  -- 14-color swatch strings (two spaces per color = 28 bytes of spaces per row)
  local row1_str          = string.rep("  ", 14)
  local row2_str          = string.rep("  ", 14)

  -- Line 1
  lines[1]                = "FG:  " .. -- "FG:" + 2-char FG swatch  → bytes 0-4
      " BG:  " ..        -- " BG:" + 2-char BG swatch → bytes 5-10
      "  " ..            -- gap                        → bytes 11-12
      row1_str ..        -- 14 color swatches          → bytes 13-40
      "  " ..
      "Char:" .. state.char ..
      "  Tool:" .. string.format("%-7s", state.tool) ..
      pen_str

  -- Line 2: 13-byte indent then row 2 colors then key hints
  lines[2]                = string.rep(" ", CLR_START) ..
      row2_str ..
      "  <f>g <b>g <c>har  <p>encil <e>raser <r>pick <Spc>pen <Esc>lift"

  -- Swatch geometry ─────────────────────────────────────────────────────────

  -- FG/BG status swatches
  swatches[#swatches + 1] = { row = 0, cs = FG_CS, ce = FG_CE, color = state.fg, kind = "fg_status" }
  swatches[#swatches + 1] = { row = 0, cs = BG_CS, ce = BG_CE, color = state.bg, kind = "bg_status" }

  -- Row 1 colors (palette line 0)
  for i = 1, 14 do
    local cs = CLR_START + (i - 1) * SWATCH_W
    swatches[#swatches + 1] = {
      row = 0,
      cs = cs,
      ce = cs + SWATCH_W,
      color = PALETTE_COLORS[i],
      kind = "swatch",
    }
  end

  -- Row 2 colors (palette line 1)
  for i = 1, 14 do
    local cs = CLR_START + (i - 1) * SWATCH_W
    swatches[#swatches + 1] = {
      row = 1,
      cs = cs,
      ce = cs + SWATCH_W,
      color = PALETTE_COLORS[14 + i],
      kind = "swatch",
    }
  end

  return lines, swatches
end

--- Render the palette buffer with text and highlight extmarks.
function M.render(state)
  local buf = state.palette_buf
  local ns  = state.ns_palette

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local lines, swatches = build_palette(state)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  for _, sw in ipairs(swatches) do
    local hl_name
    if sw.kind == "fg_status" then
      hl_name = highlight.ensure_hl(state.fg, state.fg)
    elseif sw.kind == "bg_status" then
      hl_name = highlight.ensure_hl(state.bg, state.bg)
    else
      -- Both fg and bg of the swatch cell = the swatch color (solid block)
      hl_name = highlight.ensure_hl(sw.color, sw.color)
    end
    vim.api.nvim_buf_set_extmark(buf, ns, sw.row, sw.cs, {
      end_col  = sw.ce,
      hl_group = hl_name,
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
    local hl = highlight.get_highlight(pos.line - 1, pos.column - 1)
    if hl then
      state.fg = hl.fg
      M.render(state)
    end
  end, o)

  vim.keymap.set("n", "<RightMouse>", function()
    local pos = vim.fn.getmousepos()
    local hl = highlight.get_highlight(pos.line - 1, pos.column - 1)
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
end

return M
