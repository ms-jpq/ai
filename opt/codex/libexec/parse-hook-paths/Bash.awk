#!/usr/bin/env -S -- awk -f

BEGIN {
  if (! length(APPLY_PATCH_AWK)) {
    exit 2
  }
  APPLY_PATCH_COMMAND = shell_quote(APPLY_PATCH_AWK)
}

{
  sub(/\r$/, "", $0)
  if (IN_PATCH) {
    print | APPLY_PATCH_COMMAND
    if ($0 == "*** End Patch") {
      if (close(APPLY_PATCH_COMMAND)) {
        exit 2
      }
      IN_PATCH = 0
      APPLY_PATCH = 0
    }
    next
  }
  if (APPLY_PATCH && $0 == "*** Begin Patch") {
    print | APPLY_PATCH_COMMAND
    IN_PATCH = 1
    next
  }
  if (APPLY_PATCH) {
    APPLY_PATCH = 0
  }
  scan_commands($0)
}

END {
  if (IN_PATCH && close(APPLY_PATCH_COMMAND)) {
    exit 2
  }
}

function command_name(command)
{
  sub(/^.*\//, "", command)
  return command
}

function command_start(argv, argc, L_i)
{
  if (! argc) {
    return 0
  }
  L_i = 1
  while (L_i <= argc && argv[L_i] ~ /^[[:alpha:]_][[:alnum:]_]*=/) {
    L_i++
  }
  if (argv[L_i] == "command") {
    L_i++
    while (argv[L_i] == "-p") {
      L_i++
    }
    if (argv[L_i] ~ /^-[vV]+$/) {
      return 0
    }
    if (argv[L_i] == "--") {
      L_i++
    }
  }
  if (L_i > argc) {
    return 0
  }
  return L_i
}

function emit(path)
{
  if (length(path)) {
    printf "%s%c", path, 0
  }
}

function flush(argv, argc, token)
{
  if (length(token)) {
    argv[++argc] = token
  }
  return argc
}

function has_heredoc(argv, argc, start, L_i)
{
  for (L_i = start + 1; L_i <= argc; L_i++) {
    if (argv[L_i] ~ /^[0-9]*<</) {
      return 1
    }
  }
  return 0
}

function parse_command(argv, argc, L_command, L_has_script, L_i, L_name, L_operator, L_option, L_option_arg, L_target)
{
  L_command = command_start(argv, argc)
  if (! L_command) {
    return
  }
  L_name = command_name(argv[L_command])
  if (L_name == "apply_patch" && has_heredoc(argv, argc, L_command)) {
    APPLY_PATCH = 1
    return
  }
  if (! READ_TOO || L_name != "sed") {
    return
  }
  L_has_script = 0
  for (L_i = L_command + 1; L_i <= argc; L_i++) {
    if (argv[L_i] ~ /^([0-9]*<|<>)/) {
      L_operator = argv[L_i]
      L_target = L_operator
      sub(/^[0-9]*(<<<|<<|<>|<&|<)/, "", L_target)
      if (! length(L_target) && ++L_i <= argc) {
        L_target = argv[L_i]
      }
      if (L_operator !~ /<</) {
        emit(L_target)
      }
      continue
    }
    if (argv[L_i] ~ /^([0-9]*>|>&)/) {
      L_target = argv[L_i]
      sub(/^[0-9]*(>>?|\|>|>&)/, "", L_target)
      if (! length(L_target)) {
        L_i++
      }
      continue
    }
    if (argv[L_i] == "--") {
      while (++L_i <= argc) {
        if (! L_has_script) {
          L_has_script = 1
        } else {
          emit(argv[L_i])
        }
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
    if (argv[L_i] ~ /^-[^-]+/) {
      L_option = substr(argv[L_i], 2)
      L_option_arg = L_option
      sub(/^[^ef]*/, "", L_option_arg)
      if (substr(L_option_arg, 1, 1) == "e") {
        L_has_script = 1
        if (length(L_option_arg) == 1) {
          L_i++
        }
      } else if (substr(L_option_arg, 1, 1) == "f") {
        L_has_script = 1
        L_target = substr(L_option_arg, 2)
        if (! length(L_target) && ++L_i <= argc) {
          L_target = argv[L_i]
        }
        emit(L_target)
      }
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

function scan_commands(line, argv, L_argc, L_char, L_escaped, L_i, L_j, L_next, L_quote, L_token)
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
    if (L_char == "#" && ! length(L_token)) {
      break
    }
    if (L_char ~ /[[:space:]]/) {
      L_argc = flush(argv, L_argc, L_token)
      L_token = ""
      continue
    }
    if (L_char == "<" || L_char == ">") {
      if (L_token !~ /^[0-9]+$/) {
        L_argc = flush(argv, L_argc, L_token)
        L_token = ""
      }
      L_token = L_token L_char
      L_next = substr(line, L_i + 1, 1)
      while (L_next == L_char || L_next == "&" || L_next == "|" || (L_char == "<" && L_next == ">")) {
        L_token = L_token L_next
        L_i++
        L_next = substr(line, L_i + 1, 1)
      }
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

function shell_quote(value)
{
  gsub(/'/, "'\\''", value)
  return ("'" value "'")
}
