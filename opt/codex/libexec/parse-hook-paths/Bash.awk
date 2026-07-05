#!/usr/bin/env -S -- awk -f

{
  split_commands($0)
}

function emit(L_path)
{
  printf "%s%c", L_path, 0
}

function flush_token(L_argv, L_argc, L_token)
{
  if (length(L_token)) {
    L_argv[++L_argc] = L_token
  }
  return L_argc
}

function parse(command, argv, L_argc, L_command, L_has_script, L_i)
{
  L_command = command
  sub(/^[[:space:]]*[(]+[[:space:]]*/, "", L_command)
  sub(/[[:space:]]*[)]+[[:space:]]*$/, "", L_command)
  L_argc = tokenize(L_command, argv)
  if (! L_argc) {
    return
  }
  L_command = 1
  if (argv[L_command] == "command") {
    L_command++
  }
  if (argv[L_command] != "sed") {
    return
  }
  L_has_script = 0
  for (L_i = L_command + 1; L_i <= L_argc; L_i++) {
    if (argv[L_i] == "--") {
      while (++L_i <= L_argc) {
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
      if (++L_i <= L_argc) {
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

function split_commands(line, L_command, L_char, L_escaped, L_i, L_quote)
{
  L_command = ""
  L_quote = ""
  L_escaped = 0
  for (L_i = 1; L_i <= length(line); L_i++) {
    L_char = substr(line, L_i, 1)
    if (L_escaped) {
      L_command = L_command L_char
      L_escaped = 0
      continue
    }
    if (L_char == "\\" && L_quote != "'") {
      L_command = L_command L_char
      L_escaped = 1
      continue
    }
    if (L_quote != "") {
      L_command = L_command L_char
      if (L_char == L_quote) {
        L_quote = ""
      }
      continue
    }
    if (L_char == "'" || L_char == "\"") {
      L_command = L_command L_char
      L_quote = L_char
      continue
    }
    if (L_char ~ /[;&|]/) {
      parse(L_command)
      L_command = ""
      continue
    }
    L_command = L_command L_char
  }
  parse(L_command)
}

function tokenize(command, argv, L_argc, L_char, L_escaped, L_i, L_quote, L_token)
{
  for (L_i in argv) {
    delete argv[L_i]
  }
  L_argc = 0
  L_quote = ""
  L_token = ""
  for (L_i = 1; L_i <= length(command); L_i++) {
    L_char = substr(command, L_i, 1)
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
      L_argc = flush_token(argv, L_argc, L_token)
      L_token = ""
      continue
    }
    L_token = L_token L_char
  }
  L_argc = flush_token(argv, L_argc, L_token)
  return L_argc
}
