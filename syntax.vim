fun! ListAllSyntax()
	let l:out = []

	for l:line in range(1, line('$'))
		let l:outline = []
		let l:prevgroup = ''
		let l:linelen = len(getline(l:line))
		for l:col in range(1, l:linelen)
			" TODO: Syntax can be stacked; not sure if we want/need to deal with
			" that though.
			let l:group = synIDattr(synID(l:line, l:col, 1), 'name')

			if l:group isnot# l:prevgroup && l:group isnot# ''
				call add(l:outline, [l:group, l:col, -1])
			endif

			if l:group isnot# l:prevgroup || (l:col is l:linelen && l:prevgroup isnot# '')
				let l:outline[len(l:outline) - 1][2] = l:col
			endif

			let l:prevgroup = l:group
		endfor

		call add(l:out, l:outline)
	endfor

	return l:out
endfun

fun! TestSyntax(file, want) abort
    exe 'e ' . fnameescape(a:file)

    let l:want = a:want
    let l:out = ListAllSyntax()

    if len(l:out) != len(l:want)
      call Errorf("out has different line length (%d, want %d)\nout: %s",
            \ len(l:out), len(l:want), l:out)
      return
    endif

    for l:i in range(0, len(l:out) - 1)
        if l:out[l:i] != l:want[l:i]
            call Errorf("line %d wrong\nwant: %s\nout:  %s", l:i, l:want[l:i], l:out[l:i])
        endif
    endfor
endfun
