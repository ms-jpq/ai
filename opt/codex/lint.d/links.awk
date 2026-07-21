#!/usr/bin/env -S -- awk -f

BEGIN {
  LABEL = ""
  LINK = ""
  MAX_CONTEXT = 200
  TEXT = ""
}

{
  TEXT = $0
  gsub(/`[^`]*`/, "", TEXT)
  gsub(/\[[^]]*\]\([^)]+\)/, "", TEXT)
  if (TEXT ~ /https?:\/\/[^[:space:]]+/) {
    report("Use [label](URL) instead of a bare URL.")
  }
}

{
  TEXT = $0
  while (match(TEXT, /\[[^]]*\]\([^)]+\)/)) {
    LINK = substr(TEXT, RSTART, RLENGTH)
    LABEL = LINK
    sub(/^\[/, "", LABEL)
    sub(/\]\([^)]+\)$/, "", LABEL)
    if (LABEL ~ /^#[0-9]+$/ || LABEL ~ /^[[:upper:]][[:upper:][:digit:]]*-[0-9]+$/) {
      report("Use a descriptive link label instead of a ticket ID.")
    }
    TEXT = substr(TEXT, RSTART + RLENGTH)
  }
}

function report(L_MESSAGE, L_CONTEXT)
{
  L_CONTEXT = $0
  printf "> %s\n", L_MESSAGE
  printf "> %s:%d\n", FILENAME, FNR
  if (length(L_CONTEXT) > MAX_CONTEXT) {
    printf "> %s...\n", substr(L_CONTEXT, 1, MAX_CONTEXT)
  } else {
    printf "> %s\n", L_CONTEXT
  }
}
