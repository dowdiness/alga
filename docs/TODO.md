# TODO

Active backlog for alga. Each item links to its source; non-trivial items should get a plan in `docs/plans/`.

## Active

- **DenseGraph promotion** — `DenseGraph` is proven (8–23x) and already `pub(all)` in `src/dense_graph.mbt` with `DirectedGraph` impl. Verify API design is finalized and close out remaining experiment-only code. Source: [EXPERIMENT_REPORT.md](../src/experiment/EXPERIMENT_REPORT.md#what-remains)

## Investigate

- **GenCounter for visited sets** — Proven 2.4–5.5x faster than `Array[Bool]`, but production algorithms still use `Array[Bool]`. Tied to DenseGraph decision (requires dense vertex IDs). Source: [EXPERIMENT_REPORT.md](../src/experiment/EXPERIMENT_REPORT.md#what-remains)

## Done

- **~~Show/Debug for Graph and DenseGraph~~** — Added `Show` and `Debug` impls for `Graph`, `DenseGraph`, and `AdjacencyMap`. Closed [#11](https://github.com/dowdiness/alga/issues/11)
- **~~Property-based tests for algebraic graph laws~~** — 8 property tests (100 random cases each) verifying all Mokhov 2017 axioms using `moonbitlang/quickcheck`. Also fixed a shared-mutable-array bug in `to_adjacency_map`. Closes [#14](https://github.com/dowdiness/alga/issues/14)
- **~~AdjacencyMap::edge confusing logic~~** — Simplified redundant `contains` check. Closed [#15](https://github.com/dowdiness/alga/issues/15)
- **~~indegree/outdegree convenience functions~~** — Generic over `DirectedGraph`. outdegree O(degree), indegree O(V+E). Closes [#12](https://github.com/dowdiness/alga/issues/12)
- **~~Clean up experiment files~~** — Already resolved in [#17](https://github.com/dowdiness/alga/pull/17). Closed [#16](https://github.com/dowdiness/alga/issues/16)

## Won't Do (unless revisited)

- **Trait-based GraphFolder** — Closure overhead from `for_each_successor` callback is real (1.8x) but deprioritized. Bigger wins already captured. Source: [EXPERIMENT_REPORT.md](../src/experiment/EXPERIMENT_REPORT.md#what-remains)
