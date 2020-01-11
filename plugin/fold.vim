if exists('g:loaded_fold')
    finish
endif
let g:loaded_fold = 1

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

" Why don't you use an autocmd to automatically fold a logfile?{{{
"
" 1. a logfile could have no `.log` extension
"
" 2. a logfile can be very big
"
"    Folding a big file can be slow.
"    We should not pay this price systematically, only when we decide.
"}}}
nno <silent><unique> -l :<c-u>call fold#logfile#main()<cr>

" Purpose: automatically add an empty line at the end of a multi-line comment so
" that the end marker of the fold is on a dedicated line.
nno <silent><unique> zfic :<c-u>set opfunc=fold#comment#main<cr>g@l





" finish

" Purpose:{{{
"
" Editing text in insert mode in a markdown buffer can sometimes be slow.
"
" MWE:
"
"     $ vim -Nu <(cat <<'EOF'
"     setl fdm=expr fde=Heading_depth(v:lnum)>0?'>1':'='
"     fu Heading_depth(lnum)
"         let nextline = getline(a:lnum+1)
"         let level = len(matchstr(getline(a:lnum), '^#\{1,6}'))
"         if !level
"             if nextline =~# '^=\+\s*$'
"                 return '>1'
"             elseif nextline =~# '^-\+\s*$'
"                 return '>2'
"             endif
"         endif
"         return level
"     endfu
"     ino <expr> <c-k> repeat('<del>', 300)
"     EOF
"     ) +"%d | put='text' | norm! yy300pG300Ax" /tmp/md.md
"
" Vim takes several seconds to start.
" Now, press `I C-k C-k` to delete the rest of the line.
" Again, it takes several seconds.
"
" It seems the issue is `fold#md#fde#heading_depth()` which, for some reason, is
" called more than 180,000 times!
"
" I think  that every time  a character is inserted  or removed while  in insert
" mode, Vim has to  recompute the folding level of each line  above when using a
" foldexpr.
" That would  explain why  the issue  gets worse  as the  number of  lines above
" increases, and why it gets worse  as the number of inserted/removed characters
" increases.
"
" ---
"
" The main culprit is the value `'='` returned from `Heading_depth()`.
" If you replace it with `1`, the slowness disappears.
"}}}
"   Why can't we just use `>1` and `1` to fix this issue?{{{
"
" I don't want to use `1` in `fold#md#fde#stacked()`; see the comments there.
"
" Besides, for a given buffer, we may be using:
"
"    - a different foldexpr which uses a costly value (e.g. `'='`, `'a123'`, `'s123'`)
"    - a different folding method which can still be slow (e.g. `syntax`)
"}}}
"     Ok, so how does `vim-fold` fix it?{{{
"
" It lets Vim create folds according to the value of `'fdm'` (e.g. `foldexpr` or
" `syntax`), then  it resets the latter  to `manual`, which is  much less costly
" because this  doesn't ask Vim to  re-compute anything every time  you edit the
" buffer.
"
" From `:h fold-methods`:
"
" >     Switching to  the "manual" method  doesn't remove the existing  folds.  This
" >     can be  used to first  define the folds  automatically and then  change them
" >     manually.
"
" ---
"
" You can observe the positive effect from `vim-fold` like this:
"
"     $ vim -Nu <(cat <<'EOF'
"     set rtp^=~/.vim/plugged/vim-fold | setl fdm=expr fde=Heading_depth(v:lnum)>0?'>1':'='
"     fu Heading_depth(lnum)
"         let level = len(matchstr(getline(a:lnum), '^#\{1,6}'))
"         if !level
"             if getline(a:lnum+1) =~ '^=\+\s*$'
"                 let level = 1
"             endif
"         endif
"         return level
"     endfu
"     ino <expr> <c-k> repeat('<del>', 300)
"     EOF
"     ) +"%d | put='text' | norm! yy300pG300Ax" /tmp/md.md
"
" If you get an error because of `lg#win_execute()`, add `vim-lg-lib` to the rtp.
" In any case, Vim should start up immediately, and removing 300 characters with
" `C-k` should also be instantaneous.
"}}}

" TODO: Check whether we need to execute `:norm! zv` in `s:update_win()`.{{{
"
" Old comment preceding `:norm! zv` (in our vimrc):
"
"     In a markdown file, where `'fdl'` has the value `0`, enter insert mode
"     to write the  first line of a  new fold (starting with  one or several
"     `#`); as soon as you leave insert mode, the new fold is closed.
"
"     This is annoying, because I expect to  be able to write sth inside the
"     new fold immediately; instead, I have to first open it back.
"     Let's open it automatically.
"
" https://github.com/lacygoill/config/blob/f93450ab3d9ac9cf960cbf0551dad01b668d9302/.vim/vimrc#L6262-L6273
"
" ---
"
" Maybe we need to.
" Try this:
"
"     $ vim +"%d|pu='x'|norm! yy200p" /tmp/md.md
"     " press: zo gg O #
"     :w
"
" The fold is automatically closed; it should stay open.
"
" Find a MWE of this issue.
"}}}

" TODO: finish understanding/refactoring/reviewing/documenting the "Core" and "Interface" sections

" Core {{{1
fu s:on_winleave() abort "{{{2
    for var in ['last_fdm', 'prediff_fdm']
        if exists('w:'..var)
            let b:{var} = w:{var}
        elseif exists('b:'..var)
            unlet b:{var}
        endif
    endfor
endfu

fu s:on_bufenter() abort "{{{2
    if !exists('b:lastchangedtick')
        let b:lastchangedtick = b:changedtick
    endif
    if b:changedtick != b:lastchangedtick && &l:fdm isnot# 'diff' && exists('b:prediff_fdm')
        call s:update_buf(0)
    endif
endfu

fu s:update_tab() abort "{{{2
    if exists('g:SessionLoad') | return | endif
    call s:windo('call s:update_win()')
endfu

fu s:update_win() abort "{{{2
    if exists('w:prediff_fdm')
        if empty(&l:fdm) || &l:fdm is# 'manual'
            let &l:fdm = w:prediff_fdm
            unlet w:prediff_fdm
            return
        elseif &l:fdm isnot# 'diff'
            unlet w:prediff_fdm
        endif
    endif

    if &l:fdm is# 'diff' && exists('w:last_fdm')
        let w:prediff_fdm = w:last_fdm
    endif

    if &l:fdm is# 'manual' && exists('w:last_fdm')
        let &l:fdm = w:last_fdm
    endif

    if s:should_skip()
        if exists('w:last_fdm') | unlet w:last_fdm | endif
    else
        let w:last_fdm = &l:fdm
        " TODO: Why do we need `s:update_folds()` to force Vim to create folds?{{{
        "
        " If I execute `setl fdm=expr fde=getline(v:lnum)=~#'^#'?'>1':1` in a file,
        " the folds are created immediately.
        "
        " ---
        "
        " And why does `:windo "` cause the folds to be created?
        "}}}
        call s:update_folds()
        setl fdm=manual
    endif
endfu

fu s:update_buf(feedback) abort "{{{2
    if exists('g:SessionLoad') | return | endif

    let s:curbuf = bufnr('%')
    call s:windo("if bufnr('%') == s:curbuf() | call s:update_win() | endif")

    if !a:feedback | return | endif

    if !exists('w:last_fdm')
        echom printf("'%s' folds already continuously updated", &l:fdm)
    else
        echom printf("updated '%s' folds", w:last_fdm)
    endif
endfu

fu s:curbuf() abort
    return s:curbuf
endfu

fu s:update_folds() abort
    if !s:is_reasonable() | return | endif
    let view = winsaveview()
    " Why not `:norm! zx`?{{{
    "
    " Because  it  also  undoes  all  manually  opened/closed  folds,  which  is
    " annoying. And remember that `winsaveview()`  does not save fold information.
    "}}}
    " Which alternative could I use?{{{
    "
    "     windo "
    "     au SafeState * ++once do <nomodeline> WinEnter window_height
    "
    " But in that case, you should:
    "
    "    - remove the `s:isReasonable()` guard
    "
    "    - call `s:update_folds()` from `s:windo()`, or from `s:update_buf()` and `s:update_tab()`;
    "      not from `s:update_win()`
    "      (otherwise `:windo` would be invoked for every window, which is unnecessary/too much)
    "}}}
    norm! zizi
    call winrestview(view)
endfu
"}}}1
" Utilities {{{1
fu s:windo(cmd) abort "{{{2
    if !empty(getcmdwintype()) | return | endif
    call map(range(1, winnr('$')), {_,v -> lg#win_execute(win_getid(v), a:cmd)})
endfu

fu s:should_skip() abort "{{{2
    return s:is_small() || !s:is_reasonable() || !empty(&bt) || !&l:ma
endfu

fu s:is_reasonable() abort "{{{2
    return &l:fdm is# 'syntax' || &l:fdm is# 'expr'
endfu

fu s:is_small() abort "{{{2
    " TODO: Make experiments to find the right value.
    "
    "     $ vim +"%d | put='text' | norm! yy123pG123Ax" /tmp/md.md
    "
    " Check how much time  Vim takes to start up, and how much  time it takes to
    " remove the characters when we press `I C-k`.
    "
    " ---
    "
    " Originally, it was 200; but that was way too big.
    return line('$') <= 30
endfu
"}}}1
" Interface {{{1

" TODO: What does this command do? How is it useful compared to `zx`?{{{
"
" Update: I think  one of the difference  is that `zx` only  affects the current
" window, while `FastFoldUpdate` affects all windows in the current tab page.
"}}}
com -bar -bang FastFoldUpdate call s:update_buf(<bang>0)

fu s:install_mappings() abort
    nno <silent><unique> zuz :<c-u>FastFoldUpdate!<cr>
    for suffix in ['x', 'X', 'a', 'A', 'o', 'O', 'c', 'C']
        exe 'nno <silent> z'..suffix..' :<c-u>call <SID>update_win()<cr>z'..suffix
    endfor
    for cmd in ['[z', ']z', '[Z', ']Z']
        " TODO: Integrate this in our current `[z` &friends mappings.{{{
        "
        " Try to call `fold#fast#update_win()` from `fold#motion#rhs()`.
        " If you don't, and you prefer to use these mappings, you'll need to add
        " `return ''` at the end of `s:update_win()`.
        "}}}
        "     exe 'nno <expr><silent> '..cmd..' <sid>update_win()..v:count..'..string(cmd)
        "     exe 'xno <expr><silent> '..cmd..' <sid>update_win().."gv"..v:count..'..string(cmd)
        "     exe 'ono <expr><silent> '..cmd..' "<esc>"..<sid>update_win()..''"''..v:register..v:operator..v:count1..'..string(cmd)
    endfor
endfu
call s:install_mappings()

augroup FastFoldEnter
    au!
    au VimEnter * call s:update_tab()
    " Make foldmethod local to buffer instead of window
    au WinEnter * if exists('b:last_fdm') | let w:last_fdm = b:last_fdm | endif
    au WinLeave * call s:on_winleave()
    " Update folds after:
    " foldmethod set by saving, filetype autocmd, `:loadview` or `:source Session.vim`
    au BufWritePost,FileType,SessionLoadPost * call s:update_buf(0)
    " foldmethod set by modeline
    au BufWinEnter * if !exists('b:fastfold') | call s:update_buf(0) | let b:fastfold = 1 | endif
    " entering a changed buffer
    au BufEnter * call s:on_bufenter()
    au BufLeave * let b:lastchangedtick = b:changedtick
augroup END
"}}}1
