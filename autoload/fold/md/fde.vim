" Old but can still be useful {{{1
"     fu s:has_surrounding_fencemarks(lnum) abort {{{2
"         let pos = [line('.'), col('.')]
"         call cursor(a:lnum, 1)
"
"         let start_fence    = '\%^```\|^\n\zs```'
"         let end_fence      = '```\n^$'
"         let fence_position = searchpairpos(start_fence, '', end_fence, 'W')
"
"         call cursor(pos)
"         return fence_position !=# [0,0]
"     endfu

"     fu s:has_syntax_group(lnum) abort {{{2
"         let syntax_groups = map(synstack(a:lnum, 1), {_,v -> synIDattr(v, 'name')})
"         for value in syntax_groups
"             if value =~ '\vmarkdown%(Code|Highlight)'
"                 return 1
"             endif
"         endfor
"     endfu

"     fu s:line_is_fenced(lnum) abort {{{2
"         if get(b:, 'current_syntax', '') is# 'markdown'
"             " It's cheap to check if the current line has 'markdownCode' syntax group
"             return s:has_syntax_group(a:lnum)
"         else
"             " Using searchpairpos() is expensive, so only do it if syntax highlighting
"             " is not enabled
"             return s:has_surrounding_fencemarks(a:lnum)
"         endif
"     endfu
" }}}1
" Interface {{{1
fu fold#md#fde#toggle() abort "{{{2
    let &l:fde = &l:fde is# 'fold#md#fde#stacked()'
             \ ?     'fold#md#fde#nested()'
             \ :     'fold#md#fde#stacked()'
endfu
"}}}1
" Core {{{1
fu fold#md#fde#heading_depth(lnum) abort "{{{2
    let level      = 0
    let thisline   = getline(a:lnum)
    let hash_count = len(matchstr(thisline, '^#\{1,6}'))

    if hash_count > 0
        let level = hash_count
    else
        if thisline isnot# '' && thisline isnot# '```'
            let nextline = getline(a:lnum + 1)
            if nextline =~ '^=\+\s*$'
                let level = 1
            elseif nextline =~ '^-\+\s*$'
                let level = 2
            endif
        endif
    endif
    " temporarily commented because it makes us gain 0.5 seconds when loading Vim notes
    "     if level > 0 && s:line_is_fenced(a:lnum)
    "         " Ignore # or === if they appear within fenced code blocks
    "         return 0
    "     endif
    return level
endfu

fu fold#md#fde#nested() abort "{{{2
    let depth = fold#md#fde#heading_depth(v:lnum)
    return depth > 0
       \ ?     '>'.depth
       \ :     '='
endfu

fu fold#md#fde#stacked() abort "{{{2
    return fold#md#fde#heading_depth(v:lnum) > 0
       \ ?     '>1'
       \ :     '='
endfu

