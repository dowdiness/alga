# TODO

Active backlog for alga. Each item links to its source; non-trivial items should get a plan in `docs/plans/`.

## Active

- **DenseGraph promotion** — `DenseGraph` is proven (8–23x) and already `pub(all)` in `src/dense_graph.mbt` with `DirectedGraph` impl. Verify API design is finalized and close out remaining experiment-only code. Source: [EXPERIMENT_REPORT.md](../src/experiment/EXPERIMENT_REPORT.md#what-remains)

## Investigate

- **Zero-copy graph adaptors** — `Reversed[G]`, `NodeFiltered[G]` implementing `DirectedGraph` without allocation. Enables generic SCC (no transpose copy) and cheap subgraph views. Source: [petgraph analysis](specs/2026-04-01-petgraph-analysis.md#1-zero-copy-graph-adaptors)
- **DFS edge classification** — `dfs_classify` reporting `TreeEdge`, `BackEdge`, `CrossForwardEdge`, `Finish`. Makes DFS a universal building block for cycle detection, bridges, etc. Source: [petgraph analysis](specs/2026-04-01-petgraph-analysis.md#2-dfs-edge-classification)
- **Tarjan SCC** — Single-pass, no transpose required. Would lift the "SCC is AdjacencyMap-only" limitation. Source: [petgraph analysis](specs/2026-04-01-petgraph-analysis.md#3-tarjan-scc-single-pass-no-transpose)
- **Traversal control flow** — Early termination for callbacks (`Bool` return or `ControlFlow` enum). Fixes O(V) `has_vertex` scan. Source: [petgraph analysis](specs/2026-04-01-petgraph-analysis.md#4-traversal-control-flow)
- **GenCounter for visited sets** — Proven 2.4–5.5x faster than `Array[Bool]`, but production algorithms still use `Array[Bool]`. Tied to DenseGraph decision (requires dense vertex IDs). Source: [EXPERIMENT_REPORT.md](../src/experiment/EXPERIMENT_REPORT.md#what-remains)

## Done

- **~~Condensation~~** — `AdjacencyMap::condensation() -> (AdjacencyMap, Map[Int, Int])`. Collapse SCCs into a DAG. Closes [#9](https://github.com/dowdiness/alga/issues/9)
- **~~Topological levels~~** — `topo_levels(graph) -> Map[Int, Int]?`. Longest-path distance from sources, for glitch-free reactive scheduling. Closes [#8](https://github.com/dowdiness/alga/issues/8)
- **~~Multi-source BFS/DFS~~** — `bfs_fold_multi`, `dfs_fold_multi`, `reachable_multi`. Frontier-based traversal from multiple starts. Closes [#7](https://github.com/dowdiness/alga/issues/7)
- **~~has_vertex trait method + default vertex_count~~** — Added `has_vertex` and defaulted `vertex_count` on `DirectedGraph`. Only 2 methods required now. `toposort_subset` filters invalid vertices. Closes [#20](https://github.com/dowdiness/alga/issues/20)
- **~~Show/Debug for Graph and DenseGraph~~** — Added `Show` and `Debug` impls for `Graph`, `DenseGraph`, and `AdjacencyMap`. Closed [#11](https://github.com/dowdiness/alga/issues/11)
- **~~Property-based tests for algebraic graph laws~~** — 8 property tests (100 random cases each) verifying all Mokhov 2017 axioms using `moonbitlang/quickcheck`. Also fixed a shared-mutable-array bug in `to_adjacency_map`. Closes [#14](https://github.com/dowdiness/alga/issues/14)
- **~~AdjacencyMap::edge confusing logic~~** — Simplified redundant `contains` check. Closed [#15](https://github.com/dowdiness/alga/issues/15)
- **~~indegree/outdegree convenience functions~~** — Generic over `DirectedGraph`. outdegree O(degree), indegree O(V+E). Closes [#12](https://github.com/dowdiness/alga/issues/12)
- **~~Clean up experiment files~~** — Already resolved in [#17](https://github.com/dowdiness/alga/pull/17). Closed [#16](https://github.com/dowdiness/alga/issues/16)

## Won't Do (unless revisited)

- **Trait-based GraphFolder** — Closure overhead from `for_each_successor` callback is real (1.8x) but deprioritized. Bigger wins already captured. Source: [EXPERIMENT_REPORT.md](../src/experiment/EXPERIMENT_REPORT.md#what-remains)
