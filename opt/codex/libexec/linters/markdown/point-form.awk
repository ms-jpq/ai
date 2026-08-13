#!/usr/bin/env -S -- awk -f

BEGIN {
  MAX_CONTEXT = 200
  MAX_WORDS = 33
}

NF > MAX_WORDS {
  printf "> Consider point form; line exceeds %d words.\n", MAX_WORDS
  printf "> %s:%d\n", FILENAME, FNR
  if (length($0) > MAX_CONTEXT) {
    printf "> %s...\n", substr($0, 1, MAX_CONTEXT)
  } else {
    printf "> %s\n", $0
  }
}
