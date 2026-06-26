local M = {}

local ns = vim.api.nvim_create_namespace 'feedback_items'
local items = {}
local file_comment_windows = {}
local next_id = 0
local did_setup = false
local state_loaded = false

local function project_root()
  local result = vim.system({ 'git', 'rev-parse', '--show-toplevel' }, { text = true }):wait()
  if result.code == 0 then
    local root = vim.trim(result.stdout or '')
    if root ~= '' then return vim.fs.normalize(root) end
  end
  return vim.fs.normalize(vim.loop.cwd() or vim.fn.getcwd())
end

local function storage_path()
  local dir = vim.fs.joinpath(vim.fn.stdpath 'data', 'feedback')
  local key = vim.fn.sha256(project_root())
  return dir, vim.fs.joinpath(dir, key .. '.json')
end

local function serializable_item(item)
  return {
    id = item.id,
    order = item.order,
    kind = item.kind,
    scope = item.scope,
    filename = item.filename,
    range_start = item.range_start,
    range_end = item.range_end,
    text = item.text,
    comment = item.comment,
  }
end

local function save_state()
  if not state_loaded then return end
  local dir, path = storage_path()
  if #items == 0 then
    pcall(vim.fn.delete, path)
    return
  end
  local state_items = {}
  for _, item in ipairs(items) do table.insert(state_items, serializable_item(item)) end
  local encoded = vim.json.encode { version = 1, root = project_root(), next_id = next_id, items = state_items }
  vim.fn.mkdir(dir, 'p')
  local tmp = path .. '.tmp'
  vim.fn.writefile({ encoded }, tmp)
  vim.fn.rename(tmp, path)
end

local function load_state()
  local _, path = storage_path()
  state_loaded = true
  if vim.fn.filereadable(path) ~= 1 then return end
  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), '\n'))
  if not ok or type(decoded) ~= 'table' or decoded.version ~= 1 or type(decoded.items) ~= 'table' then return end
  items = {}
  next_id = tonumber(decoded.next_id) or 0
  for _, item in ipairs(decoded.items) do
    if type(item) == 'table' and item.kind and item.scope and item.filename then
      item.bufnr = nil
      item.extmarks = {}
      table.insert(items, item)
      next_id = math.max(next_id, tonumber(item.id) or 0, tonumber(item.order) or 0)
    end
  end
end

local function hl(name)
  local ok, value = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return ok and value or {}
end

local function blend(fg, bg, alpha)
  if not fg or not bg then return nil end
  local function channel(value, shift) return math.floor(value / shift) % 256 end
  local r = math.floor(channel(fg, 0x10000) * alpha + channel(bg, 0x10000) * (1 - alpha))
  local g = math.floor(channel(fg, 0x100) * alpha + channel(bg, 0x100) * (1 - alpha))
  local b = math.floor(channel(fg, 0x1) * alpha + channel(bg, 0x1) * (1 - alpha))
  return r * 0x10000 + g * 0x100 + b
end

local function setup_highlights()
  local normal = hl 'Normal'
  local normal_float = hl 'NormalFloat'
  local float_border = hl 'FloatBorder'
  local float_title = hl 'FloatTitle'
  local error = hl 'DiagnosticError'
  local warn = hl 'DiagnosticWarn'
  local ok = hl 'DiagnosticOk'
  local hint = hl 'DiagnosticHint'
  local directory = hl 'Directory'
  local diff_delete = hl 'DiffDelete'
  local diff_add = hl 'DiffAdd'

  local bg = normal.bg
  local fg = normal_float.fg or normal.fg
  local border_fg = hint.fg or directory.fg or float_border.fg or fg
  local title_fg = float_title.fg or fg
  local delete_fg = error.fg
  local good_fg = ok.fg or hint.fg
  local comment_fg = warn.fg or hint.fg
  local question_fg = hint.fg or warn.fg

  vim.api.nvim_set_hl(0, 'FeedbackFloat', { fg = fg, bg = bg })
  vim.api.nvim_set_hl(0, 'FeedbackFloatBorder', { fg = border_fg, bg = bg })
  vim.api.nvim_set_hl(0, 'FeedbackFloatTitle', { fg = title_fg, bg = bg, bold = true })
  vim.api.nvim_set_hl(0, 'FeedbackMuted', { fg = border_fg, bg = bg, italic = true })
  vim.api.nvim_set_hl(0, 'FeedbackCommentText', { fg = comment_fg, italic = true })
  vim.api.nvim_set_hl(0, 'FeedbackCommentRange', { bg = blend(comment_fg, bg, 0.10) })
  vim.api.nvim_set_hl(0, 'FeedbackQuestionText', { fg = question_fg, italic = true })
  vim.api.nvim_set_hl(0, 'FeedbackQuestionRange', { bg = blend(question_fg, bg, 0.10) })
  vim.api.nvim_set_hl(0, 'FeedbackDeleteText', { fg = delete_fg, italic = true })
  vim.api.nvim_set_hl(0, 'FeedbackDeleteRange', { bg = blend(delete_fg, bg, 0.10) or diff_delete.bg })
  vim.api.nvim_set_hl(0, 'FeedbackGoodText', { fg = good_fg, italic = true })
  vim.api.nvim_set_hl(0, 'FeedbackGoodRange', { bg = blend(good_fg, bg, 0.10) or diff_add.bg })
end

local function filename_for(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then return '[No Name]' end
  return vim.fn.fnamemodify(name, ':.')
end

local function get_visual_range()
  local mode = vim.fn.visualmode()
  local start_pos = vim.fn.getpos "'<"
  local end_pos = vim.fn.getpos "'>"
  local start_row, start_col = start_pos[2] - 1, start_pos[3] - 1
  local end_row, end_col = end_pos[2] - 1, end_pos[3] - 1
  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end
  if mode == 'V' then
    start_col = 0
    end_col = #(vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1] or '')
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

local function input(opts, callback)
  opts = opts or {}
  local width = math.min(math.floor(vim.o.columns * 0.7), 90)
  local height = 3
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid, closed
  local function resize()
    if vim.api.nvim_win_is_valid(winid) then vim.api.nvim_win_set_height(winid, math.min(math.max(vim.api.nvim_buf_line_count(bufnr), height), 12)) end
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
  winid = vim.api.nvim_open_win(bufnr, true, { relative = 'editor', width = width, height = height, row = math.floor((vim.o.lines - height) / 2), col = math.floor((vim.o.columns - width) / 2), border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' }, title = opts.prompt or 'Feedback', title_pos = 'center', style = 'minimal' })
  vim.wo[winid].winhighlight = 'NormalFloat:FeedbackFloat,FloatBorder:FeedbackFloatBorder,FloatTitle:FeedbackFloatTitle'
  vim.wo[winid].winblend = 8
  vim.wo[winid].wrap = true
  vim.wo[winid].linebreak = true
  vim.keymap.set({ 'n', 'i' }, '<C-s>', submit, { buffer = bufnr, desc = 'Submit feedback' })
  vim.keymap.set('n', '<CR>', submit, { buffer = bufnr, desc = 'Submit feedback' })
  vim.keymap.set('n', 'q', function() close(nil) end, { buffer = bufnr, desc = 'Cancel feedback' })
  vim.keymap.set('n', '<Esc>', function() close(nil) end, { buffer = bufnr, desc = 'Cancel feedback' })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, { buffer = bufnr, callback = resize })
  vim.cmd.startinsert()
end

local meta = {
  comment = { title = 'Comment', icon = '󰆈', hl = 'FeedbackCommentText', range_hl = 'FeedbackCommentRange', prompt = 'Feedback comment 󰆈  (<C-s>/<CR> submit, q/<Esc> cancel)' },
  question = { title = 'Question', icon = '', hl = 'FeedbackQuestionText', range_hl = 'FeedbackQuestionRange', prompt = 'Feedback question   (<C-s>/<CR> submit, q/<Esc> cancel)' },
  delete = { title = 'Delete', icon = '󰆴', hl = 'FeedbackDeleteText', range_hl = 'FeedbackDeleteRange', label = 'scratch this idea' },
  good = { title = 'Good', icon = '👍', hl = 'FeedbackGoodText', range_hl = 'FeedbackGoodRange', label = 'Good 👍' },
  file_comment = { title = 'File comment' },
}

local function add_range_mark(bufnr, start_row, start_col, end_row, end_col, kind, label)
  local m = meta[kind]
  local ok, id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, start_row, start_col, { end_row = end_row, end_col = end_col, hl_group = m.range_hl, virt_text = { { (' %s %s'):format(m.icon, label), m.hl } }, virt_text_pos = 'eol', hl_mode = 'combine', invalidate = true })
  return ok and { id } or {}
end

local function add_item(item)
  next_id = next_id + 1
  item.id = item.id or next_id
  item.order = next_id
  table.insert(items, item)
  save_state()
end

function M.add_range_feedback(kind)
  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = get_visual_range()
  local text = selected_text(bufnr, start_row, start_col, end_row, end_col)
  local filename = filename_for(bufnr)

  local function finish(comment)
    if (kind == 'comment' or kind == 'question') and not comment then return end
    local label = comment or meta[kind].label
    local extmarks = add_range_mark(bufnr, start_row, start_col, end_row, end_col, kind, label)
    add_item { kind = kind, scope = 'range', bufnr = bufnr, filename = filename, range_start = { line = start_row + 1, column = start_col + 1 }, range_end = { line = end_row + 1, column = end_col + 1 }, text = text, comment = comment, extmarks = extmarks }
  end

  if kind == 'comment' or kind == 'question' then
    input({ prompt = meta[kind].prompt }, finish)
  else
    finish(nil)
  end
end

local function close_file_comment_windows()
  for _, winid in ipairs(file_comment_windows) do
    if vim.api.nvim_win_is_valid(winid) then vim.api.nvim_win_close(winid, true) end
  end
  file_comment_windows = {}
end

local function item_matches_buffer(item, bufnr)
  return item.filename == filename_for(bufnr)
end

local function range_mark_is_valid(item)
  if not item.bufnr or not vim.api.nvim_buf_is_valid(item.bufnr) then return false end
  for _, extmark_id in ipairs(item.extmarks or {}) do
    local mark = vim.api.nvim_buf_get_extmark_by_id(item.bufnr, ns, extmark_id, {})
    if mark and mark[1] then return true end
  end
  return false
end

local function restore_buffer_marks(bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  for _, item in ipairs(items) do
    if item.scope == 'file' and item_matches_buffer(item, bufnr) then
      item.bufnr = bufnr
    elseif item.scope ~= 'file' and item_matches_buffer(item, bufnr) and item.range_start and item.range_end then
      if not range_mark_is_valid(item) then
        local start_row = math.max((tonumber(item.range_start.line) or 1) - 1, 0)
        local end_row = math.max((tonumber(item.range_end.line) or 1) - 1, 0)
        if start_row < line_count and end_row < line_count then
          local start_col = math.max((tonumber(item.range_start.column) or 1) - 1, 0)
          local end_col = math.max((tonumber(item.range_end.column) or 1) - 1, 0)
          local label = item.comment or (meta[item.kind] and meta[item.kind].label) or item.kind
          item.bufnr = bufnr
          item.extmarks = add_range_mark(bufnr, start_row, start_col, end_row, end_col, item.kind, label)
        end
      end
    end
  end
end

local function render_file_comment_notifications(bufnr)
  close_file_comment_windows()
  local visible = {}
  for _, item in ipairs(items) do
    if item.scope == 'file' and item_matches_buffer(item, bufnr) then item.bufnr = bufnr; table.insert(visible, item) end
  end
  if vim.tbl_isempty(visible) then return end
  table.sort(visible, function(a, b) return a.order < b.order end)
  local width, row, col = math.min(48, math.max(24, math.floor(vim.o.columns * 0.28))), 1, math.max(0, vim.o.columns - math.min(48, math.max(24, math.floor(vim.o.columns * 0.28))) - 2)
  for _, item in ipairs(visible) do
    local lines = vim.split(item.comment, '\n', { plain = true })
    if #lines > 8 then lines = vim.list_slice(lines, 1, 7); table.insert(lines, '… more') end
    local bufnr_note = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr_note].buftype = 'nofile'; vim.bo[bufnr_note].bufhidden = 'wipe'; vim.bo[bufnr_note].swapfile = false; vim.bo[bufnr_note].filetype = 'markdown'
    vim.api.nvim_buf_set_lines(bufnr_note, 0, -1, false, lines)
    local winid = vim.api.nvim_open_win(bufnr_note, false, { relative = 'editor', width = width, height = math.max(1, math.min(#lines, 8)), row = row, col = col, border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' }, title = ' 󰆈 File comment ', title_pos = 'left', style = 'minimal', focusable = false, zindex = 40 })
    vim.wo[winid].winhighlight = 'NormalFloat:FeedbackFloat,FloatBorder:FeedbackFloatBorder,FloatTitle:FeedbackFloatTitle'
    vim.wo[winid].winblend = 8; vim.wo[winid].wrap = true; vim.wo[winid].linebreak = true
    table.insert(file_comment_windows, winid)
    row = row + math.max(1, math.min(#lines, 8)) + 2
    if row >= vim.o.lines - 2 then break end
  end
end

function M.add_file_comment()
  local bufnr = vim.api.nvim_get_current_buf()
  input({ prompt = 'File feedback 󰆈  (<C-s>/<CR> submit, q/<Esc> cancel)' }, function(comment)
    if not comment then return end
    add_item { kind = 'file_comment', scope = 'file', bufnr = bufnr, filename = filename_for(bufnr), comment = comment }
    render_file_comment_notifications(bufnr)
    vim.notify('Added file feedback', vim.log.levels.INFO)
  end)
end

local function grouped_items()
  local groups, by_filename = {}, {}
  for _, item in ipairs(items) do
    local group = by_filename[item.filename]
    if not group then
      group = { filename = item.filename, order = item.order, items = {} }
      by_filename[item.filename] = group
      table.insert(groups, group)
    end
    group.order = math.min(group.order, item.order)
    table.insert(group.items, item)
  end
  table.sort(groups, function(a, b) return a.order < b.order end)
  for _, group in ipairs(groups) do table.sort(group.items, function(a, b) return a.order < b.order end) end
  return groups
end

function M.render_review()
  if #items == 0 then return nil, 0 end
  local lines = { '# Feedback', '' }
  for _, group in ipairs(grouped_items()) do
    for _, item in ipairs(group.items) do
      local title = meta[item.kind].title or item.kind
      local location = group.filename
      if item.scope ~= 'file' then location = ('%s:%d-%d'):format(group.filename, item.range_start.line, item.range_end.line) end
      local message = item.comment
      if item.kind == 'delete' then message = message or 'I dont like this.' end
      if item.kind == 'good' then message = message or 'I like this.' end
      if item.kind == 'file_comment' then title = 'File' end
      if item.kind == 'delete' or item.kind == 'good' then
        table.insert(lines, ('- %s:'):format(location))
        table.insert(lines, message)
      else
        local entry = ('- %s %s'):format(title, location)
        if message and message ~= '' then entry = entry .. ': ' .. message end
        table.insert(lines, entry)
      end
      if item.scope ~= 'file' and item.text and item.text ~= '' then
        table.insert(lines, '  ```')
        for _, text_line in ipairs(vim.split(item.text, '\n', { plain = true })) do table.insert(lines, '  ' .. text_line) end
        table.insert(lines, '  ```')
      end
    end
  end
  return table.concat(lines, '\n'), #items
end

function M.clear()
  for _, item in ipairs(items) do
    if item.scope ~= 'file' and item.bufnr and vim.api.nvim_buf_is_valid(item.bufnr) then
      for _, extmark_id in ipairs(item.extmarks or {}) do pcall(vim.api.nvim_buf_del_extmark, item.bufnr, ns, extmark_id) end
    end
  end
  items = {}
  close_file_comment_windows()
  save_state()
end

function M.clear_feedback()
  local count = #items
  if count == 0 then vim.notify('No feedback to clear', vim.log.levels.INFO); return end
  M.clear()
  vim.notify(('Cleared %d feedback item(s)'):format(count), vim.log.levels.INFO)
end

function M.yank_feedback()
  local review, count = M.render_review()
  if not review then vim.notify('No feedback to yank', vim.log.levels.INFO); return end
  vim.fn.setreg('+', review); vim.fn.setreg('"', review)
  vim.notify(('Yanked %d feedback item(s)'):format(count), vim.log.levels.INFO)
end

function M.send_feedback_to_sidekick()
  local review, count = M.render_review()
  if not review then vim.notify('No feedback to send', vim.log.levels.INFO); return end
  local ok_cli, sidekick_cli = pcall(require, 'sidekick.cli')
  local ok_text, sidekick_text = pcall(require, 'sidekick.text')
  if not ok_cli or not ok_text then vim.notify('sidekick.nvim is not available', vim.log.levels.ERROR); return end
  local ok_send, err = pcall(sidekick_cli.send, { text = sidekick_text.to_text(review) })
  if not ok_send then vim.notify(('Failed to send feedback to Sidekick: %s'):format(err), vim.log.levels.ERROR); return end
  M.clear()
  vim.notify(('Sent %d feedback item(s) to Sidekick and cleared them'):format(count), vim.log.levels.INFO)
end

function M.setup()
  if did_setup then return end
  did_setup = true
  setup_highlights()
  load_state()
  restore_buffer_marks(vim.api.nvim_get_current_buf())
  vim.api.nvim_create_autocmd('ColorScheme', { callback = setup_highlights })
  vim.keymap.set('x', '<leader>rc', function() vim.cmd 'normal! \27'; vim.schedule(function() M.add_range_feedback 'comment' end) end, { desc = 'Feedback: add range comment' })
  vim.keymap.set('x', '<leader>rq', function() vim.cmd 'normal! \27'; vim.schedule(function() M.add_range_feedback 'question' end) end, { desc = 'Feedback: add question' })
  vim.keymap.set('x', '<leader>rd', function() vim.cmd 'normal! \27'; vim.schedule(function() M.add_range_feedback 'delete' end) end, { desc = 'Feedback: delete/scratch' })
  vim.keymap.set('x', '<leader>rg', function() vim.cmd 'normal! \27'; vim.schedule(function() M.add_range_feedback 'good' end) end, { desc = 'Feedback: good/keep' })
  vim.keymap.set('n', '<leader>rc', M.add_file_comment, { desc = 'Feedback: add file comment' })
  vim.keymap.set('n', '<leader>ry', M.yank_feedback, { desc = 'Feedback: yank all' })
  vim.keymap.set('n', '<leader>rs', M.send_feedback_to_sidekick, { desc = 'Feedback: send all to Sidekick' })
  vim.keymap.set('n', '<leader>rx', M.clear_feedback, { desc = 'Feedback: clear all' })
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufReadPost', 'VimResized' }, { callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    restore_buffer_marks(bufnr)
    render_file_comment_notifications(bufnr)
  end })
end

return M
