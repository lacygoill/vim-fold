fu! fold#md#promote#main(_) abort "{{{1
    for i in range(1, v:count1)
        call s:promote()
    endfor
endfu

fu! s:promote() abort "{{{1
    let range = line("'<").','.line("'>")
    if s:choice is# 'more'
        sil exe 'keepj keepp '.range.'s/^\(#\+\)/\1#/e'
    else
        sil exe 'keepj keepp '.range.'s/^\(#\+\)#/\1/e'
    endif
endfu

fu! fold#md#promote#set(choice) abort "{{{1
    let s:choice = a:choice
endfu

