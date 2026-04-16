.PHONY: lint mypy shellcheck tsc

lint: mypy shellcheck tsc

mypy: ./.venv/bin
	git ls-files --deduplicate -z -- '*.py' | xargs -0 -- '$</mypy' --

shellcheck: $(VAR)/bin/shellcheck
	git ls-files --deduplicate -z -- '*.*sh' | xargs -0 -- '$<' --

tsc: ./node_modules/.bin
	'$</tsc' --noEmit
