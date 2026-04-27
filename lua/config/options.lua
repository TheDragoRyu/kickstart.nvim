-- [[ Setting options ]]
-- See `:help vim.o`

vim.o.number = true
vim.o.relativenumber = true

vim.o.mouse = 'a'

-- Already in the status line
vim.o.showmode = false

-- Sync clipboard between OS and Neovim
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

vim.o.breakindent = true
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
vim.o.expandtab = true

vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

vim.o.signcolumn = 'yes'

vim.o.updatetime = 1000

vim.o.timeoutlen = 300

vim.o.splitright = true
vim.o.splitbelow = true

-- vim.opt (not vim.o) for convenient table interface
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type
vim.o.inccommand = 'split'

vim.o.cursorline = true
vim.o.cursorlineopt = 'number'

vim.o.scrolloff = 4

-- Raise a dialog instead of failing on unsaved changes
vim.o.confirm = true

-- Terminal transparency (acrylic/blur backgrounds)
-- Enable by setting NVIM_TRANSPARENT=1 in your terminal profile
if vim.env.NVIM_TRANSPARENT == '1' then
  vim.api.nvim_create_autocmd('ColorScheme', {
    pattern = '*',
    callback = function()
      vim.api.nvim_set_hl(0, 'Normal', { bg = 'none' })
      vim.api.nvim_set_hl(0, 'NormalNC', { bg = 'none' })
      vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'none' })
      vim.api.nvim_set_hl(0, 'WhichKeyFloat', { bg = 'none' })
      vim.api.nvim_set_hl(0, 'WhichKeyBorder', { bg = 'none' })
      vim.api.nvim_set_hl(0, 'NeoTreeNormal', { bg = 'none' })
      vim.api.nvim_set_hl(0, 'NeoTreeNormalNC', { bg = 'none' })
      vim.api.nvim_set_hl(0, 'NeoTreeEndOfBuffer', { bg = 'none' })
    end,
  })
end
