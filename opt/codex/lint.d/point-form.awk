#!/usr/bin/env -S -- awk -f

BEGIN {
  MAX_LENGTH = 300
}

length($0) > MAX_LENGTH {
  printf "%s:%d: consider point form; line exceeds %d characters\n", FILENAME, FNR, MAX_LENGTH
  printf "> %s\n", $0
}
