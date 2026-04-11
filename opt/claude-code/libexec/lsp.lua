#!/usr/bin/env -S -- nvim -l

do
  local lspconfig = vim.fs.joinpath(vim.fn.stdpath "cache", "..", "helix-rt", "nvim", "pack", "start", "nvim-lspconfig")
  vim.opt.rtp:append { lspconfig }
end

local lspdata = (function()
  local path = vim.fs.joinpath(vim.fn.stdpath "config", "apriori", "lsp.json")
  local json = vim.fn.readblob(path)
  return vim.json.decode(json, { luanil = { object = true, array = true } })
end)()

do
  local acc = {}
  for name, conf in pairs(lspdata) do
    local keys = { "filetypes", "init_options", "settings" }
    local overrides = { detached = false }

    for _, k in pairs(keys) do
      if conf[k] then
        overrides[k] = conf[k]
      end
    end

    local argv = conf.args and { { "" }, conf.args } or { (vim.lsp.config[name] or {}).cmd or {} }
    local cmds = vim.iter(argv):flatten():totable()
    cmds[1] = conf.bin
    overrides.cmd = cmds

    vim.lsp.config(name, overrides)
    local conf = vim.lsp.config[name]

    acc[name] = conf
  end
end
