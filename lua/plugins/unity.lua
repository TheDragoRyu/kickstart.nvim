local function is_unity_project()
  return vim.fn.isdirectory(vim.fn.getcwd() .. '/Assets') == 1
end

local function generate_guid()
  math.randomseed(vim.uv.hrtime())
  return ('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'):gsub('x', function()
    return string.format('%x', math.random(0, 15))
  end)
end

local function write_meta(cs_path)
  local meta_path = cs_path .. '.meta'
  if vim.fn.filereadable(meta_path) == 1 then return end
  local guid = generate_guid()
  local lines = {
    'fileFormatVersion: 2',
    'guid: ' .. guid,
    'MonoImporter:',
    '  externalObjects: {}',
    '  serializedVersion: 2',
    '  defaultReferences: []',
    '  executionOrder: 0',
    '  icon: {instanceID: 0}',
    '  userData: ',
    '  assetBundleName: ',
    '  assetBundleVariant: ',
  }
  vim.fn.writefile(lines, meta_path)
end

return {
  -- dummy spec so lazy.nvim loads this file
  dir = vim.fn.stdpath 'config',
  name = 'unity-meta',
  lazy = false,
  config = function()
    vim.api.nvim_create_autocmd('BufNewFile', {
      pattern = '*.cs',
      callback = function()
        if not is_unity_project() then return end
        local path = vim.fn.expand '%:p'
        -- defer so the file path is fully resolved
        vim.schedule(function()
          write_meta(path)
          vim.notify('Created ' .. vim.fn.fnamemodify(path, ':t') .. '.meta', vim.log.levels.INFO)
        end)
      end,
    })
  end,
}
