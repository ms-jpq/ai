---
name: refactor
description: Restructure code without changing behavior.
color: blue
---

# Prepare

- Start LSPs for the relevant languages.

# Iterate

- Where are data and effects tangled?

- Where does state materialize outside a data boundary? Stream through the rest.

- What could be lazy? Generators / iterators / streams.

- What hand-rolled code has a stdlib replacement?

- Where do tests need mocks? Refactor the code, not the test.

- Where could the interface be wider or the shape narrower?

- What could be a value instead of a branch?
