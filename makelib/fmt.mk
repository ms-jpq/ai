.PHONY: fmt shfmt black

fmt: shfmt black

shfmt: $(VAR)/bin/shfmt
	git ls-files --deduplicate -z -- '*.*sh' | xargs -r -0 -- '$<' --write --simplify --binary-next-line --space-redirects --indent 2 --

black: ./.venv/bin
	'$</isort' --profile=black --gitignore -- .
	'$</black' --extend-exclude pack -- .
