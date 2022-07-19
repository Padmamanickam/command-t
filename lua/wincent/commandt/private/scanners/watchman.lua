-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local watchman = {}

local sockname = nil

local socket = nil

local files = nil

watchman.get = function(force)
  -- TODO impl; note that we don't want this to return a list of (Lua) strings
  -- but rather a scanner handle
end

watchman.get_socket = function()
  if socket == nil then
    local name = watchman.get_sockname()
    if name == nil then
      error('wincent.commandt.scanners.watchman.get_socket(): no sockname')
    end
    local lib = require('wincent.commandt.private.lib')
    socket = lib.commandt_watchman_connect(name)
  end
  return socket
end

-- Run `watchman get-sockname` to get current socket name; `watchman` will spawn
-- in response to this command if it is not already running.
--
-- See: https://facebook.github.io/watchman/docs/cmd/get-sockname.html
watchman.get_sockname = function()
  if sockname == nil then
    if vim.fn.executable('watchman') == 1 then
      local output = vim.fn.systemlist('watchman get-sockname')
      local decoded = vim.fn.json_decode(output)
      if decoded['error'] then
        error(
          'wincent.commandt.scanners.watchman.get_sockname(): watchman get-sockname error = '
            .. tostring(decoded['error'])
        )
      else
        sockname = decoded['sockname']
      end
    else
      error('wincent.commandt.scanners.watchman.get_sockname(): no watchman executable')
    end
  end
  return sockname
end

-- Internal: Used by the benchmark suite so that we can identify this scanner
-- from among others.
watchman.name = 'watchman'

-- Internal: Used by the benchmark suite so that we can avoid calling `vim` functions
-- inside `get_sockname()` from our pure-C benchmark harness.
watchman.set_sockname = function(name)
  sockname = name
end

-- Equivalent to:
--
--    watchman -j <<-JSON
--      ["query", "/path/to/root", {
--        "expression": ["type", "f"],
--        "fields": ["name"],
--        "relative_root": "some/relative/path"
--      }]
--    JSON
--
-- If `relative_root` is `nil`, it will be omitted from the query.
--
-- TODO: no need to export this function
--
watchman.query = function(root, relative_root)
  local socket = watchman.get_socket() -- TODO: when to clean up?
  local lib = require('wincent.commandt.private.lib')

  -- To see this, run:
  --
  --     llvm --file nvim
  --     r
  --     :lua my_watch = require'wincent.commandt.private.scanners.watchman'.watch_project('/Users/wincent/code/command-t')
  --     :lua require'wincent.commandt.private.scanners.watchman'.query(my_watch['watch'])
  --
  return lib.commandt_watchman_query(root, relative_root, socket)
end

-- BUG: we leak this forever, but I want its lifetime to be bonded to that of
-- the scanner object
local result = nil

-- temporary function
watchman.scanner = function(dir)
  local lib = require('wincent.commandt.private.lib')
  local project = watchman.watch_project(dir)
  -- Result needs to persist until scanner is garbage collected.
  -- TODO: figure out the right way to do that...
  result = watchman.query(project.watch, project.relative_path)
  local scanner = lib.scanner_new_str(result.files, result.count)
  return scanner
end

-- Equivalent to `watchman watch-project $root`.
--
-- Returns a table with `watch` and `relative_path` properties. `relative_path`
-- my be `nil`.
watchman.watch_project = function(root)
  local socket = watchman.get_socket() -- TODO: when to clean up?
  local lib = require('wincent.commandt.private.lib')

  -- To see this, run:
  --
  --     llvm --file nvim
  --     r
  --     :lua require'wincent.commandt.private.scanners.watchman'.watch_project('/Users/wincent/code/command-t')
  --
  return lib.commandt_watchman_watch_project(root, socket)
end

return watchman
