# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] — 2026-06-22

### ⚠️ Breaking changes

- `DirectedGraph` trait decomposed into finer-grained `VertexSet` and
  `Successors` capability traits. `DirectedGraph` remains as a convenience
  alias (`VertexSet + Successors`). Algorithms that only need edge
  traversal (`dfs_fold`, `bfs_fold`, `reachable`, `outdegree`) now accept
  `[G : Successors]` instead of requiring the full `DirectedGraph` bound.
  Existing `impl DirectedGraph` blocks must be split into separate
  `VertexSet` and `Successors` blocks.

### Added

- **`DenseGraph::dfs_events()`** — specialized DFS event iterator using
  `FixedArray[Int]` (0=white, 1=gray, 2=black) for O(1) vertex state
  lookups instead of the generic `Map[Int, Bool]` (O(log V)).
- **`DenseGraph::is_reachable_gen(from, to, marks, gen)`** — early-exit
  reachability query using a reusable `FixedArray[Int]` + generation
  counter, eliminating per-call visited-set allocation.
- **`DenseGraph::reachable_gen(start, marks, gen)`** — full reachability
  with reusable generation-counter buffer. ~1.2× faster than repeated
  `DenseGraph::reachable` on deep graphs (chain_1000, wasm-gc --release).
- **`SuccessorsOnly` test helper** — conformance test verifying that
  `reachable`, `dfs_fold`, `bfs_fold`, and `outdegree` work without
  requiring `VertexSet`.

### Removed

- **`src/experiment/` package** — performance experiment code (visited-set
  variants, foldg variants, DenseGraph iteration archeology) archived.
  Experiment report preserved at `docs/archive/2026-03-31-perf-experiment-report.md`.

### Fixed

- `conformance.mbt`: replaced `HashSet.fold()` with manual `each()` loop
  (the `fold` method does not exist on `HashSet`).

## [0.3.1] — 2026-06-22

### Changed

- Migrated to current MoonBit `moon.mod` DSL and refreshed the
  quickcheck dependency (0.11.2 → 0.14.0).

### Fixed

- Stale relative link in the CST traversal experiment report
  repointed to the preserved copy at
  `loom/docs/performance/2026-03-30-cst-traversal-tiers.md`.

## [0.3.0] — 2026-04-24

### Added

- **Cycle diagnostics** — `find_cycle(g) -> Array[Int]?` returns one
  witness cycle (a path `[v0, …, vk]` with closing edge `vk → v0`), and
  `toposort_or_cycle(g) -> Result[Array[Int], Array[Int]]` returns the
  topological order on success or a cycle witness on failure (for
  contract-conformant graphs; returns `Err([])` if a non-conformant
  impl leaves `toposort` and `find_cycle` disagreeing). More informative
  than `has_cycle` / `toposort` for error reporting in reactive-graph
  libraries, movable-tree CRDTs, and build systems.
- **Local reachability queries** — `is_reachable(g, from, to) -> Bool`
  early-exits as soon as `to` is discovered instead of materializing
  the full reachable set. `would_create_cycle(g, u, v) -> Bool`
  predicts whether adding edge `u → v` would create a cycle (self-loop
  case handled). Avoids constructing the hypothetical graph and
  early-exits as soon as a back-edge is found — cheaper than
  `has_cycle` on a materialized graph, though still traversal-scale
  in the worst case.
- **Generic Kosaraju SCC** — `kosaraju_scc(g)` now works on any
  `DirectedGraph + Predecessors`, not just `AdjacencyMap`. The backward
  DFS walks `predecessors` directly instead of materializing a
  transposed graph. `AdjacencyMap::scc` is preserved as a thin wrapper
  — existing callers are unaffected. (`AdjacencyMap::transpose()` was
  already O(1) via bidirectional storage, so `AdjacencyMap` callers
  never paid a transpose-materialization cost; the win is that generic
  callers now get the same cheap path.)
- **Conformance test kit** — `check_conformance(g)` and
  `check_predecessors_conformance(g)` return an `Array[String]` of
  violation messages (empty = conformant) for adopters to call on
  their own `DirectedGraph` / `Predecessors` implementations. Covers
  eight laws: `iter` uniqueness, successor-set closure, `has_vertex`
  consistency (spot-checked, not exhaustively proven),
  `vertex_count` agreement, successor / predecessor
  dedup, `each_*` default-vs-override agreement, and
  predecessor / successor symmetry. Test-time only — catches contract
  violations that algorithms would otherwise silently misbehave on.

### Changed

- Top-level comment in `src/scc.mbt` updated — Kosaraju is no longer
  described as AdjacencyMap-specific.

## [0.2.0] — 2026-04-21

### ⚠️ Breaking changes

- `DirectedGraph` trait required methods changed from callback-based
  (`each_vertex` / `each_successor`) to iter-based
  (`iter() -> Iter[Int]` / `successors(v) -> Iter[Int]`). The old callback
  methods remain as defaulted helpers, but existing `impl DirectedGraph`
  blocks must be updated to provide `iter` and `successors`.

### Added

- **`Predecessors` capability trait** and bidirectional adjacency storage
  on `AdjacencyMap` and `DenseGraph` — efficient reverse-direction queries
  without a separate data structure.
- **`Reversed[G]` zero-cost graph adaptor** — wraps any `DirectedGraph`
  implementing `Predecessors` and presents the edge-reversed view with
  no copying.
- **`dfs_events`** — pull-based DFS yielding `DfsEvent` values (`Discover`,
  `Finish`, `TreeEdge`, `BackEdge`, `CrossForwardEdge`) for full edge
  classification.
- **`tarjan_scc`** — generic Tarjan strongly-connected-components
  algorithm over any `DirectedGraph`, single-pass with no transpose.
  Complements the existing Kosaraju implementation.
- **`condensation`** — condenses a graph into the DAG of its SCCs.
- **`topo_levels`** — topological layer assignment via longest-path
  distance from sources; useful for scheduling and glitch-free reactive
  systems.
- **Multi-source BFS and DFS** — `bfs_fold_multi`, `dfs_fold_multi`,
  `reachable_multi` accept an `Array[Int]` seed set rather than a single
  start vertex.
- **`has_vertex`** method and default `vertex_count` on the
  `DirectedGraph` trait. `toposort_subset` now filters out-of-range
  vertices via `has_vertex` instead of panicking.
- **`indegree` / `outdegree`** convenience functions generic over
  `DirectedGraph`.
- **`toposort_subset`** — topological order of an induced vertex
  subgraph.
- **`DenseGraph`** — dense-vertex representation (`Array[Array[Int]]`)
  with bidirectional storage, O(1) vertex-range checks, and specialized
  DFS / toposort / Kosaraju-SCC routines that bypass trait dispatch for
  hot paths (≈ 8–23× faster than `AdjacencyMap` on the benchmarked
  workloads).
- **`Show` and `Debug` impls** for `Graph`, `AdjacencyMap`, and
  `DenseGraph`.

### Changed

- (BREAKING — see above) `DirectedGraph` trait migrated to iter-based
  required methods.
- Experiment/benchmark code moved into a separate `src/experiment/`
  sub-package, keeping the library core free of benchmark noise.
- `DenseGraph` public surface narrowed — the struct is now `pub` (not
  `pub(all)`), and unused standalone query methods
  (`vertex_count`/`has_vertex`/`has_edge`/`edge_count`) plus the
  leaky-buffer `reachable_with` API were removed.
- Unused trait bounds on `reversed()` and the `Predecessors for
  Reversed[G]` impl narrowed to match actual use.

### Fixed

- DFS and SCC traversals are iterative (explicit stack) — no stack
  overflow on deep graphs (verified on graphs up to 10 000 vertices
  in benchmarks; SCC correctness verified with property tests
  up to 200 vertices).
- Negative modulo bias and `Int::MIN` overflow in the `Arbitrary`
  instance used by property-based tests.
- Non-deterministic vertex ordering in `toposort_subset` output.
- Redundant `contains` check in `AdjacencyMap::edge`.

### Performance

- `DenseGraph` provides substantially faster DFS / SCC / adjacency
  queries than `AdjacencyMap` on graphs with dense, 0..n-1 vertex IDs.
- `dfs_events` internal state simplified to a `Map[Int, Bool]` encoding,
  reducing per-traversal allocations.

## [0.1.0] — 2026-03-23

Initial release — algebraic graphs for MoonBit, in the tradition of
Haskell's [`algebraic-graphs`](https://hackage.haskell.org/package/algebraic-graphs)
by Andrey Mokhov.
