fu! fold#md#heading_depth(lnum) abort "{{{1
    let level     = 0
    let thisline  = getline(a:lnum)
    let hashCount = len(matchstr(thisline, '^#\{1,6}'))

    if hashCount > 0
        let level = hashCount
    else
        if thisline isnot# ''
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
       \ ?     '>'.depth
       \ :     '='
endfu

fu! fold#md#sort_by_size(lnum1,lnum2) abort "{{{1
    " get the level of the first fold
    let lvl = strlen(matchstr(getline(a:lnum1), '^#*'))
    if lvl ==# 0
        return 'echoerr "the first line is not a fold title"'
    endif

    " disable folding, because it could badly interfere when we move lines with `:m`
    let &l:fen = 0

    " What's this?{{{
    "
    " A pattern describing the end of a fold.
    " (to be more accurate, its last newline or the end of the buffer)
    "}}}
    let pat = '\n\%(#\{1,'.lvl.'}#\@!\)\|\%$'

    call cursor(a:lnum1, 1)

    " search the end of the first fold
    let foldend = search(pat, 'W', a:lnum2)
    if foldend == 0
        return ''
    endif
    " What's this?{{{
    "
    " We begin populating the list `folds`.
    " Each item in this list is a dictionary with three keys:
    "
    "     • foldstart:    first line in the fold
    "     • foldend:      last line in the fold
    "     • size:         size of the fold
    "}}}
    let folds = [{'foldstart': a:lnum1, 'foldend': foldend, 'size': foldend - a:lnum1 + 1}]
    " What does the loop do?{{{
    "
    "     1. it looks for the end of the next fold with the same level
    "
    "     2. it populates the list `folds` with info about this new current fold
    "
    "     3. every time it finds a previous fold which is bigger
    "        than the current one:
    "
    "                • it moves the latter above
    "                • it re-calls the function to continue the process
    "}}}
    while foldend > 0
        " We're going to maybe move the  current fold; but it's not necessary if
        " there's only 1 fold.
        if len(folds) > 1
            " get relevant info about the last fold which we added to `folds`
            " at the end of the previous iteration
            let size = folds[-1].size
            let foldstart = folds[-1].foldstart
            let foldend = folds[-1].foldend

            " move last fold if necessary
            for f in folds
                " if you find a previous fold which is bigger
                if f.size > size
                    " move last fold above
                    sil exe foldstart.','.foldend.'m ' . (f.foldstart - 1)
                    return fold#md#sort_by_size(a:lnum1,a:lnum2)
                endif
            endfor
        endif

        let orig_lnum = line('.')
        let foldend = search(pat, 'W', a:lnum2)
        "                  ┌ stop if you find a fold whose level is < `lvl`
        "                  │
        if foldend == 0 || match(getline(orig_lnum+1), '^\%(#\{'.(lvl-1).'}#\@!\)') ==# 0
            break
        endif
        let folds += [{'foldstart': orig_lnum + 1, 'foldend': foldend, 'size': foldend - orig_lnum}]
    endwhile

    " re-enable folding
    let &l:fen = 1
    return ''
endfu

fu! fold#md#stacked() abort "{{{1
    return fold#md#heading_depth(v:lnum) > 0
       \ ?     '>1'
       \ :     '='
endfu

fu! fold#md#toggle_fde() abort "{{{1
    let &l:fde = &l:fde is# 'fold#md#stacked()'
             \ ?     'fold#md#nested()'
             \ :     'fold#md#stacked()'
endfu

