" Interface {{{1
fu! fold#md#how_many#print() abort "{{{2
    let view = winsaveview()
    let s:current_lvl = s:get_current_lvl()

    call s:move_to_first_fold(1)
    let msg_first_part = s:get_number_of_folds(1)
    call winrestview(view)

    call s:move_to_first_fold(2)
    let msg_second_part = s:get_number_of_folds(2)
    call winrestview(view)

    echom msg_first_part.', '.msg_second_part
endfu

" Core {{{1
fu! s:move_to_first_fold(n) abort "{{{2
    if a:n == 1
        " move to first line of first neighbour fold
        let pat = s:current_lvl == 1
            \ ? '^#\+$\n\zs\|\%^'
            \ : '^#\+$\n\zs\|^#\{'.(s:current_lvl - 1).'}#\@!\s\S\+.*\n\zs\|\%^'
    else
        " move to first line of parent fold
        let pat = s:current_lvl == 1
            \ ? '^\%(#\+\n\|\%^\)\zs#\s\S\+'
            \ : '^#\{'.(s:current_lvl-1).'}#\@!'
    endif
    call search(pat, 'bcW')
endfu

fu! s:get_number_of_folds(n) abort "{{{2
    " a:n == 1
    "    get the number of  folds with the same level, and in  the same block of
    "    consecutive folds
    "
    " a:n == 2
    "     get the number of folds with the same level, and the same parent
    let pat = s:current_lvl == 1
        \ ? '^#\+$\|\%$'
        \ : (a:n == 1 ? '^#\+$\|' : '').'^#\{'.(s:current_lvl-1).'}#\@!\|\%$'

    let first_line_last_fold = search(pat, 'nW')
    let cnt = 0
    while cnt < 999 && line('.') < first_line_last_fold
        call search('^#\{'.s:current_lvl.'}#\@!\s\S\+\|\%$', 'W')
        let cnt += 1
    endwhile

    return (a:n == 1 ? cnt : cnt - 1)
endfu

" Utility {{{1
fu! s:get_current_lvl() abort "{{{2
    let pat = '^#\+\ze\s\+'
    let first_line = search(pat, 'bcnW')
    let current_lvl = len(matchstr(getline(first_line), pat))
    return current_lvl
endfu

