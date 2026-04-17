# Makefile

- GNU Make only. No POSIX make compatibility.

- Recipes are multiline bash scripts. `.ONESHELL` is always active — heredocs work. Shell-Scripting rules apply in recipes.

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

- `clean`/`clobber` follow Ruby Rake semantics. `makelib/*.mk` holds task targets.

- Each `makelib/*.mk` owns one phony umbrella and a `clobber.<task>` wired into `clobber`. Dot-separated namespacing: `pkg.posix`, `clobber.docker`. `._` suffix for internal targets.

```make
.PHONY: task clobber.task
clobber: clobber.task
all: task

clobber.task:
	rm -vfr -- '$(TMP)/task'
```

- `$(VAR)` is the project-local prefix with Linux FHS layout: `$(VAR)/bin/` for executables, `$(TMP)` for scratch (typically `$(VAR)/tmp`). Dependencies are real file targets under `$(VAR)/`.

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

- Single-quote automatic variables: `'$@'`, `'$<'`, `'$^'`, `'$|'`. `'$</subpath'` appends to a directory prerequisite. `$|` is the first order-only prerequisite. `$(@D)` is the directory part of `$@`.

- `$$` in recipes passes a literal `$` to bash — Make expands `$` first. Doubles to `$$$$` inside `eval`'d templates.

- Reusable command variables: `CURL := curl --fail --location --remove-on-error --create-dirs --no-progress-meter`.

- `$(origin VAR)` to detect CLI overrides.

- Make text functions (`$(patsubst)`, `$(notdir)`, `$(dir)`, `$(subst)`, `$(addprefix)`, `$(filter-out)`) over `$(shell)` for string work. `$(shell)` only when the host is needed.

- `define`/`call`/`eval`/`foreach` for repetitive targets. Double-escape automatic variables inside `eval`'d templates (`'$$@'`, `'$$<'`):

```make
define TEMPLATE
task: $1
$1:
	do-thing '$$@' '$2'
endef

$(foreach item,$(DATA),$(eval $(call TEMPLATE,...)))
```

- `define` also embeds foreign code (Python, shell) as multi-line variables. `export -- VAR` exports them to recipes:

```make
define PY_SCRIPT
from json import dump, load
from sys import stdin, stdout
dump(sorted(load(stdin), key=lambda r: r["name"]), stdout)
endef
export -- PY_SCRIPT

sorted.json: items.json
	python3 <<< '$(PY_SCRIPT)' < '$<' > '$@'
```

- Multi-target rules: `$(VAR)/bin $(TMP):` shares one recipe across targets.

- Data tables as whitespace-aligned `define` blocks, packed with `tr -s -- ' ' '!'`, iterated via `$(foreach)` splitting on `!`. `META_2D` formalizes 2-column tables:

```make
define DATA
$(OPT)/foo  https://example.com/foo.tar.gz
$(OPT)/bar  https://example.com/bar.tar.gz
endef

DATA := $(shell tr -s -- ' ' '!' <<<'$(DATA)')
$(call META_2D,DATA,TEMPLATE)
```

- Accumulator variables (`+=`) when multiple `.mk` files contribute to one target.

- Sentinel files as completion timestamps. Prerequisites for one target can split across files.

- `.WAIT` serializes prerequisites under `--jobs`. `.PHONY: .WAIT` until GNU Make 4.4+ is baseline.
