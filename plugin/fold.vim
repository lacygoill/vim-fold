vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

# Mappings {{{1

nno H <cmd>call fold#collapse_expand#hlm('H')<cr>
nno L <cmd>call fold#collapse_expand#hlm('L')<cr>
nno M <cmd>call fold#collapse_expand#hlm('M')<cr>

# Purpose: automatically add an empty line at the end of a multi-line comment so
# that the end marker of the fold is on a dedicated line.
nno <expr><unique> zfic fold#comment#main()

# Why don't you use an autocmd to automatically fold a logfile?{{{
#
# 1. a logfile could have no `.log` extension
#
# 2. a logfile can be very big
#
#    Folding a big file can be slow.
#    We should not pay this price systematically, only when we decide.
#}}}
nno <unique> za <cmd>call fold#adhoc#main()<cr>

noremap <expr><unique> [z fold#motion#rhs('[z')
noremap <expr><unique> ]z fold#motion#rhs(']z')

map(['A', 'C', 'M', 'O', 'R', 'X', 'c', 'o', 'v', 'x'],
    (_, v) => execute('nno z' .. v
    .. ' <cmd>call fold#lazy#compute()<bar>exe "norm! " .. (v:count ? v:count : "") .. "z' .. v .. '"<cr>'))
nno <space><space> <cmd>call fold#lazy#compute()<bar>exe 'norm! ' .. (v:count ? v:count : '') .. 'za'<cr>

# I think that we sometimes try to open a fold from visual mode by accident.
# It leads to an unexpected visual selection; let's prevent this from happening.
xno <space><space> <c-\><c-n>

# Autocmds{{{1

augroup LazyFold | au!
    # recompute folds in all windows displaying the current buffer,
    # after saving it or after the foldmethod has been set by a filetype plugin
    au BufWritePost,FileType * fold#lazy#computeWindows()

    # restore folds after a diff{{{
    #
    # Here's what happens to `'fdm'` when we diff a file which is folded with an expr:
    #
    #    1. fdm=expr (set by filetype plugin)
    #    2. fdm=manual (reset by vim-fold)
    #    3. fdm=diff (reset again when we diff the file)
    #
    # When we stop  the diff with `:diffoff`, Vim  automatically resets `'diff'`
    # to `manual`, because:
    #
    #    > Resets related options also when 'diff' was not set.
    #
    # Source: `:h :diffoff`.
    #
    # However, the folds have been lost when `'diff'` was set.
    # We need  to make Vim recompute  them according to the  original foldmethod
    # (the one set by our filetype plugin).
    #}}}
    au OptionSet diff fold#lazy#handleDiff()
augroup END
