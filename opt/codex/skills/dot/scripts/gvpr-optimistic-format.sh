#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

FORMAT=(
  clang-format
  --assume-filename=script.c
  '--style={BasedOnStyle: LLVM, IndentWidth: 2, ColumnLimit: 120, BreakStringLiterals: false, AllowShortFunctionsOnASingleLine: None}'
)

FIRST=''
if IFS= read -r -- FIRST; then
  FIRST+=$'\n'
fi

case "$FIRST" in
'#!'*)
  printf -- '%s' "$FIRST"
  exec -- "${FORMAT[@]}"
  ;;
*)
  {
    printf -- '%s' "$FIRST"
    cat
  } | "${FORMAT[@]}"
  ;;
esac
