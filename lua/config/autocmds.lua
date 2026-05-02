-- [[ Basic Autocommands ]]
-- See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Server for Unity external editor bridge (nvim-unity wrapper)
do
  local addr = vim.fn.has 'win32' == 1 and [[\\.\pipe\nvim-unity]] or (vim.env.XDG_RUNTIME_DIR or '/tmp') .. '/nvim-unity.sock'
  pcall(vim.fn.serverstart, addr)
end

-- Pre-save: ensure a blank line above each C# method/ctor/dtor/local-function
-- (mirrors Rider's "blank lines around method" formatting).
local function ensure_blank_between_csharp_methods(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'c_sharp')
  if not ok or not parser then
    return
  end
  local tree = parser:parse()[1]
  if not tree then
    return
  end

  local query = vim.treesitter.query.parse(
    'c_sharp',
    '[(method_declaration) (constructor_declaration) (destructor_declaration) (local_function_statement)] @m'
  )

  local function is_doc_or_attr(line)
    return line:match '^%s*///' ~= nil or line:match '^%s*%[' ~= nil
  end

  local inserts = {}
  for _, node in query:iter_captures(tree:root(), bufnr, 0, -1) do
    local start_row = node:range()
    -- Walk up past contiguous xml-doc (///) and attribute ([...]) lines
    -- so the blank line lands above the whole header block.
    local block_row = start_row
    while block_row > 0 do
      local above = vim.api.nvim_buf_get_lines(bufnr, block_row - 1, block_row, false)[1] or ''
      if not is_doc_or_attr(above) then
        break
      end
      block_row = block_row - 1
    end

    if block_row > 0 then
      local prev = vim.api.nvim_buf_get_lines(bufnr, block_row - 1, block_row, false)[1] or ''
      if prev:match '%S' and not prev:match '^%s*[{]%s*$' then
        inserts[#inserts + 1] = block_row
      end
    end
  end

  table.sort(inserts, function(a, b)
    return a > b
  end)
  for _, row in ipairs(inserts) do
    vim.api.nvim_buf_set_lines(bufnr, row, row, false, { '' })
  end
end

vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = { '*.cs' },
  group = vim.api.nvim_create_augroup('csharp-blank-between-methods', { clear = true }),
  callback = function(ev)
    ensure_blank_between_csharp_methods(ev.buf)
  end,
})

-- Markdown-specific settings for Obsidian-like rendering
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'markdown',
  group = vim.api.nvim_create_augroup('markdown-settings', { clear = true }),
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.conceallevel = 2
    vim.opt_local.spell = true
    vim.opt_local.list = false
  end,
})
