#!/usr/bin/env -S -- awk -f

BEGIN {
  STATUS = 0
}

/^[[:space:]]*#/ {
  next
}

{
  if ($0 ~ /\[\[[[:space:]]+-v([[:space:]]|\])/) {
    report("Do not use [[ -v ... ]]; use [[ -n ${NAME:-} ]].")
  }
  if ($0 ~ /\]\][[:space:]]*(\|\||&&)[[:space:]]*(continue|break|exit)([[:space:];]|$)/) {
    report("Do not short-circuit from a [[ ... ]] test; use an if block.")
  }
  if ($0 ~ /^[[:space:]]*(function[[:space:]]+|[[:alpha:]_][[:alnum:]_]*[[:space:]]*\(\)[[:space:]]*\{)/) {
    report("Do not declare shell functions; split reusable behavior into an array or a script.")
  }
}

END {
  exit STATUS
}

function report(L_message)
{
  printf "> %s\n", L_message
  printf "> %s:%d\n", FILENAME, FNR
  printf "> %s\n", $0
  STATUS = 1
}
