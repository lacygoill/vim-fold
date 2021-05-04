vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# Specification{{{
#
# `]z` should move the cursor to:
#
#    - the end of the current fold
#    - the end of the next fold
#    - right above the start of the next nested fold
#
# Whichever is the nearest.
#
# Exception: when the folding method is  'marker', the cursor should not move on
# a line containing a folding marker; it should move right above.
#
# `[z` should move the cursor to:
#
#    - right below the start of the current fold
#    - right below the start of the previous fold
#    - right below the end of the previous nested fold
#
# Whichever is the nearest.
#}}}

# Init {{{1

# Set this  to a non-zero  value to  make the code  preserve the state  of folds
# (open vs closed).
# Warning: When set, the motions may be slow in files with a lot of folds.
# If that's an issue, adjust `BIG_FILE`.
const PRESERVE_FOLD_STATE: number = 1

# Saving/restoring the  state of all the  folds takes time; the  more folds, the
# longer it takes  (e.g. vimrc); as a  workaround, we bite the  bullet and never
# preserve the state of the folds in big files.
const BIG_FILE: number = 1'000

# Interface {{{1
def fold#motion#rhs(lhs: string): string #{{{2
    if &l:fdm == 'manual' && !exists('b:last_fdm')
        return ''
    endif

    var mode: string = mode(true)
    var cnt: number = v:count1
    # If we're in visual block mode, we can't pass `C-v` directly.{{{
    #
    # Since  8.2.2062,  `<cmd>`  handles  `C-v`  just like  it  would  be  on  a
    # command-line entered  with `:`. That  is, it's interpreted as  "insert the
    # next character literally".
    #
    # Solution: double `<C-v>`.
    #}}}
    if mode == "\<c-v>"
        mode = "\<c-v>\<c-v>"
    endif

    # Why pressing Escape from visual mode?{{{
    #
    # To make sure  the cursor is positioned  on the corner of  the selection we
    # were controlling.  Otherwise,  it could be unexpectedly  positioned on the
    # other corner:
    #
    #     $ vim -Nu NONE +"pu=['aaa', 'bbb', 'ccc']" +'norm! 1GVG'
    #     " press:  colon C-u Enter
    #     " the cursor gets positioned on the first line instead of the last line
    #
    # ---
    #
    # Btw, don't bother trying to stay in visual mode.
    # Our  code  may execute  commands  which  makes  us  quit the  visual  mode
    # frequently (e.g. `zo`, `zc`; `zv` and motions are ok though).
    #}}}
    # Why pressing `V` in operator-pending mode?{{{
    #
    # Because in that mode, usually, we want to operate on whole lines.
    #}}}
    #   Why not `mode =~ 'o'` instead of `mode == 'no'`?{{{
    #
    # We don't want to force the motion to be linewise unconditionally.
    # E.g., we could have manually forced it to be characterwise or blockwise.
    # In those cases, we should not interfere; it would be unexpected.
    #}}}
    return printf("%s%s\<cmd>call " .. "%s(%s, %s, %d)\<cr>",
        index(['v', 'V', "\<c-v>\<c-v>"], mode) >= 0 ? "\e" : '',
        mode == 'no' ? 'V' : '',
        function(Jump),
        string(lhs),
        string(mode),
        cnt)
enddef
#}}}1
# Core {{{1
def Jump( #{{{2
    lhs: string,
    mode: string,
    cnt: number
)
    # recompute folds to make sure they are up-to-date
    fold#lazy#compute()

    var fixed_corner: number
    if mode == 'n'
        norm! m'
    elseif mode =~ "^[vV\<c-v>]$"
        # Line number of the corner of the selection which is "fixed". {{{
        #
        # I.e. we don't make it change because we are controlling the other corner.
        # We'll need this info to select the desired range of lines at the end.
        # We need to save it now, because the current line is going to change.
        #}}}
        fixed_corner = line('.') == line("'<") ? line("'>") : line("'<")
    endif

    var view: dict<number> = winsaveview()
    if PRESERVE_FOLD_STATE && line('$') <= BIG_FILE
        Foldsavestate()
    endif

    norm! zR
    for i in range(cnt)
        NextFold(lhs)
    endfor

    if PRESERVE_FOLD_STATE
        && line('$') <= BIG_FILE
        && maparg('j', 'n', 0, 1)->get('rhs', '') !~ 'move_and_open_fold'
        Foldreststate()
    else
        norm! zM
    endif
    norm! zv
    Winrestview(view)

    if mode =~ "^[vV\<c-v>]$"
        exe 'norm! ' .. fixed_corner .. 'G' .. mode .. line('.') .. 'G'
    endif
enddef

def NextFold(lhs: string)
    var orig: number = line('.')

    var next: list<number>
    if lhs == '[z'

        keepj norm! [z
        next += [line('.')]
        cursor(orig, 1)
        keepj norm! zk
        next += [line('.')]
        next->filter((_, v: number): bool => v != orig)
        if empty(next)
            return
        endif
        cursor(max(next), 1)

        var is_fold_start: bool = IsFoldStart()
        var is_fold_end: bool = IsFoldEnd()
        var is_next_line_foldable: bool = (line('.') + 1)->foldlevel() > 0
        var moved_just_above: bool = line('.') == orig - 1

        # FIXME: Doesn't always work as expected.{{{
        #
        #     $ vim --cmd 'let g:rust_fold=2 | setl ft=rust fdc=5' +'norm! GzR' <(curl -Ls https://raw.githubusercontent.com/BurntSushi/ripgrep/cb0dfda936748a7ca7a2d52d8b033bc48382d5f9/build.rs)
        #     " press [z 7 times
        #     " the 7th time, we jump from 166 to 157
        #     " we should have jumped from 166 to 163 (then 162, then 157)
        #
        # This could be fixed by replacing `if moved_just_above` with:
        #
        #     let is_foldlvl_bigger_on_previous_line = foldlevel('.') < (line('.') - 1)->foldlevel()
        #     if is_foldlvl_bigger_on_previous_line
        #         if !moved_just_above && is_next_line_foldable
        #             +
        #         endif
        #     elseif moved_just_above
        #
        # But doing  so would break  the motion in  nested folds in  other files
        # (markdown + vim).
        #
        # For the moment, this is an acceptable issue.
        # It only seems to affect a folded  line which is right after the end of
        # a nested fold, and which is not followed by another folded line in the
        # same fold.   IOW, it's an  extremely particular case which  should not
        # bother us in practice.
        #}}}
        # don't be stuck right before a fold start (this issue is due to `:+`)
        if moved_just_above
            NextFold('[z')
            return
        elseif is_fold_start || (is_fold_end && is_next_line_foldable)
            # don't jump on the first line of a fold; just after
            :+
        else
            # `silent!` to suppress `E132` when there are no folds in a Vim file
            NextFold('[z')
            return
        endif

    else

        keepj norm! ]z
        next += [line('.')]
        cursor(orig, 1)
        keepj norm! zj
        next += [line('.')]
        next->filter((_, v: number): bool => v != orig)
        if empty(next)
            return
        endif
        cursor(min(next), 1)

        var is_fold_start: bool = IsFoldStart()
        var is_fold_end: bool = IsFoldEnd()
        var is_previous_line_foldable: bool = (line('.') - 1)->foldlevel() > 0
        var has_end_marker: bool = &l:fdm == 'marker'
            && getline('.') =~ split(&l:fmr, ',')[1] .. '\d*\s*$'
        var moved_just_below: bool = line('.') == orig + 1

        # special case: if we're before the *first* fold, jump right before its start (instead of its end)
        if is_fold_start && !is_previous_line_foldable && !moved_just_below
            :-
        elseif (is_fold_start || has_end_marker) && moved_just_below
            # don't be stuck right before a fold end (this issue is due to `:-`)
            NextFold(']z')
            return
        elseif (is_fold_start || has_end_marker) && is_previous_line_foldable
            # don't jump on the start of a fold – `zj` does that – nor on a line
            # containing closing foldmarkers; move right before
            :-
        elseif !is_fold_end
            NextFold(']z')
            return
        endif

    endif
enddef

def IsFoldStart(): bool
    if foldlevel('.') <= 0
        return false
    endif

    norm! zc
    var is_fold_start: bool = line('.') == foldclosed('.')
    norm! zo

    return is_fold_start
enddef

def IsFoldEnd(): bool
    if foldlevel('.') <= 0
        return false
    endif

    norm! zc
    var is_fold_end: bool = line('.') == foldclosedend('.')
    norm! zo

    return is_fold_end
enddef

def Foldsavestate()
    var pos: list<number> = getcurpos()
    state = {open: [], closed: []}
    folddoclosed state.closed += GetState('closed')
    folddoopen state.open += GetState('open')
    setpos('.', pos)
enddef
var state: dict<list<number>>

def GetState(which_one: string): list<number>
    if which_one == 'closed'
        if line('.') == foldclosed('.')
            return [line('.')]
        endif
    elseif which_one == 'open'
        if foldlevel('.') <= 0
            return []
        endif
        norm! zc
        if line('.') == foldclosed('.')
            return [line('.')]
        endif
        norm! zo
    endif
    return []
enddef

def Foldreststate()
    var pos: list<number> = getcurpos()
    for lnum in state.open
        exe 'norm! ' .. lnum .. 'Gzo'
    endfor
    for lnum in state.closed
        exe 'norm! ' .. lnum .. 'Gzc'
    endfor
    setpos('.', pos)
enddef

def Winrestview(view: dict<number>)
    var pos: list<number> = getcurpos()
    winrestview(view)
    setpos('.', pos)
enddef

