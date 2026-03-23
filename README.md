# alga

Algebraic graphs for MoonBit — a directed graph trait and algorithm library inspired by Haskell's [algebraic-graphs (alga)](https://hackage.haskell.org/package/algebraic-graphs).

## Overview

Two independent layers:

**Layer A — Observation:** `DirectedGraph` trait with callback-style iteration (fixed vertex type `Int`). Any data structure implementing the trait gets access to all algorithms.

- `dfs_fold` / `reachable` — depth-first traversal
- `bfs_fold` — breadth-first traversal
- `toposort` / `has_cycle` — topological sort (Kahn's algorithm)
- `AdjacencyMap::scc` — strongly connected components (Kosaraju's algorithm)

**Layer B — Construction:** `GraphSym` trait (finally tagless) + `Graph` enum (free algebra) + `foldg` catamorphism.

- Combinators: `path`, `clique`, `circuit`, `star`, `vertices`, `edges`
- Transformations: `gmap`, `bind`, `induce`, `remove_vertex`
- Bridge: `Graph::to_adjacency_map` converts expressions to efficient representation

## Usage

```moonbit
let g = AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
let r = reachable(g, 1)  // [1, 2, 3, 4]
let order = toposort(g)  // Some([1, 2, 3, 4])

let expr = Graph::path([1, 2, 3])
let am = expr.to_adjacency_map()
```

## License

Apache-2.0
