# Performance Snapshot — 2026-03-31

WASM-GC target, `--release` mode, MoonBit compiler as of 2026-03-31.

This is a dated snapshot. New measurements go in new files; old ones are not updated.

## Current benchmarks (1,000-vertex graphs)

### AdjacencyMap (Map-based, sparse vertex IDs)

| Operation | Chain | Diamond | Notes |
|---|---|---|---|
| from_edges | 62 µs | — | O(E) amortized |
| toposort | 139 µs | 105 µs | Kahn's algorithm |
| toposort_subset (half) | 37 µs | — | Only walks induced subgraph |
| reachable (DFS) | 97 µs | 84 µs | Mark-and-reverse, explicit stack |
| BFS | 68 µs | 38 µs | Queue-based |
| has_cycle | 122 µs | — | Derived from toposort |
| SCC | 296 µs | — | Kosaraju (includes transpose) |
| condensation (acyclic) | 855 µs | — | SCC + DAG construction |
| condensation (cyclic) | 594 µs | — | Fewer components → less DAG work |
| transpose | 80 µs | — | Builds reverse adjacency |
| outdegree | 0.02 µs | 0.04 µs | O(degree), single vertex |
| indegree | 20 µs | 31 µs | O(V+E), full scan |
| topo_levels | 235 µs | 407 µs | Modified Kahn's with longest-path level tracking |
| dfs_fold_multi (3 starts) | 70 µs | — | Negligible overhead vs single-source |
| bfs_fold_multi (3 starts) | 75 µs | — | Negligible overhead vs single-source |

### DenseGraph (Array-based, dense 0..n-1 vertex IDs)

From the experiment report (same hardware, same compiler):

| Operation | Chain 1K | Speedup vs AdjacencyMap |
|---|---|---|
| DFS reachable | 6.6 µs | 14x |
| DFS reachable (10K) | 83 µs | 23x |
| BFS | 7.1 µs | 11x |
| Toposort | 13 µs | 11x |
| SCC (acyclic) | 62 µs | 7.5x |
| SCC (cyclic) | 50 µs | 10x |
| Transpose | 18 µs | 11.5x |

### Graph expressions (algebraic construction → AdjacencyMap)

| Expression | to_adjacency_map | Notes |
|---|---|---|
| path(100) | 22.5 µs | Direct edge collection, O(V+E) |
| path(1000) | 851 µs | |
| clique(50) | 91.6 µs | 17x vs recursive foldg |
| star(1000) | 413 µs | 114x vs recursive foldg |

### foldg overhead (lightweight fold, B = Int)

| Variant | path_1000 | Notes |
|---|---|---|
| foldg (recursive) | 13.1 µs | Fastest for lightweight folds |
| foldg_iter (iterative) | 36.3 µs | 2.8x slower, but stack-safe |

## Performance history

### v0.1.0 — Initial release (2026-03-29)

- `AdjacencyMap` with `Map[Int, Array[Int]]` adjacency
- `Map[Int, Bool]` visited sets
- Recursive DFS (stack overflow on deep graphs)
- Recursive `foldg` with pairwise AdjacencyMap merging → O(n²) for to_adjacency_map

### Optimization round 1 — Iterative algorithms (2026-03-29)

Commit `cede354`: converted DFS and SCC from recursive to iterative with explicit stacks.

**Impact:** Fixed stack overflow on graphs with 10K+ vertices. No performance change for normal-sized graphs.

### Optimization round 2 — Performance investigation (2026-03-30)

Commits `fa12aba`, `0998b06`: systematic benchmark-driven optimization.

**Visited sets:** Replaced `Map[Int, Bool]` with `Array[Bool]` in production algorithms.
- 2.4x faster for DFS, BFS, toposort
- GenCounter (`FixedArray[Int]` + generation) proven 1.1-1.4x better for repeated calls, but not yet applied to production (requires dense vertex IDs)

**DFS mark-and-reverse:** Eliminated per-vertex temporary array allocation in `dfs_fold`.
- 1.9x speedup — the hidden allocation was a bigger bottleneck than closure dispatch

**Direct edge collection in to_adjacency_map:** Replaced O(n²) pairwise AdjacencyMap merging with single-pass edge collection via `foldg_iter`.
- 17-127x speedup depending on expression shape (path: 69x, star: 114x, clique: 17x)

**DenseGraph type:** New `Array[Array[Int]]` representation for dense vertex IDs.
- 8-23x faster than AdjacencyMap across all algorithms
- Flat array access vs tree map lookup is the dominant factor
- Added optimized DFS, BFS, toposort, SCC, transpose methods

**Overhead decomposition (DFS reachable, chain_1000):**

| Source | Factor |
|---|---|
| Map adjacency lookup | 1.5x |
| Per-vertex temp array allocation | 1.9x |
| Closure call_ref in for_each_successor | 1.8x |
| Map visited set | 2.7x |
| **Combined** | **14x** |

### Package split (2026-03-31)

Commit `cab17bf` (#17): moved experiment files to `src/experiment/` sub-package. No performance change — organizational only. Added `toposort_subset` for induced subgraph ordering.

### Property tests + bug fix (2026-03-31)

PR #22: Added 8 property-based law tests using `moonbitlang/quickcheck`. During testing, discovered and fixed a shared-mutable-array bug in `to_adjacency_map` where the `empty` value passed to `foldg_iter` was aliased across Empty nodes, causing spurious self-loops.

### Degree functions (2026-03-31)

PR #23: Added `outdegree` (O(degree)) and `indegree` (O(V+E)) as generic functions. Benchmarks: outdegree ~0.02 µs, indegree ~20 µs on 1K-vertex chain.

## When to use which representation

| Scenario | Use | Why |
|---|---|---|
| General purpose, sparse IDs | AdjacencyMap | Handles any vertex IDs, algebraic operations |
| Repeated algorithm calls, dense IDs | DenseGraph | 8-23x faster, O(1) lookup |
| Building graphs from expressions | Graph + to_adjacency_map | Algebraic combinators, deferred evaluation |
| Single algorithm call, known topology | AdjacencyMap::from_edges | Simple, no expression overhead |

## Methodology

All benchmarks use `moon bench --release` (WASM-GC target). Each measurement is the mean of 10 rounds with automatic iteration count scaling. Graphs are pre-built outside the benchmark loop. Results are from a single machine and should be treated as relative comparisons, not absolute numbers.
