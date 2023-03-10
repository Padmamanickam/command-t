# SPDX-FileCopyrightText: Copyright 2011-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

module CommandT
  class Finder
    class TagFinder < Finder
      def initialize(options = {})
        @scanner = Scanner::TagScanner.new options
        @matcher = Matcher.new @scanner, :always_show_dot_files => true
      end

      def open_selection(command, selection, options = {})
        if @scanner.include_filenames
          selection = selection[0, selection.index(':')]
        end

        #  open the tag and center the screen on it
        ::VIM::command "silent! tag #{selection} | :normal zz"
      end

      def prepare_selection(selection)
        # Pass selection through as-is, bypassing path-based stuff that the
        # controller would otherwise do, like `expand_path`,
        # `sanitize_path_string` and `relative_path_under_working_directory`.
        selection
      end

      def flush
        @scanner.flush
      end

      def name
        'Tags'
      end
    end
  end
end
