vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

import InTerminalBuffer from 'lg.vim'

def fold#adhoc#main() #{{{1
    if &ft != '' && &ft != 'markdown'
        return
    endif
    b:title_like_in_markdown = true
    if InTerminalBuffer()
        setl fdm=expr
        &l:fde = "getline(v:lnum) =~ '^٪' ? '>1' : '='"
        setl fdt=fold#fdt#get()
        return
    endif
    runtime! ftplugin/markdown.vim
    # usually, we set fold options via an autocmd listening to `BufWinEnter`
    do <nomodeline> BufWinEnter
enddef

