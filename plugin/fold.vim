if exists('g:loaded_fold')
    finish
endif
let g:loaded_fold = 1

" Why the `[Z` and `]Z` mappings?{{{
"
" By default the cursor is moved to the previous/next fold:
"
"     • no matter its level
"       with `zj` and `zk`
"
"     • on the condition its level is greater than the current one
"       with `[z` and `]z`
"
" I don't like the asymmetry between the 2 pairs of mappings.
" I prefer to use `[z`, `]z` and `[Z`, `]Z`.
"}}}
noremap  <expr><silent><unique>  [Z  fold#motion#rhs('[Z')
noremap  <expr><silent><unique>  ]Z  fold#motion#rhs(']Z')
noremap  <expr><silent><unique>  [z  fold#motion#rhs('[z')
noremap  <expr><silent><unique>  ]z  fold#motion#rhs(']z')

xno  <silent>  [f  :<c-u>call fold#md#promote#set('less')<bar>set opfunc=fold#md#promote#main<bar>exe 'norm! '.v:count1.'g@l'<cr>
xno  <silent>  ]f  :<c-u>call fold#md#promote#set('more')<bar>set opfunc=fold#md#promote#main<bar>exe 'norm! '.v:count1.'g@l'<cr>

" Increase/decrease  'fdl', in  a  markdown  buffer  in “nesting” mode.{{{
" Use it to quickly see the titles up to an arbitrary depth.
" Useful  to get  an overview  of  the contents  of  the notes  of an  arbitrary
" precision.
"}}}
nno  <silent>  [of  :<c-u>call fold#md#option#fdl('less')<cr>
nno  <silent>  ]of  :<c-u>call fold#md#option#fdl('more')<cr>

" Why don't you use an autocmd to automatically fold a logfile?{{{
"
" 1. a logfile could have no `.log` extension
"
" 2. a logfile can be very big
"
"    Folding a big file can be slow.
"    We should not pay this price automatically, only when we decide.
"}}}
nno  <silent><unique>  -l  :<c-u>call fold#logfile#main()<cr>

