return {
  'nvim-telescope/telescope.nvim',
  event = 'VimEnter',
  dependencies = {
    'nvim-lua/plenary.nvim',
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      build = 'make',
      cond = function()
        return vim.fn.executable 'make' == 1
      end,
    },
    { 'nvim-telescope/telescope-ui-select.nvim' },
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
  },
  config = function()
    local is_unity = vim.fn.isdirectory(vim.fn.getcwd() .. '/Assets') == 1

    require('telescope').setup {
      defaults = {
        mappings = {
          i = { ['<c-enter>'] = 'to_fuzzy_refine' },
        },
        file_ignore_patters = {
          '%.dll$',
          '%.csproj$',
          -- Unity Specific
          '%.cache$',
          '%.meta$',
          '%.unity$',
          '%.asset$',
          '%.anim$',
          '%.png$',
          '%.controller$',
          '%.mat$',
          '%.prefab$',
          '%.playable$',
          '%.shadergraph$',
          '%.shadersubgraph$',
          '%.shader$',
          '%.rsp$',
          '%.rsp2$',
          '%.mvfrm$',
          '%.aseprite$',
          -- Text format
          '%.ttf$',
          -- Audio/Video file formats
          '%.mp3$',
          '%.mp4$',
          '%.wav$',
        },
      },
      extensions = {
        ['ui-select'] = {
          require('telescope.themes').get_dropdown(),
        },
      },
    }

    pcall(require('telescope').load_extension, 'fzf')
    pcall(require('telescope').load_extension, 'ui-select')

    local builtin = require 'telescope.builtin'
    vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
    vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
    vim.keymap.set('n', '<leader>sf', function()
      builtin.find_files(is_unity and { glob_pattern = '*.cs' } or {})
    end, { desc = '[S]earch [F]iles' })
    vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
    vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
    vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
    vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
    vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
    vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
    vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

    vim.keymap.set('n', '<leader>/', function()
      builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
        winblend = 10,
        previewer = false,
      })
    end, { desc = '[/] Fuzzily search in current buffer' })

    vim.keymap.set('n', '<leader>s/', function()
      builtin.live_grep {
        grep_open_files = true,
        prompt_title = 'Live Grep in Open Files',
      }
    end, { desc = '[S]earch [/] in Open Files' })

    vim.keymap.set('n', '<leader>sn', function()
      builtin.find_files { cwd = vim.fn.stdpath 'config' }
    end, { desc = '[S]earch [N]eovim files' })

    -- Unity: find scenes/prefabs/assets referencing the current C# script via its GUID
    vim.keymap.set('n', '<leader>su', function()
      local cs_path = vim.fn.expand '%:p'
      local meta_path = cs_path .. '.meta'
      local meta = io.open(meta_path, 'r')
      if not meta then
        vim.notify('No .meta file: ' .. meta_path, vim.log.levels.WARN)
        return
      end
      local guid
      for line in meta:lines() do
        guid = line:match '^guid: (%x+)'
        if guid then break end
      end
      meta:close()
      if not guid then
        vim.notify('Could not extract GUID from ' .. meta_path, vim.log.levels.WARN)
        return
      end
      builtin.grep_string {
        search = guid,
        prompt_title = 'Unity Asset Usages (GUID: ' .. guid .. ')',
        glob_pattern = { '*.unity', '*.prefab', '*.asset' },
        additional_args = { '--no-ignore' },
      }
    end, { desc = '[S]earch [U]nity asset usages' })
  end,
}
