include @top_srcdir@/oracc-doc-rules.txt

SUBDIRS = 

all-local:
	perl $(top_srcdir)/misc/xdf/xdfmanager.plx -prefix $(top_srcdir)

clean-local:
	rm -fr html

install-data-local:
	$(top_srcdir)/oracc-doc-install.sh $(DESTDIR)$(prefix) $(top_srcdir)

EXTRA_DIST = \
	starting.xdf \
	etc/rest-hello.png \
	etc/rest-test-oml-P108301-xmd.png \
	etc/rest-top.png
