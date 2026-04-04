local M = {}

function M.setup(opts)
  vim.api.nvim_create_user_command("Paint", function(args)
    local fargs = args.fargs
    local data = {}

    if fargs[1] == "load" then
      local path = fargs[2]
      if not path then
        vim.notify("paint: usage: Paint load <file.json>", vim.log.levels.ERROR)
        return
      end
      data = require("paint.save").load_json(path) or {}
    else
      for _, arg in ipairs(fargs) do
        local key, value = arg:match("([%w_]+)=(%w+)")
        if key then data[key] = value end
      end
    end

    opts = vim.tbl_extend("force", opts, data)
    require("paint.layout").open(opts)
  end, {
    nargs = "*",
    desc = "Open paint.nvim canvas"
  })
end

return M
