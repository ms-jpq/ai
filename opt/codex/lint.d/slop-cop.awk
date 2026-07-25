#!/usr/bin/env -S -- awk -f

BEGIN {
  PATTERNS[1] = "load[- ]bearing"
  PATTERNS[2] = "genuine(ly)?|truly"
  PATTERNS[3] = "meaningful(ly)?"
  PATTERNS[4] = "that'?s the"
}

{
  TEXT = tolower($0)
  for (INDEX in PATTERNS) {
    if (match(TEXT, PATTERNS[INDEX])) {
      print "> Slop Cop:"
      printf "> %s:%d\n", FILENAME, FNR
      printf "> %s\n", substr($0, RSTART, RLENGTH)
    }
  }
}
