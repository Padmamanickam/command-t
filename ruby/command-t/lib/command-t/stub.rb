# SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

module CommandT
  class Stub
    expected = "#{Metadata::EXPECTED_RUBY_VERSION}-p#{Metadata::EXPECTED_RUBY_PATCHLEVEL}"
    actual = "#{RUBY_VERSION}-p#{defined?(RUBY_PATCHLEVEL) ? RUBY_PATCHLEVEL : '[unknown]'}"
    @@load_error = [
      'command-t.vim could not load the C extension.',
      'Please see INSTALLATION and TROUBLE-SHOOTING in the help.',
      "Vim Ruby version: #{actual}"
    ]
    @@load_error << "Expected version: #{expected}" if actual != expected
    @@load_error << 'For more information type:    :help command-t-ruby'

    [
      :flush,
      :show_buffer_finder,
      :show_command_finder,
      :show_file_finder,
      :show_history_finder,
      :show_help_finder,
      :show_jump_finder,
      :show_line_finder,
      :show_mru_finder,
      :show_search_finder,
      :show_tag_finder
    ].each do |method|
      define_method(method) { warn *@@load_error }
    end

    def active_finder
      ''
    end

    def path
      ''
    end

    def return_is_own_buffer
      0
    end

  private

    def warn(*msg)
      ::VIM::command 'echohl WarningMsg'
      msg.each { |m| ::VIM::command "echo '#{m}'" }
      ::VIM::command 'echohl none'
    end
  end
end
