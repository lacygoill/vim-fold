vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# FAQ{{{
# What's the purpose of this script?{{{
#
# Editing text in insert mode in a markdown buffer can sometimes be slow.
#
# MWE:
#
#     $ vim -Nu <(cat <<'EOF'
#         setlocal foldmethod=expr foldexpr=MarkdownFold()
#         def MarkdownFold(): any
#             var line: string = getline(v:lnum)
#             if line =~ '^#\+ '
#                 return '>' .. match(line, ' ')
#             endif
#             var nextline: string = getline(v:lnum + 1)
#             if line =~ '^.\+$' && nextline =~ '^=\+$'
#                 return '>1'
#             endif
#             if line =~ '^.\+$' && nextline =~ '^-\+$'
#                 return '>2'
#             endif
#             return '='
#         enddef
#         inoremap <expr> <C-K> repeat('<Del>', 300)
#         silent edit /tmp/md.md
#         :% delete
#         put ='text'
#         silent normal! yy300pG300Ax
#     EOF
#     )
#
# Vim takes several seconds to start.
# Now, press `I C-k` to delete the rest of the line.
# Again, it takes several seconds.
#
# It seems the issue is `markdown#fold#foldexpr#headingDepth()` which, for some
# reason, is called more than 180,000 times!
#
# I think  that every time  a character is inserted  or removed while  in insert
# mode, Vim has to  recompute the folding level of each line  above when using a
# foldexpr.
# That would  explain why  the issue  gets worse  as the  number of  lines above
# increases, and why it gets worse  as the number of inserted/removed characters
# increases.
#
# ---
#
# The main culprit is the value `'='` returned from `MarkdownFold()`.
# If you replace it with `1`, the slowness disappears.
#}}}
#   Why can't I just use `>1` and `1` to fix this issue?{{{
#
# We don't want to use `1` in `markdown#fold#foldexpr#stacked()`; see the comments there.
#
# Besides, for a given buffer, we may be using:
#
#    - a different foldexpr which also uses a costly value (e.g. `'='`, `'a123'`, `'s123'`)
#    - a different folding method which can still be slow (e.g. `syntax`)
#}}}
#     Ok, so how does `vim-fold` fix it?{{{
#
# It  lets Vim  create  folds according  to the  value  of `'foldmethod'`  (e.g.
# `foldexpr` or `syntax`), then it resets  the latter to `manual`, which is much
# less costly  because it doesn't ask  Vim to recompute anything  every time you
# edit the buffer.
#
# From `:help fold-methods`:
#
#    > Switching to  the "manual" method  doesn't remove the existing  folds.  This
#    > can be  used to first  define the folds  automatically and then  change them
#    > manually.
#}}}

# When won't the foldmethod be reset from a costly value to 'manual'?{{{
#
# When an autocmd installed after the ones from `vim-fold` resets `'foldmethod'`.
# As an example, add this to `~/.vim/after/plugin/markdown.vim`:
#
#     autocmd FileType markdown &l:foldmethod = 'expr'
#
# And disable the `BufWinEnter` autocmd in your markdown filetype plugin.
# Finally, run:
#
#     $ vim
#     :edit /tmp/md.md
#
# The foldmethod is set to 'expr'.
#
# See: https://github.com/Konfekt/FastFold/commit/e14d31902fea2ee8fde22c99921ba946d18f692c
#}}}
#   How to fix this possible issue?{{{
#
# Delay the vim-fold autocmds until `VimEnter`.
#
# However, another issue will arise:
#
#     $ vim /tmp/md.md
#
# In that case, the foldmethod is still 'expr', even after delaying the autocmds.
#
# Solution: on `VimEnter` invoke `fold#lazy#compute()` in *all* windows
# (*in addition to installing the autocmds*):
#
#     getwininfo()
#         ->mapnew((_, v: dict<any>) => win_execute(v.winid, 'fold#lazy#compute(false)'))
#
# See:
# https://github.com/Konfekt/FastFold/issues/30
# https://github.com/Konfekt/FastFold/blob/bd88eed0c22a298a49f52a14a673bc1aad8c0a1b/plugin/fastfold.vim#L184
#}}}
#     Why don't you try to fix it?{{{
#
# I can't imagine a realistic scenario where this issue would affect us.
# I think  it would require an  autocmd listening to `FileType`;  we would never
# install such an autocmd to set the foldmethod.
# We will always  use proper ftplugins, which are sourced  *before* the autocmds
# of third-party plugins are fired.
#}}}

# Why could it be useful to disable the lazyfold feature in small files?{{{
#
# https://github.com/Konfekt/FastFold/pull/55
#}}}
#   How could I do it?{{{
#
# Initialize some constant:
#
#     const MIN_LINES: number = 30
#
# Write this function:
#
#     def IsSmall()
#         return line('$') <= MIN_LINES
#     enddef
#
# And update `ShouldSkip()` to include it:
#
#     return IsSmall() || !IsCostly() || !empty(&buftype) || !&l:modifiable
#            ^-------^
#}}}
#   Which pitfalls should I be aware of?{{{
#
# `MIN_LINES` adds complexity; not  in terms of number of lines  of code, but in
# terms of logic; it increases the number of code paths.
#
# Suppose the script contains a bug which  can be reproduced when some options A
# and B are both on, or both off.
# But during your tests, you can't reproduce with A and B off, because you use a
# small file.
# You'll come to the conclusion that the bug  is only triggered when A and B are
# on; you may find a solution, but you won't have fixed the bug in all cases.
#
# Also, you may sometimes reproduce the issue, but not always, because you don't
# know or  have forgotten about the  fact that the  number of lines in  the file
# matters.
#
# More generally, the more  code paths, the harder it is to  debug and reason on
# issues.
#
# ---
#
# If you choose a too big value, you may experience lag too frequently.
#
# Whatever value you use for `MIN_LINES`, make this experiment:
#
#                                                 replace with the new number you want to use (minus 3)
#                                                 vvv  vvv
#     $ vim +":% delete | put ='text' | normal! yy123pG123Ax" /tmp/md.md
#     " make sure that 'foldmethod' is 'expr'
#     " press:  I C-k C-k
#
# Check how much time it takes for Vim to remove all the characters.
# Choose a value for which the time is acceptable.
#
# 30 seems like a  good fit, because it's a round number, and  it's close to the
# current maximum number of lines we can display in a window (`&lines`).
# It makes sense to consider a file which  fits on a single screen as small; but
# not anything above.
#}}}

# When won't the folds be recomputed?{{{
#
# When  you  modify  a buffer  to  add  new  folded  text, the  folds  won't  be
# recomputed until  you save  the buffer  or use  a custom  fold-related command
# (e.g. `SPC SPC`, `]Z`), provided that the latter has been customized to invoke
# `#compute()`.
#
# If you  use a  fold-related command, but  don't save, the  folds will  only be
# recomputed in the current window; they won't be recomputed in inactive windows
# displaying the current buffer.
# If  this is  an  issue,  then you  should  refactor  your custom  fold-related
# commands so that they invoke `#compute_windows()`.
#
# I don't see the  necessity to do it right now;  `#compute()` seems good enough
# until we save.
#}}}
# How to make Vim recompute folds in another script?{{{
#
# Call `#compute()` if you want to recompute folds only in the current window.
# If you call it from an autocmd, pass it the optional boolean `false`.
# This will force Vim to recompute folds  no matter what, even if it has already
# been done recently.
#}}}
# I want to test how our "lazyfold" feature behaves when the foldmethod is set to syntax.  What should I do?{{{
#
#     $ git clone https://github.com/BurntSushi/ripgrep && cd *(/oc[1])
#     $ vim --cmd 'let g:rust_fold=2' build.rs
#}}}
#}}}

# Interface{{{1
def fold#lazy#computeWindows() #{{{2
    # compute folds in each window displaying the current buffer; not just the current window
    var curbuf: number = bufnr('%')
    getwininfo()
        ->filter((_, v: dict<any>): bool => v.bufnr == curbuf)
        # When I save a new fold, it stays open in the current window (✔), but not in an inactive one (✘)!{{{
        #
        # Use this block instead:
        #
        #     var curlnum: number = line('.')
        #     var was_visible: bool = foldclosed('.') == -1
        #     var curbuf: number = bufnr('%')
        #     getwininfo()
        #         ->filter((_, v: dict<any>): bool => v.bufnr == curbuf)
        #         ->mapnew((_, v: number) => win_execute(v, [
        #             'fold#lazy#compute(false)',
        #             'execute ' .. was_visible .. ' && foldclosed(' .. curlnum .. ') >= 0
        #                 ? "normal! ' .. curlnum .. 'Gzv"
        #                 : ""'
        #             ]))
        #
        # The issue is due to the fact that the current line in inactive windows
        # is not synchronized with the current line in the active window.
        #
        # ---
        #
        # I don't try to fix this "issue" because it adds too much code for what
        # seems to be an edge case.
        #
        # Note  that the  previous block  could change  the current  line of  an
        # inactive window; you may want to preserve it.
        #
        # Besides, whether it's an issue is  debatable.  I mean the fold did not
        # exist  in an  inactive window,  so  when Vim  closes it  automatically
        # there, you can't say that its state has not been preserved; it did not
        # have a state to begin with.
        #}}}
        ->mapnew((_, v: dict<any>) => win_execute(v.winid, 'fold#lazy#compute(false)'))
enddef

def fold#lazy#compute(noforce = true) #{{{2
    # Why not just inspecting `&l:diff`?{{{
    #
    # It would cause this issue:
    #
    #     $ vimdiff /tmp/md1.md /tmp/md2.md
    #     :tabnew
    #     :edit /tmp/md2.md
    #     :echo &l:foldmethod
    #     expr˜
    #     " it should be 'manual'
    #
    # That's because the window in the new  tab page has copied the local values
    # of some options from a diffed window (including `'diff'` which is set).
    #}}}
    if &l:foldmethod == 'diff'
        return
    endif
    # If the file is to be skipped, make sure `b:last_foldmethod` does not exist.{{{
    #
    # Its existence has a meaning for our  code; I suspect that keeping it while
    # the file is to be skipped could lead to subtle bugs.
    #}}}
    if ShouldSkip()
        unlet! b:last_foldmethod b:lazyfold_changedtick
        return
    endif

    # To improve performance, bail out if folds have been recomputed recently.
    # What's this optional argument?{{{
    #
    # When it's false, it means that we want folds to be recomputed no matter what.
    #}}}
    #   Ok, and why do you bail out only when it does not exist?{{{
    #
    # When  we call  `#compute()`  from  a custom  mapping,  we  don't pass  the
    # optional argument, to  let the function know that it  should not recompute
    # folds if it has already been done recently.
    # Otherwise, if the mapping is pressed  repeatedly very fast, there would be
    # too much lag in a big file.
    #
    # When  we call  `#compute()`  from  an autocmd,  we  do  pass the  optional
    # argument, because  in that case  we want them  to be recomputed  no matter
    # what (even if they have been recomputed recently).
    #}}}
    #     and only when the buffer has changed?{{{
    #
    # If the buffer has not changed, there's no reason to recompute the folds.
    #
    # In fact, bailing out can improve the performance in some cases.
    # Suppose we are in a big folded file.
    # There's no reason to recompute all the folds every time we press `SPC SPC`
    # to toggle a fold.
    # Same thing for any custom  mapping which invokes this function; especially
    # if we press it frequently (e.g. `] SPC` followed by a smashed `.`, or `]Z`
    # followed by a smashed `;`/`,`).
    #}}}
    #     why don't you bail out if the buffer is not modified?{{{
    #
    # Suppose you delete a fold, then undo.
    # The buffer is still unmodified, but the folding information has been lost.
    # For Vim, this text you've restored is not folded.
    # We probably expect Vim to recompute the fold when we press `SPC SPC` inside.
    #}}}
    if noforce && b:changedtick == get(b:, 'lazyfold_changedtick')
        return
    endif
    b:lazyfold_changedtick = b:changedtick

    # temporarily restore the original costly foldmethod
    if exists('b:last_foldmethod') && &l:foldmethod == 'manual'
        # Don't close a new fold automatically.{{{
        #
        # When saving a  modified buffer containing a new fold,  the latter could be
        # closed automatically; we don't want that.
        #
        # MWE:
        #
        #     $ vim -Nu NONE -S <(cat <<'EOF'
        #         setlocal foldminlines=0 foldmethod=manual foldexpr=getline(v:lnum)=~'^#'?'>1':'='
        #         autocmd BufWritePost * setlocal foldmethod=expr | eval foldlevel(1) | setlocal foldmethod=manual
        #         :% delete | silent put =repeat(['x'], 5) | :1
        #     EOF
        #     ) /tmp/md.md
        #
        #     " press:  O # Esc :write  (the fold is closed automatically)
        #     " press:  O # Esc :write  (the fold is closed automatically if 'foldminlines' is 0)
        #
        # I think that for the issue to be reproduced, you need to:
        #
        #    - set `'foldlevel'` to 0 (it is by default)
        #    - modify the buffer so that the expr method detects a *new* fold
        #    - switch from manual to expr
        #}}}
        var was_visible: bool = foldclosed('.') == -1
        &l:foldmethod = b:last_foldmethod
        # Wait.  Aren't the folds recomputed only when `foldlevel(1)` is evaluated?{{{
        #
        # Any folding-related function causes folds to be recomputed.
        # So the  evaluation of the next  `foldclosed()` causes the folds  to be
        # recomputed  immediately (to  be  accurate, they  are recomputed  right
        # before computing the fold level of the current line).
        #}}}
        if was_visible && foldclosed('.') >= 0
            # Do *not* move `normal! zv` in `#compute_windows()`.{{{
            #
            # The latter is only invoked on certain events:
            #
            #     FileType
            #     BufWritePost
            #     BufWinEnter
            #
            # This is not frequent enough.
            #
            # E.g.  we  manually  call  `#compute()` from  `Jump()`  (called  by
            # `fold#motion#rhs()`).
            # If you moved  `:normal! zv` in `#compute_windows()`,  it would not
            # be executed  when we  press `]z`, which  would prevent  the latter
            # from moving the cursor to the end of a *new* open fold.
            #
            # It would work only after pressing it twice.
            # Indeed,  the first  time,  the fold  would be  closed  as soon  as
            # vim-fold executes:
            #
            #     &l:foldmethod = b:last_foldmethod
            #
            # Btw, the reason why the fold seems to stay open is because `#go()`
            # runs `:normal! zv` at the end; but it *is* temporarily closed, and
            # it  *is* closed  right  before  `]z` is  pressed  by `#go()`  (via
            # `:normal`) for the first time in a new fold.
            #}}}
            # `:normal! zv` may be executed in an inactive window.{{{
            #
            # Which is ok.
            # It happens when `FileType` or `BufWritePost` are fired.
            #
            # `:normal! zv` is helpful when the buffer is reloaded (e.g. with `:edit`).
            # When that happens:
            #
            #    - all the folds are deleted in all the windows displaying the buffer
            #
            #    - folds are recreated when  the foldmethod is temporarily reset
            #      to its original costly  value (e.g. 'expr'), and `foldclosed('.')`
            #      is evaluated
            #
            #    - the new folds are closed (if `'foldlevel'` is 0)
            #
            # If `normal! zv`  was not executed in an inactive  window, we would
            # not see the contents of its current fold when we reload the buffer
            # from another window.  I prefer to see it.
            #}}}
            normal! zv
        endif
    endif

    # and now get back to 'manual'
    b:last_foldmethod = &l:foldmethod
    # Why evaluate this function?{{{
    #
    # To make sure Vim recomputes folds, before we reset the foldmethod to manual.
    # Without, there is a risk that no fold would be created:
    #
    #     $ vim -Nu NONE -S <(cat <<'EOF'
    #         setlocal foldminlines=0 foldmethod=manual foldexpr=getline(v:lnum)=~'^#'?'>1':'='
    #         :% delete | put =repeat(['x'], 5) | :1
    #     EOF
    #     ) /tmp/file
    #     " insert:  #
    #     " run:  setlocal foldmethod=expr | setlocal foldmethod=manual
    #     " no fold is created;
    #     " but a fold would have been created if you had run:
    #
    #         :setlocal foldmethod=expr | eval foldlevel(1) | setlocal foldmethod=manual
    #
    #      or
    #
    #         :setlocal foldmethod=expr | execute ':1 windo "' | setlocal foldmethod=manual
    #
    #      or
    #
    #         :setlocal foldmethod=expr
    #         :setlocal manual
    #
    # ---
    #
    # I don't know why/how it works, but the original FastFold plugin implicitly
    # relies on  a side effect  of `:windo`  for folds  to be  recomputed before
    # resetting the foldmethod to manual.
    #}}}
    #   Why not `:normal! zx`?{{{
    #
    # It does not preserve manually opened/closed folds.
    # Note that `winsaveview()` does not save fold information.
    #}}}
    #   Why with the legacy syntax?{{{
    #
    # If 'foldexpr' has been set in a legacy script/function, it might contain a
    # binary operator which is not surrounded by whitespace (because whoever set
    # the option  didn't want  to write  a backslash every  time they  needed to
    # include a space).  But in Vim9 script, that's an error.
    # See: https://github.com/vim/vim/issues/7625#issuecomment-755268156
    #}}}
    legacy eval foldlevel(1)
    &l:foldmethod = 'manual'
enddef

def fold#lazy#handleDiff() #{{{2
    var enter_diff_mode: bool = v:option_new == '1' && v:option_old == '0'
    var leave_diff_mode: bool = v:option_new == '0' && v:option_old == '1'

    if enter_diff_mode && exists('b:last_foldmethod')
        b:prediff_fdm = b:last_foldmethod
    elseif leave_diff_mode && exists('b:prediff_fdm')
        &l:foldmethod = b:prediff_fdm
        # with legacy syntax  to suppress errors in case binary  operator is not
        # surrounded by whitespace
        legacy eval foldlevel(1)
        unlet! b:prediff_fdm
    endif
enddef
#}}}1
# Utilities {{{1
def ShouldSkip(): bool #{{{2
    return !IsCostly() || !empty(&buftype) || !&l:modifiable
enddef

def IsCostly(): bool #{{{2
    var pat: string = '^\%(expr\|indent\|syntax\)$'
    return (exists('b:last_foldmethod') && b:last_foldmethod =~ pat)
        || &l:foldmethod =~ pat
enddef

