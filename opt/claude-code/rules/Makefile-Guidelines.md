# Makefile Guidelines

- GNU Make only. No POSIX make compatibility.

- Recipes are multiline bash scripts. `.ONESHELL` is always active. All Shell-Scripting-Guidelines apply inside recipes.

- Refer to the options set in the following prelude:

```make
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

.PHONY: help clean clobber

clean:
	shopt -u failglob
	rm -v -rf --

clobber: clean
	shopt -u failglob
	rm -v -rf --

include makelib/*.mk
```

- `clean`/`clobber` follow Rake semantics.

- Each `makelib/*.mk` file owns one task — a phony umbrella grouping related subtargets, with a `<task>.clean` wired as a prerequisite of the global `clean`.

- `$(VAR)` is the project-local prefix with FHS semantics: `$(VAR)/bin/` for executables, `$(VAR)/tmp/` for scratch. Dependencies are real file targets under `$(VAR)/*`; other targets depend on them via prerequisites.

```make
$(VAR):
	mkdir -v -p -- '$@'

$(VAR)/bin: | $(VAR)
	mkdir -v -p -- '$@'

$(VAR)/bin/shfmt: | $(VAR)/bin
	URI='https://github.com/mvdan/sh/releases/latest/download/shfmt_$(V_SHFMT)_$(OS)_$(GOARCH)'
	$(CURL) --output '$@' -- "$$URI"
	chmod +x '$@'

shfmt: $(VAR)/bin/shfmt
	git ls-files --deduplicate -z -- '*.*sh' | xargs -r -0 -- '$<' --write --
```

- Single-quote automatic variables: `'$@'`, `'$<'`, `'$^'`. `'$</subpath'` for paths relative to a directory prerequisite.

```make
mypy: ./.venv/bin
	git ls-files --deduplicate -z -- '*.py' | xargs -0 -- '$</mypy' --
```
