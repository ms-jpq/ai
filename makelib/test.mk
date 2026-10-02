.PHONY: test test.node test.quine test.service-template

test: test.node test.quine test.service-template

test.node: ./node_modules/.bin
	npm run test

test.quine:
	./opt/s6/quine.test.sh

test.service-template:
	./opt/dl/jobs/dispatch/data/service-template.test.sh
