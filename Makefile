PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
SYSCONFDIR ?= /etc
DESTDIR ?= 
VERSION ?= 
distdir = genkernel-next-$(VERSION)

# Add off-Git/generated files here that need to be shipped with releases
EXTRA_DIST = genkernel.8

default: genkernel.8

genkernel.8: doc/genkernel.8.txt doc/asciidoc.conf Makefile genkernel
	a2x --conf-file=doc/asciidoc.conf --attribute="genkernelversion=$(VERSION)" \
		 --format=manpage -D . "$<"

install: default

	install -d $(DESTDIR)/$(SYSCONFDIR)
	install -m 644 genkernel.conf $(DESTDIR)/$(SYSCONFDIR)/

	install -d $(DESTDIR)/$(BINDIR)
	install -m 755 genkernel $(DESTDIR)/$(BINDIR)/

	install -d $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 gen_arch.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 gen_bootloader.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 gen_cmdline.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 gen_compile.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 gen_configkernel.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 gen_determineargs.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 gen_funcs.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 gen_initramfs.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 gen_moddeps.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 gen_package.sh $(DESTDIR)/$(PREFIX)/share/genkernel

	install -m 644 initramfs.mounts $(DESTDIR)/$(SYSCONFDIR)/

	cp -rp arch $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp defaults $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp modules $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp netboot $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp patches $(DESTDIR)/$(PREFIX)/share/genkernel/

	install -d $(DESTDIR)/var/lib/genkernel/src
	install -m 644 tarballs/* $(DESTDIR)/var/lib/genkernel/src/

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

.PHONY: clean check-git-repository dist default install
