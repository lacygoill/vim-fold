fu fold#logfile#main() abort "{{{1
    if !(&ft is# '' || &ft is# 'markdown' && search('^health#', 'n'))
        return
    endif
    " How is it possible that the folds persist when we do `:FoldLogfile`, then reload the buffer?{{{
    "
    " A logfile has no filetype.
    " There's no default filetype plugin which could be sourced automatically by
    " Vim, and undo the settings we're going to install.
    "}}}
    let b:title_like_in_markdown = 1
    runtime! ftplugin/markdown.vim
    " usually, we set fold options via an autocmd listening to `BufWinEnter`
    do <nomodeline> BufWinEnter
endfu

