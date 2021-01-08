vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

def fold#collapse_expand#hlm(key: string)
    var cnt = v:count
    if cnt != 0 && key != 'M'
        exe 'norm! ' .. cnt .. key
    else
        fold#lazy#compute()
        exe 'norm! ' .. {H: 'zM', L: 'zR', M: 'zMzv'}[key] .. 'zz'
    endif
enddef

