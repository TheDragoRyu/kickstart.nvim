-- autopairs
-- https://github.com/windwp/nvim-autopairs

return {
  'windwp/nvim-autopairs',
  event = 'InsertEnter',
  config = function()
    local autopairs = require 'nvim-autopairs'
    local Rule = require 'nvim-autopairs.rule'
    local cond = require 'nvim-autopairs.conds'
    local csharp_filetypes = { 'cs', 'cshtml', 'razor' }

    autopairs.setup {
      -- Built-ins cover Rider-style (), [], {}, quotes, backticks, pair
      -- deletion, moveright, and <CR> splitting.
    }

    autopairs.add_rules {
      -- Close <> for C# generic type arguments, but avoid common comparisons.
      Rule('<', '>', csharp_filetypes)
        :with_pair(cond.before_regex('[%w_%)]', 1))
        :with_pair(cond.not_after_regex('[%w_%.]', 1))
        :with_move(function(opts)
          return opts.char == '>'
        end),

      -- Rider-like completion for C# raw string literals: """|""".
      Rule('"""', '"""', 'cs'):with_pair(cond.not_before_char('"', 3)),

      -- Rider closes block comments in C# and markup comments in Razor views.
      Rule('/*', '*/', csharp_filetypes):with_pair(cond.not_after_regex('%*', 1)),
      Rule('<!--', '-->', { 'cshtml', 'razor' }):with_cr(cond.none()),
    }
  end,
}
