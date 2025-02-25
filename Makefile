MAKEFLAGS += --check-symlink-times
MAKEFLAGS += --jobs
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables
MAKEFLAGS += --shuffle
MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.DELETE_ON_ERROR:
.ONESHELL:
.SHELLFLAGS := --norc --noprofile -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar -c

.DEFAULT_GOAL := help

# TODO: gnumake 4.4 .WAIT
.PHONY: clean clobber .WAIT

CLEAN :=
CLOBBER :=

clean:
	shopt -u failglob
	rm -v -rf -- '$(TMP)' package-lock.json $(CLEAN)

clobber: clean
	shopt -u failglob
	rm -v -rf -- '$(VAR)' ./.venv/ ./node_modules/ $(CLOBBER)


CURL := curl --fail-with-body --location --no-progress-meter
VAR := ./var
TMP := $(VAR)/tmp

$(VAR):
	mkdir -v -p -- '$@'

$(TMP): | $(VAR)
	mkdir -v -p -- '$@'

include makelib/*.mk
# include opt/*/makelib/*.mk
