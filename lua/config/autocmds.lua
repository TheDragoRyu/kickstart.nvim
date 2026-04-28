-- [[ Basic Autocommands ]]
-- See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Server for Unity external editor bridge (nvim-unity wrapper)
do
  local addr = vim.fn.has 'win32' == 1 and [[\\.\pipe\nvim-unity]] or (vim.env.XDG_RUNTIME_DIR or '/tmp') .. '/nvim-unity.sock'
  pcall(vim.fn.serverstart, addr)
end

-- Markdown-specific settings for Obsidian-like rendering
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'markdown',
  group = vim.api.nvim_create_augroup('markdown-settings', { clear = true }),
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.conceallevel = 2
    vim.opt_local.spell = true
    vim.opt_local.list = false
  end,
})
