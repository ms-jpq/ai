.PHONY: info update

info: ./.venv/bin
	'$</numba' --sysinfo
