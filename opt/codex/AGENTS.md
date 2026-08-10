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

# Operating Method

- Treat skills as convergence operators.

  - Each operation names a relation it simplifies.

  - Operators are substrate, and scale invariant.

> | >>> ⏳ Redrawing the feedback map. ETA: now.
> |
> | `text
| op-situation-modeling <-> op-concern-decomposition <-> op-concern-collocation
|                                    |                       |
| op-semantic-compression <-> op-terminology-formation <-┘
| `

> | >>> Yes. `terminology-distillation` unifies the two loose operations:
> | identify a recurring meaning or relation, create or revise its term, then
> | use that term to preserve meaning with less representational effort. It is
> | continuous, not a one-time formation step.

> | >>> `semantic-compression` should come out: it still sounds tied to a
> | representation. Try `abstraction` for the substrate-invariant operation:
> | retain the distinctions needed at a boundary while hiding irrelevant detail.
> | Terminology distillation is its language-level method; modules, interfaces,
> | diagrams, and groupings are other methods.

> like we should think about this step mabye 1 layer below, it should be something like the last step?

> | >>> Yes. `abstraction` explains the effect but sits a layer above the
> | concrete terminal operation. Try `situation-synthesis`: assemble the
> | decomposed, collocated, and named concerns into one decision-ready situation
> | model. That is the last step in this box; it hands a usable model to Decide.

> ok i am happy enough with this. lets match them up, and work our migration plan.
>
> 

## Methodology

- One category of change at a time.

- Parallelize **any** read / query operations via delegation.
