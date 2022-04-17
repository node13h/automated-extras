SHELL = bash

PROJECT := automated-extras

SEMVER_RE := ^([0-9]+.[0-9]+.[0-9]+)(-([0-9A-Za-z.-]+))?(\+([0-9A-Za-z.-]))?$
VERSION := $(shell cat VERSION)
VERSION_PRE := $(shell [[ "$(VERSION)" =~ $(SEMVER_RE) ]] && printf '%s\n' "$${BASH_REMATCH[3]:-}")

PKG_VERSION := $(shell [[ "$(VERSION)" =~ $(SEMVER_RE) ]] && printf '%s\n' "$${BASH_REMATCH[1]}")
ifdef VERSION_PRE
PKG_RELEASE := 1.$(VERSION_PRE)
else
PKG_RELEASE := 1
endif

BINTRAY_RPM_PATH := alikov/rpm/$(PROJECT)/$(PKG_VERSION)
BINTRAY_DEB_PATH := alikov/deb/$(PROJECT)/$(PKG_VERSION)

PREFIX := /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib
SHAREDIR = $(PREFIX)/share
DOCSDIR = $(SHAREDIR)/doc
MANDIR = $(SHAREDIR)/man

SDIST_TARBALL := sdist/$(PROJECT)-$(VERSION).tar.gz
SDIST_DIR = $(PROJECT)-$(VERSION)
SPEC_FILE := $(PROJECT).spec
RPM_PACKAGE := bdist/noarch/$(PROJECT)-$(PKG_VERSION)-$(PKG_RELEASE).noarch.rpm
DEB_PACKAGE := bdist/$(PROJECT)_$(VERSION)_all.deb

.PHONY: install build clean release-start release-finish uninstall release sdist rpm publish-rpm deb publish-deb publish

all: build

clean:
	rm -f automated-extras-config.sh
	rm -f lib/automated-extras-config.sh
	rm -rf bdist sdist

automated-extras-config.sh: automated-extras-config.sh.in VERSION
	sed -e 's~@LIBDIR@~$(LIBDIR)/automated-extras~g' -e 's~@VERSION@~$(VERSION)~g' automated-extras-config.sh.in >automated-extras-config.sh

lib/automated-extras.sh: lib/automated-extras.sh.in
	sed -e 's~@VERSION@~$(VERSION)~g' lib/automated-extras.sh.in >lib/automated-extras.sh

build: automated-extras-config.sh lib/automated-extras.sh

install: build
	install -m 0755 -d $(DESTDIR)$(BINDIR)
	install -m 0755 -d $(DESTDIR)$(LIBDIR)/automated-extras
	install -m 0755 -d $(DESTDIR)$(DOCSDIR)/automated-extras
	install -m 0755 automated-extras-config.sh $(DESTDIR)$(BINDIR)
	install -m 0644 lib/*.sh $(DESTDIR)$(LIBDIR)/automated-extras
	install -m 0644 README.* $(DESTDIR)$(DOCSDIR)/automated-extras

uninstall:
	rm -f -- $(DESTDIR)$(BINDIR)/automated-extras-config.sh
	rm -rf -- $(DESTDIR)$(LIBDIR)/automated-extras
	rm -rf -- $(DESTDIR)$(DOCSDIR)/automated-extras

release-start:
	bash release.sh start

release-finish:
	bash release.sh finish

release: release-start release-finish

$(SDIST_TARBALL):
	mkdir -p sdist; \
	tar --transform 's~^~$(SDIST_DIR)/~' \
	    --exclude .git \
	    --exclude sdist \
	    --exclude bdist \
	    --exclude '*~' \
	    -czf $(SDIST_TARBALL) \
	    *

sdist: $(SDIST_TARBALL)

$(RPM_PACKAGE): PREFIX := /usr
$(RPM_PACKAGE): $(SDIST_TARBALL)
	mkdir -p bdist; \
	rpmbuild -ba "$(SPEC_FILE)" \
	  --define rpm_version\ $(PKG_VERSION) \
	  --define rpm_release\ $(PKG_RELEASE) \
	  --define sdist_dir\ $(SDIST_DIR) \
	  --define sdist_tarball\ $(SDIST_TARBALL) \
	  --define prefix\ $(PREFIX) \
	  --define _srcrpmdir\ sdist/ \
	  --define _rpmdir\ bdist/ \
	  --define _sourcedir\ $(CURDIR)/sdist \
	  --define _bindir\ $(BINDIR) \
	  --define _libdir\ $(LIBDIR) \
	  --define _defaultdocdir\ $(DOCSDIR) \
	  --define _mandir\ $(MANDIR)

rpm: $(RPM_PACKAGE)

control: control.in VERSION
	sed -e 's~@VERSION@~$(VERSION)~g' control.in >control

$(DEB_PACKAGE): control $(SDIST_TARBALL)
	mkdir -p bdist; \
	target=$$(mktemp -d); \
	mkdir -p "$${target}/DEBIAN"; \
	cp control "$${target}/DEBIAN/control"; \
	tar -C sdist -xzf $(SDIST_TARBALL); \
	make -C sdist/$(SDIST_DIR) DESTDIR="$$target" PREFIX=/usr install; \
	dpkg-deb --build "$$target" $(DEB_PACKAGE); \
	rm -rf -- "$$target"

deb: $(DEB_PACKAGE)

publish-rpm: rpm
	jfrog bt upload --publish=true $(RPM_PACKAGE) $(BINTRAY_RPM_PATH)

publish-deb: deb
	jfrog bt upload --publish=true --deb xenial/main/all $(DEB_PACKAGE) $(BINTRAY_DEB_PATH)

publish: publish-rpm publish-deb
