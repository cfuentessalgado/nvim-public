local M = {}

local scratch_dir = vim.fs.joinpath(vim.fn.stdpath 'cache', 'scratch')
local group = vim.api.nvim_create_augroup('custom-scratch-files', { clear = true })
local scratch_files = {}

local function sanitize_name(name)
  name = vim.trim(name or '')
  if name == '' then
    return nil
  end

  -- Keep it inside the scratch directory even if the prompt receives a path.
  return vim.fs.basename(name)
end

local function delete_file(path)
  if path and vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
  end
end

function M.edit()
  vim.ui.input({ prompt = 'Scratch file name: ', default = 'scratch.' }, function(input)
    local name = sanitize_name(input)
    if not name then
      return
    end

    vim.fn.mkdir(scratch_dir, 'p')

    local path = vim.fs.joinpath(scratch_dir, string.format('%s-%s', os.time(), name))
    vim.fn.writefile({}, path)

    vim.cmd.edit(vim.fn.fnameescape(path))
    local bufnr = vim.api.nvim_get_current_buf()

    scratch_files[bufnr] = path

    vim.b[bufnr].scratch_file = true
    vim.bo[bufnr].bufhidden = 'hide'
    vim.bo[bufnr].swapfile = false

    vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
      group = group,
      buffer = bufnr,
      once = true,
      callback = function(args)
        delete_file(scratch_files[args.buf])
        scratch_files[args.buf] = nil
      end,
    })
  end)
end

vim.api.nvim_create_autocmd('VimLeavePre', {
  group = group,
  callback = function()
    for bufnr, path in pairs(scratch_files) do
      delete_file(path)
      scratch_files[bufnr] = nil
    end
  end,
})

vim.keymap.set('n', '<leader>sef', M.edit, { desc = '[S]cratch [E]dit [F]ile' })

return M
