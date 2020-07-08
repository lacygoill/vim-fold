fu fold#fdt#get() abort "{{{1
    let foldstartline = getline(v:foldstart)
    " get the desired level of indentation for the title
    if get(b:, 'title_like_in_markdown', 0)
        let level = markdown#fold#foldexpr#heading_depth(v:foldstart)
        let indent = repeat(' ', (level-1)*3)
    else
        let indent = foldstartline =~# '{{\%x7b\d\+\s*$'
                 \ ?     repeat(' ', (v:foldlevel-1)*3)
                 \ :     matchstr(foldstartline, '^\s*')
    endif

    " If you don't care about html and css, you could probably simplify the code
    " of this function, and get rid of `cml_right`.
    let cml_left = '\V'..escape(matchstr(&l:cms, '\S*\ze\s*%s'), '\')..'\m'
    let cml_right = '\V'..escape(matchstr(&l:cms, '.*%s\s*\zs.*'), '\')..'\m'

    " remove comment leader
    " Why 2 spaces in the bracket expression?{{{
    "
    " The first is a space, the other is a no-break space.
    " We sometimes use the latter when we want the title to be indented compared
    " to the title of the previous fold (outside markdown).
    " This  can be  useful to  prevent  the title  from being  highlighted as  a
    " codeblock.
    "}}}
    let pat = '^\s*'..cml_left..'[  \t]\='
    " remove fold markers
    if cml_right is# '\V\m'
        let pat ..= '\|\s*\%('..cml_left..'\)\=\s*{{\%x7b\d*\s*$'
    else
        let pat ..= '\|\s*'..cml_right..'\s*'..cml_left..'\s*{{\%x7b\d*\s*'..cml_right..'\s*$'
    endif

    let title = substitute(foldstartline, pat, '', 'g')

    " remove filetype specific noise
    let title = get(b:, 'title_like_in_markdown', 0)
            \ ?     substitute(foldstartline, '^[-=#]\+\s*', '', '')
            \ : &ft is# 'sh' || &ft is# 'zsh'
            \ ?     substitute(title, '^.*\zs()\s*\%({\|(\)', '', '')
            \ : &ft is# 'vim'
            \ ?     substitute(title, '^\s*\%(fu\%[nction]\|def\)!\= \%(.*\%(#\|s:\)\)\=\(.\{-}\)(.*).*', '\1', '')
            \ : &ft is# 'python'
            \ ?     substitute(title, '^def\s\+\|(.\{-})\%(^def\s\+.*\)\@<=:', '', 'g')
            \ :     title

    if get(b:, 'foldtitle_full', 0)
        let foldsize  = (v:foldend - v:foldstart)
        let linecount = '['..foldsize..']'..repeat(' ', 4 - strlen(foldsize))
        return indent ..(foldsize > 1 ? linecount : '')..title
    else
        return indent..title
    endif
endfu

