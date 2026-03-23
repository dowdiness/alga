# alga

Algebraic graphs for MoonBit — a directed graph trait and algorithm library inspired by Haskell's [algebraic-graphs (alga)](https://hackage.haskell.org/package/algebraic-graphs).

## Architecture

The library has two independent layers connected by a bridge:

```
Layer A: Observation                    Layer B: Construction
(DirectedGraph trait)                   (GraphSym trait + Graph enum)

  ┌─────────────────┐                    ┌──────────────────┐
  │ DirectedGraph    │                    │ GraphSym         │
  │  vertex_count    │                    │  empty, vertex   │
  │  for_each_vertex │                    │  overlay, connect│
  │  for_each_succ.  │                    └──────┬───────────┘
  └──────┬──────────┘                           │
         │                                       │ implements
         │ implements                             │
         │                                  ┌────┴────┐
   ┌─────┴─────┐    bridge:               │  Graph   │
   │AdjacencyMap│◄──────────── foldg ◄─────│  (enum)  │
   └─────┬─────┘  to_adjacency_map         └──────────┘
         │
         │ algorithms
         ▼
   dfs_fold, bfs_fold
   reachable, toposort
   has_cycle, scc
```

**Layer A (Observation)** answers "what does this graph look like?" Any data structure implementing `DirectedGraph` gets all algorithms for free.

**Layer B (Construction)** answers "how do I build a graph?" Using four algebraic operations (empty, vertex, overlay, connect) you can describe any directed graph, then interpret it into any representation.

**The bridge:** `Graph::to_adjacency_map()` converts algebraic expressions into the efficient `AdjacencyMap` representation, connecting construction to observation.

## Quick start

```moonbit
// Build a graph from edges
let g = AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])

// Run algorithms
let r = reachable(g, 1)       // [1, 2, 3, 4]
let order = toposort(g)       // Some([1, 2, 3, 4])
let cyclic = has_cycle(g)     // false
let components = g.scc()      // [[1], [2], [3], [4]]

// Build with algebraic expressions
let expr = Graph::path([1, 2, 3])
let am = expr.to_adjacency_map()
assert_true(am.has_edge(1, 2))
```

## Algorithms

| Algorithm | Function | Time | Description |
|-----------|----------|------|-------------|
| DFS | `dfs_fold(g, start, init, f)` | O(V+E) | Depth-first fold with early termination |
| BFS | `bfs_fold(g, start, init, f)` | O(V+E) | Breadth-first fold with early termination |
| Reachability | `reachable(g, start)` | O(V+E) | All vertices reachable from start |
| Toposort | `toposort(g)` | O(V+E) | Topological ordering (Kahn's algorithm) |
| Cycle detection | `has_cycle(g)` | O(V+E) | True if graph contains a directed cycle |
| SCC | `g.scc()` | O(V+E) | Strongly connected components (Kosaraju) |

All algorithms except SCC are generic over `DirectedGraph` — they work on any implementing type. SCC requires `transpose`, which is specific to `AdjacencyMap`.

## Graph construction combinators

| Combinator | Example | Result |
|------------|---------|--------|
| `vertices([1, 2, 3])` | Three isolated vertices | No edges |
| `edges([(1,2), (3,4)])` | Explicit edge list | Edges 1→2, 3→4 |
| `path([1, 2, 3])` | Linear chain | 1→2→3 |
| `circuit([1, 2, 3])` | Closed loop | 1→2→3→1 |
| `clique([1, 2, 3])` | Complete graph | 1→2, 1→3, 2→3 |
| `star(1, [2, 3, 4])` | Hub and spokes | 1→2, 1→3, 1→4 |

## Implementing DirectedGraph for your types

The trait has only three methods. Implement them and all algorithms just work:

```moonbit
struct MyGraph { edges : Array[Array[Int]] }

impl DirectedGraph for MyGraph with vertex_count(self) {
  self.edges.length()
}

impl DirectedGraph for MyGraph with for_each_vertex(self, f) {
  for i in 0..<self.edges.length() { f(i) }
}

impl DirectedGraph for MyGraph with for_each_successor(self, v, f) {
  for w in self.edges[v] { f(w) }
}

// Now you can use:
// toposort(my_graph), reachable(my_graph, 0), has_cycle(my_graph), etc.
```

## Design decisions

**Fixed vertex type (Int):** MoonBit traits don't support type parameters or associated types. We fix vertices to `Int` and let users maintain their own `Id → Int` mapping. This is the same approach used by algebraic graph libraries in languages without type families.

**Callback-style iteration:** Without associated types we can't return `Iter[Vertex]` from trait methods. Instead we push vertices into `(Int) -> Unit` callbacks (CPS style), avoiding intermediate allocations.

**Iterative algorithms:** DFS and SCC use explicit stacks instead of recursion, preventing stack overflow on deep graphs (tested up to 10K+ vertices).

## Performance

Benchmarks on a 1,000-vertex chain graph (WASM-GC, release mode):

| Operation | Time |
|-----------|------|
| from_edges | 62 µs |
| toposort | 124 µs |
| reachable (DFS) | 97 µs |
| BFS | 68 µs |
| has_cycle | 122 µs |
| SCC | 296 µs |
| transpose | 80 µs |

Run benchmarks: `moon bench --release`

## References

- Andrey Mokhov, [Algebraic Graphs with Class](https://dl.acm.org/doi/10.1145/3122955.3122956) (Haskell Symposium, 2017) — the foundational paper
- Haskell [algebraic-graphs](https://hackage.haskell.org/package/algebraic-graphs) package — the original implementation
- Kahn (1962), Topological sorting of large networks
- Kosaraju-Sharir (1978), Strongly connected components

## License

Apache-2.0
