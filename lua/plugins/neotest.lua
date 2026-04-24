return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'Issafalcon/neotest-dotnet',
  },
  config = function()
    require('neotest').setup {
      adapters = {
        require('neotest-dotnet') {
          dap = { justMyCode = false },
          dotnet_additional_args = {},
          discovery_root = 'project',
        },
      },
    }
  end,
  keys = {
    {
      '<leader>tt',
      function()
        require('neotest').run.run()
      end,
      desc = 'Test: Run nearest',
    },
    {
      '<leader>tT',
      function()
        require('neotest').run.run(vim.fn.expand '%')
      end,
      desc = 'Test: Run file',
    },
    {
      '<leader>ts',
      function()
        require('neotest').summary.toggle()
      end,
      desc = 'Test: Summary panel',
    },
    {
      '<leader>to',
      function()
        require('neotest').output.open()
      end,
      desc = 'Test: Output',
    },
  },
}
