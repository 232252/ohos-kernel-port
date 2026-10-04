# A stand-in for a kernel tree, just large enough to exercise the config path.
VERSION = 6
PATCHLEVEL = 6
SUBLEVEL = 101
EXTRAVERSION =
NAME = Test

ARCH ?= arm64

.PHONY: all olddefconfig kernelversion prepare
all:
	@:

olddefconfig:
	@# Stand in for kconfig: record that we ran, and leave .config alone.
	@echo "olddefconfig ran (ARCH=$(ARCH))" > .olddefconfig-ran

kernelversion:
	@echo "$(VERSION).$(PATCHLEVEL).$(SUBLEVEL)$(EXTRAVERSION)"

prepare:
	@:
