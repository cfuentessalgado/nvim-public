local M = {}

local ns = vim.api.nvim_create_namespace 'annotating_annotations'
local annotations_by_file = {}
local next_id = 0

local function hl(name)
  local ok, value = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return ok and value or {}
end

local function blend(fg, bg, alpha)
  if not fg or not bg then return nil end

  local function channel(value, shift)
    return math.floor(value / shift) % 256
  end

  local r = math.floor(channel(fg, 0x10000) * alpha + channel(bg, 0x10000) * (1 - alpha))
  local g = math.floor(channel(fg, 0x100) * alpha + channel(bg, 0x100) * (1 - alpha))
  local b = math.floor(channel(fg, 0x1) * alpha + channel(bg, 0x1) * (1 - alpha))

  return r * 0x10000 + g * 0x100 + b
end

local function setup_highlights()
  local normal = hl 'Normal'
  local error = hl 'DiagnosticError'
  local warn = hl 'DiagnosticWarn'
  local ok = hl 'DiagnosticOk'
  local hint = hl 'DiagnosticHint'
  local diff_delete = hl 'DiffDelete'
  local diff_add = hl 'DiffAdd'

  local bg = normal.bg
  local delete_fg = error.fg
  local good_fg = ok.fg or hint.fg
  local comment_fg = warn.fg or hint.fg
  local question_fg = hint.fg or warn.fg
  local delete_bg = blend(delete_fg, bg, 0.10) or diff_delete.bg
  local good_bg = blend(good_fg, bg, 0.10) or diff_add.bg
  local comment_bg = blend(comment_fg, bg, 0.10)
  local question_bg = blend(question_fg, bg, 0.10)

  vim.api.nvim_set_hl(0, 'AnnotatingDeleteLine', { bg = delete_bg })
  vim.api.nvim_set_hl(0, 'AnnotatingDeleteRange', { bg = delete_bg })
  vim.api.nvim_set_hl(0, 'AnnotatingDeleteText', { fg = delete_fg, italic = true })
  vim.api.nvim_set_hl(0, 'AnnotatingDeleteSign', { fg = delete_fg, bold = true })
  vim.api.nvim_set_hl(0, 'AnnotatingCommentRange', { bg = comment_bg })
  vim.api.nvim_set_hl(0, 'AnnotatingCommentText', { fg = comment_fg, italic = true })
  vim.api.nvim_set_hl(0, 'AnnotatingCommentSign', { fg = comment_fg, bold = true })
  vim.api.nvim_set_hl(0, 'AnnotatingQuestionRange', { bg = question_bg })
  vim.api.nvim_set_hl(0, 'AnnotatingQuestionText', { fg = question_fg, italic = true })
  vim.api.nvim_set_hl(0, 'AnnotatingQuestionSign', { fg = question_fg, bold = true })
  vim.api.nvim_set_hl(0, 'AnnotatingGoodLine', { bg = good_bg })
  vim.api.nvim_set_hl(0, 'AnnotatingGoodRange', { bg = good_bg })
  vim.api.nvim_set_hl(0, 'AnnotatingGoodText', { fg = good_fg, italic = true })
  vim.api.nvim_set_hl(0, 'AnnotatingGoodSign', { fg = good_fg, bold = true })
end

setup_highlights()
vim.api.nvim_create_autocmd('ColorScheme', { callback = setup_highlights })

local function filename_for(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then return '[No Name]' end
  return vim.fn.fnamemodify(name, ':p')
end

local function display_filename(filename)
  if filename == '[No Name]' then return filename end
  return vim.fn.fnamemodify(filename, ':.')
end

local function get_visual_range()
  local mode = vim.fn.visualmode()
  local start_pos = vim.fn.getpos "'<"
  local end_pos = vim.fn.getpos "'>"
  local start_row = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_row = end_pos[2] - 1
  local end_col = end_pos[3] - 1

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  if mode == 'V' then
    start_col = 0
    local line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1] or ''
    end_col = #line
  end

  return start_row, start_col, end_row, end_col
end

local function selected_text(bufnr, start_row, start_col, end_row, end_col)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  if vim.tbl_isempty(lines) then return '' end

  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_col + 1, math.max(start_col + 1, end_col))
  else
    lines[1] = string.sub(lines[1], start_col + 1)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
  end

  return table.concat(lines, '\n')
end

local function ensure_file(filename)
  annotations_by_file[filename] = annotations_by_file[filename] or {}
  return annotations_by_file[filename]
end

local function use_signs()
  return vim.g.annotating_use_signs == true
end

local function normalize_range(bufnr, start_row, start_col, end_row, end_col)
  if start_row == end_row and start_col == end_col then
    local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ''
    end_col = math.min(start_col + 1, #line)
  end

  return start_row, start_col, end_row, end_col
end

local function add_range_annotation_mark(bufnr, start_row, start_col, end_row, end_col, opts)
  start_row, start_col, end_row, end_col = normalize_range(bufnr, start_row, start_col, end_row, end_col)

  local ok, extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, start_row, start_col, {
    end_row = end_row,
    end_col = end_col,
    hl_group = opts.range_hl_group,
    sign_text = use_signs() and opts.sign_text or nil,
    sign_hl_group = use_signs() and opts.sign_hl_group or nil,
    virt_text = opts.virt_text,
    virt_text_pos = 'eol',
    hl_mode = 'combine',
    invalidate = true,
  })

  return ok and { extmark_id } or {}
end

local function add_annotation(item)
  next_id = next_id + 1
  item.order = next_id
  item.id = next_id
  table.insert(ensure_file(item.filename), item)
end

local function input_comment(callback)
  local width = math.min(math.floor(vim.o.columns * 0.7), 90)
  local height = 3
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid
  local closed = false

  local function resize()
    if vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_set_height(winid, math.min(math.max(vim.api.nvim_buf_line_count(bufnr), height), 12))
    end
  end

  local function close(value)
    if closed then return end
    closed = true
    if vim.api.nvim_win_is_valid(winid) then vim.api.nvim_win_close(winid, true) end
    callback(value)
  end

  local function submit()
    local value = vim.trim(table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n'))
    close(value ~= '' and value or nil)
  end

  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].bufhidden = 'wipe'
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = 'markdown'
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '' })

  winid = vim.api.nvim_open_win(bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = 'rounded',
    title = ' Annotation comment 󰆈  (<C-s>/<CR> submit, q/<Esc> cancel) ',
    title_pos = 'center',
    style = 'minimal',
  })

  vim.wo[winid].wrap = true
  vim.wo[winid].linebreak = true
  vim.keymap.set({ 'n', 'i' }, '<C-s>', submit, { buffer = bufnr, desc = 'Submit annotation comment' })
  vim.keymap.set('n', '<CR>', submit, { buffer = bufnr, desc = 'Submit annotation comment' })
  vim.keymap.set('n', 'q', function() close(nil) end, { buffer = bufnr, desc = 'Cancel annotation comment' })
  vim.keymap.set('n', '<Esc>', function() close(nil) end, { buffer = bufnr, desc = 'Cancel annotation comment' })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, { buffer = bufnr, callback = resize })
  vim.cmd.startinsert()
end

function M.delete_this()
  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = get_visual_range()
  local extmarks = add_range_annotation_mark(bufnr, start_row, start_col, end_row, end_col, {
    range_hl_group = 'AnnotatingDeleteRange',
    sign_text = '󰆴',
    sign_hl_group = 'AnnotatingDeleteSign',
    virt_text = { { ' 󰆴 scratch this idea', 'AnnotatingDeleteText' } },
  })

  add_annotation {
    kind = 'delete',
    bufnr = bufnr,
    filename = filename_for(bufnr),
    range_start = { line = start_row + 1, column = start_col + 1 },
    range_end = { line = end_row + 1, column = end_col + 1 },
    text = selected_text(bufnr, start_row, start_col, end_row, end_col),
    extmarks = extmarks,
  }
end

function M.good()
  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = get_visual_range()
  local extmarks = add_range_annotation_mark(bufnr, start_row, start_col, end_row, end_col, {
    range_hl_group = 'AnnotatingGoodRange',
    sign_text = '👍',
    sign_hl_group = 'AnnotatingGoodSign',
    virt_text = { { ' Good 👍', 'AnnotatingGoodText' } },
  })

  add_annotation {
    kind = 'good',
    bufnr = bufnr,
    filename = filename_for(bufnr),
    range_start = { line = start_row + 1, column = start_col + 1 },
    range_end = { line = end_row + 1, column = end_col + 1 },
    text = selected_text(bufnr, start_row, start_col, end_row, end_col),
    extmarks = extmarks,
  }
end

local function text_annotation(kind, icon, hl_group)
  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = get_visual_range()

  input_comment(function(comment)
    if not comment then return end

    local sign_hl_group = ({
      comment = 'AnnotatingCommentSign',
      question = 'AnnotatingQuestionSign',
    })[kind]
    local range_hl_group = ({
      comment = 'AnnotatingCommentRange',
      question = 'AnnotatingQuestionRange',
    })[kind]

    local extmarks = add_range_annotation_mark(bufnr, start_row, start_col, end_row, end_col, {
      range_hl_group = range_hl_group,
      sign_text = icon,
      sign_hl_group = sign_hl_group,
      virt_text = { { (' %s %s'):format(icon, comment), hl_group } },
    })

    add_annotation {
      kind = kind,
      bufnr = bufnr,
      filename = filename_for(bufnr),
      range_start = { line = start_row + 1, column = start_col + 1 },
      range_end = { line = end_row + 1, column = end_col + 1 },
      text = selected_text(bufnr, start_row, start_col, end_row, end_col),
      comment = comment,
      extmarks = extmarks,
    }
  end)
end

function M.comment()
  text_annotation('comment', '󰆈', 'AnnotatingCommentText')
end

function M.question()
  text_annotation('question', '', 'AnnotatingQuestionText')
end

function M.render_file(filename)
  filename = filename or filename_for(vim.api.nvim_get_current_buf())
  local items = annotations_by_file[filename] or {}
  if vim.tbl_isempty(items) then return nil, 0 end

  table.sort(items, function(a, b)
    if a.range_start.line == b.range_start.line then return a.order < b.order end
    return a.range_start.line < b.range_start.line
  end)

  local lines = {
    '# File annotations',
    '',
    ('File: `%s`'):format(display_filename(filename)),
    '',
    'Use these annotations as review feedback for this file only. Treat “Good” as content to preserve or build on. Treat “Delete this” as content to remove or reject. Treat “Question” as something to answer before changing the related code.',
    '',
  }

  for _, item in ipairs(items) do
    local title = ({
      delete = 'Delete this / scratch this idea',
      comment = 'Comment',
      question = 'Question',
      good = 'Good / keep this',
    })[item.kind] or item.kind

    table.insert(lines, ('## %s: lines %d-%d'):format(title, item.range_start.line, item.range_end.line))
    table.insert(lines, '')

    if item.comment then
      table.insert(lines, 'Annotation:')
      table.insert(lines, '')
      table.insert(lines, '```markdown')
      table.insert(lines, item.comment)
      table.insert(lines, '```')
      table.insert(lines, '')
    end

    table.insert(lines, 'Selected text:')
    table.insert(lines, '')
    table.insert(lines, '```')
    table.insert(lines, item.text or '')
    table.insert(lines, '```')
    table.insert(lines, '')
  end

  return table.concat(lines, '\n'), #items
end

function M.yank_file()
  local review, count = M.render_file()
  if not review then
    vim.notify('No annotations for current file', vim.log.levels.INFO)
    return
  end

  vim.fn.setreg('+', review)
  vim.fn.setreg('"', review)
  vim.notify(('Yanked %d annotation(s) for current file'):format(count), vim.log.levels.INFO)
end

function M.send_file_to_sidekick()
  local review, count = M.render_file()
  if not review then
    vim.notify('No annotations for current file', vim.log.levels.INFO)
    return
  end

  local ok_cli, sidekick_cli = pcall(require, 'sidekick.cli')
  local ok_text, sidekick_text = pcall(require, 'sidekick.text')
  if not ok_cli or not ok_text then
    vim.notify('sidekick.nvim is not available', vim.log.levels.ERROR)
    return
  end

  local ok_send, err = pcall(sidekick_cli.send, { text = sidekick_text.to_text(review) })
  if not ok_send then
    vim.notify(('Failed to send annotations to Sidekick: %s'):format(err), vim.log.levels.ERROR)
    return
  end

  M.clear_file { silent = true }
  vim.notify(('Sent %d annotation(s) for current file to Sidekick and cleared them'):format(count), vim.log.levels.INFO)
end

function M.clear_file(opts)
  opts = opts or {}
  local filename = filename_for(vim.api.nvim_get_current_buf())
  local items = annotations_by_file[filename] or {}
  if vim.tbl_isempty(items) then
    if not opts.silent then vim.notify('No annotations for current file', vim.log.levels.INFO) end
    return
  end

  for _, item in ipairs(items) do
    if vim.api.nvim_buf_is_valid(item.bufnr) then
      for _, extmark_id in ipairs(item.extmarks or {}) do
        pcall(vim.api.nvim_buf_del_extmark, item.bufnr, ns, extmark_id)
      end
    end
  end

  annotations_by_file[filename] = nil
  if not opts.silent then vim.notify(('Cleared %d annotation(s) for current file'):format(#items), vim.log.levels.INFO) end
end

vim.keymap.set('x', '<leader>pd', function()
  vim.cmd 'normal! \27'
  vim.schedule(M.delete_this)
end, { desc = 'Annotating: delete this / scratch idea' })

vim.keymap.set('x', '<leader>pc', function()
  vim.cmd 'normal! \27'
  vim.schedule(M.comment)
end, { desc = 'Annotating: comment selection' })

vim.keymap.set('x', '<leader>pg', function()
  vim.cmd 'normal! \27'
  vim.schedule(M.good)
end, { desc = 'Annotating: mark good' })

vim.keymap.set('x', '<leader>pq', function()
  vim.cmd 'normal! \27'
  vim.schedule(M.question)
end, { desc = 'Annotating: question selection' })

vim.keymap.set('n', '<leader>py', M.yank_file, { desc = 'Annotating: yank current file annotations' })
vim.keymap.set('n', '<leader>ps', M.send_file_to_sidekick, { desc = 'Annotating: send current file annotations' })
vim.keymap.set('n', '<leader>px', M.clear_file, { desc = 'Annotating: clear current file annotations' })

return M
