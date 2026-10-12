---
paths:
  - "*.ps1"
---

# PowerShell

## Defaults

```powershell
Set-StrictMode -Version 'Latest'
$ErrorActionPreference = 'Stop'
```

- Use full cmdlet names and named parameters.

---

## Pipelines

```powershell
$existing = @(
    $paths | Where-Object { Test-Path -LiteralPath $_ }
)
$searchPath = $existing | Join-String -Separator ([IO.Path]::PathSeparator)
```

- Compose object pipelines with `Where-Object` and `ForEach-Object`.

- Convert objects to text only at the output boundary.

- Wrap pipeline results in `@(...)` when callers need an array even with zero or one result.

- Suppress incidental method results with `$null = ...` or `Out-Null` so they do not become function output.

---

## Command Arguments

```powershell
$options = @{
    LiteralPath = $source
    Destination = $destination
    Recurse = $true
}
Copy-Item @options
```

- Use hashtable splatting for named parameters and array splatting for positional or native-command arguments.

- Use `& $command @arguments` to invoke a command held in a variable.

- Use splatting instead of backtick line continuations or assembled command strings.

---

## Null Comparisons

- Put `$null` on the left, as in `$null -eq $value`, to avoid collection-filtering semantics.
