# Makefile Guidelines

- GNU Make only. No POSIX make compatibility.

- Recipes are multiline bash scripts. `.ONESHELL` is always active — heredocs work in recipes. All Shell-Scripting-Guidelines apply inside recipes.

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

- `clean`/`clobber` follow Rake semantics. `lib/*.mk` holds shared infrastructure (OS detection, macros, command variables). `makelib/*.mk` holds task-specific targets.

- Each `makelib/*.mk` owns one phony umbrella with a `clobber.<task>` wired as a prerequisite of `clobber`. Dot-separated phony namespacing throughout: `pkg.posix`, `clobber.docker`. `._` suffix for internal targets: `pkg._`.

```make
.PHONY: helix clobber.helix
clobber: clobber.helix
all: helix

clobber.helix:
	rm -vfr -- $(HELIX)/languages.toml
```

- `$(VAR)` is the project-local prefix with FHS semantics: `$(VAR)/bin/` for executables. `$(TMP)` for scratch, typically `$(VAR)/tmp`. Dependencies are real file targets under `$(VAR)/*`.

```make
$(VAR):
	mkdir -v -p -- '$@'

$(VAR)/bin/shfmt: | $(VAR)/bin
	URI='https://github.com/mvdan/sh/releases/latest/download/shfmt_$(V_SHFMT)_$(OS)_$(GOARCH)'
	$(CURL) --output '$@' -- "$$URI"
	chmod +x '$@'

shfmt: $(VAR)/bin/shfmt
	git ls-files --deduplicate -z -- '*.*sh' | xargs -r -0 -- '$<' --write --
```

- Single-quote automatic variables: `'$@'`, `'$<'`, `'$^'`, `'$|'`. `'$</subpath'` for paths relative to a directory prerequisite. `$|` references the first order-only prerequisite.

- Order-only prerequisites (`|`) for directories and one-time setup that should not trigger rebuilds: `$(VAR)/bin/tool: | $(VAR)/bin`.

- Reusable command variables — the Make equivalent of the shell array pattern: `CURL := curl --fail --location --remove-on-error --create-dirs --no-progress-meter`.

- `ifeq`/`ifneq`/`ifdef` for conditional blocks. `$(origin VAR, command line)` to detect CLI overrides for mode switching.

- Prefer Make text functions (`$(patsubst)`, `$(notdir)`, `$(dir)`, `$(subst)`, `$(addprefix)`, `$(filter-out)`, etc.) over `$(shell)` for string manipulation. `$(shell ...)` only for dynamic evaluation that needs the host.

- `define`/`call`/`eval`/`foreach` for generating repetitive targets. Inside `eval`'d templates, double-escape automatic variables (`'$$@'`, `'$$<'`):

```make
define TEMPLATE
task: $1
$1:
	do-thing '$$@' '$2'
endef

$(foreach item,$(DATA),$(eval $(call TEMPLATE,...)))
```

- Structured data as whitespace-aligned tables inside `define`, packed with `tr -s -- ' ' '!'`, iterated via `$(foreach)` splitting on `!`. `META_2D` formalizes 2-column tables:

```make
define REPOS
$(OPT)/ai       https://github.com/ms-jpq/ai
$(OPT)/fzf-tab  https://github.com/Aloxaf/fzf-tab
endef

REPOS := $(shell tr -s -- ' ' '!' <<<'$(REPOS)')
$(call META_2D,REPOS,TEMPLATE)
```

- Accumulator variables when multiple `.mk` files contribute to one target: `CLOBBER.FS += /etc/docker/*` across files, consumed by one recipe.

- Sentinel files (`._touch`) as timestamps for group completion. Prerequisites for the same target can split across declarations and files.

- `.WAIT` for serializing prerequisites under `--jobs`. `.PHONY: .WAIT` until GNU Make 4.4+ is baseline.
