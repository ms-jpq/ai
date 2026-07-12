.PHONY: cc oc co
CLOBBER += $(VAR)/codex/model_catalog.json

CC := ./opt/claude-code
OC := ./opt/opencode
CO := ./opt/codex
CO_PROFILES := $(basename $(notdir $(wildcard $(CO)/profiles/*.toml)))

cc: $(CC)/local-plugins/omnibus/.lsp.json
$(CC)/local-plugins/omnibus/.lsp.json: ~/.config/nvim/libexec/cc.lua
	'$<' > '$@'

oc: $(OC)/opencode.json
$(OC)/opencode.json: $(OC)/libexec/opencode.jq ./node_modules/.bin $(CC)/local-plugins/omnibus/.mcp.json  ~/.config/nvim/apriori/mappings.json
	'$<' --sort-keys --slurpfile c $(CC)/local-plugins/omnibus/.mcp.json --slurpfile m ~/.config/nvim/apriori/mappings.json '$@' | sponge -- '$@'
	./node_modules/.bin/prettier --write -- '$@'

co: $(VAR)/codex/model_catalog.json

$(VAR)/codex: | $(VAR)
	mkdir -v -p -- '$@'

define CO_PROFILE_TEMPLATE
co: $(VAR)/codex/$1.config.toml
$(VAR)/codex/$1.config.toml: $(CO)/profiles/$1.toml $(CO)/libexec/materialize-profile.sh $(CO)/libexec/materialize-profile.awk | $(VAR)/codex
	'$(CO)/libexec/materialize-profile.sh' '$$<' '$$@'
endef

$(foreach profile,$(CO_PROFILES),$(eval $(call CO_PROFILE_TEMPLATE,$(profile))))

$(VAR)/codex/model_catalog.json: $(CO)/libexec/model_catalog.jq | $(VAR)/codex
	set -a
	source -- ./.env
	set +a
	URL="https://openrouter.ai/api/v1/models"
	$(CURL) -- "$$URL" | '$<' > '$@'
