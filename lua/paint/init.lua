local M = {}

function M.setup(opts)
  vim.api.nvim_create_user_command("Paint", function(args)
    for _, arg in ipairs(args.fargs) do
      local key, value = arg:match("(%w+)=(%w+)")
      if key then opts[key] = value end
    end

    require("paint.layout").open(opts)
  end, {
    nargs = "*",
    desc = "Open paint.nvim canvas"
  })
end

return M
