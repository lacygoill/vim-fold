vim9script noclear

def fold#comment#main(type = ''): string
    if type == ''
        &operatorfunc = 'fold#comment#main'
        return 'g@l'
    endif
    execute "silent normal! V\<Cmd>call comment#object#main()\<CR>"
    execute "normal! \<Esc>"
    var cml: string = '\V'
        ..  &commentstring->matchstr('\S*\ze\s*%s')->escape('\')
        .. '\m'
    if getline("'>") !~ '^\s*' .. cml .. '\s*$'
        execute "normal! o\<Esc>"
    endif
    execute "silent normal! V\<Cmd>call comment#object#main()\<CR>"
    normal! zf
    return ''
enddef

