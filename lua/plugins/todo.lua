local gh = require('custom.pack').gh

vim.pack.add { gh 'folke/todo-comments.nvim' }
require('todo-comments').setup {}
