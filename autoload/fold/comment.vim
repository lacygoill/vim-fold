fu fold#comment#main(_) abort
    sil exe "norm! V:\<c-u>call comment#object#main(0)\r"
    exe "norm! \e"
    let cml = '\V'..escape(matchstr(&l:cms, '\S*\ze\s*%s'), '\')..'\m'
    if getline("'>") !~# '^\s*'..cml..'\s*$'
        exe "norm! o\e"
    endif
    sil exe "norm! V:\<c-u>call comment#object#main(0)\r"
    norm! zf
endfu

