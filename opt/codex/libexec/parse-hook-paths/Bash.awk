#!/usr/bin/env -S -- awk -f

{
  if ($0 ~ /(^|[[:space:];&|()])apply_patch([[:space:]<]|$)/) {
    APPLY_PATCH = 1
  }
  if (APPLY_PATCH && sub(/^\*\*\* (Add|Update|Delete) File: /, "", $0)) {
    emit($0)
    next
  }
  if (APPLY_PATCH && sub(/^\*\*\* Move to: /, "", $0)) {
    emit($0)
    next
  }
}

function emit(path)
{
  printf "%s%c", path, 0
}
