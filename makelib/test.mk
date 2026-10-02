.PHONY: test test.node test.quine test.service-template test.quine-lifecycle

test: test.node test.quine test.service-template test.quine-lifecycle

test.node: ./node_modules/.bin
	npm run test

test.quine:
	./opt/s6/quine.test.sh

test.service-template:
	./opt/dl/jobs/dispatch/data/service-template.test.sh

test.quine-lifecycle:
	python3 ./opt/s6/quine.lifecycle.test.py
