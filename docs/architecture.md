# Architecture

## Overview

```
Layer A: Observation                    Layer B: Construction
(DirectedGraph trait)                   (GraphSym trait + Graph enum)

  ┌─────────────────┐                    ┌──────────────────┐
  │ DirectedGraph    │                    │ GraphSym         │
  │  for_each_vertex │                    │  empty, vertex   │
  │  for_each_succ.  │                    │  overlay, connect│
  │  vertex_count*   │                    └──────┬───────────┘
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
   scc (AdjacencyMap-specific)
```

## Layer A: Observation

The `DirectedGraph` trait is the foundation. It has two required methods and two defaulted methods:

```moonbit
pub(open) trait DirectedGraph {
  for_each_vertex(Self, (Int) -> Unit) -> Unit
  for_each_successor(Self, Int, (Int) -> Unit) -> Unit
  vertex_count(Self) -> Int = _
  has_vertex(Self, Int) -> Bool = _
}
```

Any type that implements the two required methods gets every generic algorithm for free — `vertex_count` and `has_vertex` have O(V) defaults derived from `for_each_vertex`. Override them for O(1) when your data structure supports constant-time queries. The trait is deliberately minimal — adding required methods increases the implementation burden for new types.

### Callback-style iteration

`for_each_vertex` and `for_each_successor` use callbacks instead of returning iterators. This is a deliberate design choice forced by MoonBit's trait system (no associated types to express `Iter[Vertex]`), but it also avoids intermediate allocations. Algorithms that consume successors (DFS, BFS, toposort) can process them inline without collecting into temporary arrays.

The tradeoff: the 1.8x closure dispatch overhead measured in benchmarks is inherent to this design. A trait-based `GraphFolder` could eliminate it, but the wins from other optimizations (flat adjacency, mark-and-reverse DFS) have been larger.

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

All generic algorithms follow the same pattern: take `G : DirectedGraph`, use `for_each_vertex` and `for_each_successor` for traversal, use `vertex_count` for pre-allocation.

| Algorithm | File | Complexity | Notes |
|---|---|---|---|
| DFS fold | `dfs.mbt` | O(V+E) | Explicit stack, mark-and-reverse for correct ordering |
| BFS fold | `bfs.mbt` | O(V+E) | Queue-based |
| Reachable | `dfs.mbt` | O(V+E) | Built on dfs_fold |
| Toposort | `toposort.mbt` | O(V+E) | Kahn's algorithm |
| Toposort subset | `toposort.mbt` | O(V_sub+E_sub) | Induced subgraph ordering |
| Cycle detection | `toposort.mbt` | O(V+E) | Derived from toposort (None = cycle) |
| Outdegree | `degree.mbt` | O(degree) | Counts via for_each_successor |
| Indegree | `degree.mbt` | O(V+E) | Full scan — no reverse index |
| SCC | `scc.mbt` | O(V+E) | Kosaraju, requires transpose (AdjacencyMap-specific) |

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
├── scc.mbt              # Strongly connected components (Kosaraju)
├── degree.mbt           # Outdegree, indegree
├── benchmark.mbt        # Performance benchmarks
└── experiment/           # Performance experiments and variants
```
