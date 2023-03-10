# SPDX-FileCopyrightText: Copyright 2011-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

module CommandT
  class Finder
    class HelpFinder < Finder
      def initialize(options = {})
        @scanner = Scanner::HelpScanner.new
        @matcher = Matcher.new @scanner, :always_show_dot_files => true
      end

      def open_selection(command, selection, options = {})
        # E434 "Can't find tag pattern" is innocuous, caused by tags like
        #
        #     LanguageClient.txt      LanguageClient.txt      /*LanguageClient.txt*
        #
        # From:
        #
        #     https://github.com/autozimu/LanguageClient-neovim
        #
        # Which has no corresponding target inside the help file.
        #
        # Related:
        #
        #     https://github.com/autozimu/LanguageClient-neovim/pull/731
        #
        ::VIM::command "try | help #{selection} | catch /E434/ | endtry"
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
        'Help'
      end
    end
  end
end
