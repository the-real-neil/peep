## Process this file with automake to produce Makefile.in

# AUTOMAKE_OPTIONS = 1.0 foreign dist-zip

# PACKAGE = peep
# VERSION = 0.5.0-rc2

# SUBDIRS = server

bin_PROGRAMS=peepd
peepd_SOURCES= \
	server/alsa.c \
	server/cmdline.c \
	server/cmdline.h \
	server/copyright.h \
	server/debug.c \
	server/debug.h \
	server/engine.c \
	server/engine.h \
	server/engine_queue.c \
	server/engine_queue.h \
	server/main.c \
	server/main.h \
	server/mixer.c \
	server/mixer.h \
	server/mixer_queue.c \
	server/mixer_queue.h \
	server/notice.c \
	server/notice.h \
	server/oss.c \
	server/parser.c \
	server/parser.h \
	server/playback.c \
	server/playback.h \
	server/server.c \
	server/server.h \
	server/sound.h \
	server/ssl_server.c \
	server/ssl_server.h \
	server/tcp_server.c \
	server/tcp_server.h \
	server/thread.c \
	server/thread.h \
	server/udp_server.c \
	server/udp_server.h \
	server/xml.c \
	server/xml.h \
	server/xml_notice.c \
	server/xml_notice.h \
	server/xml_theme.c \
	server/xml_theme.h

etc = /etc


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
