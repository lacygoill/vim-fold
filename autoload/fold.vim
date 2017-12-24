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

fu! fold#text() abort "{{{1
    let line = getline(v:foldstart)
    if &ft ==# 'markdown'
        let level = fold#md#heading_depth(v:foldstart)
        let indent = repeat(' ', (level-1)*3)
    else
        let indent = line =~# '{{'.'{\d\+\s*$' ? repeat(' ', (v:foldlevel-1)*3) : ''
    endif
    let cml   = substitute(get(split(&l:cms, '%s'), 0, ''), '\s*$', '', '')
    let title = substitute(line, '\v^\s*%('.cml.')\s*|\s*%('.cml.')?\s*\{\{\{%(\d+)?\s*$', '', 'g')

    let title = &ft ==# 'vim'
    \?              substitute(title, '\v^\s*fu%[nction]! %(.*%(#|s:))?(.{-})\(.*\).*', '\1', '')
    \:          &ft ==# 'sh'
    \?              substitute(title, '\v^.*\zs\(\)\s*%(\{|\()', '', '')
    \:          &ft ==# 'markdown'
    \?              substitute(getline(v:foldstart), '^#\+\s*', '', '')
    \:              title

    if get(b:, 'my_title_full', 0)
        let foldsize  = (v:foldend - v:foldstart)
        let linecount = '['.foldsize.']'.repeat(' ', 4 - strchars(foldsize))
        return indent.' '.linecount.' '.title
    else
        return indent.' '.title
    endif
endfu
