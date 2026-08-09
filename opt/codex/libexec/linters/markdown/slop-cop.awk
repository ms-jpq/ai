BEGIN {
  # PATTERNS: regular expression -> optional reason
}

{
  TEXT = tolower($0)
  for (PATTERN in PATTERNS) {
    if (match(TEXT, PATTERN)) {
      print "> Slop Cop:"
      if (PATTERNS[PATTERN] != "") {
        printf "> %s\n", PATTERNS[PATTERN]
      }
      printf "> %s:%d\n", FILENAME, FNR
      printf "> %s\n", substr($0, RSTART, RLENGTH)
    }
  }
}

function pattern(PATTERN, REASON)
{
  PATTERNS[PATTERN] = REASON
}
