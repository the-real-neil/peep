## Process this file with automake to produce Makefile.in

AUTOMAKE_OPTIONS = 1.0 foreign dist-zip

PACKAGE = peep
VERSION = 0.5.0-rc2

SUBDIRS = server

docdir = $(prefix)/doc/$(PACKAGE)-$(VERSION)
doc_DATA = COPYING CHANGELOG INSTALL README TODO

EXTRA_DIST= \
	$(doc_DATA)

DISTCLEANFILES= server/peep.conf

# Defines for the sound data
share = $(prefix)/share/$(PACKAGE)/$(sounddir)
sounddir = sounds

includes:

make-install-dirs:
	-if test '!' -d $(share); then mkdir -p $(share); fi

install-doc:
	tar cf - docs | (cd $(docdir); tar xf -)

install-data-hook: make-install-dirs install-doc
	@echo
	@echo ==========================================================
	@echo Installing shared sound data in $(prefix)/share/$(PACKAGE).
	@echo Use these sounds when configuring your peep.conf.
	@echo
	-for thing in `find $(sounddir)`; do \
		if test -d $$thing && test ! -d $(prefix)/share/$(PACKAGE)/$$thing; then \
			mkdir -m 755 $(prefix)/share/$(PACKAGE)/$$thing; \
		elif test -f $$thing && test ! -e $(prefix)/share/$(PACKAGE)/$$thing; then \
			$(INSTALL_DATA) $$thing $(prefix)/share/$(PACKAGE)/$$thing; \
		fi \
	done

uninstall:
	@echo Removing sound data dir: $(share);
	-if test -d $(share); then rm -rf $(prefix)/share/$(PACKAGE); fi

serverdoc = $(distdir)/docs/server
clientdoc = $(distdir)/docs/client

dist-hook:
	mkdir $(distdir)/client
	cp -r -p client/* $(distdir)/client
	mkdir $(distdir)/docs
	cp -r -p docs/* $(distdir)/docs
	mkdir $(distdir)/conf
	cp -r -p conf/* $(distdir)/conf
	latex2html=`which latex2html`
	if test $$?; then \
		cd $(serverdoc); latex2html *.tex; mv *.gif peep-server; \
		mv latex_gifs/* peep-server/; rmdir latex_gifs; \
		perl -i -ape 's|file:/usr/local/share/lib/latex2html/icons|.|' peep-server/*.html; \
	fi
	if test -x $(clientdoc)/make-client-documentation; then \
		cd $(clientdoc); ./make-client-documentation; \
	fi
