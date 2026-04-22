.PHONY: cc lsp

CC := ./opt/claude-code

lsp: $(CC)/local-plugins/omnibus/.lsp.json
$(CC)/local-plugins/omnibus/.lsp.json: ~/.config/nvim/lsp.lua
	'$<' > '$@'

cc: lsp
