if exists('g:autoloaded_fold#lazy')
    finish
endif
let g:autoloaded_fold#lazy = 1

" TODO: We've removed `s:update_tab()` and the `VimEnter` autocmd which called it.
" It didn't seem to be useful.  Why did FastFold use them?
"
"     au VimEnter * call s:update_tab()
"     fu s:update_tab() abort
"         if exists('g:SessionLoad') | return | endif
"         call s:windo('call s:update_win()')
"     endfu
"
" ---
"
" Also, FastFold delays the installation of the autocmds until `VimEnter`.
" Should we do the same?  Why?
" Does it have any effect on markdown files for which we reset 'fde' on bufwinenter?

" FAQ{{{
" What's the purpose of this script?{{{
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
"     ino <expr> <c-k><c-k> repeat('<del>', 300)
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
"   Why can't I just use `>1` and `1` to fix this issue?{{{
"
" We don't want to use `1` in `fold#md#fde#stacked()`; see the comments there.
"
" Besides, for a given buffer, we may be using:
"
"    - a different foldexpr which also uses a costly value (e.g. `'='`, `'a123'`, `'s123'`)
"    - a different folding method which can still be slow (e.g. `syntax`)
"}}}
"     Ok, so how does `vim-fold` fix it?{{{
"
" It lets Vim create folds according to the value of `'fdm'` (e.g. `foldexpr` or
" `syntax`), then  it resets  the latter  to manual, which  is much  less costly
" because  it doesn't  ask Vim  to recompute  anything every  time you  edit the
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
"     ino <expr> <c-k><c-k> repeat('<del>', 300)
"     EOF
"     ) +"%d | put='text' | norm! yy300pG300Ax" /tmp/md.md
"
" If you get an error because of `lg#win_execute()`, add `vim-lg-lib` to the rtp.
" In any case, Vim should start up immediately, and removing 300 characters with
" `C-k C-k` should also be instantaneous.
"}}}

" When won't the folds be recomputed?{{{
"
" When  you  modify  a buffer  to  add  new  folded  text, the  folds  won't  be
" recomputed until  you save  the buffer  or use  a custom  fold-related command
" (e.g. `SPC SPC`, `]Z`), provided that the latter has been customized to invoke
" `#compute()`.
"
" If you  use a  fold-related command, but  don't save, the  folds will  only be
" recomputed in the current window; they won't be recomputed in inactive windows
" displaying the current buffer.
" If  this is  an  issue,  then you  should  refactor  your custom  fold-related
" commands so that they invoke `#compute_all_windows()`.
"
" I don't see the  necessity to do it right now;  `#compute()` seems good enough
" until we save.
"}}}
" How to make Vim recompute folds in another script?{{{
"
" Call `#compute()` if you want to recompute folds only in the current window.
" If you call it from an autocmd, pass it an optional argument (e.g. 'force').
" This will force Vim to recompute folds  no matter what, even if it has already
" been done recently.
"}}}

" Why could it be useful to disable the lazyfold feature in small files?{{{
"
" https://github.com/Konfekt/FastFold/pull/55
"}}}
"   How could I do it?{{{
"
" Initialize some constant:
"
"     const s:MIN_LINES = 30
"
" Write this function:
"
"     fu s:is_small() abort
"         return line('$') <= s:MIN_LINES
"     endfu
"
" And update `s:should_skip()` to include it:
"
"     return s:is_small() || !s:is_costly() || !empty(&bt) || !&l:ma
"            ^^^^^^^^^^^^
"}}}
"   Which pitfalls should I be aware of?{{{
"
" `s:MIN_LINES` adds complexity; not in terms of number of lines of code, but in
" terms of the logic; it increases the number of code paths.
"
" Suppose the script contains a bug which  can be reproduced when some options A
" and B are both on, or both off.
" But during your tests, you can't reproduce with A and B off, because you use a
" small file.
" You'll come to the conclusion that the bug  is only triggered when A and B are
" on; you may find a solution, but you won't have fixed the bug in all cases.
"
" Also, you may sometimes reproduce the issue, but not always, because you don't
" know or  have forgotten about the  fact that the  number of lines in  the file
" matters.
"
" More generally, the more  code paths, the harder it is to  debug and reason on
" issues.
"
" ---
"
" If you choose a too big value, you may experience lag too frequently.
"
" Whatever value you use for `s:MIN_LINES`, make this experiment:
"
"                                       replace with the new number you want to use (minus 3)
"                                       vvv  vvv
"     $ vim +"%d | put='text' | norm! yy123pG123Ax" /tmp/md.md
"     " make sure that 'fdm' is 'expr'
"     " press:  I C-k C-k
"
" Check how much time it takes for Vim to remove all the characters.
" Choose a value for which the time is acceptable.
"
" 30 seems like a  good fit, because it's a round number, and  it's close to the
" current maximum number of lines we can display in a window (`&lines`).
" It makes sense to consider a file which  fits on a single screen as small; but
" not anything above.
"}}}

" I want to test how our "lazyfold" feature behaves when the foldmethod is set to syntax.  What should I do?{{{
"
"     $ git clone https://github.com/BurntSushi/ripgrep && cd *(/oc[1])
"     $ vim --cmd 'let g:rust_fold=2' build.rs
"}}}
"}}}

" Interface{{{1
fu fold#lazy#on_winleave() abort "{{{2
    " TODO: why?{{{
    "
    " It  seems  that   the  purpose  is  to  make   the  buffer-local  variable
    " synchronized with the window-local variable.
    " If the window-local variable exists, the buffer-local one must exist too.
    " And if the window-local variable does not exist, the buffer-local one must not exist either.
    "}}}
    for var in ['last_fdm', 'prediff_fdm']
        if exists('w:'..var)
            let b:{var} = w:{var}
        elseif exists('b:'..var)
            unlet b:{var}
        endif
    endfor
endfu

fu fold#lazy#compute_all_windows() abort "{{{2
    " TODO: Why?
    " if exists('g:SessionLoad') | return | endif

    let curbuf = bufnr('%')
    let winids = map(filter(getwininfo(), {_,v -> v.bufnr == curbuf}), {_,v -> v.winid})
    call map(winids, {_,v -> lg#win_execute(v, 'call fold#lazy#compute("force")')})

    " TODO: Understand what this block did, before removing it definitively.
    "
    "     if !a:feedback | return | endif
    "     if !exists('w:last_fdm')
    "         echom printf("'%s' folds already continuously updated", &l:fdm)
    "     else
    "         echom printf("updated '%s' folds", w:last_fdm)
    "     endif
endfu

fu fold#lazy#compute(...) abort "{{{2
    " To improve performance, bail out if folds have been recomputed recently.
    " What's this optional argument?{{{
    "
    " Its value doesn't matter, only its existence.
    " But by convention, use the string 'force'.
    " When it exists, it means that we want folds to be recomputed no matter what.
    "}}}
    "   Ok, and why do you bail out only when{{{
    "}}}
    "     it does not exist?{{{
    "
    " When the function invocation is triggered by:
    "
    "    - an  autocmd, it  doesn't  matter  that  folds have  been  recomputed
    "      recently, we want them to be recomputed no matter what
    "
    "    - a custom mapping, we don't want folds to be recomputed unconditionally;
    "      if the mapping is pressed repeatedly very fast, there would be too much
    "      lag in a big file
    "
    " When  we invoke  the function  from a  custom mapping,  we don't  pass the
    " optional argument, to let it know that it should not recompute folds if it
    " has already been done recently.
    "}}}
    "     and the buffer has changed?{{{
    "
    " If the buffer has not changed, there's no reason to recompute the folds.
    "
    " In fact, bailing out can improve the performance in some cases.
    " Suppose we are in a big folded file.
    " There's no reason to recompute all the folds every time we press `SPC SPC`
    " to toggle a fold.
    " Same thing for any custom  mapping which invokes this function; especially
    " if we press it frequently (e.g. `]Z` followed by a smashed `;`/`,`).
    "}}}
    if !a:0
        if b:changedtick == get(b:, 'lazyfold_changedtick')
            return
        else
            let b:lazyfold_changedtick = b:changedtick
        endif
    endif

    " TODO: what does this do?
    if exists('w:prediff_fdm')
        if empty(&l:fdm) || &l:fdm is# 'manual'
            let &l:fdm = w:prediff_fdm
            unlet w:prediff_fdm
            return
        elseif &l:fdm isnot# 'diff'
            unlet w:prediff_fdm
        endif
    endif

    " TODO: what does this do?
    if &l:fdm is# 'diff' && exists('w:last_fdm')
        let w:prediff_fdm = w:last_fdm
    endif

    if &l:fdm is# 'manual' && exists('w:last_fdm')
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
        " Do *not* move `norm! zv` in `#compute_all_windows()`.{{{
        "
        " The latter is only invoked on certain events:
        "
        "     FileType
        "     BufWritePost
        "     BufWinEnter
        "
        " `#compute()` is invoked from `#compute_all_windows()`, but we can also
        " invoke it manually; we do it e.g. in `fold#motion#go()`.
        "
        " As a  result, if you  moved `norm! zv` in  `#compute_all_windows()`, a
        " new fold  would not be recomputed  immediately when we press  `]z`; we
        " would need to press it twice.
        "
        " ---
        "
        " Old Comment:
        "
        "     OTOH, `#compute()` is invoked once  for every window displaying the
        "     current buffer in the current tab page.
        "
        "     However, `norm! zv`  would only work in the current  window; it would fail
        "     in  all the  other windows  when executed  by `win_execute()`,  because it
        "     opens folds to reveal the line *under the cursor*.
        "     But when you create  a new fold, your cursor has a  *new* position; in the
        "     other windows the cursor keeps its old position.
        "}}}
        let was_open = foldclosed('.') == -1
        let &l:fdm = w:last_fdm
        if was_open && foldclosed('.') != -1
            " `:norm! zv` may be executed in an inactive window.{{{
            "
            " Which is ok.
            " It happens when `FileType` or `BufWritePost` are fired.
            "
            " `:norm! zv` is helpful when the buffer is reloaded (e.g. with `:e`).
            " When that happens:
            "
            "    - all the folds are deleted in all the windows displaying the buffer
            "
            "    - folds are recreated when  the foldmethod is temporarily reset
            "      to its original costly  value (e.g. 'expr'), and `foldclosed('.')`
            "      is evaluated
            "
            "    - the new folds are closed (if `'foldlevel'` is 0)
            "
            " If `norm! zv` was not executed in an inactive window, we would not
            " see the  contents of its  current fold  when we reload  the buffer
            " from another window.  I prefer to see it.
            "}}}
            norm! zv
        endif
    endif

    if s:should_skip()
        " TODO: why?
        unlet! w:last_fdm
    else
        let w:last_fdm = &l:fdm
        " Why this dummy assignment?{{{
        "
        " To make sure Vim recomputes folds, before we reset the foldmethod to manual.
        " Without, there is a risk that no fold would be created:
        "
        "     $ vim -Nu NONE -S <(cat <<'EOF'
        "     setl fml=0 fdm=manual fde=getline(v:lnum)=~#'^#'?'>1':'='
        "     %d|pu=repeat(['x'], 5)|1
        "     EOF
        "     ) /tmp/file
        "     " insert:  #
        "     " run:  setl fdm=expr | setl fdm=manual
        "     " no fold is created;
        "     " but a fold would have been created if you had run:
        "
        "         :setl fdm=expr | let _ = foldlevel(1) | setl fdm=manual
        "
        "      or
        "
        "         :setl fdm=expr | exe '1windo "' | setl fdm=manual
        "
        "      or
        "
        "         :setl fdm=expr
        "         :setl manual
        "
        " ---
        "
        " I  don't know  why/how  it  works, but  the  original FastFold  plugin
        " implicitly  relies  on a  side-effect  of  `:windo`  for folds  to  be
        " recomputed before resetting the foldmethod to manual.
        "}}}
        "   Why not `:norm! zx`?{{{
        "
        " It does not preserve manually opened/closed folds.
        " And remember that `winsaveview()` does not save fold information.
        "}}}
        let _ = foldlevel(1)
        setl fdm=manual
    endif
endfu

fu fold#lazy#handle_diff() abort "{{{2
    if v:option_new == 1 && v:option_old == 0
        let w:prediff_fdm = w:last_fdm
    elseif v:option_new == 0 && v:option_old == 1 && exists('w:prediff_fdm')
        let &l:fdm = w:prediff_fdm
        let _ = foldlevel(1)
        unlet w:prediff_fdm
    endif
endfu
"}}}1
" Utilities {{{1
fu s:should_skip() abort "{{{2
    return !s:is_costly() || !empty(&bt) || !&l:ma
endfu

fu s:is_costly() abort "{{{2
    return &l:fdm =~# '^\%(expr\|indent\|syntax\)$'
endfu

