return { -- Live markdown rendering like Obsidian
  'MeanderingProgrammer/render-markdown.nvim',
  ft = { 'markdown' },
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-tree/nvim-web-devicons',
  },
  opts = {
    heading = {
      enabled = true,
      icons = { '# ', '## ', '### ', '#### ', '##### ', '###### ' },
      sign = false,
    },
    bullet = {
      enabled = true,
      icons = { '', '', '', '' },
    },
    checkbox = {
      enabled = true,
      unchecked = { icon = ' ' },
      checked = { icon = ' ' },
      custom = {
        todo = { raw = '[-]', rendered = '󰥔 ', highlight = 'RenderMarkdownTodo' },
      },
    },
    code = {
      enabled = true,
      sign = false,
      style = 'full',
      width = 'block',
      min_width = 60,
      border = 'thin',
    },
    dash = { enabled = true },
    link = { enabled = true },
    pipe_table = {
      enabled = true,
      style = 'full',
    },
  },
  keys = {
    { '<leader>tm', '<cmd>RenderMarkdown toggle<CR>', desc = '[T]oggle [M]arkdown render' },
  },
}
