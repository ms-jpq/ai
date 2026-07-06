#!/usr/bin/env -S -- awk -f

{
  if (sub(/^\*\*\* (Add|Update|Delete) File: /, "", $0)) {
    printf "%s%c", $0, 0
  }
  if (sub(/^\*\*\* Move to: /, "", $0)) {
    printf "%s%c", $0, 0
  }
}
