.PHONY: cc oc co
CLOBBER += $(VAR)/codex/model_catalog.json

CC := ./opt/claude-code
OC := ./opt/opencode
CO := ./opt/codex

cc: $(CC)/local-plugins/omnibus/.lsp.json
$(CC)/local-plugins/omnibus/.lsp.json: ~/.config/nvim/libexec/cc.lua
	'$<' > '$@'

oc: $(OC)/opencode.json
$(OC)/opencode.json: $(OC)/libexec/opencode.jq ./node_modules/.bin $(CC)/local-plugins/omnibus/.mcp.json  ~/.config/nvim/apriori/mappings.json
	'$<' --sort-keys --slurpfile c $(CC)/local-plugins/omnibus/.mcp.json --slurpfile m ~/.config/nvim/apriori/mappings.json '$@' | sponge -- '$@'
	./node_modules/.bin/prettier --write -- '$@'

co: $(VAR)/codex/model_catalog.json
$(VAR)/codex/model_catalog.json: $(CO)/libexec/model_catalog.jq | $(VAR)
	set -a
	source -- ./.env
	set +a
	URL="https://litellm.$${MCP_DOMAIN}/v1/models"
	$(CURL) -- "$$URL" | '$<' > '$@'
