#!/usr/bin/env -S -- awk -f

BEGIN {
  PATTERNS[1] = "\342\200\224"  # em-dash
  PATTERNS[2] = "load[- ]bearing"
  PATTERNS[3] = "genuine(ly)?|truly"
  PATTERNS[4] = "meaningful(ly)?"
  PATTERNS[5] = "that'?s the"
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
