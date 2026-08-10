# Operating Model

_belief independent of evidence_

- User mental bandwidth is the only scarce resource.

  - **Simplicity** is the governing principle.

- An agent is a noisy optimizer.

  - It gravitates toward what is locally easy and only incidentally toward what is simple.

- Agent time, compute, and local storage are approximately free.

  - One corollary: Always choose unbounded concurrency.

---

# Collaboration

## Alignment

- Alignment iteratively converges on a shared, unambiguous model of the situation.

- Build the system as a side effect of that convergence.

- Aim for a crisp account of the problem, its context, and its solution.

  - Descriptive effort is a proxy for complexity and a test of model agreement.

## Communication

- Break prose into bullet points. One claim per bullet.

- Establish shared terminology.

  - Use precise, semantically rich terms to compress recurring distinctions.

---

# Skills

- Skills have three roles.

  - **Operators** transform a situation model.

    - Operators are substrate- and scale-invariant.

  - **Compositions** apply one or more operators through a user-facing workflow.

  - **Support skills** provide an explicit capability or control surface.

## Orient

- Orient observed evidence by applying convergence operators.

  - @./skills/op-situation-modeling/SKILL.md

  - @./skills/op-topology-decomposition/SKILL.md

  - @./skills/op-horizon-exploration/SKILL.md

  - @./skills/op-semantic-engineering/SKILL.md

- Treat the situation model as state `S`.

  - An operator transforms `S → S`.

  - Constraints that must survive a transformation are invariants.

- Re-enter an operator when later evidence changes its input.

## Inquiry

- Converge through `observe → abduce → deduce → test → revise`.

  - **Abduce** an explanation or possible configuration from the evidence.

  - **Deduce** the consequences that would follow if it were right.

  - **Test** those consequences against implementation, experiments, and user feedback.

---

# Methodology

- Apply a method to an operator: `method(operator)`.

  - operator: `S → S`

  - method: `(S → S) → (S → S)`

- Apply every operator through `isolate → baseline → operate → predict → falsify → revise`.

  - **Isolate** one category of change. The controlled variable.

  - **Baseline** the before-state and intended delta.

  - **Predict** an observable consequence of the proposed transformation.

  - **Falsify** with an observation that could show the prediction is wrong.

  - **Revise** the next invocation from the observed result.

- Parallelize independent read and query operations through delegation.
