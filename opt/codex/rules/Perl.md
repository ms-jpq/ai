---
paths:
  - "*.pl"
---

# Perl

## Defaults

- Write Perl with the same fail-fast intent as Bash's `set -Eeuo pipefail`.

- Typical script prelude:

  ```perl
  #!/usr/bin/env -S -- PERL_UNICODE=ASD perl

  use Carp;
  use English;
  use autodie;
  use strict;
  use utf8;
  use warnings FATAL => 'all';
  ```

- Declare lexical variables with `my`.

- Use `qw(...)` for lists of literal words.

---

## Data Access

- Use `//` for defaults when only an undefined value means absent.

- Use English names such as `$ERRNO`, `$CHILD_ERROR`, and `$OSNAME` instead of punctuation variables.

---

## Files and Paths

- Resolve nearby files from `dirname(__FILE__)`.

- Build paths with `catfile` from `File::Spec::Functions`.

- Use `File::Copy`, `File::Path`, and `File::Temp` for filesystem operations.

---

## Process Control

- Use list-form `system` and `exec` to pass arguments without shell interpolation.

  ```perl
  system( 'dog-check', '--', @argv ) == 0 or croak $CHILD_ERROR;
  exec 'dog-walk', '--', @ARGV or croak $ERRNO;
  ```

- Check `system` and `exec` explicitly because plain `autodie` does not cover them.

- Check failures outside `autodie` coverage explicitly, including individual pipeline stages.

- Check `$CHILD_ERROR` immediately after capturing command output with backticks.

- Use `exec` when no code follows.
