SHELL = bash

PROJECT := automated-extras

SEMVER_RE := ^([0-9]+.[0-9]+.[0-9]+)(-([0-9A-Za-z.-]+))?(\+([0-9A-Za-z.-]))?$
VERSION := $(shell cat VERSION)

PKG_VERSION := $(shell [[ "$(VERSION)" =~ $(SEMVER_RE) ]] && printf '%s\n' "$${BASH_REMATCH[1]}")

BINTRAY_DEB_PATH := alikov/deb/$(PROJECT)/$(PKG_VERSION)

PREFIX := /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib
SHAREDIR = $(PREFIX)/share
DOCSDIR = $(SHAREDIR)/doc
MANDIR = $(SHAREDIR)/man

SDIST_TARBALL := sdist/$(PROJECT)-$(VERSION).tar.gz
SDIST_DIR = $(PROJECT)-$(VERSION)
DEB_PACKAGE := bdist/$(PROJECT)_$(VERSION)_all.deb

.PHONY: install build clean uninstall release sdist rpm deb publish-deb publish

all: build

clean:
	rm -f automated-extras-config.sh
	rm -rf bdist sdist

automated-extras-config.sh: automated-extras-config.sh.in VERSION
	sed -e 's~@LIBDIR@~$(LIBDIR)/automated-extras~g' \
	    -e 's~@VERSION@~$(VERSION)~g' automated-extras-config.sh.in >automated-extras-config.sh

build: automated-extras-config.sh

install: build
	install -m 0755 -d "$(DESTDIR)$(BINDIR)"
	install -m 0755 -d "$(DESTDIR)$(LIBDIR)/automated-extras"
	install -m 0755 -d "$(DESTDIR)$(DOCSDIR)/automated-extras"
	install -m 0755 automated-extras-config.sh "$(DESTDIR)$(BINDIR)"
	install -m 0644 lib/*.sh "$(DESTDIR)$(LIBDIR)/automated-extras"
	install -m 0644 README.* "$(DESTDIR)$(DOCSDIR)/automated-extras"

uninstall:
	rm -rf -- "$(DESTDIR)$(LIBDIR)/automated-extras"
	rm -rf -- "$(DESTDIR)$(DOCSDIR)/automated-extras"

release:
	git tag $(VERSION)

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

rpm: PREFIX := /usr
rpm: sdist
	mkdir -p bdist; \
	rpm_version=$$(cut -f 1 -d '-' <<< "$(VERSION)"); \
	rpm_release=$$(cut -s -f 2 -d '-' <<< "$(VERSION)"); \
	sourcedir=$$(readlink -f sdist); \
	rpmbuild -ba "automated-extras.spec" \
		--define "rpm_version $${rpm_version}" \
		--define "rpm_release $${rpm_release:-1}" \
		--define "full_version $(VERSION)" \
		--define "prefix $(PREFIX)" \
		--define "_srcrpmdir sdist/" \
		--define "_rpmdir bdist/" \
		--define "_sourcedir $${sourcedir}" \
		--define "_bindir $(BINDIR)" \
		--define "_libdir $(LIBDIR)" \
		--define "_defaultdocdir $(DOCSDIR)"

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

publish-deb: deb
	jfrog bt upload --publish=true --deb xenial/main/all $(DEB_PACKAGE) $(BINTRAY_DEB_PATH)

publish: publish-deb
