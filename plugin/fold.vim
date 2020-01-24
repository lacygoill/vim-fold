if exists('g:loaded_fold')
    finish
endif
let g:loaded_fold = 1

" Mappings {{{1

nno <silent> H :<c-u>call fold#collapse_expand#hlm('H')<cr>
nno <silent> L :<c-u>call fold#collapse_expand#hlm('L')<cr>
nno <silent> M :<c-u>call fold#collapse_expand#hlm('M')<cr>

" Purpose: automatically add an empty line at the end of a multi-line comment so
" that the end marker of the fold is on a dedicated line.
nno <silent><unique> zfic :<c-u>set opfunc=fold#comment#main<cr>g@l

" Why don't you use an autocmd to automatically fold a logfile?{{{
"
" 1. a logfile could have no `.log` extension
"
" 2. a logfile can be very big
"
"    Folding a big file can be slow.
"    We should not pay this price systematically, only when we decide.
"}}}
nno <silent><unique> -l :<c-u>call fold#adhoc#main()<cr>

" Why the `[Z` and `]Z` mappings?{{{
"
" By default the cursor is moved to the previous/next fold:
"
"    - no matter its level
"      with `zj` and `zk`
"
"    - on the condition its level is greater than the current one
"      with `[z` and `]z`
"
" I don't like the asymmetry between the 2 pairs of mappings.
" I prefer to use `[z`, `]z` and `[Z`, `]Z`.
"}}}
noremap <expr><silent><unique> [Z fold#motion#rhs('[Z')
noremap <expr><silent><unique> ]Z fold#motion#rhs(']Z')
noremap <expr><silent><unique> [z fold#motion#rhs('[z')
noremap <expr><silent><unique> ]z fold#motion#rhs(']z')

xno <silent> [f :<c-u>call fold#md#promote#set('less')<bar>set opfunc=fold#md#promote#main<bar>exe 'norm! '..v:count1..'g@l'<cr>
xno <silent> ]f :<c-u>call fold#md#promote#set('more')<bar>set opfunc=fold#md#promote#main<bar>exe 'norm! '..v:count1..'g@l'<cr>

" Increase/decrease  'fdl', in  a  markdown  buffer  in “nesting” mode.{{{
" Use it to quickly see the titles up to an arbitrary depth.
" Useful  to get  an overview  of  the contents  of  the notes  of an  arbitrary
" precision.
"}}}
nno <silent> [of :<c-u>call fold#md#option#fdl('less')<cr>
nno <silent> ]of :<c-u>call fold#md#option#fdl('more')<cr>

call map(['A', 'C', 'M', 'O', 'R', 'X', 'a', 'c', 'o', 'v', 'x'],
    \ {_,v -> execute('nno <silent> z'..v..' :<c-u>call fold#lazy#compute()<cr>z'..v)})
nno <silent> <space><space> :<c-u>call fold#lazy#compute()<cr>za

" I think that we sometimes try to open a fold from visual mode by accident.
" It leads to an unexpected visual selection; let's prevent this from happening.
xno <silent> <space><space> <esc>

" Autocmds{{{1

augroup LazyFold
    au!

    " make foldmethod local to buffer instead of window
    au WinEnter * if exists('b:last_fdm') | let w:last_fdm = b:last_fdm | endif
    au WinLeave * call fold#lazy#on_winleave()
    " TODO: what do these 2 previous autocmds do?

    " recompute folds in all windows displaying the current buffer,
    " after saving it or after the foldmethod has been by a filetype plugin
    " TODO: FastFold listened to `SessionLoadPost` too; why?
    au BufWritePost,FileType * call fold#lazy#compute_all_windows()

    " restore folds after a diff{{{
    "
    " Here's what happens to `'fdm'` when we diff a file which is folded with an expr:
    "
    "    1. fdm=expr (set by filetype plugin)
    "    2. fdm=manual (reset by vim-fold)
    "    3. fdm=diff (reset again when we diff the file)
    "
    " When we stop the diff, Vim resets `'diff'` to `manual`, because:
    "
    " >     Resets related options also when 'diff' was not set.
    "
    " Source: `:h :diffoff`.
    "
    " However, the folds have been lost when `'diff'` was set.
    " We need  to make Vim recompute  them according to the  original foldmethod
    " (the one set by our filetype plugin).
    "}}}
    au OptionSet diff call fold#lazy#handle_diff()

    " TODO: These autocmds were in FastFold:{{{
    "
    "     au BufEnter *
    "     \ if !exists('b:lastchangedtick') | let b:lastchangedtick = b:changedtick | endif |
    "     \ if b:changedtick != b:lastchangedtick && (&l:fdm isnot# 'diff' && exists('b:prediff_fdm'))
    "     \ | call s:UpdateBuf() | endif
    "     au BufLeave * let b:lastchangedtick = b:changedtick
    "
    " We've removed them.  Why did we remove them?  Could they be useful?
    "
    " ---
    "
    " Btw, I think the code could be simplified:
    "
    "     au BufEnter *
    "     \ if b:changedtick != get(b:, 'lastchangedtick', b:changedtick)
    "     \ && (&l:fdm isnot# 'diff' && exists('b:prediff_fdm'))
    "     \ | call s:UpdateBuf() | endif
    "     au BufLeave * let b:lastchangedtick = b:changedtick
    "
    " ---
    "
    " I think these autocmds handle the case where we've just left diff mode:
    "
    "     &l:fdm isnot# 'diff' && exists('b:prediff_fdm')
    "     ^^^^^^^^^^^^^^^^^^^^    ^^^^^^^^^^^^^^^^^^^^^^^
    "     not in diff mode        but we were recently
    "
    " And the buffer has been changed:
    "
    "     b:changedtick != get(b:, 'lastchangedtick', b:changedtick)
    "}}}
augroup END

