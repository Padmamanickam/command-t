# SPDX-FileCopyrightText: Copyright 2014-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

module CommandT
  module SCMUtilities

  private

    def nearest_ancestor(starting_directory, markers)
      path = File.expand_path(starting_directory)
      while !markers.
        map { |dir| File.join(path, dir) }.
        map { |dir| File.exist?(dir) }.
        any?
        next_path = File.expand_path(File.join(path, '..'))
        return nil if next_path == path
        path = next_path
      end
      path
    end
  end
end
