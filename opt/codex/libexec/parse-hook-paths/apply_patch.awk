#!/usr/bin/env -S -- awk -f

# https://developers.openai.com/api/docs/guides/tools-apply-patch

{
  sub(/\r$/, "", $0)
  L_trimmed = $0
  sub(/^[ \t]+/, "", L_trimmed)
  sub(/[ \t]+$/, "", L_trimmed)
  if (L_trimmed == "*** Begin Patch") {
    clear_paths()
    IN_PATCH = 1
    next
  }
  if (! IN_PATCH) {
    next
  }
  if (L_trimmed == "*** End Patch") {
    emit_paths()
    IN_PATCH = 0
    next
  }
  if ((sub(/^\*\*\* (Add|Update|Delete) File: /, "", L_trimmed)) || (sub(/^\*\*\* Move to: /, "", L_trimmed))) {
    save(L_trimmed)
  }
}

function clear_paths(L_i)
{
  for (L_i in PATHS) {
    delete PATHS[L_i]
  }
  PATH_COUNT = 0
}

function emit_paths(L_i)
{
  for (L_i = 1; L_i <= PATH_COUNT; L_i++) {
    printf "%s%c", PATHS[L_i], 0
  }
  clear_paths()
}

function save(path)
{
  if (length(path)) {
    PATHS[++PATH_COUNT] = path
  }
}
