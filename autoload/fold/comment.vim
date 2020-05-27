fu fold#comment#main(...) abort
    if !a:0
        let &opfunc = 'fold#comment#main'
        return 'g@l'
    endif
    sil exe "norm! V:\<c-u>call comment#object#main(0)\r"
    exe "norm! \e"
    let cml = '\V'..escape(matchstr(&l:cms, '\S*\ze\s*%s'), '\')..'\m'
    if getline("'>") !~# '^\s*'..cml..'\s*$'
        exe "norm! o\e"
    endif
    sil exe "norm! V:\<c-u>call comment#object#main(0)\r"
    norm! zf
endfu

