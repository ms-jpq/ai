#!/usr/bin/env -S -- awk -f

BEGIN {
  MAX_CONTEXT = 200
  LINK = ""
  PATH = ""
  TARGET = ""
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
    TARGET = LINK
    sub(/^[^]]*\]\(/, "", TARGET)
    sub(/\)$/, "", TARGET)
    if (is_local_target(TARGET)) {
      report("Use `" TARGET "` for a local file reference.")
    }
    TEXT = substr(TEXT, RSTART + RLENGTH)
  }
}

{
  TEXT = $0
  while (match(TEXT, /`[^`]+`/)) {
    PATH = substr(TEXT, RSTART + 1, RLENGTH - 2)
    TARGET = local_target(PATH)
    if (TARGET != "" && ! exists(TARGET)) {
      report("Local file reference does not exist.")
    }
    TEXT = substr(TEXT, RSTART + RLENGTH)
  }
}

function exists(L_PATH, L_LINE, L_STATUS)
{
  L_STATUS = (getline L_LINE < L_PATH)
  close(L_PATH)
  return (L_STATUS >= 0)
}

function is_local_target(L_TARGET)
{
  return (L_TARGET !~ /^([[:alpha:]][[:alnum:]+.-]*:|#|\/\/)/)
}

function local_target(L_VALUE, L_PATH, L_BASE)
{
  L_PATH = L_VALUE
  if (L_PATH !~ /^\// && L_PATH !~ /^\.\.?\// && L_PATH !~ /^[[:alnum:]_.-]+\//) {
    return ""
  }
  if (L_PATH ~ /^\//) {
    return L_PATH
  }
  L_BASE = FILENAME
  if (! sub(/\/[^\/]*$/, "", L_BASE)) {
    L_BASE = "."
  }
  return (L_BASE "/" L_PATH)
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
