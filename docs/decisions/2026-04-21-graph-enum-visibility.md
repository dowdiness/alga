# Graph enum visibility — keep `pub(all)`

**Date:** 2026-04-21
**Status:** Accepted

## Question

`moon ide analyze` flags `pub(all) enum Graph` in `src/graph_expr.mbt` with the hint *"(all) or (open) can be removed"* — i.e., `pub` alone would satisfy the compiler for current in-repo usage. Should we narrow to `pub` (or `pub(open)`) before cutting v0.1.0?

## Decision

Keep `pub(all)`. Treat the linter hint as a false positive for this type.

## Why

**1. Graph is the free algebra — its value proposition *is* external pattern matching.**

From `src/graph_expr.mbt:1–48`: Graph preserves the construction history precisely so that external code can fold it into any target algebra (AdjacencyMap, vertex count, edge list, visualization, custom IR…). That requires downstream packages to both construct values with bare constructors and pattern-match on them exhaustively. Both need `pub(all)`.

**2. A cross-package consumer already proves the need (and the experiment package confirms it).**

`src/experiment/foldg_variants.mbt` and `src/experiment/foldg_variants_test.mbt` (archived June 2026 in the DenseGraph promotion cleanup; report at `docs/archive/2026-03-31-perf-experiment-report.md`) pattern-matched on `@alga.Graph::Empty | Vertex | Overlay | Connect` from a separate package, and `src/graph_expr_qc.mbt` continues to construct and match on Graph variants in property tests. Narrowing to `pub` would break property tests and any external consumers using algebraic fold. The analyzer's "can be removed" looks at *"is (all) strictly required for a single match form?"*, not *"do external consumers construct and match here?"*

**3. `pub(open)` is semantically wrong.**

Graph's four-variant signature (`Empty | Vertex | Overlay | Connect`) is fixed by Mokhov 2017 — the algebra wouldn't hold if downstream added variants. `pub(open)` would also force every pattern match, forever, to carry a wildcard arm.

**4. No cost to keeping `pub(all)`.**

The type is stable; "downstream may bind to constructors" is exactly the contract we want. We gain nothing by narrowing except silencing the linter.

## Non-goals

This decision does *not* extend to other `pub(all)` types in the codebase — each needs its own evaluation. `DfsEvent` was evaluated separately and landed at the same verdict for a closely related reason (external pattern-match requires visible constructors) — see [DfsEvent enum visibility](2026-04-21-dfs-event-visibility.md).

## Reference

- Andrey Mokhov, [*Algebraic Graphs with Class*](https://dl.acm.org/doi/10.1145/3122955.3122956) (Haskell Symposium 2017)
- `src/graph_expr.mbt` — definition and docstring
- `src/experiment/foldg_variants.mbt` — cross-package consumer (archived June 2026; report at `docs/archive/2026-03-31-perf-experiment-report.md`)
