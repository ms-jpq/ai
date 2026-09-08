BEGIN {
  # PATTERNS: regular expression -> optional reason
  FENCE = ""
  FENCE_LENGTH = 0
  LINT_FENCED = 0
}

FNR == 1 {
  FENCE = ""
  FENCE_LENGTH = 0
  LINT_FENCED = 0
}

fence($0) {
  next
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

function fence(LINE, L_CONTENT, L_LANGUAGE, L_PATTERN, L_REMAINDER)
{
  L_CONTENT = LINE
  sub(/^ {0,3}/, "", L_CONTENT)
  if (FENCE == "") {
    if (! match(L_CONTENT, /^```+/) && ! match(L_CONTENT, /^~~~+/)) {
      return 0
    }
    FENCE = substr(L_CONTENT, 1, 1)
    FENCE_LENGTH = RLENGTH
    L_LANGUAGE = tolower(substr(L_CONTENT, RLENGTH + 1))
    sub(/^[[:space:]]*/, "", L_LANGUAGE)
    LINT_FENCED = L_LANGUAGE ~ /^(markdown|md|text|txt)([[:space:]]|$)/
    return 1
  }
  L_PATTERN = "^" FENCE FENCE FENCE "+"
  if (! match(L_CONTENT, L_PATTERN) || RLENGTH < FENCE_LENGTH) {
    return ! LINT_FENCED
  }
  L_REMAINDER = substr(L_CONTENT, RLENGTH + 1)
  if (L_REMAINDER ~ /^[[:space:]]*$/) {
    FENCE = ""
    FENCE_LENGTH = 0
    LINT_FENCED = 0
  }
  return 1
}

function pattern(PATTERN, REASON)
{
  PATTERNS[PATTERN] = REASON
}
