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

      -- /// → XML doc summary block
      vim.api.nvim_create_autocmd('TextChangedI', {
        pattern = { '*.cs', '*.cshtml', '*.razor' },
        callback = function()
          local line = vim.api.nvim_get_current_line()
          local indent = line:match '^(%s*)///$'
          if not indent then return end
          local row = vim.api.nvim_win_get_cursor(0)[1]
          local t = { indent .. '/// <summary>', indent .. '/// ', indent .. '/// </summary>' }
          vim.api.nvim_buf_set_lines(0, row - 1, row, false, t)
          vim.api.nvim_win_set_cursor(0, { row + 1, #indent + 5 })
        end,
      })

      -- <CR> on a /// line continues with /// on next line
      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = { '*.cs', '*.cshtml', '*.razor' },
        callback = function()
          vim.keymap.set('i', '<CR>', function()
            local line = vim.api.nvim_get_current_line()
            local indent = line:match '^(%s*)///'
            if indent then
              return '<CR>' .. indent .. '/// '
            end
            return '<CR>'
          end, { buffer = true, expr = true })
        end,
      })

      -- Auto-close XML doc tags on >  (e.g. <param name="x"> → <param name="x"></param>)
      vim.api.nvim_create_autocmd('TextChangedI', {
        pattern = { '*.cs', '*.cshtml', '*.razor' },
        callback = function()
          local line = vim.api.nvim_get_current_line()
          -- only inside doc comment lines
          if not line:match '^%s*///' then return end
          local col = vim.api.nvim_win_get_cursor(0)[2]
          local before = line:sub(1, col)
          -- match last unclosed opening tag (not self-closing, not closing tag)
          local tag = before:match '<([%w]+)[^/]*>$'
          if not tag then return end
          -- avoid double-inserting
          local after = line:sub(col + 1)
          if after:match('^</' .. tag .. '>') then return end
          local new_line = before .. '</' .. tag .. '>' .. after
          vim.api.nvim_set_current_line(new_line)
        end,
      })
    end,
  },
}
