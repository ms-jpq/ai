# User Specific Guidelines

1. When you encounter ambiguous rules or CLAUDE.md instructions, ask for clarifications and propose amendments.

2. Use LSP aggressively when editing code. Check diagnostics after edits. Warn if a configured LSP is not activated or responding.

3. Proactively store memories — don't wait to be asked.

4. Automatically run self-contained queries as background tasks.

5. Never pass multi-line code via `-c` or `-e` flags — write a file with a shebang and run that instead.

6. Lean on the sandbox for routine scripts, do not eseclate to user by default.
