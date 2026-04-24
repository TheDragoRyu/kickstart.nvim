return {
  'GustavEikaas/easy-dotnet.nvim',
  dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope.nvim' },
  ft = { 'cs', 'cshtml', 'razor' },
  config = function()
    require('easy-dotnet').setup {
      lsp = {
        -- roslyn.nvim owns the C# LSP; avoid a second Roslyn client that
        -- repeatedly refreshes CodeLens as "Unresolved lens ...".
        enabled = false,
        auto_refresh_codelens = false,
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
