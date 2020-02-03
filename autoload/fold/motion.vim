fu fold#motion#go(lhs, mode, cnt) abort "{{{1
    " recompute folds to make sure they are up-to-date
    call fold#lazy#compute()

    if a:mode is# 'n'
        norm! m'
    elseif a:mode =~# "^[vV\<c-v>]$"
        norm! gv
    endif

    for i in range(a:cnt)
        call s:next_fold(a:lhs)
    endfor

    " TODO: why did we do this in the past?{{{
    "
    "     if a:mode =~# 'o'
    "         if get(maparg('j', 'n', 0, 1), 'rhs', '') =~# 'move_and_open_fold'
    "             norm! zM
    "         endif
    "         norm! zv
    "     endif
    "}}}
endfu

fu s:next_fold(lhs) abort
    let orig = line('.')
    " FIXME: Doesn't work as expected when folds are nested.{{{
    "
    " I think we need to execute `]z` *and* `zj`, and capture the smallest destination.
    " Same thing for `[z` and `zk` (in a vimscript file where non-numbered folds
    " are nested).
    "
    " ---
    "
    " When you're done, remove `~/Desktop/.vim.vim`, `~/Desktop/.vim1.vim`, `~/Desktop/.md.md`.
    " But before that, make some tests in a rust file (clone rg).
    "}}}
    if a:lhs is# '[z'
        keepj norm! [z
        if line('.') == orig
            keepj norm! zk[z
        elseif line('.') == orig - 1
            return s:next_fold('[z')
        endif
        +
    else
        keepj norm! ]z

            let new = line('.')
            exe orig
            keepj norm! zj
            -
            if line('.') == orig
                keepj norm! zjzj
                -
            endif
            if line('.') > new | exe new | endif

        if line('.') == orig
            keepj norm! zj]z
        elseif line('.') == orig + 1
            return s:next_fold(']z')
        endif
        if &l:fdm is# 'marker'
            -
        endif
    endif
endfu

fu fold#motion#rhs(lhs) abort "{{{1
    let [mode, cnt] = [mode(1), v:count1]
    " If we're in visual block mode, we can't pass `C-v` directly.{{{
    "
    " It's going to by directly typed on the command-line.
    " On the command-line, `C-v` means:
    "
    "     “insert the next character literally”
    "
    " The solution is to double `C-v`.
    "}}}
    if mode is# "\<c-v>"
        let mode = "\<c-v>\<c-v>"
    endif

    " Why `mode is# 'no' ? 'V' : ''`?{{{
    "
    " In operator-pending mode, usually, we want to operate on whole lines.
    "}}}
    " Why not `mode =~# 'o'`?{{{
    "
    " We don't want to force the motion to be linewise unconditionally.
    " E.g., we could have manually forced it to be characterwise or blockwise.
    " In those cases, we should not interfere; it would be unexpected.
    "}}}
    return printf("%s:\<c-u>call fold#motion#go(%s,%s,%d)\<cr>",
        \ mode is# 'no' ? 'V' : '',
        \ string(a:lhs),
        \ string(mode),
        \ cnt)
endfu

