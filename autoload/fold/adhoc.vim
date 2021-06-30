vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

import InTerminalBuffer from 'lg.vim'

# Interface {{{1
def fold#adhoc#main() #{{{2
    if IsVimProfilingLog()
        AddMarkers()
    endif

    if &filetype != '' && &filetype != 'markdown'
        return
    endif
    b:title_like_in_markdown = true
    if InTerminalBuffer()
        &l:foldmethod = 'expr'
        &l:foldexpr = "getline(v:lnum) =~ '^٪' ? '>1' : '='"
        &l:foldtext = 'fold#foldtext#get()'
        return
    endif
    runtime! ftplugin/markdown.vim
    # usually, we set fold options via an autocmd listening to `BufWinEnter`
    doautocmd <nomodeline> BufWinEnter
enddef
#}}}1
# Core {{{1
def AddMarkers() #{{{2
    # create an empty fold before the first profiled function for better readability
    AddEmptyFold('FUNCTION')
    # same thing befored the summary at the end
    AddEmptyFold('FUNCTIONS SORTED')
    # marker for each function
    silent keepjumps keeppatterns :% substitute/^FUNCTION\s\+/## /e
    # marker for each script, and for the ending summaries
    silent keepjumps keeppatterns :% substitute/^SCRIPT\|^\zeFUNCTIONS SORTED/# /e
enddef

def AddEmptyFold(pat: string) #{{{2
    if search(pat, 'n') == 0
        return
    endif
    execute 'silent keepjumps keeppatterns :1/^' .. pat .. '\s/-1 put _'
    silent keepjumps keeppatterns substitute/^/#/
enddef
#}}}1
# Utility {{{1
def IsVimProfilingLog(): bool #{{{2
    return search('count  total (s)   self (s)', 'n') > 0
        && search('^\%(FUNCTION\|SCRIPT\|FUNCTIONS SORTED\)\s', 'n') > 0
enddef

