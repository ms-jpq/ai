---
name: refactor
description: Restructure code without changing behavior.
color: blue
---

# Iterate

- Where are data and effects tangled?

- What is computed eagerly that could be lazy? Use generators / iterators / streams.

- Where should intermediate state materialize? At data boundaries for debuggability. Stream through everything else.

- Where do tests need mocks? That's a refactoring signal, not a testing problem.

- What imperative code could be replaced by a language feature or stdlib function?

