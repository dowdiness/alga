# TODO

Active backlog for alga. Each item links to its source; non-trivial items should get a plan in `docs/plans/`.

## Active

- **DenseGraph promotion** — `DenseGraph` is proven (8–23x) and already `pub(all)` in `src/dense_graph.mbt` with `DirectedGraph` impl. Verify API design is finalized and close out remaining experiment-only code. Source: [EXPERIMENT_REPORT.md](../src/experiment/EXPERIMENT_REPORT.md#what-remains)

## Investigate

- **Split `DirectedGraph` into `VertexSet` + `Successors`** — Crisper contract: algorithms needing exhaustive iteration (toposort, SCC, `topo_levels`) require both; local queries (`reachable`, `is_reachable`, `would_create_cycle`) require only `Successors`. Lets adopters honestly impl successor-only graphs (e.g. pure functions with no enumerable vertex set). Wider refactor than the conformance kit — touches every impl. Revisit after the conformance kit lands and if `loom/incr` or another adopter hits a concrete successors-only case. Source: [PR #31 review](https://github.com/dowdiness/alga/pull/31)
- **NodeFiltered graph adaptor** — `NodeFiltered[G]` implementing `DirectedGraph` without allocation. Cheap subgraph views for scope-restricted traversals. Source: [petgraph analysis](specs/2026-04-01-petgraph-analysis.md#1-zero-copy-graph-adaptors)
- **Traversal control flow** — Early termination for push-style callbacks beyond what `Iter::contains` provides. `has_vertex` short-circuiting is now solved by the iter-based trait. Remaining: `dfs_fold`/`bfs_fold` callback could benefit from `ControlFlow` enum. Source: [petgraph analysis](specs/2026-04-01-petgraph-analysis.md#4-traversal-control-flow)
- **GenCounter for visited sets** — Proven 2.4–5.5x faster than `Array[Bool]`, but production algorithms still use `Array[Bool]`. Tied to DenseGraph decision (requires dense vertex IDs). Source: [EXPERIMENT_REPORT.md](../src/experiment/EXPERIMENT_REPORT.md#what-remains)
- **Specialized `DenseGraph::dfs_events`** — Generic `dfs_events` uses `Map[Int, Bool]` for state (O(log V) per op). A `DenseGraph`-specialized version could use `FixedArray[Bool]` for O(1) lookups, matching the pattern of `DenseGraph::reachable` and `DenseGraph::scc`. Tied to DenseGraph promotion. Source: code review of `dfs_events`
- **DFS event test helpers** — `dfs_events` tests repeat a count/filter-by-variant pattern 9 times across `dfs_test.mbt` and `graph_expr_qc.mbt`. If more `dfs_events`-consuming tests are added, extract shared helpers (e.g., `count_events(events, pred)`, `collect_edges(events, variant)`). Source: code review of `dfs_events`

## Done

- **~~Conformance test kit for `DirectedGraph` impls~~** — `check_conformance(g) -> Array[String]` and `check_predecessors_conformance(g)` verify laws A–G (iter uniqueness, successor closure, has_vertex consistency, vertex_count agreement, successor/predecessor dedup, each_* defaults-vs-override agreement, forward/backward edge symmetry). Addresses the contract-violation risk Codex flagged on PR #31.
- **~~Cycle diagnostics + generalized Kosaraju~~** — `is_reachable`, `would_create_cycle`, `find_cycle`, `toposort_or_cycle` (`Result[order, witness]`), and `kosaraju_scc` generic over `DirectedGraph + Predecessors`. Source: [PR #31](https://github.com/dowdiness/alga/pull/31)
- **~~Reversed graph adaptor~~** — `Reversed[G]` zero-cost newtype + `Predecessors` capability trait + bidirectional adjacency in `AdjacencyMap`/`DenseGraph`. `transpose()` is now O(1). Source: [spec](specs/2026-04-01-reversed-graph-adaptor-design.md)
- **~~DFS edge classification~~** — `dfs_events(graph) -> Iter[DfsEvent]` with 5 events: Discover, Finish, TreeEdge, BackEdge, CrossForwardEdge. Pull-based iterator, generic over `DirectedGraph`. Source: [spec](specs/2026-04-01-dfs-edge-classification-design.md)
- **~~Iter-based DirectedGraph trait + Tarjan SCC~~** — Migrated trait from CPS callbacks (`for_each_vertex`/`for_each_successor`) to `Iter[Int]`-based (`iter`/`successors`). Added `tarjan_scc` generic over `DirectedGraph` — single-pass, no transpose. `has_vertex` now short-circuits via `Iter::contains`. Source: [spec](specs/2026-04-01-iter-based-trait-and-tarjan-design.md)
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
