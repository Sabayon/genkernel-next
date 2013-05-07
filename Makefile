VERSION ?= 
distdir = genkernel-next-$(VERSION)

# Add off-Git/generated files here that need to be shipped with releases
EXTRA_DIST = genkernel.8

genkernel.8: doc/genkernel.8.txt doc/asciidoc.conf Makefile genkernel
	a2x --conf-file=doc/asciidoc.conf --attribute="genkernelversion=$(VERSION)" \
		 --format=manpage -D . "$<"

clean:
	rm -f $(EXTRA_DIST)

check-git-repository:
	git diff --quiet || { echo 'STOP, you have uncommitted changes in the working directory' ; false ; }
	git diff --cached --quiet || { echo 'STOP, you have uncommitted changes in the index' ; false ; }

dist: check-git-repository $(EXTRA_DIST)
	test -n "$(VERSION)" || { echo "VERSION not set" >&2; exit 1; }
	git archive --prefix=$(distdir)/ --format=tar "v$(VERSION)" > $(distdir).tar
	rm -f $(distdir).tar.xz
	xz $(distdir).tar
	scp $(distdir).tar.xz lxnay@dev.gentoo.org:~/public_html/genkernel-next/

.PHONY: clean check-git-repository dist
