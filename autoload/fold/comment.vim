fu fold#comment#main() abort
    norm Vic
    exe "norm! \e"
    let cml = '\V'..escape(matchstr(&l:cms, '\S*\ze\s*%s'), '\')..'\m'
    if getline("'>") !~# '^\s*'..cml..'\s*$'
        exe "norm! o\e"
    endif
    norm Vic
    norm! zf
endfu

