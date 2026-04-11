.PHONY: lsp

lsp: ./opt/claude-code/local-plugins/omnibus/.lsp.json
./opt/claude-code/local-plugins/omnibus/.lsp.json: ~/.config/nvim/lsp.lua ~/.config/nvim/ftdetect/mappings.json
	'$<' > '$@'
