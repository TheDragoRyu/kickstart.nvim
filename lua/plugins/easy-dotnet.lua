return {
  'GustavEikaas/easy-dotnet.nvim',
  dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope.nvim' },
  ft = { 'cs', 'cshtml', 'razor' },
  config = function()
    require('easy-dotnet').setup {
      lsp = {
        -- easy-dotnet owns the active Roslyn client in this config. Keep the
        -- LSP enabled, but do not refresh CodeLens on cursor/idle events.
        enabled = true,
        auto_refresh_codelens = false,
        config = {
          settings = {
            ['csharp|code_lens'] = {
              dotnet_enable_references_code_lens = false,
              dotnet_enable_tests_code_lens = false,
            },
          },
        },
      },
      terminal = function(path, action)
        local cmd = action == 'run' and ('dotnet run --project ' .. path) or ('dotnet build ' .. path)
        vim.cmd('split | terminal ' .. cmd)
      end,
    }
  end,
  keys = {
    { '<leader>ds', '<cmd>Dotnet solution<cr>', desc = 'Dotnet: Solution explorer' },
    { '<leader>db', '<cmd>Dotnet build<cr>', desc = 'Dotnet: Build' },
    { '<leader>dr', '<cmd>Dotnet run<cr>', desc = 'Dotnet: Run' },
    { '<leader>dp', '<cmd>Dotnet add package<cr>', desc = 'Dotnet: Add NuGet package' },
  },
}
