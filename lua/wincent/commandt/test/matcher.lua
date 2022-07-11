-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

describe('matcher.c', function()
  local lib = require'wincent.commandt.lib'

  local get_matcher = function(paths, options)
    local scanner = lib.scanner_new_copy(paths)
    local matcher = lib.commandt_matcher_new(scanner, options)
    return {
      match = function(query)
        local results = lib.commandt_matcher_run(matcher, query)
        local strings = {}
        for k = 0, results.count - 1 do
          local str = results.matches[k]
          table.insert(strings, ffi.string(str.contents, str.length))
        end
        return strings
      end,
      _scanner = scanner, -- Prevent premature GC.
      _matcher = matcher, -- Prevent premature GC.
    }
  end

  context('with an empty scanner', function()
    local matcher = nil

    before(function()
      matcher = get_matcher({})
    end)

    it('returns an empty list given an empty query', function()
      expect(matcher.match('')).to_equal({})
    end)

    it('returns an empty list given a non-empty query', function()
      expect(matcher.match('foo')).to_equal({})
    end)
  end)

  context('with a non-empty scanner', function()
    it('returns empty list when no matches', function()
      local matcher = get_matcher({'foo/bar', 'foo/baz', 'bing'})
      expect(matcher.match('xyz')).to_equal({})
    end)

    it('returns matching paths', function()
      local matcher = get_matcher({'foo/bar', 'foo/baz', 'bing'})
      expect(matcher.match('z')).to_equal({'foo/baz'})
      expect(matcher.match('bg')).to_equal({'bing'})
    end)

    it('performs case-insensitive matching', function()
      local matcher = get_matcher({'Foo'})
      expect(matcher.match('f')).to_equal({'Foo'})
    end)
  end)
end)
