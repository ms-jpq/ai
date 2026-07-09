# Apply Patch CLI

When using `apply_patch` for file edits. Pass a V4A patch on stdin.

---

## Prompt

- Run `apply_patch <<'PATCH'`.

- Start the patch with `*** Begin Patch`.

- End the patch with `*** End Patch`.

- Use `*** Add File: <path>` to create a file, followed by its full contents.

- Use `*** Update File: <path>` to edit a file, followed by `@@` hunks.

- In update hunks, prefix removed lines with `-`, added lines with `+`, and context lines with one space.

- Use `*** Delete File: <path>` to remove a file. Do not include file contents.

- Do not indent patch markers. Do not put shell prompts inside the patch.

### Example

```bash
apply_patch <<'PATCH'
*** Begin Patch
*** Update File: dogs.txt
@@
 Ruth is a dog.
-She likes slow walks.
+She likes slow walks and fast exits.

*** Add File: notes.txt
Optimization happened. Nobody improved.

*** Delete File: old-dogs.txt
*** End Patch
PATCH
```
