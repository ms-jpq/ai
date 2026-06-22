.PHONY: fmt shfmt black prettier

fmt: shfmt black prettier

shfmt: $(VAR)/bin/shfmt
	git ls-files --deduplicate -z -- '*.*sh' | xargs -r -0 -- '$<' --write --simplify --binary-next-line --space-redirects --indent 2 --

black: ./.venv/bin
	'$</isort' --profile=black --gitignore -- .
	'$</black' --extend-exclude template -- .

prettier: ./node_modules/.bin
	'$</prettier' --cache --write -- .
