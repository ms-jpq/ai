#!/usr/bin/env -S -- awk -f

{
  if (READ_TOO && ! APPLY_PATCH) {
    scan_commands($0)
  }
  if ($0 ~ /(^|[[:space:];&|()])apply_patch([[:space:]<]|$)/) {
    APPLY_PATCH = 1
  }
  if (APPLY_PATCH && (sub(/^\*\*\* (Add|Update|Delete) File: /, "", $0))) {
    emit($0)
    next
  }
  if (APPLY_PATCH && (sub(/^\*\*\* Move to: /, "", $0))) {
    emit($0)
    next
  }
}

function command_start(argv, argc, L_i)
{
  if (! argc) {
    return 0
  }
  L_i = 1
  if (argv[L_i] == "command") {
    L_i++
  }
  if (L_i > argc) {
    return 0
  }
  return L_i
}

function emit(path)
{
  printf "%s%c", path, 0
}

function flush(argv, argc, token)
{
  if (length(token)) {
    argv[++argc] = token
  }
  return argc
}

function parse_command(argv, argc, L_has_script, L_i, L_sed)
{
  L_sed = command_start(argv, argc)
  if (! L_sed || argv[L_sed] != "sed") {
    return
  }
  L_has_script = 0
  for (L_i = L_sed + 1; L_i <= argc; L_i++) {
    if (argv[L_i] == "--") {
      while (++L_i <= argc) {
        emit(argv[L_i])
      }
      return
    }
    if (argv[L_i] == "-e" || argv[L_i] == "--expression") {
      L_has_script = 1
      L_i++
      continue
    }
    if (argv[L_i] ~ /^(-e.+|--expression=.+)$/) {
      L_has_script = 1
      continue
    }
    if (argv[L_i] == "-f" || argv[L_i] == "--file") {
      L_has_script = 1
      if (++L_i <= argc) {
        emit(argv[L_i])
      }
      continue
    }
    if (argv[L_i] ~ /^-f.+/) {
      L_has_script = 1
      emit(substr(argv[L_i], 3))
      continue
    }
    if (argv[L_i] ~ /^--file=.+/) {
      L_has_script = 1
      emit(substr(argv[L_i], 8))
      continue
    }
    if (argv[L_i] ~ /^-/) {
      continue
    }
    if (! L_has_script) {
      L_has_script = 1
      continue
    }
    emit(argv[L_i])
  }
}

function scan_commands(line, argv, L_argc, L_char, L_escaped, L_i, L_j, L_quote, L_token)
{
  L_argc = 0
  L_quote = ""
  L_token = ""
  L_escaped = 0
  for (L_i = 1; L_i <= length(line); L_i++) {
    L_char = substr(line, L_i, 1)
    if (L_escaped) {
      L_token = L_token L_char
      L_escaped = 0
      continue
    }
    if (L_char == "\\" && L_quote != "'") {
      L_escaped = 1
      continue
    }
    if (L_quote != "") {
      if (L_char == L_quote) {
        L_quote = ""
      } else {
        L_token = L_token L_char
      }
      continue
    }
    if (L_char == "'" || L_char == "\"") {
      L_quote = L_char
      continue
    }
    if (L_char ~ /[[:space:]]/) {
      L_argc = flush(argv, L_argc, L_token)
      L_token = ""
      continue
    }
    if (L_char ~ /[;&|()]/) {
      L_argc = flush(argv, L_argc, L_token)
      parse_command(argv, L_argc)
      for (L_j in argv) {
        delete argv[L_j]
      }
      L_argc = 0
      L_token = ""
      continue
    }
    L_token = L_token L_char
  }
  L_argc = flush(argv, L_argc, L_token)
  parse_command(argv, L_argc)
}
