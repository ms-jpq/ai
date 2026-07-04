.PHONY: cc oc

CC := ./opt/claude-code
OC := ./opt/opencode

cc: $(CC)/local-plugins/omnibus/.lsp.json
$(CC)/local-plugins/omnibus/.lsp.json: ~/.config/nvim/libexec/cc.lua
	'$<' > '$@'

oc: $(OC)/opencode.json
$(OC)/opencode.json: ~/.config/nvim/apriori/mappings.json
	jq --slurpfile m '$<' '.formatter.fmt.extensions = ($$m[0] | keys | unique)' '$@' | sponge -- '$@'
