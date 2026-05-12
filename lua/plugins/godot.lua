local GODOT_LSP_PORT = 6005
local GODOT_DAP_PORT = 6006
local GODOT_HOST = '127.0.0.1'
local CSHARP_LSP_CLIENTS = {
  easy_dotnet = true,
  roslyn = true,
  roslyn_ls = true,
}

local function norm(path)
  if not path or path == '' then
    return nil
  end

  return (vim.fs.normalize(path):gsub('/$', ''))
end

local function godot_root(start)
  start = norm(start or vim.fn.expand '%:p:h')
  if not start then
    start = norm(vim.fn.getcwd())
  end

  if not start then
    return nil
  end

  local stat = vim.uv.fs_stat(start)
  if stat and stat.type == 'file' then
    start = vim.fs.dirname(start)
  end

  local project_file = vim.fs.find('project.godot', {
    path = start,
    upward = true,
    type = 'file',
  })[1]

  return project_file and norm(vim.fs.dirname(project_file)) or nil
end

local function godot_host()
  return vim.g.godot_host or vim.g.godot_lsp_host or GODOT_HOST
end

local function godot_lsp_port()
  return tonumber(vim.g.godot_lsp_port) or GODOT_LSP_PORT
end

local function godot_dap_port()
  return tonumber(vim.g.godot_dap_port) or GODOT_DAP_PORT
end

local function godot_executable()
  local configured = vim.g.godot_executable or vim.env.GODOT_BIN
  if configured and configured ~= '' and vim.fn.executable(configured) == 1 then
    return configured
  end

  for _, candidate in ipairs { 'godot', 'godot4' } do
    local exe = vim.fn.exepath(candidate)
    if exe ~= '' then
      return exe
    end
  end

  return nil
end

local function first_root_file(root, pattern)
  local matches = vim.fn.globpath(root, pattern, false, true)

  if type(matches) ~= 'table' or #matches == 0 then
    return nil
  end

  table.sort(matches)
  return matches[1]
end

local function godot_build_target(root)
  return first_root_file(root, '*.sln') or first_root_file(root, '*.csproj')
end

local function path_basename(path)
  return vim.fs.basename and vim.fs.basename(path) or vim.fn.fnamemodify(path, ':t')
end

local function active_lsp_clients(bufnr)
  local names = {}

  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
    names[#names + 1] = client.name
  end

  table.sort(names)
  return #names > 0 and table.concat(names, ', ') or 'none'
end

local function client_root_matches(client, root)
  local client_root = client.root_dir or client.config and client.config.root_dir
  return norm(client_root) == norm(root)
end

return {
  dir = vim.fs.joinpath(vim.fn.stdpath 'config', 'lua', 'plugins'),
  name = 'godot',
  lazy = false,
  dependencies = {
    'neovim/nvim-lspconfig',
    'saghen/blink.cmp',
  },
  config = function()
    vim.filetype.add {
      extension = {
        gd = 'gdscript',
      },
    }

    local capabilities = {}
    local ok, blink = pcall(require, 'blink.cmp')
    if ok then
      capabilities = blink.get_lsp_capabilities()
    end

    vim.lsp.config('gdscript', {
      cmd = vim.lsp.rpc.connect(godot_host(), godot_lsp_port()),
      filetypes = { 'gd', 'gdscript', 'gdscript3' },
      root_markers = { 'project.godot' },
      capabilities = capabilities,
    })
    vim.lsp.enable 'gdscript'

    vim.api.nvim_create_user_command('GodotOpenProject', function()
      local root = godot_root()
      if not root then
        vim.notify('[godot] no project.godot found', vim.log.levels.ERROR)
        return
      end

      local exe = godot_executable()
      if not exe then
        vim.notify('[godot] no godot executable found; set vim.g.godot_executable or GODOT_BIN', vim.log.levels.ERROR)
        return
      end

      local job = vim.fn.jobstart({ exe, '--path', root, '--editor' }, { detach = true })
      if job <= 0 then
        vim.notify('[godot] failed to start editor', vim.log.levels.ERROR)
        return
      end

      vim.notify('[godot] opening ' .. root, vim.log.levels.INFO)
    end, {})

    local function build_project()
      local root = godot_root()
      if not root then
        vim.notify('[godot] no project.godot found', vim.log.levels.ERROR)
        return
      end

      if vim.fn.executable 'dotnet' ~= 1 then
        vim.notify('[godot] dotnet not found on PATH', vim.log.levels.ERROR)
        return
      end

      local target = godot_build_target(root)
      if not target then
        vim.notify('[godot] no .sln or .csproj found at project root', vim.log.levels.ERROR)
        return
      end

      local lines = {}
      local function collect(_, data)
        for _, line in ipairs(data or {}) do
          if line ~= '' then
            lines[#lines + 1] = line
          end
        end
      end

      vim.notify('[godot] building ' .. path_basename(target), vim.log.levels.INFO)
      local job = vim.fn.jobstart({ 'dotnet', 'build', target }, {
        cwd = root,
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = collect,
        on_stderr = collect,
        on_exit = function(_, code)
          vim.schedule(function()
            vim.fn.setqflist({}, ' ', {
              title = 'Godot Build',
              lines = lines,
            })

            if code == 0 then
              vim.notify('[godot] build succeeded', vim.log.levels.INFO)
            else
              vim.notify('[godot] build failed; see quickfix', vim.log.levels.ERROR)
              vim.cmd.copen()
            end
          end)
        end,
      })

      if job <= 0 then
        vim.notify('[godot] failed to start dotnet build', vim.log.levels.ERROR)
      end
    end

    vim.api.nvim_create_user_command('GodotBuild', build_project, {})
    vim.keymap.set('n', '<leader>gb', build_project, { desc = 'Godot: Build C# project' })

    local function reload_csharp_lsp()
      local root = godot_root()
      if not root then
        vim.notify('[godot] no project.godot found', vim.log.levels.ERROR)
        return
      end

      local stopped = false
      for _, client in ipairs(vim.lsp.get_clients()) do
        if CSHARP_LSP_CLIENTS[client.name] and client_root_matches(client, root) then
          stopped = true
          vim.lsp.stop_client(client.id, true)
        end
      end

      vim.defer_fn(function()
        local started = false
        for _, name in ipairs { 'roslyn_ls', 'roslyn' } do
          if vim.lsp.config[name] then
            started = true
            pcall(vim.lsp.enable, name)
            pcall(vim.cmd, 'LspStart ' .. name)
          end
        end

        if started then
          local action = stopped and 'reloaded' or 'started'
          vim.notify('[godot] C# language server ' .. action, vim.log.levels.INFO)
        else
          vim.notify('[godot] no Roslyn LSP config found', vim.log.levels.ERROR)
        end
      end, stopped and 750 or 0)
    end

    vim.api.nvim_create_user_command('GodotReloadCSharp', reload_csharp_lsp, {})
    vim.keymap.set('n', '<leader>gR', reload_csharp_lsp, { desc = 'Godot: Reload C# language server' })

    vim.api.nvim_create_user_command('GodotInfo', function()
      local root = godot_root()
      local exe = godot_executable()
      local lines = {
        '[godot] root: ' .. (root or 'not found'),
        '[godot] executable: ' .. (exe or 'not found'),
        '[godot] lsp: ' .. godot_host() .. ':' .. godot_lsp_port(),
        '[godot] dap: ' .. (vim.g.godot_dap_host or vim.g.godot_host or GODOT_HOST) .. ':' .. godot_dap_port(),
        '[godot] active lsp clients: ' .. active_lsp_clients(vim.api.nvim_get_current_buf()),
      }

      vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
    end, {})
  end,
}
