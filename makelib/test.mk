.PHONY: test test.node test.quine

test: test.node test.quine

test.node: ./node_modules/.bin
	npm run test

test.quine:
	./opt/s6/quine.test.sh
