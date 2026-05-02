local function norm(p)
  if not p then return nil end
  return (vim.fs.normalize(p):gsub('/$', ''))
end

local function unity_root()
  local cwd = norm(vim.fn.getcwd())
  if cwd and vim.fn.isdirectory(cwd .. '/Assets') == 1 then return cwd end
  return nil
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

local function find_asmdef(start_dir, root)
  local dir = start_dir
  while dir and #dir >= #root and dir:sub(1, #root) == root do
    local hits = vim.fn.glob(dir .. '/*.asmdef', false, true)
    if #hits > 0 then return hits[1] end
    local parent = vim.fn.fnamemodify(dir, ':h')
    if parent == dir then break end
    dir = parent
  end
  return nil
end

local function csproj_for(file_path, root)
  local asmdef = find_asmdef(vim.fn.fnamemodify(file_path, ':h'), root)
  local name = 'Assembly-CSharp'
  if asmdef then
    local ok, content = pcall(vim.fn.readfile, asmdef)
    if ok and content then
      local s = table.concat(content, '\n')
      local n = s:match '"name"%s*:%s*"([^"]+)"'
      if n then name = n end
    end
  end
  return root .. '/' .. name .. '.csproj'
end

local function inject_compile(csproj_path, file_path, root)
  if vim.fn.filereadable(csproj_path) ~= 1 then return false, 'no csproj at ' .. csproj_path end
  local nfile = norm(file_path)
  local nroot = norm(root)
  if not nfile or not nroot or nfile:sub(1, #nroot + 1) ~= nroot .. '/' then
    return false, 'path not under root: ' .. tostring(nfile) .. ' vs ' .. tostring(nroot)
  end
  local rel = nfile:sub(#nroot + 2)
  local win_rel = rel:gsub('/', '\\')
  local lines = vim.fn.readfile(csproj_path)
  for _, l in ipairs(lines) do
    if l:find(win_rel, 1, true) or l:find(rel, 1, true) then
      return false, 'already present'
    end
  end
  local insert_at
  for i = #lines, 1, -1 do
    if lines[i]:match '</ItemGroup>' then
      insert_at = i
      break
    end
  end
  if not insert_at then return false, 'no ItemGroup' end
  table.insert(lines, insert_at, '    <Compile Include="' .. win_rel .. '" />')
  vim.fn.writefile(lines, csproj_path)
  return true, win_rel
end

local CSHARP_LSP_NAMES = { roslyn = true, roslyn_ls = true, easy_dotnet = true, omnisharp = true }

local function restart_roslyn(bufnr)
  local stopped = {}
  for _, c in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
    if CSHARP_LSP_NAMES[c.name] then
      vim.lsp.stop_client(c.id, false)
      stopped[#stopped + 1] = c.name
    end
  end
  if #stopped == 0 then return end
  local function wait_and_reedit(tries)
    for _, c in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
      if CSHARP_LSP_NAMES[c.name] then
        if tries > 0 then
          return vim.defer_fn(function() wait_and_reedit(tries - 1) end, 200)
        end
      end
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_call(bufnr, function() vim.cmd 'edit' end)
    end
  end
  wait_and_reedit(20)
end

return {
  -- dummy spec so lazy.nvim loads this file
  dir = vim.fn.stdpath 'config',
  name = 'unity-meta',
  lazy = false,
  config = function()
    local function ensure_meta(path)
      if vim.fn.filereadable(path .. '.meta') == 1 then return false end
      write_meta(path)
      vim.notify('Created ' .. vim.fn.fnamemodify(path, ':t') .. '.meta', vim.log.levels.INFO)
      return true
    end

    vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufReadPost' }, {
      pattern = '*.cs',
      callback = function()
        if not unity_root() then return end
        local path = vim.fn.expand '%:p'
        vim.schedule(function() ensure_meta(path) end)
      end,
    })

    local checked = {}

    vim.api.nvim_create_autocmd('BufWritePost', {
      pattern = '*.cs',
      callback = function(ev)
        if checked[ev.buf] then return end
        local root = unity_root()
        if not root then return end
        local path = vim.fn.expand '%:p'
        ensure_meta(path)
        local csproj = csproj_for(path, root)
        local ok, info = inject_compile(csproj, path, root)
        checked[ev.buf] = true
        if ok then
          vim.notify('[unity] Added "' .. info .. '" to ' .. vim.fn.fnamemodify(csproj, ':t'), vim.log.levels.INFO)
          restart_roslyn(ev.buf)
        end
      end,
    })

    vim.api.nvim_create_autocmd('BufDelete', {
      pattern = '*.cs',
      callback = function(ev) checked[ev.buf] = nil end,
    })

    vim.api.nvim_create_user_command('UnityInjectCurrent', function()
      local buf = vim.api.nvim_get_current_buf()
      local root = unity_root()
      if not root then
        vim.notify('[unity] no unity root', vim.log.levels.ERROR)
        return
      end
      local path = vim.fn.expand '%:p'
      local csproj = csproj_for(path, root)
      vim.notify('[unity] csproj=' .. csproj, vim.log.levels.INFO)
      local ok, info = inject_compile(csproj, path, root)
      if ok then
        vim.notify('[unity] Added "' .. info .. '"', vim.log.levels.INFO)
        restart_roslyn(buf)
      else
        vim.notify('[unity] ' .. tostring(info), vim.log.levels.WARN)
      end
    end, {})
  end,
}
