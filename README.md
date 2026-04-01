# alga

A directed graph library for [MoonBit](https://www.moonbitlang.com/) with trait-generic algorithms and algebraic construction. Inspired by Haskell's [algebraic-graphs](https://hackage.haskell.org/package/algebraic-graphs).

Implement two methods (`iter`, `successors`) on your data structure and get DFS, BFS, topological sort, cycle detection, strongly connected components, edge classification, and reverse traversal — all with O(V+E) complexity.

## Quick start

```bash
moon add dowdiness/alga
```

```moonbit
// Build a graph: 1 → 2 → 3 → 4
let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])

// Traverse
let r = @alga.reachable(g, 1)         // [1, 2, 3, 4]
let order = @alga.toposort(g)         // Some([1, 2, 3, 4])
let cyclic = @alga.has_cycle(g)       // false

// Strongly connected components
let sccs = @alga.tarjan_scc(g)        // [[4], [3], [2], [1]]

// DFS with edge classification
for event in @alga.dfs_events(g) {
  match event {
    @alga.BackEdge(u, v) => println("cycle: \{u} → \{v}")
    _ => ()
  }
}

// Reverse traversal: "what can reach vertex 4?"
let ancestors = @alga.reachable(@alga.reversed(g), 4)  // [4, 3, 2, 1]

// Algebraic construction
let expr = @alga.Graph::path([1, 2, 3])
let am = expr.to_adjacency_map()
```

## Why algebraic graphs?

Most graph libraries make you manage mutable adjacency lists by hand. Alga takes a different approach based on [Mokhov (2017)](https://dl.acm.org/doi/10.1145/3122955.3122956): four operations — `empty`, `vertex`, `overlay`, `connect` — form an algebra with eight axioms that guarantee well-formed graphs by construction. You can't create a dangling edge or an inconsistent state.

The library separates *observing* a graph (the `DirectedGraph` trait) from *building* one (the `GraphSym` trait and `Graph` enum). Algorithms are written against the observation trait, so they work on any data structure that implements it — including your own.

## How it works

```
Observation layer                      Construction layer
(DirectedGraph + Predecessors)         (GraphSym + Graph enum)

  ┌─────────────────┐                    ┌──────────────────┐
  │ DirectedGraph    │                    │ GraphSym         │
  │  iter            │                    │  empty, vertex   │
  │  successors      │                    │  overlay, connect│
  │  (+ 4 defaults)  │                    └──────┬───────────┘
  ├─────────────────┤                           │
  │ Predecessors     │                     ┌────┴────┐
  │  predecessors    │    bridge:          │  Graph   │
  └──────┬──────────┘   foldg             │  (enum)  │
         │                                 └──────────┘
   ┌─────┴─────┐   ┌────────────┐
   │AdjacencyMap│   │ DenseGraph │
   └────────────┘   └────────────┘
```

**Observation layer.** The `DirectedGraph` trait requires two methods: `iter()` returns all vertices, `successors(v)` returns outgoing neighbors. Four more methods (`each_vertex`, `each_successor`, `vertex_count`, `has_vertex`) are defaulted. Every generic algorithm in the library is bounded by this trait.

The `Predecessors` trait adds one method — `predecessors(v)` — for types that store reverse adjacency. Both built-in representations implement it, enabling the zero-cost `Reversed[G]` adaptor for reverse-direction traversal.

**Construction layer.** The `Graph` enum represents graph expressions as a syntax tree (`Empty | Vertex | Overlay | Connect`). You can transform the tree (`gmap`, `bind`, `induce`) before evaluating it into an `AdjacencyMap` via `foldg`.

**Two representations:**

- **`AdjacencyMap`** — `Map[Int, Array[Int]]` with bidirectional storage. Handles sparse, non-contiguous vertex IDs. Supports algebraic operations. O(log V) successor lookup.
- **`DenseGraph`** — `Array[Array[Int]]` with bidirectional storage. Requires vertex IDs in 0..n-1. O(1) successor lookup. 8–23x faster than `AdjacencyMap` for traversals.

Both store forward and reverse adjacency lists, making `transpose()` an O(1) field swap.

## Algorithms

Every algorithm below is generic over `DirectedGraph` unless noted otherwise.

| Algorithm | Function | Time |
|-----------|----------|------|
| DFS fold | `dfs_fold(g, start, init, f)` | O(V+E) |
| BFS fold | `bfs_fold(g, start, init, f)` | O(V+E) |
| Multi-source DFS/BFS | `dfs_fold_multi`, `bfs_fold_multi` | O(V+E) |
| Reachability | `reachable(g, v)` | O(V+E) |
| DFS edge classification | `dfs_events(g)` | O(V+E) |
| Topological sort | `toposort(g)` | O(V+E) |
| Topological levels | `topo_levels(g)` | O(V+E) |
| Cycle detection | `has_cycle(g)` | O(V+E) |
| SCC (Tarjan) | `tarjan_scc(g)` | O(V+E) |
| SCC (Kosaraju) | `g.scc()` | O(V+E) |
| Condensation | `g.condensation()` | O(V+E) |
| Reversed view | `reversed(g)` | O(1) |
| Degree queries | `outdegree(g, v)`, `indegree(g, v)` | O(deg) / O(V+E) |

Kosaraju SCC and condensation are `AdjacencyMap`-specific. `reversed(g)` requires the `Predecessors` trait. `dfs_events` returns a lazy `Iter[DfsEvent]` that classifies each edge as tree, back, or cross/forward — useful for cycle detection, post-order traversal, and scope analysis.

## Using your own graph type

Implement two methods and every algorithm works:

```moonbit
struct MyGraph { edges : Array[Array[Int]] }

impl @alga.DirectedGraph for MyGraph with iter(self) {
  (0).until(self.edges.length())
}

impl @alga.DirectedGraph for MyGraph with successors(self, v) {
  self.edges[v].iter()
}

// Now available: toposort(g), tarjan_scc(g), reachable(g, 0),
// has_cycle(g), dfs_events(g), dfs_fold(g, ...), bfs_fold(g, ...), etc.
```

Override `vertex_count` and `has_vertex` for O(1) if your type supports it. Implement `Predecessors` to enable `reversed(g)`.

## Graph construction

Build graphs algebraically using the `Graph` enum:

| Combinator | Result |
|------------|--------|
| `Graph::vertices([1, 2, 3])` | Three isolated vertices |
| `Graph::edges([(1,2), (3,4)])` | Edges 1→2, 3→4 |
| `Graph::path([1, 2, 3])` | Chain 1→2→3 |
| `Graph::circuit([1, 2, 3])` | Loop 1→2→3→1 |
| `Graph::clique([1, 2, 3])` | Complete: 1→2, 1→3, 2→3 |
| `Graph::star(1, [2, 3, 4])` | Hub: 1→2, 1→3, 1→4 |

Evaluate with `expr.to_adjacency_map()` when ready to run algorithms.

## Design notes

**Fixed vertex type.** Vertices are `Int`. MoonBit traits don't support type parameters or associated types, so the vertex type is fixed. Map your domain IDs to `Int` at the boundary.

**Pull-based iteration.** `iter` and `successors` return `Iter[Int]` — MoonBit's external iterator. This enables pause/resume (Tarjan SCC suspends successor iteration mid-traversal), early termination (`has_vertex` short-circuits), and lazy composition.

**Iterative algorithms.** DFS and SCC use explicit stacks, not recursion. Tested up to 10,000+ vertices without stack overflow.

**Property-tested laws.** All 8 algebraic graph axioms from Mokhov (2017) are verified with [`moonbitlang/quickcheck`](https://github.com/moonbitlang/quickcheck) — 100 random graph expressions per law with automatic shrinking. 237 tests total.

## Repository layout

```
src/
  traits.mbt          DirectedGraph, Predecessors traits
  adjacency_map.mbt   AdjacencyMap — sparse representation
  dense_graph.mbt     DenseGraph — dense, high-performance representation
  reversed.mbt        Reversed[G] — zero-cost reverse-direction adaptor
  graph_expr.mbt      Graph enum — algebraic expression tree + foldg
  graph_sym.mbt       GraphSym trait — algebraic construction interface
  dfs.mbt             DFS fold, DFS events (edge classification)
  bfs.mbt             BFS fold
  toposort.mbt        Topological sort, topo levels, cycle detection
  scc.mbt             Kosaraju SCC, Tarjan SCC, condensation
  degree.mbt          Indegree, outdegree
  experiment/         Performance experiments (DenseGraph, visited sets)
docs/
  philosophy.md       Why algebraic graphs, the axiom system, design principles
  architecture.md     Two-layer design, trait system, algorithm details
  TODO.md             Active backlog
```

## Further reading

- [Philosophy](docs/philosophy.md) — the algebraic graph model and why it matters
- [Architecture](docs/architecture.md) — trait design, representations, algorithm details
- Andrey Mokhov, [Algebraic Graphs with Class](https://dl.acm.org/doi/10.1145/3122955.3122956) (Haskell Symposium, 2017)
- Haskell [algebraic-graphs](https://hackage.haskell.org/package/algebraic-graphs) package

## License

Apache-2.0
