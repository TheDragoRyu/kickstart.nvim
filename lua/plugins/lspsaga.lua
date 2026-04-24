return {
  'nvimdev/lspsaga.nvim',
  event = 'LspAttach',
  config = function()
    require('lspsaga').setup {
      symbol_in_winbar = { enable = false },
      lightbulb = { enable = false },
    }
  end,
  keys = {
    { 'gch', '<cmd>Lspsaga incoming_calls<cr>', desc = 'LSP: Incoming calls' },
    { 'gcH', '<cmd>Lspsaga outgoing_calls<cr>', desc = 'LSP: Outgoing calls' },
    { 'gth', '<cmd>Lspsaga hierarchy<cr>', desc = 'LSP: Type hierarchy' },
  },
}
