# Architecture

## Overview

```
Layer A: Observation                    Layer B: Construction
(DirectedGraph trait)                   (GraphSym trait + Graph enum)

  ┌─────────────────┐                    ┌──────────────────┐
  │ DirectedGraph    │                    │ GraphSym         │
  │  iter            │                    │  empty, vertex   │
  │  successors      │                    │  overlay, connect│
  │  each_vertex*    │                    └──────┬───────────┘
  │  each_successor* │
  │  vertex_count*   │
  │  has_vertex*     │
  └──────┬──────────┘                           │
         │                                       │ implements
         │ implements                             │
         │                                  ┌────┴────┐
   ┌─────┴─────┐    bridge:               │  Graph   │
   │AdjacencyMap│◄──────────── foldg ◄─────│  (enum)  │
   ├───────────┤  to_adjacency_map         └──────────┘
   │DenseGraph │
   └─────┬─────┘
         │
         │ algorithms (generic over DirectedGraph)
         ▼
   dfs_fold, bfs_fold, reachable
   toposort, toposort_subset
   has_cycle, outdegree, indegree
   tarjan_scc (generic)
   scc, condensation (AdjacencyMap)
```

## Layer A: Observation

The `DirectedGraph` trait is the foundation. It has two required methods and four defaulted methods:

```moonbit
pub(open) trait DirectedGraph {
  iter(Self) -> Iter[Int]                              // required: all vertices
  successors(Self, Int) -> Iter[Int]                   // required: outgoing neighbors
  each_vertex(Self, (Int) -> Unit) -> Unit = _         // defaulted: push-style vertex iteration
  each_successor(Self, Int, (Int) -> Unit) -> Unit = _ // defaulted: push-style successor iteration
  vertex_count(Self) -> Int = _                        // defaulted: O(V) via Iter::count
  has_vertex(Self, Int) -> Bool = _                    // defaulted: short-circuits via Iter::contains
}
```

Any type that implements `iter` and `successors` gets every generic algorithm for free. The four defaulted methods are derived from the iterators: `each_vertex`/`each_successor` delegate to `Iter::each` for push-style algorithms (DFS, BFS, toposort), `vertex_count` uses `Iter::count`, and `has_vertex` uses `Iter::contains` which short-circuits on match. Override any default for O(1) when your data structure supports it.

### Iter-based iteration

`iter` and `successors` return `Iter[Int]` — MoonBit's pull-based external iterator (`struct Iter[X](fn() -> X?)`). Call `.next()` for one vertex at a time, enabling:

- **Pause/resume:** Tarjan SCC stores `Iter[Int]` in stack frames, calling `.next()` to advance successor iteration one step at a time across "recursive" calls.
- **Early termination:** `has_vertex` short-circuits via `Iter::contains` — O(1) best case instead of O(V).
- **Lazy composition:** `Iter::map`, `Iter::filter` compose without intermediate allocations.

### Two implementations

**AdjacencyMap** — `Map[Int, Array[Int]]`
- Sparse, non-contiguous vertex IDs (any Int)
- Supports algebraic operations (overlay, connect)
- O(log V) successor lookup via tree map
- Production default for general use

**DenseGraph** — `Array[Array[Int]]`
- Dense vertex IDs in 0..n-1
- O(1) successor lookup via array index
- 8-23x faster than AdjacencyMap for algorithms
- Convert from AdjacencyMap via `DenseGraph::from_adjacency_map`

## Layer B: Construction

The `GraphSym` trait defines the four algebraic operations:

```moonbit
pub(open) trait GraphSym {
  empty() -> Self
  vertex(Int) -> Self
  overlay(Self, Self) -> Self
  connect(Self, Self) -> Self
}
```

Both `Graph` (syntax tree) and `AdjacencyMap` (eager evaluation) implement `GraphSym`.

### Graph enum: the free algebra

`Graph` preserves the construction history as a syntax tree:

```moonbit
pub(all) enum Graph {
  Empty
  Vertex(Int)
  Overlay(Graph, Graph)
  Connect(Graph, Graph)
}
```

This enables transformations before evaluation:
- `gmap(f)` — relabel vertices
- `bind(f)` — replace each vertex with a subgraph (monadic bind)
- `induce(pred)` — filter vertices by predicate
- `remove_vertex(v)` — delete a vertex and its edges

### The bridge: foldg

`foldg` is the universal evaluator — a catamorphism that replaces each constructor with a user-supplied function:

```moonbit
pub fn[B] foldg(graph, empty, vertex, overlay, connect) -> B
```

Every derived operation (`to_adjacency_map`, `gmap`, `bind`, `induce`) is implemented via `foldg`. In category theory, this is the unique homomorphism from the free algebra to any target algebra.

Two variants exist:
- `foldg` — recursive, fastest for lightweight folds (vertex count, gmap)
- `foldg_iter` — iterative with explicit stack, stack-safe for deep expressions, ~2.8x overhead

### Combinators

Higher-level constructors built from the four primitives:

| Combinator | Builds |
|---|---|
| `vertices([1, 2, 3])` | Isolated vertices (no edges) |
| `edges([(1,2), (3,4)])` | Explicit edge list |
| `path([1, 2, 3])` | Linear chain: 1→2→3 |
| `circuit([1, 2, 3])` | Closed loop: 1→2→3→1 |
| `clique([1, 2, 3])` | Complete: 1→2, 1→3, 2→3 |
| `star(1, [2, 3, 4])` | Hub and spokes |

## Algorithms

All generic algorithms take `G : DirectedGraph`. Most use the defaulted `each_vertex`/`each_successor` for push-style traversal. Tarjan SCC uses the pull-based `iter`/`successors` directly for pause/resume.

| Algorithm | File | Complexity | Notes |
|---|---|---|---|
| DFS fold | `dfs.mbt` | O(V+E) | Explicit stack, mark-and-reverse for correct ordering |
| BFS fold | `bfs.mbt` | O(V+E) | Queue-based |
| Reachable | `dfs.mbt` | O(V+E) | Built on dfs_fold |
| Toposort | `toposort.mbt` | O(V+E) | Kahn's algorithm |
| Toposort subset | `toposort.mbt` | O(V_sub+E_sub) | Induced subgraph ordering |
| Topo levels | `toposort.mbt` | O(V+E) | Longest-path distance from sources |
| Cycle detection | `toposort.mbt` | O(V+E) | Derived from toposort (None = cycle) |
| Outdegree | `degree.mbt` | O(degree) | Counts via `Iter::count` on successors |
| Indegree | `degree.mbt` | O(V+E) | Full scan — no reverse index |
| Tarjan SCC | `scc.mbt` | O(V+E) | Generic over `DirectedGraph`, no transpose, uses `Iter.next()` |
| Kosaraju SCC | `scc.mbt` | O(V+E) | AdjacencyMap-specific, requires transpose, reverse topo order |
| Condensation | `scc.mbt` | O(V+E) | Collapse SCCs into DAG (AdjacencyMap-specific) |

DenseGraph provides optimized versions of DFS, toposort, SCC, and reachable that bypass trait dispatch for 8-23x speedup.

## Correctness guarantees

- All 8 Mokhov algebraic laws verified by property-based testing (100 random cases each, with shrinking)
- 146+ unit tests covering algorithms, combinators, edge cases
- Iterative algorithms tested up to 10K+ vertices

## File map

```
src/
├── traits.mbt           # DirectedGraph trait definition
├── adjacency_map.mbt    # AdjacencyMap: Map-based representation
├── dense_graph.mbt      # DenseGraph: Array-based fast representation
├── graph_sym.mbt        # GraphSym trait + AdjacencyMap impl
├── graph_expr.mbt       # Graph enum, foldg, foldg_iter, combinators
├── graph_expr_qc.mbt    # Arbitrary + Shrink for Graph (property testing)
├── dfs.mbt              # DFS fold, reachable
├── bfs.mbt              # BFS fold
├── toposort.mbt         # Toposort, toposort_subset, has_cycle
├── scc.mbt              # SCC: Kosaraju (AdjacencyMap), Tarjan (generic), condensation
├── degree.mbt           # Outdegree, indegree
├── benchmark.mbt        # Performance benchmarks
└── experiment/           # Performance experiments and variants
```
