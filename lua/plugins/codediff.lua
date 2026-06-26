local gh = require('custom.pack').gh

vim.pack.add({
  'https://github.com/esmuellert/codediff.nvim'
})

vim.keymap.set('n', '<leader>td', '<cmd>CodeDiff<CR>', { desc = 'Enter [D]eltaView' })


require('codediff').setup({
  explorer = {
    position = "left",  -- "left" or "bottom"
      hidden = false,  -- Initial visibility state
      width = 40,         -- Width when position is "left" (columns)
      height = 15,        -- Height when position is "bottom" (lines)
      auto_refresh = true,  -- Auto-refresh file list on focus / git index changes (set false to avoid lag in huge repos; R still refreshes manually)
      indent_markers = true,  -- Show indent markers in tree view (│, ├, └)
      initial_focus = "modified",  -- Initial focus: "explorer", "original", or "modified"
      icons = {
        folder_closed = "",  -- Nerd Font folder icon (customize as needed)
        folder_open = "",    -- Nerd Font folder-open icon
      },
      view_mode = "tree",    -- "list" or "tree"
      flatten_dirs = true,   -- Flatten single-child directory chains in tree view
      focus_on_select = true,  -- Jump to modified pane after selecting a file (default: stay in explorer)
      auto_open_on_cursor = true, -- Rebind j/k/Down/Up in the explorer to also open the file under the cursor
      status_right_margin = 1,  -- Trailing cells between status symbol (M/A/D) and right edge; increase if Nerd Font icons clip it
      visible_groups = {       -- Which groups to show (can be toggled at runtime)
        staged = true,
        unstaged = true,
        conflicts = true,
      },
  }
})
