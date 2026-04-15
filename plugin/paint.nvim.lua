if vim.g.loaded_paint_nvim then
  return
end
vim.g.loaded_paint_nvim = true

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

  if data then
    require("paint").setup(data)
  end

  require("paint").open()
end, {
  nargs = "*",
  desc = "Open paint.nvim canvas"
})
