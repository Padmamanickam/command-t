# SPDX-FileCopyrightText: Copyright 2011-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

module CommandT
  class Scanner
    class CommandScanner < Scanner
      def paths
        @paths ||= paths!
      end

    private

      def paths!
        # Get user commands.
        commands = VIM.capture('command').split("\n")[2..-1].map do |line|
          line.sub(/\A.{4}(\S+).+/, '\1')
        end

        # Get built-in commands from `ex-cmd-index`.
        ex_cmd_index = ::VIM.evaluate('expand(findfile("doc/index.txt", &runtimepath))')
        if File.readable?(ex_cmd_index)
          File.readlines(ex_cmd_index).each do |line|
            if line =~ %r{\A\|:([^|]+)\|\s+}
              commands << $~[1]
            end
          end
        end

        commands.uniq
      end
    end
  end
end
