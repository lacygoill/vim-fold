vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

def fold#comment#main(type = ''): string
    if type == ''
        &opfunc = 'fold#comment#main'
        return 'g@l'
    endif
    sil exe "norm! V\<cmd>call comment#object#main()\r"
    exe "norm! \e"
    var cml: string = '\V' .. matchstr(&l:cms, '\S*\ze\s*%s')
        ->escape('\') .. '\m'
    if getline("'>") !~ '^\s*' .. cml .. '\s*$'
        exe "norm! o\e"
    endif
    sil exe "norm! V\<cmd>call comment#object#main()\r"
    norm! zf
    return ''
enddef

