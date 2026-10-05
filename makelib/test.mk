.PHONY: test test.node test.s6

test: test.node test.s6

test.node: ./node_modules/.bin
	npm run test

test.s6:
	./opt/s6.test.sh
