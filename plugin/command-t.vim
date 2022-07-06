" SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
" SPDX-License-Identifier: BSD-2-Clause

if exists('g:command_t_loaded') || &compatible
  finish
endif
let g:command_t_loaded = 1

command! -nargs=+ CommandTOpen call commandt#GotoOrOpen(<q-args>)

if empty(&switchbuf)
  set switchbuf=usetab
endif

command! CommandTBuffer call commandt#BufferFinder()
command! CommandTCommand call commandt#CommandFinder()
command! CommandTHelp call commandt#HelpFinder()
command! CommandTHistory call commandt#HistoryFinder()
command! CommandTJump call commandt#JumpFinder()
command! CommandTLine call commandt#LineFinder()
command! CommandTMRU call commandt#MRUFinder()
command! CommandTSearch call commandt#SearchFinder()
command! CommandTTag call commandt#TagFinder()
command! -nargs=? -complete=dir CommandT call commandt#FileFinder(<q-args>)
command! CommandTFlush call commandt#Flush()
command! CommandTLoad call commandt#Load()

if !hasmapto('<Plug>(CommandT)') && maparg('<Leader>t', 'n') ==# ''
  nmap <unique> <Leader>t <Plug>(CommandT)
endif
nnoremap <silent> <Plug>(CommandT) :CommandT<CR>

if !hasmapto('<Plug>(CommandTBuffer)') && maparg('<Leader>b', 'n') ==# ''
  nmap <unique> <Leader>b <Plug>(CommandTBuffer)
endif
nnoremap <silent> <Plug>(CommandTBuffer) :CommandTBuffer<CR>

nnoremap <silent> <Plug>(CommandTHelp) :CommandTHelp<CR>
nnoremap <silent> <Plug>(CommandTHistory) :CommandTHistory<CR>

if has('jumplist')
  if !hasmapto('<Plug>(CommandTJump)') && maparg('<Leader>j', 'n') ==# ''
    nmap <unique> <Leader>j <Plug>(CommandTJump)
  endif
  nnoremap <silent> <Plug>(CommandTJump) :CommandTJump<CR>
endif

nnoremap <silent> <Plug>(CommandTCommand) :CommandTCommand<CR>
nnoremap <silent> <Plug>(CommandTLine) :CommandTLine<CR>
nnoremap <silent> <Plug>(CommandTMRU) :CommandTMRU<CR>
nnoremap <silent> <Plug>(CommandTSearch) :CommandTSearch<CR>
nnoremap <silent> <Plug>(CommandTTag) :CommandTTag<CR>

" Experimental.

if !has('nvim')
  finish
endif

command! KommandTDemo lua require'wincent.commandt'.demo()
command! KommandTBuffer lua require'wincent.commandt'.buffer_finder()
command! -nargs=? -complete=dir KommandT call luaeval("require'wincent.commandt'.file_finder(_A)", <q-args>)

augroup WincentCommandT
  autocmd!

  autocmd CmdlineChanged * call luaeval("require'wincent.commandt'.cmdline_changed(_A)", expand('<afile>'))
  autocmd CmdlineEnter * lua require'wincent.commandt'.cmdline_enter()
  autocmd CmdlineLeave * lua require'wincent.commandt'.cmdline_leave()
augroup END
