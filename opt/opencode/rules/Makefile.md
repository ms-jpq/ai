---
paths:
  - "*.mk"
  - "GNUmakefile"
  - "Makefile"
  - "makefile"
---

# Makefile

## Runtime

- Use GNU Make.

- Write recipes as multiline Bash scripts under `.ONESHELL`; heredocs work. Apply @./Shell-Scripting.md to recipes.

- Standard prelude:

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

  .DEFAULT_GOAL := all

  .PHONY: all clean clobber

  clean:
  	shopt -u failglob
  	rm -v -rf --

  clobber: clean
  	shopt -u failglob
  	rm -v -rf --

  include makelib/*.mk
  ```

---

## Task Organization

- Follow Ruby Rake semantics for `clean` / `clobber`. Keep task targets in `makelib/*.mk`.

- Give each `makelib/*.mk` one phony umbrella and a `clobber.<task>` prerequisite of `clobber`. Use dot-separated namespaces (`pkg.posix`, `clobber.docker`) and a `._` suffix for internal targets.

  ```make
  .PHONY: task clobber.task
  clobber: clobber.task
  all: task

  clobber.task:
  	rm -vfr -- '$(TMP)/task'
  ```

---

## Paths and Targets

- Use `$(VAR)` as the project-local prefix with a Linux FHS layout: `$(VAR)/bin/` for executables and `$(TMP)` for scratch, typically `$(VAR)/tmp`. Represent dependencies as real file targets under `$(VAR)/`.

  ```make
  $(VAR):
  	mkdir -v -p -- '$@'

  $(VAR)/bin: | $(VAR)
  	mkdir -v -p -- '$@'

  $(VAR)/bin/tool: | $(VAR)/bin
  	$(CURL) --output '$@' -- "$$URI"
  	chmod +x '$@'

  task: $(VAR)/bin/tool
  	git ls-files --deduplicate -z -- '*.ext' | xargs -r -0 -- '$<' --
  ```

---

## Expansion

- Single-quote automatic variables: `'$@'`, `'$<'`, `'$^'`, `'$|'`. Use `'$</subpath'` beneath a directory prerequisite. `$|` contains all order-only prerequisites. `$(@D)` is the directory part of `$@`.

- Use `$$` to pass a literal `$` from Make to Bash. Double it again to `$$$$` inside `eval` templates.

- Store reusable commands in variables: `CURL := curl --fail --location --remove-on-error --create-dirs --no-progress-meter`.

- Use `$(origin VAR)` to detect command-line overrides.

- Use Make text functions (`$(patsubst)`, `$(notdir)`, `$(dir)`, `$(subst)`, `$(addprefix)`, `$(filter-out)`) for string transformations. Use `$(shell)` only when the host environment is required.

---

## Metaprogramming

- Generate repetitive targets with `define` / `call` / `eval` / `foreach`. Double-escape automatic variables inside `eval` templates (`'$$@'`, `'$$<'`):

  ```make
  define TEMPLATE
  task: $1
  $1:
  	do-thing '$$@' '$2'
  endef

  $(foreach item,$(DATA),$(eval $(call TEMPLATE,...)))
  ```

- Embed foreign code as multiline `define` variables and export them to recipes:

  ```make
  define PY_SCRIPT
  from json import dump, load
  from sys import stdin, stdout
  dump(sorted(load(stdin), key=lambda r: r["name"]), stdout)
  endef
  export PY_SCRIPT

  sorted.json: items.json
  	python3 -c "$$PY_SCRIPT" < '$<' > '$@'
  ```

---

## Coordination

- Use multi-target rules such as `$(VAR)/bin $(TMP):` to share one recipe across targets.

- Store data tables as whitespace-aligned `define` blocks. Pack them with `tr -s -- ' ' '!'` and iterate with `$(foreach)` splitting on `!`. Use `META_2D` for two-column tables:

  ```make
  define DATA
  $(OPT)/foo  https://example.com/foo.tar.gz
  $(OPT)/bar  https://example.com/bar.tar.gz
  endef

  DATA := $(shell tr -s -- ' ' '!' <<<'$(DATA)')
  $(call META_2D,DATA,TEMPLATE)
  ```

- Use accumulator variables (`+=`) when multiple `.mk` files contribute to one target.

- Use sentinel files as completion timestamps. Split prerequisites for one target across files when needed.

- Use `.WAIT` to serialize prerequisites under `--jobs`. On older versions, use explicit prerequisite edges.
