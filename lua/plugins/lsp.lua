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
      { 'j-hui/fidget.nvim', opts = { notification = { override_vim_notify = true } } },
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
      local definition_method = methods.textDocument_definition or 'textDocument/definition'
      local prepare_call_hierarchy_method = methods.textDocument_prepareCallHierarchy or 'textDocument/prepareCallHierarchy'
      local incoming_calls_method = methods.callHierarchy_incomingCalls or 'callHierarchy/incomingCalls'

      ---@param client vim.lsp.Client
      ---@param method vim.lsp.protocol.Method|string
      ---@param bufnr? integer some lsp support methods only in specific files
      ---@return boolean
      local function client_supports_method(client, method, bufnr)
        if vim.fn.has 'nvim-0.11' == 1 then
          return client:supports_method(method, bufnr)
        else
          return client.supports_method(method, { bufnr = bufnr })
        end
      end

      local function as_lsp_location_list(result)
        if not result then
          return {}
        end

        if result.uri or result.targetUri then
          return { result }
        end

        return result
      end

      local function position_is_in_range(position, range)
        if not position or not range then
          return false
        end

        if position.line < range.start.line or position.line > range['end'].line then
          return false
        end

        if position.line == range.start.line and position.character < range.start.character then
          return false
        end

        if position.line == range['end'].line and position.character > range['end'].character then
          return false
        end

        return true
      end

      local function definition_result_contains_position(result, bufnr, position)
        local current_uri = vim.uri_from_bufnr(bufnr)

        for _, location in ipairs(as_lsp_location_list(result)) do
          local uri = location.targetUri or location.uri
          local range = location.targetSelectionRange or location.range or location.targetRange

          if uri == current_uri and position_is_in_range(position, range) then
            return true
          end
        end

        return false
      end

      local function as_call_hierarchy_item_list(result)
        if not result then
          return {}
        end

        if result.uri then
          return { result }
        end

        return result
      end

      local function format_call_hierarchy_item(item)
        if item.detail and item.detail ~= '' then
          return string.format('%s - %s', item.name, item.detail)
        end

        return item.name
      end

      local function incoming_call_locations(result)
        local locations = {}

        for _, call in ipairs(result or {}) do
          local from = call.from

          if from and from.uri then
            for _, range in ipairs(call.fromRanges or {}) do
              locations[#locations + 1] = {
                uri = from.uri,
                range = range,
                text = format_call_hierarchy_item(from),
              }
            end
          end
        end

        return locations
      end

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
          local goto_definition = function()
            if uses_direct_navigation then
              vim.lsp.buf.definition()
            else
              telescope.lsp_definitions()
            end
          end

          local goto_references_as_callers = function()
            telescope.lsp_references { include_declaration = false }
          end

          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          local function open_incoming_calls_picker(locations)
            local opts = { bufnr = event.buf }
            local conf = require('telescope.config').values
            local finders = require 'telescope.finders'
            local make_entry = require 'telescope.make_entry'
            local pickers = require 'telescope.pickers'
            local quickfix_entries = vim.tbl_map(function(location)
              return {
                filename = vim.uri_to_fname(location.uri),
                lnum = location.range.start.line + 1,
                col = location.range.start.character + 1,
                text = location.text,
              }
            end, locations)

            pickers
              .new(opts, {
                prompt_title = 'LSP Incoming Calls',
                finder = finders.new_table {
                  results = quickfix_entries,
                  entry_maker = make_entry.gen_from_quickfix(opts),
                },
                previewer = conf.qflist_previewer(opts),
                sorter = conf.generic_sorter(opts),
                push_cursor_on_edit = true,
                push_tagstack_on_edit = true,
              })
              :find()
          end

          local function jump_to_incoming_call(location)
            vim.lsp.util.show_document({
              uri = location.uri,
              range = location.range,
            }, client.offset_encoding, { reuse_win = true, focus = true })
          end

          local function handle_incoming_calls(result)
            local locations = incoming_call_locations(result)

            if #locations == 0 then
              vim.notify('No callers found', vim.log.levels.INFO)
            elseif #locations == 1 then
              jump_to_incoming_call(locations[1])
            else
              open_incoming_calls_picker(locations)
            end
          end

          local function request_incoming_calls(item)
            client:request(incoming_calls_method, { item = item }, function(err, result)
              vim.schedule(function()
                if err then
                  vim.notify('Incoming calls unavailable: ' .. err.message, vim.log.levels.WARN)
                  goto_references_as_callers()
                  return
                end

                handle_incoming_calls(result)
              end)
            end, event.buf)
          end

          local function choose_call_hierarchy_item(items)
            if #items == 0 then
              goto_references_as_callers()
            elseif #items == 1 then
              request_incoming_calls(items[1])
            else
              vim.ui.select(items, {
                prompt = 'Select call hierarchy item:',
                format_item = format_call_hierarchy_item,
              }, function(item)
                if item then
                  request_incoming_calls(item)
                end
              end)
            end
          end

          local function goto_incoming_calls_or_references()
            if
              not client
              or not client_supports_method(client, prepare_call_hierarchy_method, event.buf)
              or not client_supports_method(client, incoming_calls_method, event.buf)
            then
              goto_references_as_callers()
              return
            end

            local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
            client:request(prepare_call_hierarchy_method, params, function(err, result)
              vim.schedule(function()
                if err then
                  vim.notify('Call hierarchy unavailable: ' .. err.message, vim.log.levels.WARN)
                  goto_references_as_callers()
                  return
                end

                choose_call_hierarchy_item(as_call_hierarchy_item_list(result))
              end)
            end, event.buf)
          end

          local function goto_definition_or_callers()
            if not client or not client_supports_method(client, definition_method, event.buf) then
              goto_definition()
              return
            end

            local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
            client:request(definition_method, params, function(err, result)
              vim.schedule(function()
                if err or not definition_result_contains_position(result, event.buf, params.position) then
                  goto_definition()
                  return
                end

                goto_incoming_calls_or_references()
              end)
            end, event.buf)
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
          map('gd', goto_definition_or_callers, '[G]oto [D]efinition or callers')
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
          map('gO', telescope.lsp_document_symbols, 'Open Document Symbols')
          map('gW', telescope.lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')
          map('grt', uses_direct_navigation and vim.lsp.buf.type_definition or telescope.lsp_type_definitions, '[G]oto [T]ype Definition')

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

          -- Highlight references of the word under cursor on CursorHold.
          -- Skip on C# (Roslyn round-trip is too slow) and on huge buffers.
          local function highlight_eligible(buf)
            if vim.bo[buf].filetype == 'cs' then
              return false
            end
            return vim.api.nvim_buf_line_count(buf) <= 3000
          end

          if
            client
            and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf)
            and highlight_eligible(event.buf)
          then
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
