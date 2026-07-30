BEGIN {
  PATTERNS[0] = ""
  delete PATTERNS[0]
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

function pattern(PATTERN)
{
  PATTERNS[++PATTERN_COUNT] = PATTERN
}
