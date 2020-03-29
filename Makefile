# USER-SETTABLE VARIABLES
#
# The following variables can be overridden by user (i.e.,
# make install DESTDIR=/tmp/xxx):
#
#   Name     Default                  Description
#   ----     -------                  -----------
#   DESTDIR                           Destination directory for make install
#   PREFIX       	              Non-standard: appended to DESTDIR
#   CC       gcc                      C compiler
#   CPPFLAGS                          C preprocessor flags
#   CFLAGS   -O2 -g -W -Wall -Werror  C compiler flags
#   LDFLAGS                           Linker flags
#   COMPRESS gzip                     Program to compress man page, or ""
#   MANDIR   /usr/share/man/          Where to install man page

CC = gcc
COMPRESS = gzip
CFLAGS = -Og -g -W -Wall
MANDIR = /usr/share/man/
PKG_CONFIG = /usr/bin/pkg-config

# These variables are not intended to be user-settable
CONFDIR = /etc/sane.d
LIBDIR := $(shell $(PKG_CONFIG) --variable=libdir sane-backends)
BACKEND = libsane-airscan.so.1
MANPAGE = sane-airscan.5

SRC = \
	airscan.c \
	airscan-array.c \
	airscan-conf.c \
	airscan-devcaps.c \
	airscan-device.c \
	airscan-devops.c \
	airscan-eloop.c \
	airscan-http.c \
	airscan-jpeg.c \
	airscan-log.c \
	airscan-math.c \
	airscan-opt.c \
	airscan-pollable.c \
	airscan-trace.c \
	airscan-xml.c \
	airscan-zeroconf.c \
	sane_strstatus.c

HDR = \
	airscan.h \
	airscan-version.h

OBJS = $(SRC:.c=.o)

airscan_pkgconf_deps := \
	avahi-client \
	avahi-glib \
	libjpeg \
	libsoup-2.4

# Obtain CFLAGS for objects creation
airscan_CFLAGS += -fPIC
airscan_CFLAGS += $(foreach dep,$(airscan_pkgconf_deps),`pkg-config --cflags $(dep)`)

# Obtain LDFLAGS for library creation
airscan_LDLAGS += $(foreach dep,$(airscan_pkgconf_deps),`pkg-config --libs $(dep)`)

# Merge DESTDIR and PREFIX
PREFIX := $(abspath $(DESTDIR)/$(PREFIX))
ifeq ($(PREFIX),/)
	PREFIX :=
endif

# This magic is a workaround for libsoup bug.
#
# We are linked against libsoup. If SANE backend goes unloaded
# from the memory, all libraries it is linked against also will
# be unloaded (unless main program uses them directly).
#
# Libsoup, unfortunately, doesn't unload correctly, leaving its
# types registered in GLIB. Which sooner or later leads program to
# crash
#
# The workaround is to prevent our backend's shared object from being
# unloaded when not longer in use, and these magical options do it
# by adding NODELETE flag to the resulting ELF shared object
airscan_LDFLAGS += -Wl,-z,nodelete

all: tags $(BACKEND) airscan-test

tags: Makefile $(SRC) $(HDR)
	echo $(SRC)
	-ctags -R .

$(BACKEND): LDFLAGS += $(airscan_LDLAGS)
$(BACKEND): Makefile $(OBJS) airscan.sym
	$(CC) -o $(BACKEND) -shared $(OBJS) -Wl,--version-script=airscan.sym $(LDFLAGS)

airscan-test: airscan-test.c $(BACKEND)
	$(CC) -o $@ $^ -Wl,-rpath . ${airscan_CFLAGS}

$(OBJS): CFLAGS += $(airscan_CFLAGS)
$(OBJS): Makefile $(HDR)

# generate a vesion file from GIT information for devs
# for source packages, the .git dir is stripped, so let the opportunity
# to ship the sources package with a static .version bundled that would
# contain the correct version label
define update_version_header
	printf "#ifndef AIRSCAN_VERSION_H\n#define AIRSCAN_VERSION_H\n\n#define AIRSCAN_VERSION \"%s\"\n\n#endif\n" \
		"$(1)" > airscan-version.h.tmp; \
	if ! cmp airscan-version.h airscan-version.h.tmp >/dev/null 2>&1; then \
		cp airscan-version.h.tmp airscan-version.h ; \
	fi ; \
	rm -f airscan-version.h.tmp
endef

airscan-version.h: Makefile
	if [ -f .version ] ; then \
		$(call update_airscan_version,$(shell cat .version)); \
	elif [ -d .git ] ; then \
		$(call update_airscan_version,$(shell git describe --tags --always --dirty)); \
	else \
		$(call update_airscan_version,unknown); \
	fi
.PHONY: airscan-version.h

install: all
	mkdir -p $(PREFIX)$(CONFDIR)
	mkdir -p $(PREFIX)$(CONFDIR)/dll.d
	cp -n airscan.conf $(PREFIX)$(CONFDIR)
	cp -n dll.conf $(PREFIX)$(CONFDIR)/dll.d/airscan
	install -s -D -t $(PREFIX)$(LIBDIR)/sane $(BACKEND)
	mkdir -p $(PREFIX)/$(MANDIR)/man5
	install -m 644 -D -t $(PREFIX)$(MANDIR)/man5 $(MANPAGE)
	[ "$(COMPRESS)" = "" ] || $(COMPRESS) -f $(PREFIX)$(MANDIR)/man5/$(MANPAGE)
.PHONY: install

clean:
	rm -f airscan-test $(BACKEND) $(OBJS) airscan-version.h tags
.PHONY: clean
