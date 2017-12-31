" fu! s:has_surrounding_fencemarks(lnum) abort {{{1
"     let pos = [line('.'), col('.')]
"     call cursor(a:lnum, 1)
"
"     let start_fence    = '\%^```\|^\n\zs```'
"     let end_fence      = '```\n^$'
"     let fence_position = searchpairpos(start_fence, '', end_fence, 'W')
"
"     call cursor(pos)
"     return fence_position != [0,0]
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
"     if get(b:, 'current_syntax', '') ==# 'markdown'
"         " It's cheap to check if the current line has 'markdownCode' syntax group
"         return s:has_syntax_group(a:lnum)
"     else
"         " Using searchpairpos() is expensive, so only do it if syntax highlighting
"         " is not enabled
"         return s:has_surrounding_fencemarks(a:lnum)
"     endif
" endfu

fu! fold#motion(lhs) abort "{{{1
    let g:motion_to_repeat = a:lhs
    mark '

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
    if  &ft ==# 'markdown' && foldlevel('.') == 1
        let line = getline('.')

        if a:lhs ==# '[Z' && line =~# '^#\{2,}'
            let level = len(matchstr(line, '^#\+'))
            " search for beginning of containing fold
            call search('\v^#{'.(level-1).'}#@!', 'bW')
            "               └─────────────────┤
            "                                 └ containing fold
            return
        elseif a:lhs ==# ']Z'
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

    let keys = a:lhs ==# '[z' || a:lhs ==# ']z'
    \?             (a:lhs ==# '[z' ? 'zk' : 'zj')
    \:             tolower(a:lhs)

    call feedkeys(v:count1 . keys . 'zvzz', 'int')
endfu

fu! fold#text() abort "{{{1
    let line = getline(v:foldstart)
    if &ft ==# 'markdown'
        let level = fold#md#heading_depth(v:foldstart)
        let indent = repeat(' ', (level-1)*3)
    else
        let indent = line =~# '{{'.'{\d\+\s*$'
        \?               repeat(' ', (v:foldlevel-1)*3)
        \:               matchstr(getline(v:foldstart), '^\s*')
    endif
    let cml   = substitute(get(split(&l:cms, '%s'), 0, ''), '\s*$', '', '')
    let title = substitute(line, '\v^\s*%('.cml.')\@?\s*|\s*%('.cml.')?\s*\{\{\{%(\d+)?\s*$', '', 'g')
    "                                             └─┤
    "                                               └ for commented code

    let title = &ft ==# 'markdown'
    \?              substitute(getline(v:foldstart), '^#\+\s*', '', '')
    \:          &ft ==# 'sh'
    \?              substitute(title, '\v^.*\zs\(\)\s*%(\{|\()', '', '')
    \:          &ft ==# 'vim'
    \?              substitute(title, '\v^\s*fu%[nction]! %(.*%(#|s:))?(.{-})\(.*\).*', '\1', '')
    \:              title

    if get(b:, 'my_title_full', 0)
        let foldsize  = (v:foldend - v:foldstart)
        let linecount = '['.foldsize.']'.repeat(' ', 4 - strchars(foldsize))
        return indent.' '.linecount.' '.title
    else
        return indent.' '.title
    endif
endfu
