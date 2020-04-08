if exists('g:autoloaded_fold#motion')
    finish
endif
let g:autoloaded_fold#motion = 1

" Specification{{{
"
" `]z` should move the cursor to:
"
"    - the end of the current fold
"    - the end of the next fold
"    - right above the start of the next nested fold
"
" Whichever is the nearest.
"
" Exception: when the folding method is  'marker', the cursor should not move on
" a line containing a folding marker; it should move right above.
"
" `[z` should move the cursor to:
"
"    - right below the start of the current fold
"    - right below the start of the previous fold
"    - right below the end of the previous nested fold
"
" Whichever is the nearest.
"}}}

" Init {{{1

" Set this  to a non-zero  value to  make the code  preserve the state  of folds
" (open vs closed).
" Warning: When set, the motions may be slow in files with a lot of folds.
" If that's an issue, adjust `s:BIG_FILE`.
const s:PRESERVE_FOLD_STATE = 1

" Saving/restoring the  state of all the  folds takes time; the  more folds, the
" longer it takes  (e.g. vimrc); as a  workaround, we bite the  bullet and never
" preserve the state of the folds in big files.
const s:BIG_FILE = 1000

fu s:snr() abort
    return matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_')
endfu
let s:snr = get(s:, 'snr', s:snr())

" Interface {{{1
fu fold#motion#rhs(lhs) abort "{{{2
    if &l:fdm is# 'manual' && !exists('b:last_fdm')
        return ''
    endif

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

    " Why pressing Escape from visual mode?{{{
    "
    " To make sure  the cursor is positioned  on the corner of  the selection we
    " were controlling.  Otherwise,  it could be unexpectedly  positioned on the
    " other corner:
    "
    "     $ vim -Nu NONE +"pu=['aaa', 'bbb', 'ccc']" +'norm! 1GVG'
    "     " press:  colon C-u Enter
    "     " the cursor gets positioned on the first line instead of the last line
    "
    " ---
    "
    " Btw, don't bother trying to stay in visual mode.
    " Our  code  may execute  commands  which  makes  us  quit the  visual  mode
    " frequently (e.g. `zo`, `zc`; `zv` and motions are ok though).
    "}}}
    " Why pressing `V` in operator-pending mode?{{{
    "
    " Because in that mode, usually, we want to operate on whole lines.
    "}}}
    "   Why not `mode =~# 'o'` instead of `mode is# 'no'`?{{{
    "
    " We don't want to force the motion to be linewise unconditionally.
    " E.g., we could have manually forced it to be characterwise or blockwise.
    " In those cases, we should not interfere; it would be unexpected.
    "}}}
    return printf("%s%s:\<c-u>call "..s:snr.."jump(%s,%s,%d)\<cr>",
        \ mode =~# "^[vV\<c-v>]$" ? "\e" : '',
        \ mode is# 'no' ? 'V' : '',
        \ string(a:lhs),
        \ string(mode),
        \ cnt)
endfu
"}}}1
" Core {{{1
fu s:jump(lhs, mode, cnt) abort "{{{2
    " recompute folds to make sure they are up-to-date
    call fold#lazy#compute()

    if a:mode is# 'n'
        norm! m'
    elseif a:mode =~# "^[vV\<c-v>]$"
        " Line number of the corner of the selection which is "fixed". {{{
        "
        " I.e. we don't make it change because we are controlling the other corner.
        " We'll need this info to select the desired range of lines at the end.
        " We need to save it now, because the current line is going to change.
        "}}}
        let fixed_corner = line('.') == line("'<") ? line("'>") : line("'<")
    endif

    let view = winsaveview()
    if s:PRESERVE_FOLD_STATE && line('$') <= s:BIG_FILE | let state = s:foldsavestate() | endif

    norm! zR
    for i in range(a:cnt)
        call s:next_fold(a:lhs)
    endfor

    if s:PRESERVE_FOLD_STATE && line('$') <= s:BIG_FILE
        \ && get(maparg('j', 'n', 0, 1), 'rhs', '') !~# 'move_and_open_fold'
        call s:foldreststate(state)
    else
        norm! zM
    endif
    norm! zv
    call s:winrestview(view)

    if a:mode =~# "^[vV\<c-v>]$"
        exe 'norm! '..fixed_corner..'GV'..line('.')..'G'
    endif
endfu

fu s:next_fold(lhs) abort
    let orig = line('.')

    let next = []
    if a:lhs is# '[z'

        keepj norm! [z
        let next += [line('.')]
        keepj exe orig
        keepj norm! zk
        let next += [line('.')]
        call filter(next, 'v:val != '..orig)
        if empty(next) | return | endif
        keepj exe max(next)

        let is_fold_start = s:is_fold_start()
        let is_fold_end = s:is_fold_end()
        let is_next_line_foldable = foldlevel(line('.')+1) > 0
        let moved_just_above = line('.') == orig - 1

        " FIXME: Doesn't always work as expected.{{{
        "
        "     $ vim --cmd 'let g:rust_fold=2 | setl ft=rust fdc=5' +'norm! GzR' <(curl -Ls https://raw.githubusercontent.com/BurntSushi/ripgrep/cb0dfda936748a7ca7a2d52d8b033bc48382d5f9/build.rs)
        "     " press [z 7 times
        "     " the 7th time, we jump from 166 to 157
        "     " we should have jumped from 166 to 163 (then 162, then 157)
        "
        " This could be fixed by replacing `if moved_just_above` with:
        "
        "     let is_foldlvl_bigger_on_previous_line = foldlevel('.') < foldlevel(line('.')-1)
        "     if is_foldlvl_bigger_on_previous_line
        "         if !moved_just_above && is_next_line_foldable
        "             +
        "         endif
        "     elseif moved_just_above
        "
        " But doing  so would break  the motion in  nested folds in  other files
        " (markdown + vim).
        "
        " For the moment, this is an acceptable issue.
        " It only seems to affect a folded  line which is right after the end of
        " a nested fold, and which is not followed by another folded line in the
        " same fold.   IOW, it's an  extremely particular case which  should not
        " bother us in practice.
        "}}}
        " don't be stuck right before a fold start (this issue is due to `:+`)
        if moved_just_above
            return s:next_fold('[z')
        elseif is_fold_start || (is_fold_end && is_next_line_foldable)
            " don't jump on the first line of a fold; just after
            +
        else
            " `silent!` to suppress `E132` when there are no folds in a Vim file
            return s:next_fold('[z')
        endif

    else

        keepj norm! ]z
        let next += [line('.')]
        keepj exe orig
        keepj norm! zj
        let next += [line('.')]
        call filter(next, 'v:val != '..orig)
        if empty(next) | return | endif
        keepj exe min(next)

        let is_fold_start = s:is_fold_start()
        let is_fold_end = s:is_fold_end()
        let is_previous_line_foldable = foldlevel(line('.')-1) > 0
        let has_end_marker = &l:fdm is# 'marker' && getline('.') =~# split(&l:fmr, ',')[1]..'\d*\s*$'
        let moved_just_below = line('.') == orig + 1

        " special case: if we're before the *first* fold, jump right before its start (instead of its end)
        if is_fold_start && !is_previous_line_foldable && !moved_just_below
            -
        elseif (is_fold_start || has_end_marker) && moved_just_below
            " don't be stuck right before a fold end (this issue is due to `:-`)
            return s:next_fold(']z')
        elseif (is_fold_start || has_end_marker) && is_previous_line_foldable
            " don't jump on the start of a fold – `zj` does that – nor on a line
            " containing closing foldmarkers; move right before
            -
        elseif !is_fold_end
            return s:next_fold(']z')
        endif

    endif
endfu

fu s:is_fold_start() abort
    if foldlevel('.') <= 0 | return 0 | endif

    norm! zc
    let is_fold_start = line('.') == foldclosed('.')
    norm! zo

    return is_fold_start
endfu

fu s:is_fold_end() abort
    if foldlevel('.') <= 0 | return 0 | endif

    norm! zc
    let is_fold_end = line('.') == foldclosedend('.')
    norm! zo

    return is_fold_end
endfu

fu s:foldsavestate() abort
    let pos = getcurpos()
    let state = {'open': [], 'closed': []}
    folddoclosed let state.closed += s:get_state('closed')
    folddoopen let state.open += s:get_state('open')
    call setpos('.', pos)
    return state
endfu

fu s:get_state(which_one) abort
    if a:which_one is# 'closed'
        if line('.') == foldclosed('.') | return [line('.')] | endif
    elseif a:which_one is# 'open'
        if foldlevel('.') <= 0 | return [] | endif
        norm! zc
        if line('.') == foldclosed('.')
            return [line('.')]
        endif
        norm! zo
    endif
    return []
endfu

fu s:foldreststate(state) abort
    let pos = getcurpos()
    for lnum in a:state.open
        exe 'norm! '..lnum..'Gzo'
    endfor
    for lnum in a:state.closed
        exe 'norm! '..lnum..'Gzc'
    endfor
    call setpos('.', pos)
endfu

fu s:winrestview(view) abort
    let pos = getcurpos()
    call winrestview(a:view)
    call setpos('.', pos)
endfu

