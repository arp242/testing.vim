testing.vim is a small testing framework for Vim.

I originally implemented this for vim-go, based on Fatih's previous work (see
[1157][1157], [1158][1158], and [1476][1476]), which was presumably inspired by
[runtest.vim](https://github.com/vim/vim/blob/master/src/testdir/runtest.vim) in
the Vim source code repository.

The design is loosely inspired by Go's `testing` package.

My philosophy of testing is that it should be kept as simple as feasible;
programming is already hard enough without struggling with a poorly documented
unintuitive testing framework. This is what makes testing.vim different from
some other testing Vim runners/frameworks.

testing.vim includes support for code coverage reports (via [covimerage][cov]).

Usage
-----

Tests are stored in a `*_test.vim` files, all functions matching the
`Test_\k+() abort` signature will be run.
It is customary – but not mandatory – to store `n_test.vim` files next to the
`n.vim` file in the same directory.

testing.vim exposes several variables:

- `g:test_verbose`  – `-v` flag from commandline (`0` or `1`).
- `g:test_run`      – `-r` flag from commandline.
- `g:test_dir`      – Directory of the test file that's being run.
- `g:test_tmpdir`   – Temporary directory; will be empty and `:cd`'d to for
                      every test.

And a few functions:

- `Error(msg)`       – Add a message to `v:errors`.
- `Errorf(msg, ...)` – Like `Error()`, but with `printf()` support.
- `Log(msg)`         – Add a "log message" in `v:errors`; this won't fail the
                       test. This is useful as `echom` and `v:errors` output
					   isn't interleaved.
- `Logf(msg, ...)`   – Like Log, with with `print()` support,.


Run `./test /path/to/file_test.vim` to run test in that file, `./test
/path/to/dir` to run all test files in a directory, or `./test/path/to/dir/...`
to run al test files in a directory and all subdirectories.

A test is considered to be "failed" when `v:errors` has any items. Vim's
`assert_*` functions write to this, and it can also be written to as a regular
list (for logging, or writing your own testing logic).

You can filter test functions with the `-r` option. See `./test -h` for various
other options.

testing.vim will always use the `vim` from `PATH` to run tests; prepend a
different PATH to run a different `vim`. For testing in CI environments (Travis,
CircleCI, etc.) I recommend [vim-testbed][testbed].

### Syntax highlighting benchmarks

There is also a small script to benchmark syntax highlighting:

	./bench-syntax file.go:666

[testbed]: https://github.com/tweekmonster/vim-testbed
[cov]: https://github.com/Vimjas/covimerage
[1476]: https://github.com/fatih/vim-go/pull/1476
[1157]: https://github.com/fatih/vim-go/pull/1157
[1158]: https://github.com/fatih/vim-go/pull/1158
