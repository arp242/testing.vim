PREFIX?=/usr/local

all:

install:
	mkdir -p ${PREFIX}/share/tvim ${PREFIX}/bin

	cp tvim.vim ${PREFIX}/share/tvim/
	chmod 644   ${PREFIX}/share/tvim/tvim.vim

	sed 's!^prefix=.*!prefix="${PREFIX}/share/tvim"!' tvim > ${PREFIX}/bin/tvim
	chmod 755 ${PREFIX}/bin/tvim

uninstall:
	rm ${PREFIX}/share/tvim/tvim.vim ${PREFIX}/bin/tvim
	rmdir ${PREFIX}/share/tvim
