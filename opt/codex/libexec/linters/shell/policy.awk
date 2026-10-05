#!/usr/bin/env -S -- awk -f

BEGIN {
  STATUS = 0
  TEST = ""
}

FNR == 1 {
  TEST = ""
}

/^[[:space:]]*#/ {
  next
}

{
  if ($0 ~ /^[[:blank:]]*printf([[:blank:]]|$)/ && $0 !~ /^[[:blank:]]*printf[[:blank:]]+(-v[[:blank:]]+("([^"\\]|\\.)*"|'[^']*'|[^[:blank:]]+)[[:blank:]]+|--?[[:alnum:]_-]+[[:blank:]]+)*--([[:blank:]]|$)/) {
    report("Use -- before the printf format; options such as -v NAME may precede it.")
  }
  if ($0 ~ /\[\[[[:space:]]+-v([[:space:]]|\])/) {
    report("Do not use unsafe [[ -v ... ]]; use [[ -n ${NAME:-} ]].")
  }
  if ($0 ~ /\]\][[:space:]]*(\|\||&&)[[:space:]]*(continue|break|exit)([[:space:];]|$)/) {
    report("Do not short-circuit from a [[ ... ]] test; use an if block.")
  }
  if ($0 ~ /^[[:space:]]*(function[[:space:]]+|[[:alpha:]_][[:alnum:]_]*[[:space:]]*\(\)[[:space:]]*\{)/) {
    report("Do not declare shell functions; split reusable behaviour into an array or a script.")
  }
  LINE = $0
  gsub(/"([^"\\]|\\.)*"|'[^']*'/, "_", LINE)
  gsub(/\\./, "_", LINE)
  sub(/(^|[[:space:]])#.*/, "", LINE)
  while (length(LINE)) {
    if (TEST == "") {
      OPEN = index(LINE, "[[")
      if (! OPEN) {
        break
      }
      LINE = substr(LINE, OPEN + 2)
      TEST = " "
    }
    if (! match(LINE, /(^|[[:space:]])\]\]([[:space:];&|)]|$)/)) {
      TEST = TEST LINE "\n"
      break
    }
    CLOSE = RSTART + index(substr(LINE, RSTART, RLENGTH), "]]") - 1
    TEST = TEST substr(LINE, 1, CLOSE - 1)
    if (TEST ~ /&&|\|\||(^|[[:space:](])!([[:space:](]|$)/) {
      report("Keep &&, ||, and ! outside [[ ... ]]; combine or negate separate tests.")
    }
    TEST = ""
    LINE = substr(LINE, CLOSE + 2)
  }
}

END {
  exit STATUS
}

function report(L_message)
{
  printf "> %s\n", L_message
  printf "> %s:%d\n", FILENAME, FNR
  printf "> %s\n\n", $0
  STATUS = 1
}
