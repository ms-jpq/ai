.PHONY: test test.node test.s6 test.dl

test: test.node test.s6 test.dl

test.node: ./node_modules/.bin
	npm run test

test.s6:
	./opt/s6.test.sh

test.dl:
	./opt/dl.test.sh
