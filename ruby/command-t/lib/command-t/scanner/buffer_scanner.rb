# SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

module CommandT
  class Scanner
    # Returns a list of all open buffers.
    class BufferScanner < Scanner
      include PathUtilities

      def paths
        @paths ||= paths!
      end

    private

      def paths!
        VIM.capture('ls').scan(/\n\s*(\d+)[^\n]+/).map do |n|
          number = n[0].to_i
          name = ::VIM.evaluate("bufname(#{number})")
          relative_path_under_working_directory(name) unless name == ''
        end.compact
      end
    end
  end
end
