.PHONY: info update

info: ./.venv/bin
	'$</numba' --sysinfo

update:
	git submodule foreach --recursive git pull
