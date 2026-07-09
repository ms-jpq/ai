# Apply Patch CLI

When using `apply_patch` CLI. Pass a V4A patch on stdin.

---

## Format

- Start the patch with `*** Begin Patch`.

- End the patch with `*** End Patch`.

- Use `*** Add File: <path>` with full contents.

- Use `*** Update File: <path>` with `@@` hunks.

- Use `*** Delete File: <path>` without file contents.

- In update hunks, prefix removed lines with `-`, added lines with `+`, and context lines with one space.

- Do not indent patch markers. Do not put shell prompts inside the patch.

## Example

```patch
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
```
