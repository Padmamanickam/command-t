return {
  variants = {
    {
      name = 'buffer',
      source = 'wincent.commandt.private.scanner.buffer',
      times = 10000,
      skip_in_ci = false,
      stub_candidates = function(scanner)
        -- Note this is all a bit fake because the real scanner would burn
        -- cycles actually asking Vim for these, and that's the actually
        -- interesting part of the work.
        scanner.get = function()
          return {
            '.ctags',
            '.gitattributes',
            '.github/workflows/lua.yml',
            '.github/workflows/ruby.yaml',
            '.gitignore',
            '.gitmodules',
            '.mailmap',
            '.rspec',
            '.styluaignore',
            '.vim_org.yml',
            '.watchmanconfig',
            'CODE_OF_CONDUCT.md',
            'CONTRIBUTING.md',
            'Gemfile',
            'Gemfile.lock',
            'LICENSE',
            'README.md',
            'Rakefile',
            'appstream/vim-command-t.metainfo.xml',
            'autoload/commandt.vim',
            'autoload/commandt/private.vim',
            'bin/benchmarks/matcher.lua',
            'bin/benchmarks/matcher.rb',
            'bin/benchmarks/scanner.lua',
            'bin/benchmarks/watchman.rb',
            'bin/prettier.sh',
            'bin/stylua.sh',
            'bin/test.lua',
            'bin/test.sh',
            'data/benchmark.yml',
            'data/wincent/commandt/benchmark/configs/matcher.lua',
            'data/wincent/commandt/benchmark/configs/scanner.lua',
            'data/wincent/commandt/benchmark/logs/.gitignore',
            'doc/.gitignore',
            'doc/command-t.txt',
            'fixtures/bar/abc',
            'fixtures/bar/xyz',
            'fixtures/baz',
            'fixtures/bing',
            'fixtures/foo/alpha/t1',
            'fixtures/foo/alpha/t2',
            'fixtures/foo/beta',
            'ftplugin/CommandTMatchListing.lua',
            'ftplugin/CommandTPrompt.lua',
            'lua/wincent/commandt/README.md',
            'lua/wincent/commandt/init.lua',
            'lua/wincent/commandt/lib/.gitignore',
            'lua/wincent/commandt/lib/.make/.gitignore',
            'lua/wincent/commandt/lib/Makefile',
            'lua/wincent/commandt/lib/commandt.c',
            'lua/wincent/commandt/lib/commandt.h',
            'lua/wincent/commandt/lib/debug.c',
            'lua/wincent/commandt/lib/debug.h',
            'lua/wincent/commandt/lib/die.c',
            'lua/wincent/commandt/lib/die.h',
            'lua/wincent/commandt/lib/heap.c',
            'lua/wincent/commandt/lib/heap.h',
            'lua/wincent/commandt/lib/matcher.c',
            'lua/wincent/commandt/lib/matcher.h',
            'lua/wincent/commandt/lib/scanner.c',
            'lua/wincent/commandt/lib/scanner.h',
            'lua/wincent/commandt/lib/score.c',
            'lua/wincent/commandt/lib/score.h',
            'lua/wincent/commandt/lib/str.c',
            'lua/wincent/commandt/lib/str.h',
            'lua/wincent/commandt/lib/watchman.c',
            'lua/wincent/commandt/lib/watchman.h',
            'lua/wincent/commandt/lib/xmalloc.c',
            'lua/wincent/commandt/lib/xmalloc.h',
            'lua/wincent/commandt/lib/xmap.c',
            'lua/wincent/commandt/lib/xmap.h',
            'lua/wincent/commandt/private/benchmark.lua',
            'lua/wincent/commandt/private/lib.lua',
            'lua/wincent/commandt/private/match_listing.lua',
            'lua/wincent/commandt/private/path.lua',
            'lua/wincent/commandt/private/prompt.lua',
            'lua/wincent/commandt/private/scanner/buffer.lua',
            'lua/wincent/commandt/private/scanner/git.lua',
            'lua/wincent/commandt/private/scanner/help.lua',
            'lua/wincent/commandt/private/scanner/init.lua',
            'lua/wincent/commandt/private/scanner/rg.lua',
            'lua/wincent/commandt/private/scanner/test/init.lua',
            'lua/wincent/commandt/private/scanner/watchman.lua',
            'lua/wincent/commandt/private/test/path.lua',
            'lua/wincent/commandt/private/time.lua',
            'lua/wincent/commandt/test/matcher.lua',
            'plugin/command-t.lua',
            'plugin/command-t.vim',
            'ruby/command-t/command-t.gemspec',
            'ruby/command-t/ext/command-t/.gitignore',
            'ruby/command-t/ext/command-t/depend',
            'ruby/command-t/ext/command-t/ext.c',
            'ruby/command-t/ext/command-t/ext.h',
            'ruby/command-t/ext/command-t/extconf.rb',
            'ruby/command-t/ext/command-t/heap.c',
            'ruby/command-t/ext/command-t/heap.h',
            'ruby/command-t/ext/command-t/match.c',
            'ruby/command-t/ext/command-t/match.h',
            'ruby/command-t/ext/command-t/matcher.c',
            'ruby/command-t/ext/command-t/matcher.h',
            'ruby/command-t/ext/command-t/ruby_compat.h',
            'ruby/command-t/ext/command-t/watchman.c',
            'ruby/command-t/ext/command-t/watchman.h',
            'ruby/command-t/lib/command-t.rb',
            'ruby/command-t/lib/command-t/controller.rb',
            'ruby/command-t/lib/command-t/finder.rb',
            'ruby/command-t/lib/command-t/finder/buffer_finder.rb',
            'ruby/command-t/lib/command-t/finder/command_finder.rb',
            'ruby/command-t/lib/command-t/finder/file_finder.rb',
            'ruby/command-t/lib/command-t/finder/help_finder.rb',
            'ruby/command-t/lib/command-t/finder/history_finder.rb',
            'ruby/command-t/lib/command-t/finder/jump_finder.rb',
            'ruby/command-t/lib/command-t/finder/line_finder.rb',
            'ruby/command-t/lib/command-t/finder/mru_buffer_finder.rb',
            'ruby/command-t/lib/command-t/finder/tag_finder.rb',
            'ruby/command-t/lib/command-t/match_window.rb',
            'ruby/command-t/lib/command-t/metadata/fallback.rb',
            'ruby/command-t/lib/command-t/mru.rb',
            'ruby/command-t/lib/command-t/path_utilities.rb',
            'ruby/command-t/lib/command-t/progress_reporter.rb',
            'ruby/command-t/lib/command-t/prompt.rb',
            'ruby/command-t/lib/command-t/scanner.rb',
            'ruby/command-t/lib/command-t/scanner/buffer_scanner.rb',
            'ruby/command-t/lib/command-t/scanner/command_scanner.rb',
            'ruby/command-t/lib/command-t/scanner/file_scanner.rb',
            'ruby/command-t/lib/command-t/scanner/file_scanner/find_file_scanner.rb',
            'ruby/command-t/lib/command-t/scanner/file_scanner/git_file_scanner.rb',
            'ruby/command-t/lib/command-t/scanner/file_scanner/ruby_file_scanner.rb',
            'ruby/command-t/lib/command-t/scanner/file_scanner/watchman_file_scanner.rb',
            'ruby/command-t/lib/command-t/scanner/help_scanner.rb',
            'ruby/command-t/lib/command-t/scanner/history_scanner.rb',
            'ruby/command-t/lib/command-t/scanner/jump_scanner.rb',
            'ruby/command-t/lib/command-t/scanner/line_scanner.rb',
            'ruby/command-t/lib/command-t/scanner/mru_buffer_scanner.rb',
            'ruby/command-t/lib/command-t/scanner/tag_scanner.rb',
            'ruby/command-t/lib/command-t/scm_utilities.rb',
            'ruby/command-t/lib/command-t/settings.rb',
            'ruby/command-t/lib/command-t/stub.rb',
            'ruby/command-t/lib/command-t/util.rb',
            'ruby/command-t/lib/command-t/vim.rb',
            'ruby/command-t/lib/command-t/vim/screen.rb',
            'ruby/command-t/lib/command-t/vim/window.rb',
            'spec/command-t/controller_spec.rb',
            'spec/command-t/finder/buffer_finder_spec.rb',
            'spec/command-t/finder/file_finder_spec.rb',
            'spec/command-t/matcher_spec.rb',
            'spec/command-t/scanner/buffer_scanner_spec.rb',
            'spec/command-t/scanner/file_scanner/ruby_file_scanner_spec.rb',
            'spec/command-t/scanner/file_scanner/watchman_file_scanner_spec.rb',
            'spec/command-t/scanner/file_scanner_spec.rb',
            'spec/command-t/vim_spec.rb',
            'spec/command-t/watchman/utils_spec.rb',
            'spec/spec_helper.rb',
            'stylua.toml',
            'vendor/vimscriptuploader',
            'vendor/vroom',
          }
        end
      end,
    },
    {
      name = 'git',
      source = 'wincent.commandt.private.scanner.git',
      times = 100,
      skip_in_ci = false,
    },
    {
      name = 'rg',
      source = 'wincent.commandt.private.scanner.rg',
      times = 100,
      skip_in_ci = true,
    },
    {
      name = 'watchman',
      source = 'wincent.commandt.private.scanner.watchman',
      -- Not sure why this one is so slow in the suite; it feels fast interactively.
      times = 5,
      skip_in_ci = true,
    },
  },
}