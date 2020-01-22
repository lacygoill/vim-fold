if exists('g:autoloaded_fold#lazy')
    finish
endif
let g:autoloaded_fold#lazy = 1

" TODO: finish understanding/refactoring/reviewing/documenting the "Interface" section

" TODO: We call `#update_win()` in various plugins.
" Should we call `#update_buf()` instead?
" Originally, FastFold provided a command which called `#update_buf()`...

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
"                                           replace with the new number you want to use (minus 3)
"                                           vvv  vvv
"         $ vim +"%d | put='text' | norm! yy123pG123Ax" /tmp/md.md
"         " make sure that 'fdm' is 'expr'
"         " press:  I C-k C-k
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
    for var in ['last_fdm', 'prediff_fdm']
        if exists('w:'..var)
            let b:{var} = w:{var}
        elseif exists('b:'..var)
            unlet b:{var}
        endif
    endfor
endfu

fu fold#lazy#update_buf() abort "{{{2
    if exists('g:SessionLoad') | return | endif

    " TODO: Once Nvim supports `win_execute()`, remove `s:curbuf()`, and just use `s:curbuf` instead.{{{
    "
    " Here's why we need `s:curbuf()` in addition to `s:curbuf`.
    "
    " `s:windo()` invokes `lg#win_execute()`; the latter will invoke `win_execute()`:
    "
    "     call win_execute("if bufnr('%') == s:curbuf | call fold#lazy#update_win() | endif")
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
    call s:windo("if bufnr('%') == s:curbuf() | call fold#lazy#update_win() | endif")
    " TODO: Understand what this block did, before removing it definitively.
    "
    "     if !a:feedback | return | endif
    "     if !exists('w:last_fdm')
    "         echom printf("'%s' folds already continuously updated", &l:fdm)
    "     else
    "         echom printf("updated '%s' folds", w:last_fdm)
    "     endif
endfu

fu s:curbuf() abort
    return s:curbuf
endfu

fu fold#lazy#update_win() abort "{{{2
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
        " Do *not* move `norm! zv` in `#update_buf()`.{{{
        "
        " The latter is only invoked on certain events:
        "
        "     BufEnter
        "     BufWinEnter
        "     BufWritePost
        "     FileType
        "     SessionLoadPost
        "
        " `#update_win()`  is  invoked from  `#update_buf()`,  but  we can  also
        " invoke it manually; we do it e.g. in `fold#motion#go()`.
        "
        " As a  result, if you moved  `norm! zv` in `#update_buf()`,  a new fold
        " would not be recomputed immediately when  we press `]z`; we would need
        " to press it twice.
        "
        " ---
        "
        " Old Comment:
        "
        "     OTOH, `#update_win()` is invoked once  for every window displaying the
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
            norm! zv
        endif
    endif

    if s:should_skip()
        " if exists('w:last_fdm') | unlet w:last_fdm | endif
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
"}}}1
" Utilities {{{1
fu s:windo(cmd) abort "{{{2
    if !empty(getcmdwintype()) | return | endif
    call map(range(1, winnr('$')), {_,v -> lg#win_execute(win_getid(v), a:cmd)})
endfu

fu s:should_skip() abort "{{{2
    return !s:is_costly() || !empty(&bt) || !&l:ma
endfu

fu s:is_costly() abort "{{{2
    return &l:fdm =~# '^\%(expr\|indent\|syntax\)$'
endfu
