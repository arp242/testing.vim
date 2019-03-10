" vint: -ProhibitSetNoCompatible
set nocompatible nomore shellslash encoding=utf-8 shortmess+=WIF
lang mess C

filetype plugin indent on
syntax on

let s:path = fnamemodify(bufname(''), ':.')
let s:fname = fnamemodify(bufname(''), ':t:r')
let s:lines = ListAllSyntax()

silent! exe printf('split %s/syntax.tmp', fnameescape(g:test_tmpdir))
call append('$', [
			\ '',
			\ printf('fun! Test_%s() abort', s:fname), 
			\ printf('    call TestSyntax(g:test_packdir . "/%s",', s:path),
			\ '        \ [',
	\ ])

for s:line in s:lines
	call append('$', printf('        \ %s,', s:line))
endfor
call append('$', ['    \ ])', 'endfun'])

silent! write
qa!
