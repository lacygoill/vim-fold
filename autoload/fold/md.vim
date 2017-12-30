fu! fold#md#heading_depth(lnum) abort "{{{1
    let level     = 0
    let thisline  = getline(a:lnum)
    let hashCount = len(matchstr(thisline, '^#\{1,6}'))

    if hashCount > 0
        let level = hashCount
    else
        if thisline != ''
            let nextline = getline(a:lnum + 1)
            if nextline =~ '^=\+\s*$'
                let level = 1
            elseif nextline =~ '^-\+\s*$'
                let level = 2
            endif
        endif
    endif
    " temporarily commented because it makes us gain 0.5 seconds when loading
    " Vim notes
    "         if level > 0 && s:line_is_fenced(a:lnum)
    "             " Ignore # or === if they appear within fenced code blocks
    "             return 0
    "         endif
    return level
endfu

fu! fold#md#nested() abort "{{{1
    let depth = fold#md#heading_depth(v:lnum)
    return depth > 0
    \?         '>'.depth
    \:         '='
endfu

fu! fold#md#stacked() abort "{{{1
    return fold#md#heading_depth(v:lnum) > 0
    \?         '>1'
    \:         '1'
endfu

fu! fold#md#toggle_fde() abort "{{{1
    let &l:fde = &l:fde ==# 'fold#md#stacked()'
    \?               'fold#md#nested()'
    \:               'fold#md#stacked()'
endfu
