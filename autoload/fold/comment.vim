fu fold#comment#main(...) abort
    if !a:0
        let &opfunc = 'fold#comment#main'
        return 'g@l'
    endif
    sil exe "norm! V\<cmd>call comment#object#main()\r"
    exe "norm! \e"
    let cml = '\V' .. matchstr(&l:cms, '\S*\ze\s*%s')->escape('\') .. '\m'
    if getline("'>") !~# '^\s*' .. cml .. '\s*$'
        exe "norm! o\e"
    endif
    sil exe "norm! V\<cmd>call comment#object#main()\r"
    norm! zf
endfu

