#!/usr/bin/env -S -- sed -E -n -f

1 {
  /^---$/! q
  b
}

/^paths:[[:space:]]*$/ {
  :l1
  n
  s/^[[:space:]]*-[[:space:]]+("([^"]*)"|'([^']*)'|([^[:space:]]+))[[:space:]]*$/\2\3\4/p
  t l1
  /^---$/! q
}

/^---$/ q
