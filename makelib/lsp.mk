.PHONY: lsp

CC_DIR := ./opt/claude-code
LSP_TARGET := $(CC_DIR)/local-plugins/omnibus/.lsp.json

lsp: $(LSP_TARGET)
$(LSP_TARGET): $(CC_DIR)/libexec/lsp.lua $(CC_DIR)/libexec/lsp.jq $(CC_DIR)/libexec/filetypes.json
	'$<' '$(CC_DIR)/libexec/lsp.jq' --slurpfile '$(CC_DIR)/libexec/filetypes.json' > '$@'
