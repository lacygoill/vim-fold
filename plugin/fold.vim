vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# Mappings {{{1

nnoremap <unique> H <Cmd>call fold#collapseExpand#hlm('H')<CR>
nnoremap <unique> L <Cmd>call fold#collapseExpand#hlm('L')<CR>
nnoremap <unique> M <Cmd>call fold#collapseExpand#hlm('M')<CR>

# Purpose: automatically add an empty line at the end of a multi-line comment so
# that the end marker of the fold is on a dedicated line.
nnoremap <expr><unique> zfic fold#comment#main()

# Why don't you use an autocmd to automatically fold a logfile?{{{
#
# 1. a logfile could have no `.log` extension
#
# 2. a logfile can be very big
#
#    Folding a big file can be slow.
#    We should not pay this price systematically, only when we decide.
#}}}
nnoremap <unique> za <Cmd>call fold#adhoc#main()<CR>

map <unique> ]z <Plug>(next-fold)
map <unique> [z <Plug>(prev-fold)
noremap <expr> <Plug>(next-fold) fold#motion#rhs(']z')
noremap <expr> <Plug>(prev-fold) fold#motion#rhs('[z')

# Make sure  that all normal folding  commands recompute the folds  (i.e. invoke
# our `fold#lazy#compute()`).
def WrapFoldCommands()
    var fold_cmds: list<string> =<< trim END
        zA
        zC
        zM
        zO
        zR
        zX
        zc
        zo
        zv
        zx
    END
    var mapcmd: string = 'nnoremap <unique> %s'
        .. ' <Cmd>call fold#lazy#compute()'
        .. ' <Bar> execute "normal! " .. (v:count ? v:count : "") .. "%s"<CR>'
    for cmd in fold_cmds
        execute printf(mapcmd, cmd, cmd)
    endfor
    execute printf(mapcmd, '<space><space>', 'za')
enddef
WrapFoldCommands()

# I think that we sometimes try to open a fold from visual mode by accident.
# It leads to an unexpected visual selection; let's prevent this from happening.
xnoremap <unique> <Space><Space> <C-\><C-N>

# Autocmds{{{1

augroup LazyFold | autocmd!
    # recompute folds in all windows displaying the current buffer,
    # after saving it or after the foldmethod has been set by a filetype plugin
    autocmd BufWritePost,FileType * fold#lazy#computeWindows()

    # restore folds after a diff{{{
    #
    # Here's what happens to `'foldmethod'` when we diff a file which is folded with an expr:
    #
    #    1. foldmethod=expr (set by filetype plugin)
    #    2. foldmethod=manual (reset by vim-fold)
    #    3. foldmethod=diff (reset again when we diff the file)
    #
    # When we stop  the diff with `:diffoff`, Vim  automatically resets `'diff'`
    # to `manual`, because:
    #
    #    > Resets related options also when 'diff' was not set.
    #
    # Source: `:help :diffoff`.
    #
    # However, the folds have been lost when `'diff'` was set.
    # We need  to make Vim recompute  them according to the  original foldmethod
    # (the one set by our filetype plugin).
    #}}}
    autocmd OptionSet diff fold#lazy#handleDiff()
augroup END
