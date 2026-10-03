.PHONY: test test.node test.s6 test.service-template

test: test.node test.s6 test.service-template

test.node: ./node_modules/.bin
	npm run test

test.s6:
	./opt/s6.test.sh

test.service-template:
	./opt/dl/jobs/dispatch/data/service-template.test.sh
