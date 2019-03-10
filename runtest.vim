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

" Note: this won't error out if the dir exists since Vim 8.0.1708; can remove
" this check at some point.
if !isdirectory(g:test_tmpdir)
	call mkdir(g:test_tmpdir, 'p')
endif

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

" Store all log messages.
let s:logs = []

" Add all :messages to s:logs.
fun! s:log_messages(f) abort
	let l:mess = split(execute('silent messages'), "\n")
	let l:mess = filter(l:mess, { i, v -> l:v !~? '^Messages maintainer' })
	let l:mess = map(l:mess, { i, v -> '        ' . a:f . ': ' . l:v })
	let s:logs += l:mess
	silent messages clear
endfun

" Get a list of all Test_ or Benchmark_ functions.
fun! s:find_fun(pat) abort
	let l:tests = execute('silent function /' . a:pat)
	let l:tests = split(l:tests, "\n")
	let l:tests = filter(l:tests, { i, v -> l:v =~# '^function \k\{-1,}() abort$' })
	let l:tests = map(l:tests, { i, v -> substitute(l:v, 'function \(\k\{-1,}\)() abort', '\1', 'g') })
	return l:tests
endfun

fun! s:run_tests() abort
	" Initialize variables.
	let l:fail = 0
	let l:done = 0

	let l:tests = s:find_fun('^Test_')
	if g:test_run isnot# ''
		let l:tests = filter(l:tests, { i, v -> l:v =~# g:test_run })
	endif

	" Log any messages that we may already accumulated.
	if g:test_verbose
		call s:log_messages('')
	endif

	" Iterate over all tests and execute them.
	for l:test in sort(l:tests)
		let l:started = reltime()
		if g:test_verbose
			call add(s:logs, printf('=== RUN  %s', l:test))
		endif

		try
			call call(l:test, [])
		catch
			let v:errors += [v:exception]
		endtry

		let l:elapsed_time = s:since(l:started)
		let l:done += 1

		if len(v:errors) > 0
			let l:errors = v:errors
			let l:failed = 0

			for l:i in range(len(l:errors))
				let l:err = l:errors[l:i]

				" Log message: add to output but don't fail test.
				if type(l:err) is v:t_list && l:err[0] is# s:log_marker
					let l:errors[l:i] = l:err[1]
				else
					let l:failed = 1
					let l:fail += 1

					" --- FAIL Test_Comment (0.000s)
					call add(s:logs, printf('--- FAIL %s (%ss)', l:test, l:elapsed_time))
				endif
			endfor

			" Add :messages.
			" Note that order between log messages and asserts aren't preserved;
			" no real good way to do that. Writing to v:errors is better.
			call s:log_messages(l:test)

			" Remove function name from start of errors and indent.
			let l:errors = map(l:errors,
				\ {i, v -> substitute(l:v, '^function ' . l:test . ' ', '', '')})
			
			" Support messages with newlines.
			let l:experr = []
			for l:err in l:errors
				call extend(l:experr, map(split(l:err, "\n"),
							\ {i, v -> repeat(' ', 10) . l:v}))
			endfor

			call extend(s:logs, l:experr)

			if l:failed
				call add(s:logs, 'FAIL')
			endif

			" Reset so we can capture failures of the next test.
			let v:errors = []
		else
			if g:test_verbose
				call add(s:logs, printf('--- PASS %s (%ss)', l:test, l:elapsed_time))
			endif
		endif

		if g:test_verbose
			call s:log_messages(l:test)
		endif
	endfor  " for l:test in sort(l:tests)

	" Create an empty fail to indicate that at least one test failed.
	if l:fail > 0
		exe printf('split %s/FAILED', fnameescape(s:tmp))
		silent write
	endif

	call s:log_messages('')

	let l:total_elapsed_time = s:since(s:total_started)
	call add(s:logs, printf('%s %s %s  %s tests  %ss',
			\ (l:fail > 0 ? 'FAIL' : 'ok  '),
			\ s:testfile,
			\ repeat(' ', 25 - len(s:testfile)),
			\ l:done, l:total_elapsed_time))
	if len(l:tests) is 0
		let s:logs[len(s:logs) - 1] .= ' [no tests to run]'
	endif

	" Don't need to write logs if we're going to run benchmarks.
	if g:test_bench isnot# '' && l:fail is 0 && !g:test_verbose
		let s:logs = []
	endif

	call s:write_logs()

	return l:fail is 0
endfun

fun! s:write_logs() abort
	silent! exe printf('split %s/test.tmp', fnameescape(s:tmp))
	call setline(1, s:logs)
	if !g:test_verbose
		silent :g/^$/d
	endif

	" Don't write with newline, so we can add coverage data in the shell script.
	setlocal noendofline nofixeol
	silent! write
endfun

fun! s:run_benchmarks() abort
	let l:tests = s:find_fun('^Benchmark_')
	if g:test_run isnot# ''
		let l:tests = filter(l:tests, { i, v -> l:v =~# g:test_bench })
	endif

	let g:bench_n = 100000
	for l:test in l:tests
		let l:started = reltime()
		try
			call call(l:test, [])
		catch
			let v:errors += [v:exception]
		endtry

		let l:elapsed_time = s:since(l:started)

		call s:log_messages(l:test)
		call add(s:logs, printf('%s%s %ss',
					\ l:test, repeat(' ', 32 - len(l:test)),
					\ l:elapsed_time))
	endfor

	call s:write_logs()
endfun

" Run all tests in this file.
if s:run_tests() && g:test_bench isnot# ''
	call s:run_benchmarks()
endif

qall!
