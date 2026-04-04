local function add_unique(list, values)
  local seen = {}

  for _, item in ipairs(list) do
    seen[item] = true
  end

  for _, item in ipairs(values) do
    if not seen[item] then
      table.insert(list, item)
      seen[item] = true
    end
  end
end

return {
  {
    'mason-org/mason.nvim',
    optional = true,
    opts = function(_, opts)
      opts.registries = opts.registries or {
        'github:mason-org/mason-registry',
      }

      add_unique(opts.registries, {
        'github:Crashdummyy/mason-registry',
      })
    end,
  },
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      add_unique(opts.ensure_installed, { 'roslyn' })
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter',
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      add_unique(opts.ensure_installed, { 'c_sharp' })
    end,
  },
  {
    'seblyng/roslyn.nvim',
    dependencies = {
      'neovim/nvim-lspconfig',
      'saghen/blink.cmp',
    },
    event = {
      'BufReadPre *.cs',
      'BufNewFile *.cs',
      'BufReadPre *.cshtml',
      'BufNewFile *.cshtml',
      'BufReadPre *.razor',
      'BufNewFile *.razor',
    },
    opts = {},
    config = function(_, opts)
      vim.lsp.config('roslyn', {
        capabilities = require('blink.cmp').get_lsp_capabilities(),
      })

      require('roslyn').setup(opts)
    end,
  },
}
