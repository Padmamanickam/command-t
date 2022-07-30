-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

-- TODO: remember cached directories
return function(dir, options)
  if vim.startswith(dir, './') then
    dir = dir:sub(3, -1)
  end
  if dir ~= '' and dir ~= '.' then
    dir = vim.fn.shellescape(dir)
  end
  local lib = require('wincent.commandt.private.lib')
  local finder = {}
  finder.scanner = require('wincent.commandt.private.scanners.find').scanner(dir)
  finder.matcher = lib.matcher_new(finder.scanner, options)
  finder.run = function(query)
    local results = lib.matcher_run(finder.matcher, query)
    local strings = {}
    for i = 0, results.count - 1 do
      local str = results.matches[i]
      table.insert(strings, ffi.string(str.contents, str.length))
    end
    return strings
  end
  finder.open = function(item, kind)
    options.open(vim.fn.fnameescape(item), kind)
  end
  return finder
end