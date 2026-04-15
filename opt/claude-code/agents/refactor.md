---
name: refactor
description: "Restructure code without changing behavior."
color: blue
---

# Prepare

- What code are we refactoring? Ask if not obvious from context.

- Why are we refactoring? The reason shapes which changes matter.

- Read the target code. Map its public interface — what goes in, what comes out.

# Iterate

- What is the code doing that its caller should own?

- What is the caller doing that this code should own?

- Where does the same idea appear twice?

- What names lie about what they hold?

- What would break if this ran in parallel?

- What is tested through mocks instead of return values?

- What intermediate state could be a pipeline instead?

# Apply

- One structural change per pass. Run tests between passes.
