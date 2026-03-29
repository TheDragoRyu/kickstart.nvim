-- [[ Basic Keymaps ]]
-- See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

vim.keymap.set('n', 'ge', function()
  vim.diagnostic.jump { count = 1, float = true }
end, { desc = '[G]o to Next [e]rror' })
vim.keymap.set('n', 'gE', function()
  vim.diagnostic.jump { count = -1, float = true }
end, { desc = '[G]o to Previous [E]rror' })

-- Quick exit from insert mode
vim.keymap.set('i', 'jk', '<Esc>')

-- Void register shortcuts
vim.keymap.set('n', 'x', '"_x')
vim.keymap.set('n', 'X', '"_dd')
vim.keymap.set('v', 'x', '"_d')
vim.keymap.set('v', '<leader>p', '"_dP')

-- Move text up and down when selected
vim.keymap.set('v', 'J', ":move '>+1<CR>gv=gv", { silent = true })
vim.keymap.set('v', 'K', ":move '<-2<CR>gv=gv", { silent = true })

-- Exit terminal mode
-- NOTE: Won't work in all terminal emulators/tmux/etc
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Split navigation: CTRL+<hjkl> to switch between windows
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- NOTE: Some terminals have colliding keymaps or can't send distinct keycodes
vim.keymap.set('n', '<C-S-h>', '<C-w>H', { desc = 'Move window to the left' })
vim.keymap.set('n', '<C-S-l>', '<C-w>L', { desc = 'Move window to the right' })
vim.keymap.set('n', '<C-S-j>', '<C-w>J', { desc = 'Move window to the lower' })
vim.keymap.set('n', '<C-S-k>', '<C-w>K', { desc = 'Move window to the upper' })
