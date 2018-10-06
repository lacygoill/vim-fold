fu! fold#md#promote#main(type) abort "{{{1
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

