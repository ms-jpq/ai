#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob dotglob

UNIQUE=0
if [[ ${1:-} == --unique ]]; then
  UNIQUE=1
  shift -- 1
fi
if (($# < 2)); then
  set -x
  exit 2
fi
WANTS="$1"
LIMIT="$2"
shift -- 2
case "$WANTS" in
. | data/wants) ;;
*)
  set -x
  exit 2
  ;;
esac
if [[ $LIMIT != -1 ]] && [[ $LIMIT != +([0-9]) ]]; then
  set -x
  exit 2
fi
if [[ $LIMIT != -1 ]]; then LIMIT=$((10#$LIMIT)); fi
START="$PWD"
declare -A -- ACTIVE=() SEEN=()

for ROOT in "$@"; do
  if [[ $ROOT != /* ]]; then ROOT="$START/$ROOT"; fi
  ROOT="${ROOT%/}"
  cd -P -- "$ROOT"
  STACK=(enter "$PWD" "${ROOT##*/}" "$LIMIT")
  while ((${#STACK[@]})); do
    DEPTH="${STACK[-1]}"
    unset 'STACK[-1]'
    CHAIN="${STACK[-1]}"
    unset 'STACK[-1]'
    DIR="${STACK[-1]}"
    unset 'STACK[-1]'
    ACTION="${STACK[-1]}"
    unset 'STACK[-1]'
    if [[ $ACTION == leave ]]; then
      ACTIVE[$DIR]=''
      SEEN[$DIR]=1
      continue
    fi
    if ! [[ -d $DIR ]]; then
      printf -- '%s\0%s\0' "$CHAIN" ''
      continue
    fi
    cd -P -- "$DIR"
    DIR="$PWD"
    if [[ -n ${ACTIVE[$DIR]:-} ]]; then
      tee >&2 <<- EOF
Dependency cycle at $CHAIN
EOF
      exit 2
    fi
    if ((UNIQUE)) && [[ -n ${SEEN[$DIR]:-} ]]; then
      continue
    fi
    printf -- '%s\0%s\0' "$CHAIN" "$DIR"
    if ((DEPTH == 0)); then
      continue
    fi
    ACTIVE[$DIR]=1
    STACK+=(leave "$DIR" "$CHAIN" "$DEPTH")
    LINKS=("$DIR/$WANTS/"*)
    for ((INDEX = ${#LINKS[@]} - 1; INDEX >= 0; INDEX--)); do
      LINK="${LINKS[$INDEX]}"
      if [[ -L $LINK ]]; then
        STACK+=(enter "$LINK" "$CHAIN/${LINK##*/}" "$((DEPTH < 0 ? -1 : DEPTH - 1))")
      fi
    done
  done
done
