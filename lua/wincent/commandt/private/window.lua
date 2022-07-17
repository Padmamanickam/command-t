-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

-- Convenience wrapper around Neovim floating windows.
--
-- Manages a floating window and associated buffer, and provides methods for
-- positioning, updating, setting a title etc.

local window = {}

local merge = require('wincent.commandt.private.merge')

local Window = {}

local mt = {
  __index = Window,
}
local is_integer = function(numberish)
  return type(numberish) == 'number' and math.floor(numberish) == numberish
end

local validate_options = function(options)
  if
    (type(options.bottom) == 'number' and options.top ~= nil)
    or (type(options.top) == 'number' and options.bottom ~= nil)
  then
    error('Window.new(): cannot set both `bottom` and `top`')
  end
  if options.bottom == nil and options.top == nil then
    error('Window.new(): must provide one of `bottom` or `top`')
  end
  if options.bottom ~= nil and (not is_integer(options.bottom) or options.bottom < 0) then
    error('Window.new(): `bottom` must be a non-negative integer')
  end
  if options.buftype ~= 'nofile' and options.buftype ~= 'prompt' then
    error("Window.new(): `buftype` must be 'nofile' or 'prompt'")
  end
  if not is_integer(options.margin) or options.margin < 0 then
    error('Window.new(): `margin` must be a non-negative integer')
  end
  if options.onchange ~= nil and type(options.onchange) ~= 'function' then
    error('Window.new(): `onchange` must be a function')
  end
  if options.onclose ~= nil and type(options.onclose) ~= 'function' then
    error('Window.new(): `onclose` must be a function')
  end
  if options.top ~= nil and (not is_integer(options.top) or options.top < 0) then
    error('Window.new(): `top` must be a non-negative integer')
  end
end

function Window.new(options)
  options = merge({
    bottom = nil,
    buftype = 'nofile', -- Also, 'prompt'.
    filetype = nil,
    height = 1,
    margin = 0,
    onclose = nil,
    onchange = nil,
    prompt = '> ', -- Has no effect unless `buftype` is 'prompt'.
    title = 'Command-T', -- Set to '' to suppress.
    top = nil,
  }, options)
  validate_options(options)
  local w = {
    _bottom = options.bottom,
    _buftype = options.buftype,
    _filetype = options.filetype,
    _height = options.height,
    _main_buffer = nil,
    _main_window = nil,
    _margin = options.margin,
    _onchange = options.onchange,
    _onclose = options.onclose,
    _padded_title = options.title ~= '' and (' ' .. options.title .. ' ') or '',
    _prompt = options.prompt,
    _title = options.title,
    _title_buffer = nil,
    _title_window = nil,
    _top = options.top,
  }
  setmetatable(w, mt)
  return w
end

-- Focus the window and enter insert mode, ready to receive input.
function Window:focus()
  -- TODO: if not shown, show first automatically?, then...
  vim.api.nvim_set_current_win(self._main_window)
  vim.cmd('startinsert')
end

function Window:show()
  if self._main_buffer == nil then
    self._main_buffer = vim.api.nvim_create_buf(
      false, -- listed = false
      true -- scratch = true
    )
    if self._main_buffer == 0 then
      error('Window:show(): nvim_create_buf() failed')
    end
    local ps1 = self._prompt or '> '
    if self._buftype == 'prompt' then
      vim.api.nvim_buf_set_option(self._main_buffer, 'buftype', 'prompt')
      vim.fn.prompt_setprompt(self._main_buffer, ps1)
    end
    if self._filetype ~= nil then
      vim.api.nvim_buf_set_option(self._main_buffer, 'filetype', self._filetype)
    end
    if self._onchange then
      local callback = function()
        -- Should be able to use `vim.fn.prompt_getprompt(self._main_buffer)`,
        -- but it only returns the prompt prefix for some reason...
        local query = vim.api.nvim_get_current_line():sub(#ps1 + 1)
        self._onchange(query)
      end
      vim.api.nvim_create_autocmd('TextChanged', {
        buffer = self._main_buffer,
        callback = callback,
      })
      vim.api.nvim_create_autocmd('TextChangedI', {
        buffer = self._main_buffer,
        callback = callback,
      })
    end
    vim.api.nvim_create_autocmd('VimResized', {
      buffer = self._main_buffer,
      callback = function()
        -- This will resposition title, too, so no need for a separate autocmd.
        self:_reposition()
      end,
    })
  end
  local position = self:_calculate_position()
  if self._main_window == nil then
    self._main_window = vim.api.nvim_open_win(
      self._main_buffer,
      true, -- enter = true
      merge({
        border = 'single',
        focusable = false,
        noautocmd = true,
        relative = 'editor',
        style = 'minimal',
      }, position)
    )
    if self._main_window == 0 then
      error('Window:show(): nvim_open_win() failed')
    end
    -- TODO: maybe watch for buffer destruction too
    -- then nvim_win_close
    -- TODO: watch for VimResized events then nvim_win_get_position and adjust
    -- not: nvim_win_set_height
    -- not: nvim_win_set_width (requires vertical split)
    -- this one: nvim_win_set_config
    vim.api.nvim_create_autocmd('WinClosed', {
      once = true,
      callback = function()
        self._main_window = nil
      end,
    })
    vim.api.nvim_win_set_option(self._main_window, 'wrap', false)
    -- TODO: decide whether I need to clear lines here.
    vim.api.nvim_buf_set_lines(
      self._main_buffer,
      0, -- start
      -1, -- end
      false, -- strict indexing = false
      {} -- replacement lines
    )
  end
  if self._padded_title ~= '' then
    if self._title_buffer == nil then
      self._title_buffer = vim.api.nvim_create_buf(
        false, -- listed = false
        true -- scratch = true
      )
      if self._title_buffer == 0 then
        error('Window:show(): nvim_create_buf() failed')
      end
      vim.api.nvim_buf_set_option(self._title_buffer, 'buftype', 'nofile')
      vim.api.nvim_buf_set_option(self._title_buffer, 'filetype', 'CommandTTitle')
    end
    -- TODO: trim title if too wide
    if self._title_window == nil then
      self._title_window = vim.api.nvim_open_win(
        self._title_buffer,
        false, -- enter = false
        merge(
          {
            focusable = false,
            noautocmd = true,
            relative = 'editor',
            style = 'minimal',
            zindex = 60, -- Default for floats is 50
          },
          position,
          {
            col = position.col + #self._prompt,
            height = 1,
            row = math.max(0, position.row),
            width = #self._padded_title,
          }
        )
      )
      if self._title_window == 0 then
        error('Window:show(): nvim_open_win() failed')
      end
    end
    vim.api.nvim_buf_set_lines(
      self._title_buffer,
      0, -- start
      -1, -- end
      false, -- strict indexing
      { self._padded_title } -- TODO: put actual type
    )
  end
end

function Window:replace_lines(lines, options)
  if self._main_buffer ~= nil then
    vim.api.nvim_buf_set_lines(
      self._main_buffer,
      0, -- start
      -1, -- end
      false, -- strict indexing
      lines -- replacement lines
    )
  end
  if options and options.adjust_height then
    -- TODO: rather than overwriting height, distinguish maxheight and height
    -- maxheight will stay fixed, but height can fluctuate with content
    self._height = math.max(1, #lines)
    self:_reposition()
  end
end

function Window:_reposition()
  local position = merge(
    self:_calculate_position(),
    -- Need `relative` to avoid:
    --
    --    non-float cannot have 'row' [C]: in function 'nvim_win_set_config'
    --
    -- See: https://github.com/neovim/neovim/issues/18368
    { relative = 'editor' }
  )
  if self._main_window ~= nil then
    vim.api.nvim_win_set_config(self._main_window, position)
  end
  if self._title_window ~= nil then
    vim.api.nvim_win_set_config(
      self._title_window,
      merge(position, {
        col = position.col + #self._prompt,
        height = 1,
        row = math.max(0, position.row),
        width = #(' ' .. self._title .. ' '),
      })
    )
  end
end

-- Return a clamped `value` (restricted to range `minimum, maximum`).
local clamp = function(value, minimum, maximum)
  return math.max(minimum, math.min(value, maximum))
end

-- Tries to fit window within existing dimensions. If the editor window is too
-- small, then shrinks to fit inside it. If it is still too small, all bets are
-- off.
function Window:_calculate_position()
  local editor_width = vim.o.columns
  local width = math.max(1, #self._padded_title, editor_width - 2 * self._margin)
  local col = math.floor((editor_width - width) / 2)
  local editor_height = vim.o.lines
  local border_height = 2
  local usable_height = editor_height - vim.o.cmdheight
  if type(self._top) == 'number' then
    local height = clamp(self._height, 1, usable_height - self._top - border_height)
    return {
      col = col,
      height = height,
      row = self._top,
      width = width,
    }
  elseif type(self._bottom) == 'number' then
    local height = clamp(self._height, 1, usable_height - self._bottom - border_height)
    return {
      col = col,
      height = height,
      row = usable_height - self._bottom - height - border_height,
      width = width,
    }
  end
end

window.Window = Window

return window
