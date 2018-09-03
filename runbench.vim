" vint: -ProhibitSetNoCompatible
set nocompatible nomore shellslash encoding=utf-8 shortmess+=WIF
lang mess C

filetype plugin indent on
syntax on

syntime on
redraw!
let s:report = execute('syntime report')
execute ':e ' . fnameescape($RUNBENCH_OUT)
call setline('.', split(s:report, '\n'))
wq
