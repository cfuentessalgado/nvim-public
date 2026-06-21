local gh = require('custom.pack').gh

local telescope_plugins = {
  gh 'nvim-lua/plenary.nvim',
  gh 'nvim-telescope/telescope.nvim',
  gh 'nvim-telescope/telescope-ui-select.nvim',
}
if vim.fn.executable 'make' == 1 then table.insert(telescope_plugins, gh 'nvim-telescope/telescope-fzf-native.nvim') end
vim.pack.add(telescope_plugins)

local picker_prefs = {
  show_untracked = true,
  previewer = true,
  winblend = 10,
  border = true,
  layout_config = { width = 0.8, height = 0.6 },
}

require('telescope').setup {
  defaults = { preview = { treesitter = false } },
  pickers = {
    git_files = picker_prefs,
    find_files = picker_prefs,
    oldfiles = picker_prefs,
    buffers = picker_prefs,
  },
  extensions = {
    fzf = {},
    ['ui-select'] = { require('telescope.themes').get_dropdown() },
  },
}

pcall(require('telescope').load_extension, 'fzf')
pcall(require('telescope').load_extension, 'ui-select')

local builtin = require 'telescope.builtin'
vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>f', builtin.git_files, { desc = 'Search Git [F]iles' })
vim.keymap.set('n', '<leader>sc', builtin.git_status, { desc = 'Search [C]hanged' })
vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files' })
vim.keymap.set('n', '<leader>sx', builtin.commands, { desc = '[S]earch Commands' })
vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = 'Find existing buffers' })

local function plan_files(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or vim.uv.cwd()

  local files = {}
  local seen = {}

  local function add(path)
    if vim.fn.filereadable(path) ~= 1 or seen[path] then return end
    seen[path] = true
    local display = vim.fn.fnamemodify(path, ':~:.')
    table.insert(files, {
      value = path,
      path = path,
      filename = path,
      display = display,
      ordinal = display,
    })
  end

  for _, path in ipairs(vim.fn.globpath(opts.cwd, 'plans/**/*', true, true)) do
    add(path)
  end

  for _, path in ipairs(vim.fn.globpath(opts.cwd, '**/PLAN.md', true, true)) do
    add(path)
  end

  table.sort(files, function(a, b) return a.ordinal < b.ordinal end)

  require('telescope.pickers').new(opts, {
    prompt_title = 'Plan Files',
    finder = require('telescope.finders').new_table {
      results = files,
      entry_maker = function(entry) return entry end,
    },
    previewer = require('telescope.config').values.file_previewer(opts),
    sorter = require('telescope.config').values.generic_sorter(opts),
  }):find()
end

local function live_multigrep(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or vim.uv.cwd()

  local finder = require('telescope.finders').new_async_job {
    command_generator = function(prompt)
      if not prompt or prompt == '' then return nil end
      local pieces = vim.split(prompt, '  ')
      local args = { 'rg' }
      if pieces[1] then vim.list_extend(args, { '-e', pieces[1] }) end
      if pieces[2] then vim.list_extend(args, { '-g', pieces[2] }) end
      return vim.iter({ args, { '--color=never', '--no-heading', '--with-filename', '--line-number', '--column', '--smart-case' } }):flatten():totable()
    end,
    entry_maker = require('telescope.make_entry').gen_from_vimgrep(opts),
    cwd = opts.cwd,
  }

  require('telescope.pickers').new(opts, {
    debounce = 100,
    prompt_title = 'Multi Grep',
    finder = finder,
    previewer = require('telescope.config').values.grep_previewer(opts),
    sorter = require('telescope.sorters').empty(),
  }):find()
end

vim.keymap.set('n', '<leader>sg', live_multigrep, { desc = '[S]earch by [G]rep with glob' })
vim.keymap.set('n', '<leader>g', function() builtin.grep_string { search = vim.fn.input 'Grep > ' } end, { desc = 'Grep prompt' })
vim.keymap.set('n', '<leader>/', function()
  builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown { winblend = 10, previewer = false })
end, { desc = 'Fuzzily search in current buffer' })
vim.keymap.set('n', '<leader>s/', function()
  builtin.live_grep { grep_open_files = true, prompt_title = 'Live Grep in Open Files' }
end, { desc = '[S]earch in Open Files' })
vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end, { desc = '[S]earch [N]eovim files' })
vim.keymap.set('n', '<leader>sp', plan_files, { desc = '[S]earch [P]lan files' })

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
  callback = function(event)
    local buf = event.buf
    vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })
    vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })
    vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })
    vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })
    vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })
    vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })
  end,
})
