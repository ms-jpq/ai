#!/usr/bin/env -S -- awk -f

BEGIN {
  MAX_CONTEXT = 200
  MAX_LENGTH = 300
}

length($0) > MAX_LENGTH {
  printf "> Consider point form; line exceeds %d characters.\n", MAX_LENGTH
  printf "> %s:%d\n", FILENAME, FNR
  if (length($0) > MAX_CONTEXT) {
    printf "> %s...\n", substr($0, 1, MAX_CONTEXT)
  } else {
    printf "> %s\n", $0
  }
}
