fu! fold#motion#go(lhs, mode) abort "{{{1
    if a:mode is# 'n'
        norm! m'
    elseif index(['v', 'V', "\<c-v>"], a:mode) >= 0
        " If we  were initially  in visual mode,  we've left it  as soon  as the
        " mapping pressed Enter  to execute the call to this  function.  We need
        " to get back in visual mode, before the search.
        norm! gv
    endif

    let line = getline('.')

    " Special Case:{{{
    " If we're in a markdown file, and the folds are stacked, all folds have the
    " same  level (`1`). So,  `[Z` and  `]Z`  won't be  able  to get  us to  the
    " beginning / ending of the containing fold; technically there's none.
    "
    " In this case, we still want `[Z` and `]Z` to move the cursor.
    " We try to  emulate the default behaviour of `[z`  and `]z`, by recognizing
    " the different  fold levels via  the number of #  at the beginning  of each
    " fold.
    "}}}
    if  &ft is# 'markdown' && foldlevel('.') ==# 1
        let line = getline('.')

        if a:lhs is# '[z' && line =~# '^#\{2,}'
            let level = len(matchstr(line, '^#\+'))
            " search for beginning of containing fold
            return search('\v^#{'.(level-1).'}#@!', 'bW')

        elseif a:lhs is# ']z'
            let next_line = getline(line('.')+1)
            if next_line =~# '^#\{2,}'
                let level = len(matchstr(next_line, '^#\+'))
                " search for ending of containing fold
                return search('\v\ze\n#{'.(level-1).'}#@!|.*%$', 'W')
                "                ├───┘                   ├───┘
                "                │                       └  OR, look for the last line
                "                │                         Why? The containing fold may be the last fold.
                "                │                         In this case, there will be no next fold,
                "                │                         and the previous pattern will fail.
                "                │
                "                └ ending of containing fold =
                "                          just before the first line of the next fold
                "                          whose level is the same as the containing one
            endif
        endif
    endif

    let keys = a:lhs is# '[Z'
           \ ?     'zk'
           \ : a:lhs is# ']Z'
           \ ?     'zj'
           \ :     a:lhs

    exe 'norm! '.v:count1.keys

    if a:mode isnot# 'no'
        norm! zv
    endif
endfu

fu! fold#motion#rhs(lhs) abort "{{{1
    let mode = mode(1)

    " If we're in visual block mode, we can't pass `C-v` directly.
    " It's going to by directly typed on the command-line.
    " On the command-line, `C-v` means:
    "
    "     “insert the next character literally”
    "
    " The solution is to double `C-v`.
    if mode is# "\<c-v>"
        let mode = "\<c-v>\<c-v>"
    endif

    " Why `mode is# 'no' ? 'V' : ''`?{{{
    "
    " In operator-pending mode, usually, we want to operate on whole lines.
    "}}}
    return printf("%s:\<c-u>call fold#motion#go(%s,%s)\<cr>",
    \             mode is# 'no' ? 'V' : '',
    \             string(a:lhs),
    \             string(mode))
endfu

