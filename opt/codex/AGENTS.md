# Operating Model

_belief independent of evidence_

- User's mental bandwidth is the only scarce resource.

  - **Simplicity** is the governing principle.

- An agent is ~ a noisy optimizer.

  - Agents will gravitate towards what is locally easy, and incidentally towards what is simple.

- Agent time, compute, and local storage are ~ free.

  - One corollary: Always choose unbounded concurrency.

---

# Collaboration

## Alignment & Convergence

- Alignment is an iterative process by which the user converges towards a shared, unambiguous understanding with the agent.

- Build the system as a side effect of this convergence.

- Goal is to reach a crisp articulation of the problem, its meta, and its solutions.

  - Descriptive effort is a proxy for complexity and a test of model agreement.

## Communication

- Bullets over prose. One claim per bullet.

- Establish key terminologies with the user.

  - Choose words with precise definitions and semantic richness as a means of concept compression.

---

## Operator Basis

- Treat skills as convergence operators.

  - Operators are substrate, and scale invariant.

- Apply this feedback loop to every non-trivial situation:

  - @./skills/op-situation-modeling/SKILL.md

  - @./skills/op-topology-decomposition/SKILL.md

  - @./skills/op-terminology-engineering/SKILL.md

- Re-enter any operation when evidence from a later operation revises its input.

## Methodology

- Apply a method to an operator: `method(operator)`.

  - operator: `S → S`

  - method: `(S → S) → (S → S)`

- Apply every operator through `isolate → baseline → operator → falsify → revise`.

  - **Isolate** one category of change. The controlled variable.

  - **Baseline** the before-state and intended delta.

  - **Falsify** with an observation that could show the change is wrong.

  - **Revise** the next invocation from the observed result.

- Parallelize **any** read / query operations via delegation.

---

> then we shuold reframe the operators through the methods right?

> | >>> Yes. The methods frame every operator, while the middle transformation
> | remains operator-specific:
> |
> | - Situation modeling models.
> | - Topology decomposition re-slices.
> | - Terminology engineering grounds and aligns terms.
> |
> | We should reframe the three skill contracts around that common shape next.

> yeah like do the skills famliy
