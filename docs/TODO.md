# TODO

Active backlog for alga. Each item links to its source; non-trivial items should get a plan in `docs/plans/`.

## Active

(empty)

## Done

- **DenseGraph promotion** — API verified stable; experiment package archived. Source: [perf experiment report](archive/2026-03-31-perf-experiment-report.md)
- **Conformance test kit** — `check_conformance(g) -> Array[String]` and `check_predecessors_conformance(g)`.
- **Cycle diagnostics + generalized Kosaraju** — `is_reachable`, `would_create_cycle`, `find_cycle`, `toposort_or_cycle`, `kosaraju_scc`.
- **Reversed graph adaptor** — `Reversed[G]` zero-cost newtype + `Predecessors` capability trait.
- **DFS edge classification** — `dfs_events(graph) -> Iter[DfsEvent]` with 5 event types.
- **Iter-based DirectedGraph trait + Tarjan SCC** — Migrated to iter-based required methods; added `tarjan_scc`.
- **Condensation** — `AdjacencyMap::condensation() -> (AdjacencyMap, Map[Int, Int])`.
- **Topological levels** — `topo_levels(graph) -> Map[Int, Int]?`.
- **Multi-source BFS/DFS** — `bfs_fold_multi`, `dfs_fold_multi`, `reachable_multi`.
- **has_vertex trait method** — Added `has_vertex` + defaulted `vertex_count` on DirectedGraph.
- **Show/Debug for Graph and DenseGraph** — Added impls.
- **Property-based tests** — 8 algebraic graph laws verified with `moonbitlang/quickcheck`.
- **Split DirectedGraph into VertexSet + Successors** — Traits split; all impls updated.
- **DenseGraph::dfs_events** — Specialized DFS event iterator using `FixedArray[Int]`.
- **GenCounter for visited sets** — `DenseGraph::reachable_gen` + `DenseGraph::is_reachable_gen`. Plan: [2026-06-22-gencounter-densegraph.md](plans/2026-06-22-gencounter-densegraph.md).
- **DFS event test helpers** — `count_events` and `collect_edge_pairs` in `dfs.mbt`.

## Won't Do

- **Trait-based GraphFolder** — Closure overhead deprioritized.
- **NodeFiltered graph adaptor** — No adopter. See [decisions-needed](decisions-needed.md).
- **Traversal control flow** — No adopter. See [decisions-needed](decisions-needed.md).
