# provii - provisioning utility for portable, binary cli tools 

srcdir:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
prefix = /usr/local

bindir = $(prefix)/bin
mandir = $(prefix)/man
datadir = $(prefix)/share
all: install

install: all 
	@echo "Installing provii (iinst)"
	@if [ -f $(bindir)/provii ]; then rm $(bindir)/provii; fi
	@if [ -f $(bindir)/iinst ]; then rm $(bindir)/iinst; fi
	@chmod 755 $(srcdir)/provii
	@ln -sf $(srcdir)/provii $(bindir)/provii
	@ln -sf $(srcdir)/provii $(bindir)/iinst

uninstall:
	@echo "Uninstalling provii"
	@if [ -f $(bindir)/iinst ]; then rm $(bindir)/iinst; fi
	@if [ -f $(bindir)/provii ]; then rm $(bindir)/provii; fi

