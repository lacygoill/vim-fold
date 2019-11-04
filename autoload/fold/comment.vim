fu fold#comment#main() abort
    norm Vic
    exe "norm! \e"
    let cml = '\V'..escape(matchstr(split(&l:cms, '%s'), '\S*'), '\')..'\m'
    if getline("'>") !~# '^\s*'..cml..'\s*$'
        exe "norm! o\e"
    endif
    norm Vic
    norm! zf
endfu

