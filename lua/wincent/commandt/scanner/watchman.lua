-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local watchman = {}

local sockname = nil

local socket = nil

watchman.get_socket = function()
  if socket == nil then
    local name = watchman.get_sockname()
    if name == nil then
      error('wincent.commandt.scanner.watchman.get_socket(): no sockname')
    end
    socket = c.commandt_watchman_connect(name)
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
        error('wincent.commandt.scanner.watchman.get_sockname(): watchman get-sockname error = ' .. tostring(decoded['error']))
      else
        sockname = decoded['sockname']
      end
    else
      error('wincent.commandt.scanner.watchman.get_sockname(): no watchman executable')
    end
  end
  return sockname
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
watchman.query = function(root, relative_root)
  -- TODO: pass sockname down... will open a connection if there isn't one
  -- already
  --
  -- When to clean up?
end

-- Equivalent to `watchman watch-project $root`.
--
-- Returns a table with `watch` and `relative_root` properties. `relative_root`
-- my be `nil`.
watchman.watch_project = function(root)
  -- TODO: pass sockname down... will open a connection if there isn't one
  -- already
  --
  -- When to clean up?
end

return watchman
