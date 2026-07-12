#!/usr/bin/env -S -- awk -f

FNR == NR {
  PROFILE[++PROFILE_N] = $0
  TABLE = table_header($0)
  if (TABLE != "") {
    PROFILE_IN_TABLE = 1
    PROFILE_TABLES[TABLE] = 1
    next
  }
  KEY = top_key($0)
  if (! PROFILE_IN_TABLE && KEY != "") {
    PROFILE_KEYS[KEY] = 1
  }
  next
}

! PRINTED_PROFILE {
  print_profile()
}

{
  TABLE = table_header($0)
  if (TABLE != "") {
    DST_IN_TABLE = 1
    DST_SKIP_TABLE = TABLE in PROFILE_TABLES
    if (DST_SKIP_TABLE) {
      next
    }
    DST_STARTED = 1
    print
    next
  }
  if (DST_SKIP_TABLE) {
    next
  }
  LINE = trim($0)
  if (! DST_STARTED && LINE == "") {
    next
  }
  if (LINE ~ /^#:schema[[:space:]]/) {
    next
  }
  KEY = top_key($0)
  if (! DST_IN_TABLE && KEY in PROFILE_KEYS) {
    next
  }
  DST_STARTED = 1
  print
}

END {
  print_profile()
}

function print_profile(L_i)
{
  if (PRINTED_PROFILE) {
    return
  }
  for (L_i = 1; L_i <= PROFILE_N; L_i += 1) {
    print PROFILE[L_i]
  }
  print ""
  PRINTED_PROFILE = 1
}

function table_header(value, L_header)
{
  L_header = trim(value)
  if (L_header !~ /^\[\[?/) {
    return ""
  }
  return L_header
}

function top_key(value, L_key)
{
  L_key = trim(value)
  if (L_key !~ /^[A-Za-z0-9_.-]+[[:space:]]*=/) {
    return ""
  }
  sub(/[[:space:]]*=.*/, "", L_key)
  return L_key
}

function trim(value, L_value)
{
  L_value = value
  sub(/^[[:space:]]+/, "", L_value)
  sub(/[[:space:]]+$/, "", L_value)
  return L_value
}
