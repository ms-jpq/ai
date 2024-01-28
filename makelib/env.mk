define OS_DETECT
case "$$OSTYPE" in
darwin*)
	printf -- '%s' darwin
	;;
linux*)
	printf -- '%s' linux
	;;
msys)
	printf -- '%s' nt
	;;
*)
	exit 1
	;;
esac
endef

HOSTTYPE := $(shell printf -- '%s' "$$HOSTTYPE")
OS := $(shell $(OS_DETECT))

ifeq ($(HOSTTYPE), aarch64)
GOARCH := arm64
else
GOARCH := amd64
endif

