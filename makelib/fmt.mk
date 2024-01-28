.PHONY: fmt shfmt black prettier

fmt: shfmt black prettier

shfmt: $(VAR)/bin/shfmt
	git ls-files --deduplicate -z -- '*.*sh' | xargs -0 -- '$<' --write --indent 2 --

black: ./.venv/bin
	'$</isort' --profile=black --gitignore -- .
	'$</black' --extend-exclude pack -- .

prettier: ./node_modules/.bin
	'$</prettier' --cache --write -- .
