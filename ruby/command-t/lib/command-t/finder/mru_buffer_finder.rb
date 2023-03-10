# SPDX-FileCopyrightText: Copyright 2014-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

module CommandT
  class Finder
    class MRUBufferFinder < BufferFinder
      def initialize
        @scanner = Scanner::MRUBufferScanner.new
        @matcher = Matcher.new @scanner, :always_show_dot_files => true
      end

      # Override sorted_matches_for to prevent MRU ordered matches from being
      # ordered alphabetically.
      def sorted_matches_for(str, options = {})
        matches = super(str, options.merge(:sort => false))

        # Take current buffer (by definition, the most recently used) and move it
        # to the end of the results.
        if MRU.last &&
          relative_path_under_working_directory(
            ::VIM.evaluate("bufname(#{MRU.last})")
          ) == matches.first
          matches[1..-1] + [matches.first]
        else
          matches
        end
      end

      def name
        'Recent'
      end
    end
  end
end
