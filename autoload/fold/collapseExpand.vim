vim9script noclear

def fold#collapseExpand#hlm(key: string)
    var cnt: number = v:count
    if cnt != 0 && key != 'M'
        execute 'normal! ' .. cnt .. key
    else
        fold#lazy#compute()
        execute 'normal! ' .. {H: 'zM', L: 'zR', M: 'zMzv'}[key] .. 'zz'
    endif
enddef

