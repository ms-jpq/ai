.PHONY: mistral mistral.venv

mistral: mistral.venv

mistral.venv: ./opt/mistral/.venv

CLOBBER += ./opt/mistral/.venv
./opt/mistral/.venv:
	python3 -m venv -- '$@'
	'$@/bin/pip' install --requirement '$(@D)/mistral-src/requirements.txt'

