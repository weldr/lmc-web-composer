PYTHON ?= /usr/bin/python3
DESTDIR ?= /

PKGNAME = lorax
VERSION = $(shell awk '/Version:/ { print $$2 }' $(PKGNAME).spec)
RELEASE = $(shell awk '/Release:/ { print $$2 }' $(PKGNAME).spec | sed -e 's|%.*$$||g')
TAG = lorax-$(VERSION)-$(RELEASE)


default: all

src/pylorax/version.py: lorax.spec
	echo "num = '$(VERSION)-$(RELEASE)'" > src/pylorax/version.py

all: src/pylorax/version.py
	$(PYTHON) setup.py build

install: all
	$(PYTHON) setup.py install --root=$(DESTDIR)
	mkdir -p $(DESTDIR)/$(mandir)/man1
	install -m 644 docs/man/lorax.1 $(DESTDIR)/$(mandir)/man1
	install -m 644 docs/man/livemedia-creator.1 $(DESTDIR)/$(mandir)/man1

check:
	@echo "*** Running pylint ***"
	PYTHONPATH=$(PYTHONPATH):./src/ ./tests/pylint/runpylint.py

clean:
	-rm -rf build src/pylorax/version.py

tag:
	git tag -f $(TAG)

docs:
	$(MAKE) -C docs apidoc

archive:
	@git archive --format=tar --prefix=$(PKGNAME)-$(VERSION)/ $(TAG) > $(PKGNAME)-$(VERSION).tar
	@gzip $(PKGNAME)-$(VERSION).tar
	@echo "The archive is in $(PKGNAME)-$(VERSION).tar.gz"

dist: tag archive
	scp $(PKGNAME)-$(VERSION).tar.gz fedorahosted.org:lorax

local:
	@rm -rf $(PKGNAME)-$(VERSION).tar.gz
	@rm -rf /var/tmp/$(PKGNAME)-$(VERSION)
	@dir=$$PWD; cp -a $$dir /var/tmp/$(PKGNAME)-$(VERSION)
	@rm -rf /var/tmp/$(PKGNAME)-$(VERSION)/.git
	@dir=$$PWD; cd /var/tmp; tar --gzip -cSpf $$dir/$(PKGNAME)-$(VERSION).tar.gz $(PKGNAME)-$(VERSION)
	@rm -rf /var/tmp/$(PKGNAME)-$(VERSION)
	@echo "The archive is in $(PKGNAME)-$(VERSION).tar.gz"

ci:
	@sudo docker build -t composer-test .
	@sudo docker run --rm -e "top_srcdir=/root/lmc-composer-demo/src" --entrypoint make composer-test -C /root/lmc-composer-demo check
