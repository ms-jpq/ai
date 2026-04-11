#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if ! [[ -v TMUX ]]; then
  set -x
  exit 2
fi

CURRENT="$(tmux display-message -p -- '#{@claude_session}')"
if [[ -n $CURRENT ]]; then
  printf -- '%s' "$CURRENT"
  exit 0
fi

PANES="$(tmux list-panes -F '#{@claude_session}')"
readarray -t -- SESSIONS <<< "$PANES"

UNIQUE=()
for ID in "${SESSIONS[@]}"; do
  if [[ -z $ID ]]; then
    continue
  fi
  UNIQUE+=("$ID")
done

case "${#UNIQUE[@]}" in
1)
  printf -- '%s' "${UNIQUE[*]}"
  exit 0
  ;;
*)
  tmux display-message -- "🚧 ${UNIQUE[*]:--}"
  ;;
esac

exit 1
