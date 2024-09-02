.PHONY: lint mypy shellcheck

lint: mypy shellcheck

mypy: ./.venv/bin
	git ls-files --deduplicate -z -- '*.py' | xargs -0 -- '$</mypy' --

shellcheck: $(VAR)/bin/shellcheck
	git ls-files --deduplicate -z -- '*.*sh' | xargs -0 -- '$<' --
