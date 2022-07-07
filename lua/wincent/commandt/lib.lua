-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local lib = {}

-- Lazy-load dynamic (C) library code on first access.
local c = {}

setmetatable(c, {
  __index = function(table, key)
    ffi.cdef[[
      typedef struct {
          const char *contents;
          size_t length;
          size_t capacity;
      } str_t;

      typedef struct {
          str_t *candidate;
          long bitmask;
          float score;
      } haystack_t;

      typedef struct {
          str_t **candidates;
          size_t count;
          size_t capacity;
          unsigned clock;
      } scanner_t;

      typedef struct {
          scanner_t *scanner;
          haystack_t *haystacks;
          bool always_show_dot_files;
          bool case_sensitive;
          bool ignore_spaces;
          bool never_show_dot_files;
          bool recurse;
          unsigned limit;
          int threads;
          const char *needle;
          unsigned long needle_length;
          long needle_bitmask;
          const char *last_needle;
          unsigned long last_needle_length;
      } matcher_t;

      typedef struct {
          str_t **matches;
          unsigned count;
      } result_t;

      // Matcher methods.

      matcher_t *commandt_matcher_new(
          scanner_t *scanner,
          bool always_show_dot_files,
          bool case_sensitive,
          bool ignore_spaces,
          unsigned limit,
          bool never_show_dot_files,
          bool recurse
      );
      void commandt_matcher_free(matcher_t *matcher);
      result_t *commandt_matcher_run(matcher_t *matcher, const char *needle);

      void commandt_result_free(result_t *result);

      // Scanner methods.

      scanner_t *scanner_new_copy(const char **candidates, size_t count);
      void scanner_free(scanner_t *scanner);
      void commandt_print_scanner(scanner_t *scanner);
    ]]

    local dirname = debug.getinfo(1).source:match('@?(.*/)')
    local extension = (function()
      -- Possible values listed here: http://luajit.org/ext_jit.html#jit_os
      if ffi.os == 'Windows' then
        return '.dll'
      end
      return '.so'
    end)()
    c = ffi.load(dirname .. 'commandt' .. extension)
    return c[key]
  end
})

-- Utility function for working with functions that take optional arguments.
--
-- Creates a merged table contaiing items from the supplied tables, working from
-- left to right.
--
-- ie. `merge(t1, t2, t3)` will insert elements from `t1`, then `t2`, then
-- `t3` into a new table, then return the new table.
local merge = function(...)
  local final = {}
  for _, t in ipairs({...}) do
    if t ~= nil then
      for k, v in pairs(t) do
        final[k] = v
      end
    end
  end
  return final
end

lib.commandt_matcher_new = function(scanner, options)
  options = merge({
    always_show_dot_files = false,
    case_sensitive = false,
    ignore_spaces = true,
    limit = 15,
    never_show_dot_files = false,
    recurse = true,
  }, options)
  if options.limit < 1 then
    error("limit must be > 0")
  end
  local matcher = c.commandt_matcher_new(
    scanner,
    options.always_show_dot_files,
    options.case_sensitive,
    options.ignore_spaces,
    options.limit,
    options.never_show_dot_files,
    options.recurse
   )
  ffi.gc(matcher, c.commandt_matcher_free)
  return matcher
end

lib.commandt_matcher_run = function(matcher, needle)
  print('searching for: ' .. needle)
  return c.commandt_matcher_run(matcher, needle)
end

lib.print_scanner = function(scanner)
  c.commandt_print_scanner(scanner)
end

lib.scanner_new_copy = function(candidates)
  local count = #candidates
  local scanner = c.scanner_new_copy(
    ffi.new('const char *[' .. count .. ']', candidates),
    count
  )
  ffi.gc(scanner, c.scanner_free)
  return scanner
end

return lib
