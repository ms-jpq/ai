.PHONY: cc oc

CC := ./opt/claude-code
OC := ./opt/opencode

cc: $(CC)/local-plugins/omnibus/.lsp.json
$(CC)/local-plugins/omnibus/.lsp.json: ~/.config/nvim/libexec/cc.lua
	'$<' > '$@'

oc: $(OC)/opencode.json
$(OC)/opencode.json: $(OC)/libexec/opencode.jq ./node_modules/.bin $(CC)/local-plugins/omnibus/.mcp.json  ~/.config/nvim/apriori/mappings.json
	'$<' --sort-keys --slurpfile c $(CC)/local-plugins/omnibus/.mcp.json --slurpfile m ~/.config/nvim/apriori/mappings.json '$@' | sponge -- '$@'
	./node_modules/.bin/prettier --write -- '$@'
