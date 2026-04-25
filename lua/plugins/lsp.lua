local ensure_installed = { 'gopls', 'pyright', 'lua_ls' }

return {
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      { 'WhoIsSethDaniel/mason-tool-installer.nvim', opts = { ensure_installed = ensure_installed } },
      { 'j-hui/fidget.nvim', opts = {} },
      'saghen/blink.cmp',
    },
    config = function()
      local csharp_lsp_clients = {
        easy_dotnet = true,
        roslyn = true,
      }

      local unity_project_cache = {}

      local function is_csharp_lsp_client(client_id)
        local client = vim.lsp.get_client_by_id(client_id)
        return client and csharp_lsp_clients[client.name] == true
      end

      local function is_unity_csharp_buffer(bufnr)
        if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= 'cs' then
          return false
        end

        local filename = vim.api.nvim_buf_get_name(bufnr)
        if filename == '' then
          return false
        end

        local cached = unity_project_cache[filename]
        if cached ~= nil then
          return cached
        end

        local project_settings = vim.fs.find('ProjectSettings', {
          path = vim.fs.dirname(filename),
          upward = true,
          type = 'directory',
        })[1]
        local is_unity = project_settings and vim.uv.fs_stat(vim.fs.joinpath(project_settings, 'ProjectVersion.txt')) ~= nil or false

        unity_project_cache[filename] = is_unity
        return is_unity
      end

      local function diagnostic_code(diagnostic)
        local code = diagnostic and diagnostic.code
        if type(code) == 'table' then
          code = code.value or code.code
        end

        return code and tostring(code) or nil
      end

      local function diagnostic_message(diagnostic)
        local message = diagnostic and diagnostic.message
        if type(message) == 'table' then
          message = message.value
        end

        return type(message) == 'string' and message or ''
      end

      local function diagnostic_range(diagnostic)
        if diagnostic and diagnostic.range then
          return diagnostic.range.start.line, diagnostic.range['end'].line
        end

        local start_line = diagnostic and diagnostic.lnum or 0
        return start_line, diagnostic and diagnostic.end_lnum or start_line
      end

      local function has_serializefield_attribute(bufnr, line)
        if not is_unity_csharp_buffer(bufnr) then
          return false
        end

        for lnum = line, math.max(line - 6, 0), -1 do
          local text = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ''
          local attribute_text = text:match '^%s*%[(.-)%]'

          if attribute_text and attribute_text:find('SerializeField', 1, true) then
            return true
          end

          -- Only walk through an attribute block directly attached to the field.
          if lnum ~= line and not attribute_text then
            return false
          end
        end

        return false
      end

      local function is_serializefield_readonly_diagnostic(diagnostic, bufnr)
        local message = diagnostic_message(diagnostic):lower()
        local is_make_field_readonly = diagnostic_code(diagnostic) == 'IDE0044' or message:find('make field readonly', 1, true)

        if not is_make_field_readonly then
          return false
        end

        local start_line, end_line = diagnostic_range(diagnostic)
        for line = start_line, end_line do
          if has_serializefield_attribute(bufnr, line) then
            return true
          end
        end

        return has_serializefield_attribute(bufnr, start_line)
      end

      local function filter_serializefield_readonly_diagnostics(diagnostics, bufnr)
        return vim.tbl_filter(function(diagnostic)
          return not is_serializefield_readonly_diagnostic(diagnostic, bufnr)
        end, diagnostics or {})
      end

      local methods = vim.lsp.protocol.Methods
      vim.lsp.handlers[methods.textDocument_publishDiagnostics] = function(err, result, ctx, config)
        if result and result.diagnostics and is_csharp_lsp_client(ctx.client_id) then
          local bufnr = vim.uri_to_bufnr(result.uri)
          if is_unity_csharp_buffer(bufnr) then
            result = vim.tbl_extend('force', result, {
              diagnostics = filter_serializefield_readonly_diagnostics(result.diagnostics, bufnr),
            })
          end
        end

        return vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx, config)
      end

      vim.lsp.handlers[methods.textDocument_diagnostic] = function(err, result, ctx)
        if result and result.items and ctx.params and ctx.params.textDocument and is_csharp_lsp_client(ctx.client_id) then
          local bufnr = vim.uri_to_bufnr(ctx.params.textDocument.uri)
          if is_unity_csharp_buffer(bufnr) then
            result = vim.tbl_extend('force', result, {
              items = filter_serializefield_readonly_diagnostics(result.items, bufnr),
            })
          end
        end

        return vim.lsp.diagnostic.on_diagnostic(err, result, ctx)
      end

      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          local telescope = require 'telescope.builtin'
          local uses_direct_navigation = client and (client.name == 'roslyn' or client.name == 'easy_dotnet')
          local uses_csharp_lens = uses_direct_navigation

          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('gn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('ga', function()
            vim.lsp.buf.code_action {
              filter = function(action)
                if not uses_direct_navigation or not is_unity_csharp_buffer(event.buf) then
                  return true
                end

                local title = (action.title or ''):lower()
                local is_readonly_action = title:find('readonly', 1, true) and title:find('field', 1, true)

                if is_readonly_action and has_serializefield_attribute(event.buf, vim.api.nvim_win_get_cursor(0)[1] - 1) then
                  return false
                end

                for _, diagnostic in ipairs(action.diagnostics or {}) do
                  if is_serializefield_readonly_diagnostic(diagnostic, event.buf) then
                    return false
                  end
                end

                return true
              end,
            }
          end, '[G]oto Code [A]ction', { 'n', 'x' })
          map('gr', uses_direct_navigation and vim.lsp.buf.references or telescope.lsp_references, '[G]oto [R]eferences')
          map('gi', uses_direct_navigation and vim.lsp.buf.implementation or telescope.lsp_implementations, '[G]oto [I]mplementation')
          map('gd', uses_direct_navigation and vim.lsp.buf.definition or telescope.lsp_definitions, '[G]oto [D]efinition')
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
          map('gO', telescope.lsp_document_symbols, 'Open Document Symbols')
          map('gW', telescope.lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')
          map('grt', uses_direct_navigation and vim.lsp.buf.type_definition or telescope.lsp_type_definitions, '[G]oto [T]ype Definition')

          ---@param client vim.lsp.Client
          ---@param method vim.lsp.protocol.Method
          ---@param bufnr? integer some lsp support methods only in specific files
          ---@return boolean
          local function client_supports_method(client, method, bufnr)
            if vim.fn.has 'nvim-0.11' == 1 then
              return client:supports_method(method, bufnr)
            else
              return client.supports_method(method, { bufnr = bufnr })
            end
          end

          if client and uses_csharp_lens and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_codeLens, event.buf) then
            local codelens_augroup = vim.api.nvim_create_augroup('kickstart-lsp-codelens', { clear = false })
            local refresh_codelens = function()
              if not vim.api.nvim_buf_is_valid(event.buf) then
                return
              end
              vim.lsp.codelens.refresh { bufnr = event.buf }
            end

            -- Roslyn CodeLens is expensive in Unity solutions; refresh it at
            -- stable points instead of on cursor movement or idle events.
            for _, delay in ipairs { 2000, 10000 } do
              vim.defer_fn(refresh_codelens, delay)
            end
            vim.api.nvim_clear_autocmds { group = codelens_augroup, buffer = event.buf }
            vim.api.nvim_create_autocmd('BufWritePost', {
              buffer = event.buf,
              group = codelens_augroup,
              callback = refresh_codelens,
            })

            map('<leader>cl', refresh_codelens, 'Refresh Code[L]ens')
            map('<leader>cL', vim.lsp.codelens.run, 'Run Code[L]ens')
          end

          -- Highlight references of the word under cursor on CursorHold
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- Diagnostic Config
      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
          },
        } or {},
        virtual_text = {
          source = 'if_many',
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }

      -- Platform-aware Python config
      local sysname = vim.loop.os_uname().sysname
      local python_platform = 'Linux'

      if sysname:match 'Windows' then
        python_platform = 'Windows'
      elseif sysname:match 'Darwin' then
        python_platform = 'Darwin'
      end

      local python_path = './.venv/bin/python'
      if python_platform == 'Windows' then
        python_path = '.\\.venv\\Scripts\\python.exe'
      end

      local capabilities = require('blink.cmp').get_lsp_capabilities()

      local server_configs = {
        gopls = {},
        pyright = {
          settings = {
            python = {
              venvPath = '.',
              venv = '.venv',
              pythonPath = python_path,
              pythonPlatform = python_platform,
              analysis = {
                autoSearchPaths = true,
                diagnosticMode = 'workspace',
                useLibraryCodeForTypes = true,
                extraPaths = { '.', 'src', 'config', 'utils', 'app' },
              },
            },
          },
        },
        lua_ls = {
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
            },
          },
        },
      }

      for name, config in pairs(server_configs) do
        local merged = vim.tbl_deep_extend('force', {
          capabilities = capabilities,
        }, config or {})

        vim.lsp.config(name, merged)
      end

      require('mason-lspconfig').setup {
        ensure_installed = {},
        automatic_installation = false,
        handlers = {
          function(server_name)
            vim.lsp.enable(server_name)
          end,
        },
      }
    end,
  },
}
