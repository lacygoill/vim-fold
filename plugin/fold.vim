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





" TODO: finish understanding/refactoring/reviewing/documenting the "Core" and "Interface" sections

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

" Init {{{1

" Originally, `vim-fastfold` used 200, but it seemed too much.{{{
"
" Whatever value you use, make this experiment:
"
"                                       replace with the new number you want to use (minus 3)
"                                       vvv  vvv
"     $ vim +"%d | put='text' | norm! yy123pG123Ax" /tmp/md.md
"     " make sure that 'fdm' is 'expr'
"     " press:  I C-k
"
" Check how much time it takes for Vim to remove all the characters.
" Choose a value for which the time is acceptable.
" 30 seems like a  good fit, because it's a round number, and  it's close to the
" current maximum number of lines I can display in a window (`&lines`).
"
" `s:MIN_LINES` is  used to  determine whether  a file is  small, in  which case
" `'fdm'` is not reset to `manual`.
" It makes sense to consider a file which  fits on a single screen as small; but
" not anything above.
"}}}
const s:MIN_LINES = 30

" Interface {{{1

" TODO: What does this command do? How is it useful compared to `zx`?{{{
"
" Update: I think  one of the difference  is that `zx` only  affects the current
" window, while `FoldLazyCompute` affects all windows in the current tab page.
"}}}
com -bar -bang FoldLazyCompute call s:update_buf(<bang>0)

fu s:install_mappings() abort
    nno <silent><unique> zuz :<c-u>FoldLazyCompute!<cr>
    for suffix in ['x', 'X', 'a', 'A', 'o', 'O', 'c', 'C']
        exe 'nno <silent> z'..suffix..' :<c-u>call <SID>update_win()<cr>z'..suffix
    endfor
    for cmd in ['[z', ']z', '[Z', ']Z']
        " TODO: Integrate this in our current `[z` &friends mappings.{{{
        "
        " Try to call `fold#fast#update_win()` from `fold#motion#rhs()`.
        " If you don't, and you prefer to use these mappings, you'll need to add
        " `return ''` at the end of `s:update_win()`.
        "
        " You'll probably need to make `s:update_win()` a public function.
        " If you don't want to (or can't), maybe you could use `:FoldLazyCompute`
        " (if necessary, allow it to accept  an optional argument to tell it which
        " function it should invoke...).
        "}}}
        "     exe 'nno <expr><silent> '..cmd..' <sid>update_win()..v:count..'..string(cmd)
        "     exe 'xno <expr><silent> '..cmd..' <sid>update_win().."gv"..v:count..'..string(cmd)
        "     exe 'ono <expr><silent> '..cmd..' "<esc>"..<sid>update_win()..''"''..v:register..v:operator..v:count1..'..string(cmd)
    endfor
endfu
call s:install_mappings()

augroup LazyFold
    au!
    au VimEnter * call s:update_tab()
    " Make foldmethod local to buffer instead of window
    au WinEnter * if exists('b:last_fdm') | let w:last_fdm = b:last_fdm | endif
    au WinLeave * call s:on_winleave()
    " Update folds after:
    " foldmethod set by saving, filetype autocmd, `:loadview` or `:source Session.vim`
    au BufWritePost,FileType,SessionLoadPost * call s:update_buf(0)
    " foldmethod set by modeline
    au BufWinEnter * if !exists('b:lazyfold') | call s:update_buf(0) | let b:lazyfold = 1 | endif
    " entering a changed buffer
    au BufEnter * call s:on_bufenter()
    au BufLeave * let b:lazyfold_lastchangedtick = b:changedtick
augroup END
"}}}1
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
    if !exists('b:lazyfold_lastchangedtick')
        let b:lazyfold_lastchangedtick = b:changedtick
    endif
    if b:changedtick != b:lazyfold_lastchangedtick && &l:fdm isnot# 'diff' && exists('b:prediff_fdm')
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
        " Why do you delay `:setl fdm=manual`?{{{
        "
        " If you run it immediately, no fold will be created:
        "
        "     $ vim -Nu NONE -S <(cat <<'EOF'
        "     setl fml=0 fdm=manual fde=getline(v:lnum)=~#'^#'?'>1':'='
        "     %d|pu=repeat(['x'], 5)|1
        "     EOF
        "     ) /tmp/file
        "     " insert:  #
        "     " run:  setl fdm=expr | setl fdm=manual
        "     " no fold is created;
        "     " but if you had run `:setl fdm=expr`, then later `:setl manual`, a fold would have been created
        "}}}
        "   Why not `:norm! zx`?{{{
        "
        " It also  undoes all manually  opened/closed folds, which  is annoying.
        " And remember that `winsaveview()` does not save fold information.
        "}}}
        "   Which alternatives could I use?{{{
        "
        "     exe winnr()..'windo "'
        "     setl fdm=manual
        "
        " Or:
        "
        "     let view = winsaveview()
        "     norm! zizi
        "     setl fdm=manual
        "     call winrestview(view)
        "}}}
        "     Why don't you use them?{{{
        "
        " `:windo`  works, but  I don't  understand why;  and its  documentation
        " doesn't say that it forces Vim to recompute folds.
        " I  don't like  relying  on  an undocumented  feature;  the devs  would
        " probably not care if it broke.
        "
        " `:norm! zizi` works too, but it's much costlier than `setwinvar()`:
        "
        "     :10000Time let view = winsaveview() | exe "norm! zizi" | call winrestview(view)
        "     1.500 seconds to run ...~
        "
        "     :10000Time call timer_start(0, {-> ''}) | let [curwin, curbuf] = [win_getid(), bufnr('%')] | eval winbufnr(curwin) == curbuf && setwinvar(curwin, '&fdm', 'manual')
        "     0.220 seconds to run ...~
        "}}}
        if s:is_reasonable()
            let [curwin, curbuf] = [win_getid(), bufnr('%')]
            call timer_start(0, {-> winbufnr(curwin) == curbuf && setwinvar(curwin, '&fdm', 'manual')})
        endif
    endif
endfu

fu s:update_buf(feedback) abort "{{{2
    if exists('g:SessionLoad') | return | endif

    " Why `was_open`?{{{
    "
    " When saving a  modified buffer containing a new fold,  the latter could be
    " closed automatically; we don't want that.
    "
    " MWE:
    "
    "     $ vim -Nu NONE -S <(cat <<'EOF'
    "     setl fml=0 fdm=manual fde=getline(v:lnum)=~#'^#'?'>1':'='
    "     au BufWritePost * setl fdm=expr | exe "norm! zizi" | setl fdm=manual
    "     %d|sil pu=repeat(['x'], 5)|1
    "     EOF
    "     ) /tmp/md.md
    "
    "     " press:  O # Esc :w  (the fold is closed automatically)
    "     " press:  O # Esc :w  (the fold is closed automatically if 'fml' is 0)
    "
    " I think that for the issue to be reproduced, you need to:
    "
    "    - set `'fdl'` to 0 (it is by default)
    "    - modify the buffer so that the expr method detects a *new* fold
    "    - switch from manual to expr
    "}}}
    let was_open = foldclosed('.') == -1
    " TODO: Once Nvim supports `win_execute()`, remove `s:curbuf()`, and just use `s:curbuf` instead.{{{
    "
    " Here's why we need `s:curbuf()` in addition to `s:curbuf`.
    "
    " `s:windo()` invokes `lg#win_execute()`; the latter will invoke `win_execute()`:
    "
    "     call win_execute("if bufnr('%') == s:curbuf | call s:update_win() | endif")
    "
    " `win_execute()` will fail  to evaluate `s:curbuf` because  it's a variable
    " local to a *different* script.
    " OTOH, `win_execute()` *can* evaluate a script-local function provided that
    " the `s:` scope has been translated  into `<snr>123_` (we take care of that
    " in `lg#win_execute()`).
    "
    " So, we need to use a wrapper  function to refer to a script-local variable
    " defined in a different script.
    "}}}
    let s:curbuf = bufnr('%')
    call s:windo("if bufnr('%') == s:curbuf() | call s:update_win() | endif")
    " TODO: Do we need to do that somewhere else?  If so, is there a better location to handle all cases?
    if was_open && foldclosed('.') != -1
        norm! zv
    endif

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
    return line('$') <= s:MIN_LINES
endfu
"}}}1
