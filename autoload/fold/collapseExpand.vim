vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

def fold#collapseExpand#hlm(key: string)
    var cnt: number = v:count
    if cnt != 0 && key != 'M'
        execute 'normal! ' .. cnt .. key
    else
        fold#lazy#compute()
        execute 'normal! ' .. {H: 'zM', L: 'zR', M: 'zMzv'}[key] .. 'zz'
    endif
enddef

