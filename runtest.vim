" Make sure some options are set to sane defaults and output all messages in
" English.
" vint: -ProhibitSetNoCompatible
set nocompatible nomore noshowmode viminfo= shellslash encoding=utf-8 shortmess+=WIF
lang mess C

" Make sure the test file won't get modified; can happen on bugs in this script.
setl nomodifiable

" Make sure people aren't running an ancient Vim.
if v:version < 704 || (v:version is 704 && !has('patch2009'))
	silent! exe printf('split %s/test.tmp', fnameescape(g:test_tmpdir))
	call setline(1, 'testing.vim requires Vim 7.4.2009 or Neovim 0.2.0')
	w
	cquit!
endif

" Options from arguments.
let g:test_verbose = get(g:, 'test_verbose', 0)
let s:tmp          = g:test_tmpdir
let g:test_tmpdir  = s:tmp . '/tmp'

call mkdir(g:test_tmpdir, 'p')

" Helper functions available in tests.
let s:log_marker = '__TEST_LOG__'
fun! Error(msg) abort
	let v:errors = add(v:errors, a:msg)
endfun
fun! Errorf(msg, ...) abort
	let v:errors = add(v:errors, call('printf', [a:msg] + a:000))
endfun
fun! Log(msg) abort
	let v:errors = add(v:errors, [s:log_marker, a:msg])
endfun
fun! Logf(msg, ...) abort
	let v:errors = add(v:errors, [s:log_marker, call('printf', [a:msg] + a:000)])
endfun

" Initialize variables.
let s:fail = 0
let s:done = 0
let s:logs = []

" Add all messages (usually errors).
fun! s:logmessages(f) abort
	let l:mess = split(execute('silent messages'), "\n")
	let l:mess = filter(l:mess, { i, v -> l:v !~? '^Messages maintainer' })
	let l:mess = map(l:mess, { i, v -> '        ' . a:f . ': ' . l:v })
	let s:logs += l:mess
	silent messages clear
endfun

" Format time elapsed since start.
fun! s:since(start) abort
	return substitute(reltimestr(reltime(a:start)), '\v^\s*(\d+\.\d{0,3}).*', '\1', '')
endfun

" Source the passed test file.
let s:total_started = reltime()
source %

" cd into the dir of the test file.
let s:testfile = substitute(expand('%'), '^\./\?', '', '')
let g:test_dir = expand('%:p:h') 

execute 'cd ' . fnameescape(g:test_tmpdir)

" Get a list of all Test_ functions for the given file.
let s:tests = execute('silent function /^Test_')
let s:tests = split(s:tests, "\n")
let s:tests = filter(s:tests, { i, v -> l:v =~# '^function \k\{-1,}() abort$' })
let s:tests = map(s:tests, { i, v -> substitute(l:v, 'function \(\k\{-1,}\)() abort', '\1', 'g') })
if g:test_run isnot# ''
	let s:tests = filter(s:tests, { i, v -> l:v =~# g:test_run })
endif

" Log any messages that we may already accumulated.
if g:test_verbose
	call s:logmessages('')
endif

" Iterate over all tests and execute them.
for s:test in sort(s:tests)
	let s:started = reltime()
	if g:test_verbose
		call add(s:logs, printf('=== RUN  %s', s:test))
	endif

	try
		call call(s:test, [])
	catch
		let v:errors += [v:exception]
	endtry

	let s:elapsed_time = s:since(s:started)
	let s:done += 1

	if len(v:errors) > 0
		let s:errors = v:errors

		let s:failed = 0

		for s:i in range(len(s:errors))
			let s:err = s:errors[s:i]

			" Log message; add to output but don't fail test.
			if type(s:err) is v:t_list && s:err[0] is# s:log_marker
				let s:errors[s:i] = s:err[1]
			else
				let s:failed = 1
				" --- FAIL Test_Comment (0.000s)
				call add(s:logs, printf('--- FAIL %s (%ss)', s:test, s:elapsed_time))
			endif
		endfor

		if s:failed
			let s:fail += 1
		endif

		" Add :messages.
		" Note that order between log messages and asserts aren't preserved; no
		" real good way to do that. Writing to v:errors is probably better.
		call s:logmessages(s:test)

		" Remove function name from start of errors and indent.
		call extend(s:logs, map(s:errors, {
					\ i, v -> '        ' . substitute(l:v, '^function ' . s:test . ' ', '', '')
					\ }))
		if s:failed
			call add(s:logs, 'FAIL')
		endif

		" Reset so we can capture failures of the next test.
		let v:errors = []
	else
		if g:test_verbose
			call add(s:logs, printf('--- PASS %s (%ss)', s:test, s:elapsed_time))
		endif
	endif

	if g:test_verbose
		call s:logmessages(s:test)
	endif
endfor

" Create an empty fail to indicate that at least one test failed.
if s:fail > 0
	exe printf('split %s/FAILED', fnameescape(s:tmp))
	silent write
endif

let s:total_elapsed_time = s:since(s:total_started)

" Store all internal messages from s:logs as well.
silent! exe printf('split %s/test.tmp', fnameescape(s:tmp))
call setline(1, s:logs)
call append(line('$'), printf('%s %s %s  %s tests  %ss',
		\ (s:fail > 0 ? 'FAIL' : 'ok  '),
		\ s:testfile,
		\ repeat(' ', 25 - len(s:testfile)),
		\ s:done, s:total_elapsed_time))
if len(s:tests) is 0
	call setline(line('$'), getline('$') . ' [no tests to run]')
endif
if !g:test_verbose
	silent :g/^$/d
endif

" Don't write with newline, so we can add coverage data in the shell script.
setlocal noendofline nofixeol
silent! write

" Our work here is done.
qall!
