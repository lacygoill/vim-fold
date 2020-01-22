fu fold#collapse_expand#hlm(cmd) abort
    let cnt = v:count
    if cnt && a:cmd isnot# 'M'
        exe 'norm! '..cnt..a:cmd
    else
        call fold#lazy#update_win()
        exe 'norm! '..{'H': 'zM', 'L': 'zR', 'M': 'zMzv'}[a:cmd]..'zz'
    endif
endfu

