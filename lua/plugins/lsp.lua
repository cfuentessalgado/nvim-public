local gh = require('custom.pack').gh

vim.pack.add {
  gh 'j-hui/fidget.nvim',
  gh 'folke/lazydev.nvim',
  gh 'neovim/nvim-lspconfig',
  gh 'mason-org/mason.nvim',
  gh 'mason-org/mason-lspconfig.nvim',
  gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
  { src = gh 'saghen/blink.cmp', version = vim.version.range '1.*' },
}

require('fidget').setup {}
require('lazydev').setup { library = { { path = '${3rd}/luv/library', words = { 'vim%.uv' } } } }

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
  callback = function(event)
    local map = function(keys, func, desc, mode)
      mode = mode or 'n'
      vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
    end

    map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
    map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
    map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
    map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
    map('<leader>wd', require('telescope.builtin').diagnostics, '[W]orkspace [D]iagnostics')
    map('<leader>dd', function() require('telescope.builtin').diagnostics { bufnr = 0 } end, '[D]ocument [D]iagnostics')
    map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
    map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
    map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
    map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })
    map('K', vim.lsp.buf.hover, 'Hover Documentation')
    map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
      local group = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, { buffer = event.buf, group = group, callback = vim.lsp.buf.document_highlight })
      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, { buffer = event.buf, group = group, callback = vim.lsp.buf.clear_references })
      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
        end,
      })
    end

    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
      map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
    end

    map('<leader>td', function()
      local current = vim.diagnostic.config().virtual_text
      vim.diagnostic.config { virtual_text = not current }
    end, '[T]oggle [D]iagnostic virtual text')
    map('<leader>cf', function() require('conform').format { async = true, lsp_format = 'fallback' } end, '[C]ode [F]ormat')
    vim.api.nvim_buf_create_user_command(event.buf, 'Format', function() require('conform').format { lsp_format = 'fallback' } end, { desc = 'Format current buffer with conform' })
  end,
})

vim.diagnostic.config {
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = true,
  signs = vim.g.have_nerd_font and {
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚 ',
      [vim.diagnostic.severity.WARN] = '󰀪 ',
      [vim.diagnostic.severity.INFO] = '󰋽 ',
      [vim.diagnostic.severity.HINT] = '󰌶 ',
    },
  } or {},
  virtual_text = false,
}

local servers = {
  gopls = {},
  rust_analyzer = {},
  ts_ls = { filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' } },
  -- phpantom_lsp = {
  --   cmd = { 'phpantom_lsp'},
  --   filetypes = { 'php'},
  --   root_markers = { 'composer.json', '.git' },
  -- },
  intelephense = {
    filetypes = { 'php' },
    settings = {
      intelephense = {
        inlayHints = {
          parameterNames = { enabled = 'all' },
          variableTypes = { enabled = true },
          propertyDeclarationTypes = { enabled = true },
          functionLikeReturnTypes = { enabled = true },
        },
      },
    },
  },
  bashls = {},
  html = {},
  emmet_language_server = {
    filetypes = { 'css', 'eruby', 'html', 'javascript', 'javascriptreact', 'less', 'sass', 'scss', 'pug', 'typescriptreact', 'blade', 'vue' },
  },
  lua_ls = {
    on_init = function(client)
      client.server_capabilities.documentFormattingProvider = false
      if client.workspace_folders then
        local path = client.workspace_folders[1].name
        if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
      end
      client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
        runtime = { version = 'LuaJIT', path = { 'lua/?.lua', 'lua/?/init.lua' } },
        workspace = {
          checkThirdParty = false,
          library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), { '${3rd}/luv/library', '${3rd}/busted/library' }),
        },
      })
    end,
    settings = { Lua = { format = { enable = false } } },
  },
}

require('mason').setup {}
local ensure_installed = vim.tbl_keys(servers or {})
vim.list_extend(ensure_installed, { 'stylua' })
require('mason-tool-installer').setup { ensure_installed = ensure_installed }

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_deep_extend('force', capabilities, require('blink.cmp').get_lsp_capabilities())
for name, server in pairs(servers) do
  server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
  vim.lsp.config(name, server)
  vim.lsp.enable(name)
end
