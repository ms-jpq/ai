---
name: op-topology-reshaping
description: Reshape dependency topology by splitting, merging, moving, and collocating concerns to remove accidental dependencies.
---

# Topology Reshaping

## Reshape

- Start from an explicit topology model.

- Re-slice the topology where evidence exposes accidental coupling or distance.

  - Split an entangled concern.

  - Merge concerns that cannot be independently understood or verified.

  - Move or collocate the parts required for one local decision.

  - Remove an accidental dependency or make an unavoidable one explicit.

- Preserve the intended external contracts unless the topology model demonstrates that they are wrong.

## Compare

- Compare the proposed topology with the current one.

  - Count concepts, boundaries, dependencies, exceptions, and remote reads.

  - Prefer the shape that leaves the next change locally understandable and verifiable.

## Verify

- Verify every changed boundary and dependency.

- Verify that the resulting execution order remains valid.

- Record retained dependencies and why they cannot be removed.
