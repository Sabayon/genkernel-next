PACKAGE_VERSION = `/bin/fgrep GK_V= genkernel | sed "s/.*GK_V='\([^']\+\)'/\1/"`

genkernel.8: doc/genkernel.8.txt doc/asciidoc.conf Makefile
	a2x --conf-file=doc/asciidoc.conf --attribute="genkernelversion=$(PACKAGE_VERSION)" \
		 --format=manpage -D . "$<"

clean:
	rm -f genkernel.8
