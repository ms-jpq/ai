---
paths:
  - "*.go"
---

# Go

## Function Composition

- Model reusable work as small functions from one value to the next. Compose those functions instead of accumulating stateful helper objects.

- Keep I/O, mutation, and concurrency at the edges; make the composed core take values and return values or errors.

## Generics

- Use type parameters for transforms whose behavior is independent of the domain type. Keep domain-specific behavior concrete.

- Constrain a type parameter only by the operations the function performs. Compose small generic functions into the specialized workflow.
