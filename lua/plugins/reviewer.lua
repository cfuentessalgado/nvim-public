local M = {}

local ns = vim.api.nvim_create_namespace 'reviewer_comments'
local comments = {}
local file_comment_windows = {}
local next_comment_id = 0
local patch_context_lines = 3

local function hl(name)
  local ok, value = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return ok and value or {}
end

local function setup_highlights()
  local normal = hl 'Normal'
  local normal_float = hl 'NormalFloat'
  local float_border = hl 'FloatBorder'
  local float_title = hl 'FloatTitle'
  local diagnostic_hint = hl 'DiagnosticHint'
  local directory = hl 'Directory'

  -- Use the editor background instead of NormalFloat. Many themes make
  -- NormalFloat black, which creates an obvious square behind rounded borders.
  local bg = normal.bg
  local fg = normal_float.fg or normal.fg
  local border_fg = diagnostic_hint.fg or directory.fg or float_border.fg or fg
  local title_fg = float_title.fg or fg

  vim.api.nvim_set_hl(0, 'ReviewerComment', { fg = title_fg, italic = true })
  vim.api.nvim_set_hl(0, 'ReviewerFloat', { fg = fg, bg = bg })
  vim.api.nvim_set_hl(0, 'ReviewerFloatBorder', { fg = border_fg, bg = bg })
  vim.api.nvim_set_hl(0, 'ReviewerFloatTitle', { fg = title_fg, bg = bg, bold = true })
  vim.api.nvim_set_hl(0, 'ReviewerNotification', { fg = fg, bg = bg })
  vim.api.nvim_set_hl(0, 'ReviewerNotificationBorder', { fg = border_fg, bg = bg })
  vim.api.nvim_set_hl(0, 'ReviewerNotificationTitle', { fg = title_fg, bg = bg, bold = true })
  vim.api.nvim_set_hl(0, 'ReviewerMuted', { fg = border_fg, bg = bg, italic = true })
end

setup_highlights()

vim.api.nvim_create_autocmd('ColorScheme', {
  callback = setup_highlights,
})

local function is_diff_buffer(bufnr)
  return vim.startswith(vim.api.nvim_buf_get_name(bufnr), 'deltaview://diff/')
end

local function filename_for(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)

  if name == '' then
    return '[No Name]'
  end

  if vim.startswith(name, 'deltaview://diff/') then
    local path = name:match '^deltaview://diff/(.-)%s+'

    if path then
      if vim.startswith(path, '//') then
        path = path:sub(2)
      end

      return vim.fn.fnamemodify(path, ':.')
    end
  end

  return vim.fn.fnamemodify(name, ':.')
end

local function diff_marker_for(bufnr, lnum)
  local line_map = vim.b[bufnr].delta_line_map
  local map = line_map and line_map[lnum]

  if not map then
    return nil
  end

  if map.type == 'added' then
    return '+'
  end

  if map.type == 'removed' then
    return '-'
  end

  if map.type == 'context' then
    return ' '
  end

  return nil
end

local function diff_source_range(bufnr, start_row, end_row)
  local line_map = vim.b[bufnr].delta_line_map or {}
  local range = { old_start = nil, old_end = nil, new_start = nil, new_end = nil }

  for lnum = start_row + 1, end_row + 1 do
    local map = line_map[lnum]

    if map then
      if map.old then
        range.old_start = math.min(range.old_start or map.old, map.old)
        range.old_end = math.max(range.old_end or map.old, map.old)
      end

      if map.new then
        range.new_start = math.min(range.new_start or map.new, map.new)
        range.new_end = math.max(range.new_end or map.new, map.new)
      end
    end
  end

  return range
end

local function ranges_overlap(a_start, a_end, b_start, b_end)
  if not a_start or not a_end or not b_start or not b_end then
    return false
  end

  return a_start <= b_end and b_start <= a_end
end

local function git_patch_for_range(filename, range)
  local result = vim.system({ 'git', 'diff', ('-U%d'):format(patch_context_lines), '--', filename }, { text = true }):wait()

  if result.code ~= 0 and result.code ~= 1 then
    return nil
  end

  local hunks = {}
  local current

  for _, line in ipairs(vim.split(result.stdout or '', '\n', { plain = true })) do
    local old_start, old_count, new_start, new_count = line:match '^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@'

    if old_start then
      local hunk_header = line:gsub('^(@@.-@@).*$','%1')

      local old_len = tonumber(old_count ~= '' and old_count or '1')
      local new_len = tonumber(new_count ~= '' and new_count or '1')

      current = {
        old_start = tonumber(old_start),
        old_end = tonumber(old_start) + old_len - 1,
        new_start = tonumber(new_start),
        new_end = tonumber(new_start) + new_len - 1,
        lines = { hunk_header },
      }
      table.insert(hunks, current)
    elseif current then
      table.insert(current.lines, line)
    end
  end

  local selected = {}

  for _, hunk in ipairs(hunks) do
    if ranges_overlap(range.old_start, range.old_end, hunk.old_start, hunk.old_end)
      or ranges_overlap(range.new_start, range.new_end, hunk.new_start, hunk.new_end)
    then
      vim.list_extend(selected, hunk.lines)
    end
  end

  if vim.tbl_isempty(selected) then
    return nil
  end

  return table.concat(selected, '\n')
end

local function get_visual_text(bufnr, start_row, start_col, end_row, end_col, opts)
  opts = opts or {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)

  if vim.tbl_isempty(lines) then
    return ''
  end

  if opts.diff_markers then
    for index, line in ipairs(lines) do
      local marker = diff_marker_for(bufnr, start_row + index)

      if marker then
        lines[index] = marker .. line
      end
    end

    return table.concat(lines, '\n')
  end

  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_col + 1, end_col)
  else
    lines[1] = string.sub(lines[1], start_col + 1)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
  end

  return table.concat(lines, '\n')
end

local function close_file_comment_windows()
  for _, winid in ipairs(file_comment_windows) do
    if vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_close(winid, true)
    end
  end

  file_comment_windows = {}
end

local function visible_file_comments(bufnr)
  local items = {}

  for _, item in ipairs(vim.tbl_values(comments)) do
    if item.scope == 'file' and item.bufnr == bufnr then
      table.insert(items, item)
    end
  end

  table.sort(items, function(a, b) return a.order < b.order end)

  return items
end

local function render_file_comment_notifications(bufnr)
  close_file_comment_windows()

  local items = visible_file_comments(bufnr or vim.api.nvim_get_current_buf())

  if vim.tbl_isempty(items) then
    return
  end

  local width = math.min(48, math.max(24, math.floor(vim.o.columns * 0.28)))
  local row = 1
  local col = math.max(0, vim.o.columns - width - 2)

  for _, item in ipairs(items) do
    local lines = vim.split(item.comment, '\n', { plain = true })
    local truncated = #lines > 8

    if truncated then
      lines = vim.list_slice(lines, 1, 7)
      table.insert(lines, ('… %d more line(s)'):format(#vim.split(item.comment, '\n', { plain = true }) - 7))
    end

    local max_height = math.max(1, math.min(#lines, 8))
    local bufnr_note = vim.api.nvim_create_buf(false, true)

    vim.bo[bufnr_note].buftype = 'nofile'
    vim.bo[bufnr_note].bufhidden = 'wipe'
    vim.bo[bufnr_note].swapfile = false
    vim.bo[bufnr_note].filetype = 'markdown'
    vim.api.nvim_buf_set_lines(bufnr_note, 0, -1, false, lines)

    local winid = vim.api.nvim_open_win(bufnr_note, false, {
      relative = 'editor',
      width = width,
      height = max_height,
      row = row,
      col = col,
      border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
      title = ' 󰆈 File comment ',
      title_pos = 'left',
      style = 'minimal',
      focusable = false,
      zindex = 40,
    })

    vim.wo[winid].winhighlight = table.concat({
      'NormalFloat:ReviewerNotification',
      'FloatBorder:ReviewerNotificationBorder',
      'FloatTitle:ReviewerNotificationTitle',
    }, ',')
    vim.wo[winid].winblend = 8
    vim.wo[winid].wrap = true
    vim.wo[winid].linebreak = true
    table.insert(file_comment_windows, winid)

    row = row + max_height + 2

    if row >= vim.o.lines - 2 then
      break
    end
  end
end

local function review_input(opts, callback)
  opts = opts or {}

  local width = math.min(math.floor(vim.o.columns * 0.7), 90)
  local height = 3
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid
  local closed = false

  local function resize()
    if not vim.api.nvim_win_is_valid(winid) then
      return
    end

    local line_count = math.max(1, vim.api.nvim_buf_line_count(bufnr))
    vim.api.nvim_win_set_height(winid, math.min(math.max(line_count, height), 12))
  end

  local function close(value)
    if closed then
      return
    end

    closed = true

    if vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_close(winid, true)
    end

    callback(value)
  end

  local function submit()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local value = vim.trim(table.concat(lines, '\n'))
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
    border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
    title = opts.prompt or 'Review comment',
    title_pos = 'center',
    style = 'minimal',
  })

  vim.wo[winid].winhighlight = table.concat({
    'NormalFloat:ReviewerFloat',
    'FloatBorder:ReviewerFloatBorder',
    'FloatTitle:ReviewerFloatTitle',
  }, ',')
  vim.wo[winid].winblend = 8
  vim.wo[winid].wrap = true
  vim.wo[winid].linebreak = true

  vim.keymap.set({ 'n', 'i' }, '<C-s>', submit, { buffer = bufnr, desc = 'Submit review comment' })
  vim.keymap.set('n', '<CR>', submit, { buffer = bufnr, desc = 'Submit review comment' })
  vim.keymap.set('n', 'q', function() close(nil) end, { buffer = bufnr, desc = 'Cancel review comment' })
  vim.keymap.set('n', '<Esc>', function() close(nil) end, { buffer = bufnr, desc = 'Cancel review comment' })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = bufnr,
    callback = resize,
  })

  vim.cmd.startinsert()
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
    end_col = #vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1]
  end

  return start_row, start_col, end_row, end_col
end

function M.add_comment()
  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = get_visual_range()

  local diff_buffer = is_diff_buffer(bufnr)
  local source_range = diff_buffer and diff_source_range(bufnr, start_row, end_row) or nil
  local selected_text = diff_buffer
      and (git_patch_for_range(filename_for(bufnr), source_range) or get_visual_text(bufnr, start_row, start_col, end_row, end_col, { diff_markers = true }))
    or get_visual_text(bufnr, start_row, start_col, end_row, end_col)

  review_input({ prompt = 'Review comment 󰆈  (<C-s>/<CR> submit, q/<Esc> cancel)' }, function(comment)
    if not comment or comment == '' then
      return
    end

    local was_modifiable = vim.bo[bufnr].modifiable

    if not was_modifiable then
      vim.bo[bufnr].modifiable = true
    end

    local ok, id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, end_row, 0, {
      virt_text = { { ' 󰆈 ' .. comment, 'ReviewerComment' } },
      virt_text_pos = 'eol',
      hl_mode = 'combine',
      invalidate = true,
    })

    if not was_modifiable then
      vim.bo[bufnr].modifiable = false
    end

    if not ok then
      vim.notify(('Reviewer failed to add comment: %s'):format(id), vim.log.levels.ERROR)
      return
    end

    next_comment_id = next_comment_id + 1

    comments[id] = {
      id = id,
      order = next_comment_id,
      bufnr = bufnr,
      scope = diff_buffer and 'diff_range' or 'range',
      filename = filename_for(bufnr),
      range_start = { line = start_row + 1, column = start_col + 1 },
      range_end = { line = end_row + 1, column = end_col + 1 },
      patch = diff_buffer and selected_text or nil,
      comment = comment,
    }
  end)
end

function M.add_file_comment()
  local bufnr = vim.api.nvim_get_current_buf()

  review_input({ prompt = 'Review file comment 󰆈  (<C-s>/<CR> submit, q/<Esc> cancel)' }, function(comment)
    if not comment or comment == '' then
      return
    end

    next_comment_id = next_comment_id + 1
    local id = ('file:%d'):format(next_comment_id)

    comments[id] = {
      id = id,
      order = next_comment_id,
      bufnr = bufnr,
      scope = 'file',
      filename = filename_for(bufnr),
      comment = comment,
    }

    render_file_comment_notifications(bufnr)
    vim.notify('Added reviewer file comment', vim.log.levels.INFO)
  end)
end

local function grouped_comments()
  local files = {}
  local by_filename = {}

  for _, item in ipairs(vim.tbl_values(comments)) do
    local group = by_filename[item.filename]

    if not group then
      group = { filename = item.filename, order = item.order, file_comments = {}, comments = {} }
      by_filename[item.filename] = group
      table.insert(files, group)
    else
      group.order = math.min(group.order, item.order)
    end

    if item.scope == 'file' then
      table.insert(group.file_comments, item)
    else
      table.insert(group.comments, item)
    end
  end

  table.sort(files, function(a, b) return a.order < b.order end)

  for _, group in ipairs(files) do
    table.sort(group.file_comments, function(a, b) return a.order < b.order end)
    table.sort(group.comments, function(a, b) return a.order < b.order end)
  end

  return files
end

function M.render_review()
  local files = grouped_comments()
  local count = #vim.tbl_values(comments)

  if count == 0 then
    return nil, 0
  end

  local lines = {
    '# Review',
    '',
    'Address the following comments.',
    '',
  }

  for _, group in ipairs(files) do
    table.insert(lines, ('## `%s`'):format(group.filename))
    table.insert(lines, '')

    for _, item in ipairs(group.file_comments) do
      table.insert(lines, '### File comment')
      table.insert(lines, '')
      table.insert(lines, '```markdown')
      table.insert(lines, item.comment)
      table.insert(lines, '```')
      table.insert(lines, '')
    end

    for _, item in ipairs(group.comments) do
      if item.scope == 'diff_range' then
        table.insert(
          lines,
          ('### `%s:diff:%d:%d-%d:%d`'):format(
            item.filename,
            item.range_start.line,
            item.range_start.column,
            item.range_end.line,
            item.range_end.column
          )
        )
        table.insert(lines, '')
        table.insert(lines, '```markdown')
        table.insert(lines, item.comment)
        table.insert(lines, '```')
        table.insert(lines, '')
        table.insert(lines, 'Patch context:')
        table.insert(lines, '')
        table.insert(lines, '```diff')
        table.insert(lines, item.patch or '')
        table.insert(lines, '```')
        table.insert(lines, '')
      else
        table.insert(
          lines,
          ('### `%s:range:%d:%d-%d:%d`'):format(
            item.filename,
            item.range_start.line,
            item.range_start.column,
            item.range_end.line,
            item.range_end.column
          )
        )
        table.insert(lines, '')
        table.insert(lines, '```markdown')
        table.insert(lines, item.comment)
        table.insert(lines, '```')
        table.insert(lines, '')
      end
    end
  end

  return table.concat(lines, '\n'), count
end

function M.clear_comments()
  for _, item in pairs(comments) do
    if item.scope ~= 'file' and vim.api.nvim_buf_is_valid(item.bufnr) then
      vim.api.nvim_buf_del_extmark(item.bufnr, ns, item.id)
    end
  end

  comments = {}
  close_file_comment_windows()
end

function M.clear_review()
  local count = #vim.tbl_values(comments)

  if count == 0 then
    vim.notify('No reviewer comments to clear', vim.log.levels.INFO)
    return
  end

  M.clear_comments()
  vim.notify(('Cleared %d reviewer comment(s)'):format(count), vim.log.levels.INFO)
end

function M.yank_review()
  local review, count = M.render_review()

  if not review then
    vim.notify('No reviewer comments to yank', vim.log.levels.INFO)
    return
  end

  vim.fn.setreg('+', review)
  vim.fn.setreg('"', review)

  vim.notify(('Yanked %d reviewer comment(s)'):format(count), vim.log.levels.INFO)
end

function M.send_review_to_sidekick()
  local review, count = M.render_review()

  if not review then
    vim.notify('No reviewer comments to send', vim.log.levels.INFO)
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
    vim.notify(('Failed to send review to Sidekick: %s'):format(err), vim.log.levels.ERROR)
    return
  end

  M.clear_comments()

  vim.notify(('Sent %d reviewer comment(s) to Sidekick'):format(count), vim.log.levels.INFO)
end

vim.keymap.set('x', '<leader>rc', function()
  vim.cmd 'normal! \27'
  vim.schedule(M.add_comment)
end, { desc = 'Reviewer: add range comment' })

vim.keymap.set('n', '<leader>rc', M.add_file_comment, { desc = 'Reviewer: add file comment' })
vim.keymap.set('n', '<leader>rx', M.clear_review, { desc = 'Reviewer: clear comments' })

vim.api.nvim_create_autocmd({ 'BufEnter', 'VimResized' }, {
  callback = function()
    render_file_comment_notifications(vim.api.nvim_get_current_buf())
  end,
})
vim.keymap.set('n', '<leader>ry', M.yank_review, { desc = 'Reviewer: yank review' })
vim.keymap.set('n', '<leader>rs', M.send_review_to_sidekick, { desc = 'Reviewer: send review to Sidekick' })

return M
