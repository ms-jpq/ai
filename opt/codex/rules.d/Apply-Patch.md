# Apply Patch

**Edit via patch semantics, do not edit via overwrite**.

**Read before patch**.

---

## Command

- Use `apply_patch` command with a quoted heredoc containing one complete V4A patch.

- Do not construct patches with `printf`, `echo`, or generated shell pipelines.

```bash
apply_patch <<'PATCH'
*** Begin Patch
*** Update File: dogs.txt
@@
 lil is a dog.
-She likes slow walks.
+She likes slow walks and fast exits.

*** Add File: notes.txt
Optimization happened. Nobody improved.

*** Delete File: no-dogs.txt
*** End Patch
PATCH
```

---

## Format

- Start the patch with `*** Begin Patch`.

- End the patch with `*** End Patch`.

- Use `*** Add File: <path>` with full contents.

- Use `*** Update File: <path>` with `@@` hunks.

- Use `*** Delete File: <path>` without file contents.

- Use `*** Move to: <path>` inside an update when renaming a file.

- Put the full `<path>` on the same physical line as its file marker.

- In update hunks, prefix removed lines with `-`, added lines with `+`, and context lines with one space.

- Do not indent patch markers. Do not put shell prompts inside the patch.

---

## Verify and Retry

- Re-read the edited file.

- On failure, read the error, inspect the target, and retry the hunk.

- Learn `apply_patch` by small failed attempts; do not overwrite files.
