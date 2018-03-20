" fu! s:has_surrounding_fencemarks(lnum) abort {{{1
"     let pos = [line('.'), col('.')]
"     call cursor(a:lnum, 1)
"
"     let start_fence    = '\%^```\|^\n\zs```'
"     let end_fence      = '```\n^$'
"     let fence_position = searchpairpos(start_fence, '', end_fence, 'W')
"
"     call cursor(pos)
"     return fence_position !=# [0,0]
" endfu

" fu! s:has_syntax_group(lnum) abort {{{1
"     let syntax_groups = map(synstack(a:lnum, 1), { i,v -> synIDattr(v, 'name') })
"     for value in syntax_groups
"         if value =~ '\vmarkdown%(Code|Highlight)'
"             return 1
"         endif
"     endfor
" endfu

" fu! s:line_is_fenced(lnum) abort {{{1
"     if get(b:, 'current_syntax', '') is# 'markdown'
"         " It's cheap to check if the current line has 'markdownCode' syntax group
"         return s:has_syntax_group(a:lnum)
"     else
"         " Using searchpairpos() is expensive, so only do it if syntax highlighting
"         " is not enabled
"         return s:has_surrounding_fencemarks(a:lnum)
"     endif
" endfu

fu! fold#motion_go(lhs, mode) abort "{{{1
    if a:mode is# 'n'
        norm! m'
    elseif index(['v', 'V', "\<c-v>"], a:mode) >= 0
        " If we  were initially  in visual mode,  we've left it  as soon  as the
        " mapping pressed Enter  to execute the call to this  function.  We need
        " to get back in visual mode, before the search.
        norm! gv
    endif

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
            call search('\v^#{'.(level-1).'}#@!', 'bW')
            "               └─────────────────┤
            "                                 └ containing fold
            return
        elseif a:lhs is# ']z'
            let next_line = getline(line('.')+1)
            if next_line =~# '^#\{2,}'
                let level = len(matchstr(next_line, '^#\+'))
                " search for ending of containing fold
                call search('\v\ze\n#{'.(level-1).'}#@!|.*%$', 'W')
                "              │   │                   └───┤
                "              │   │                       └ OR, look for the last line
                "              │   │                         Why? The containing fold may be the last fold.
                "              │   │                         In this case, there will be no next fold,
                "              │   │                         and the previous pattern will fail.
                "              └───┤
                "                  └ ending of containing fold =
                "                        just before the first line of the next fold
                "                        whose level is the same as the containing one
                return
            endif
        endif
    endif

    let keys = a:lhs is# '[Z' || a:lhs is# ']Z'
    \?             (a:lhs is# '[Z' ? 'zk' : 'zj')
    \:             tolower(a:lhs)

    exe 'norm! '.v:count1.keys

    " If you  try to  simplify this  block in a  single statement,  don't forget
    " this: the function shouldn't do anything in operator-pending mode.
    if a:mode is# 'n'
        norm! zMzv
    elseif index(['v', 'V', "\<c-v>"], a:mode) >= 0
        norm! zv
    endif
endfu

fu! fold#motion_rhs(lhs) abort "{{{1
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

    return printf(":\<c-u>call fold#motion_go(%s,%s)\<cr>",
    \             string(a:lhs), string(mode))
endfu

fu! fold#text() abort "{{{1
    let line = getline(v:foldstart)
    " get the desired level of indentation for the title
    if &ft is# 'markdown'
        let level = fold#md#heading_depth(v:foldstart)
        let indent = repeat(' ', (level-1)*3)
    else
        let indent = line =~# '{{'.'{\d\+\s*$'
        \?               repeat(' ', (v:foldlevel-1)*3)
        \:               matchstr(getline(v:foldstart), '^\s*')
    endif

    " get a possible comment leader
    let cml = '\V'.matchstr(get(split(&l:cms, '%s'), 0, ''), '\S*').'\v'
    "           │
    "           └ the comment leader could contain special characters,
    "             like % in a tex file

    " remove general noise
    let title = substitute(line, '\v^\s*%('.cml.')\@?\s?|\s*%('.cml.')?\s*\{\{\{%(\d+)?\s*$', '', 'g')
    "                                             └─┤
    "                                               └ for commented code

    " remove filetype specific noise
    let title = &ft is# 'markdown'
    \?              substitute(getline(v:foldstart), '^#\+\s*', '', '')
    \:          &ft is# 'sh'
    \?              substitute(title, '\v^.*\zs\(\)\s*%(\{|\()', '', '')
    \:          &ft is# 'vim'
    \?              substitute(title, '\v^\s*fu%[nction]! %(.*%(#|s:))?(.{-})\(.*\).*', '\1', '')
    \:          &ft is# 'python'
    \?              substitute(title, '^def\s\+\|(.\{-})\%(^def\s\+.*\)\@<=:', '', 'g')
    \:              title

    if get(b:, 'my_title_full', 0)
        let foldsize  = (v:foldend - v:foldstart)
        let linecount = '['.foldsize.']'.repeat(' ', 4 - strchars(foldsize))
        return indent.linecount.title
    else
        return indent.title
    endif
endfu
