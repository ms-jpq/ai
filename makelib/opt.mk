.PHONY: cc lsp

cc: lsp

lsp: ./opt/claude-code/local-plugins/omnibus/.lsp.json
./opt/claude-code/local-plugins/omnibus/.lsp.json: ~/.config/nvim/lsp.lua
	'$<' > '$@'
