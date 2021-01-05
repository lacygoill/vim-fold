vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

def fold#fdt#get(): string #{{{1
    var foldstartline = getline(v:foldstart)
    var indent: string
    var level: number
    # get the desired level of indentation for the title
    if get(b:, 'title_like_in_markdown', false)
        level = markdown#fold#foldexpr#headingDepth(v:foldstart)
        indent = repeat(' ', (level - 1) * 3)
    else
        indent = foldstartline =~ '{{\%x7b\d\+\s*$'
            ?     repeat(' ', (v:foldlevel - 1) * 3)
            :     matchstr(foldstartline, '^\s*')
    endif

    # If you don't care about html and css, you could probably simplify the code
    # of this function, and get rid of `cml_right`.
    var cml_left: string
    var cml_right: string
    if &ft == 'vim'
        cml_left = '["#]'
        cml_right = '\V\m'
    else
        cml_left = '\V' .. matchstr(&l:cms, '\S*\ze\s*%s')->escape('\') .. '\m'
        cml_right = '\V' .. matchstr(&l:cms, '.*%s\s*\zs.*')->escape('\') .. '\m'
    endif

    # remove comment leader
    # Why 2 spaces in the bracket expression?{{{
    #
    # The first is a space, the other is a no-break space.
    # We sometimes use the latter when we want the title to be indented compared
    # to the title of the previous fold (outside markdown).
    # This  can be  useful to  prevent  the title  from being  highlighted as  a
    # codeblock.
    #}}}
    var pat = '^\s*' .. cml_left .. '[  \t]\='
    # remove fold markers
    if cml_right == '\V\m'
        pat ..= '\|\s*\%(' .. cml_left .. '\)\=\s*{{\%x7b\d*\s*$'
    else
         pat ..= '\|\s*' .. cml_right .. '\s*' .. cml_left .. '\s*{{\%x7b\d*\s*' .. cml_right .. '\s*$'
    endif

    # we often use backticks for codespans, but a codespan's highlighting is not
    # visible in a fold title, so backticks are just noise; remove them
    pat ..= '\|`'

    var title = substitute(foldstartline, pat, '', 'g')

    # remove filetype specific noise
    if get(b:, 'title_like_in_markdown', false)
        title = substitute(foldstartline, '^[-=#]\+\s*', '', '')
    elseif &ft == 'sh' || &ft == 'zsh'
        title = substitute(title, '^.*\zs()\s*\%({\|(\)', '', '')
    elseif &ft == 'vim'
        pat = '^\s*\%(fu\%[nction]\|\%(export\s\+\)\=def\)!\='
            # ignore `aaa#bbb#` in `aaa#bbb#func()`, and ignore `s:` in `s:func()`
            .. ' \%(.*\%(#\|s:\)\)\='
            # capture the function name
            .. '\(.\{-}\)'
            # but not the function arguments
            .. '(.*'
        title = substitute(title, pat, '\1', '')
    elseif &ft == 'python'
        title = substitute(title, '^def\s\+\|(.\{-})\%(^def\s\+.*\)\@<=:', '', 'g')
    endif

    if get(b:, 'foldtitle_full', false)
        var foldsize = (v:foldend - v:foldstart)
        var linecount = '[' .. foldsize .. ']' .. repeat(' ', 4 - strlen(foldsize))
        return indent .. (foldsize > 1 ? linecount : '') .. title
    else
        return indent .. title
    endif
enddef

