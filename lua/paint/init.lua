local M = {}

function M.setup()
  vim.api.nvim_create_user_command("Paint", function()
    require("paint.layout").open()
  end, { desc = "Open paint.nvim canvas" })
end

return M
