# Reversed Graph Adaptor

Date: 2026-04-01

References:
- [petgraph analysis](2026-04-01-petgraph-analysis.md#1-zero-copy-graph-adaptors) — motivation
- [MoonBit trait patterns](~/.claude/skills/moonbit-traits) — capability trait pattern
- Spike verification: generic impl + multi-trait bounds confirmed working

## Problem

Reverse-direction traversal (finding predecessors, reverse reachability, reverse DFS) requires reversing all edges. Currently `AdjacencyMap::transpose()` is the only option — it allocates a full graph copy and only works on `AdjacencyMap`. There is no way to traverse edges in reverse on `DenseGraph` or any custom `DirectedGraph`.

Use cases that need reverse traversal:
- **Reverse reachability**: "what depends on vertex v?" (impact analysis in Canopy)
- **Reverse DFS with edge classification**: `dfs_events(reversed(g))` for reverse post-order
- **Generic Kosaraju SCC**: forward DFS + reverse DFS (though `tarjan_scc` already solves this)
- **Reverse topological order**: `toposort(reversed(g))`

## Design

### Capability trait: `Predecessors`

A single-method trait representing the capability to query incoming edges.

```moonbit
pub(open) trait Predecessors {
  predecessors(Self, Int) -> Iter[Int]
}
```

Types opt in by implementing this trait alongside `DirectedGraph`. No default implementation — there is no correct O(1) default, and an O(V+E) default would be a performance trap.

This follows MoonBit's capability trait pattern: fine-grained, one method, composed via multi-trait bounds.

### Bidirectional adjacency storage

Both `AdjacencyMap` and `DenseGraph` store forward and reverse edge lists, built during construction at negligible additional cost (one extra insert per edge).

#### AdjacencyMap

```moonbit
priv struct AdjacencyMap {
  adjacency : Map[Int, Array[Int]]  // existing: v -> [successors]
  reverse : Map[Int, Array[Int]]    // new: v -> [predecessors]
}
```

`transpose()` becomes trivial — swap the two maps:

```moonbit
pub fn transpose(self : AdjacencyMap) -> AdjacencyMap {
  { adjacency: self.reverse, reverse: self.adjacency }
}
```

#### DenseGraph

```moonbit
pub(all) struct DenseGraph {
  successors : Array[Array[Int]]     // existing
  predecessors : Array[Array[Int]]   // new
}
```

Adding a field to `pub(all)` struct is a breaking change for direct construction, acceptable at v0.1.0.

### Zero-cost `Reversed[G]` newtype

```moonbit
pub struct Reversed[G] {
  graph : G
}
```

Implements `DirectedGraph` by delegating to the original graph, swapping successors and predecessors. Implements `Predecessors` by returning the original's successors.

```moonbit
pub impl[G : DirectedGraph + Predecessors] DirectedGraph for Reversed[G] with iter(self) {
  G::iter(self.graph)
}

pub impl[G : DirectedGraph + Predecessors] DirectedGraph for Reversed[G] with successors(self, v) {
  G::predecessors(self.graph, v)
}

pub impl[G : DirectedGraph + Predecessors] DirectedGraph for Reversed[G] with has_vertex(self, v) {
  G::has_vertex(self.graph, v)
}

pub impl[G : DirectedGraph + Predecessors] DirectedGraph for Reversed[G] with vertex_count(self) {
  G::vertex_count(self.graph)
}

pub impl[G : DirectedGraph + Predecessors] Predecessors for Reversed[G] with predecessors(self, v) {
  G::successors(self.graph, v)
}
```

All impl blocks must have identical constraints (`G : DirectedGraph + Predecessors`) — MoonBit requires uniform constraints across impl blocks for the same type.

### Constructor

```moonbit
pub fn[G : DirectedGraph + Predecessors] reversed(graph : G) -> Reversed[G] {
  { graph, }
}
```

### MoonBit type system constraint

The spike verified:
- `impl[G : DirectedGraph + Predecessors] DirectedGraph for Reversed[G]` compiles and works
- Multi-trait bounds (`G : DirectedGraph + Predecessors`) work in both impl blocks and function signatures
- All impl blocks for the same trait+type must use identical type parameter constraints

### Properties

- **Zero allocation**: `Reversed[G]` holds only a reference to the original graph. No copying.
- **Involution**: `Reversed(Reversed(g))` produces the same traversal as `g`. Successors of the double-reversed graph call predecessors of the reversed graph, which call successors of the original.
- **Full composability**: `Reversed[G]` implements `DirectedGraph + Predecessors`, so it works with all existing algorithms: `dfs_events`, `dfs_fold`, `bfs_fold`, `reachable`, `toposort`, `tarjan_scc`, `has_cycle`, `topo_levels`, `indegree`, `outdegree`.

## Construction changes

All `AdjacencyMap` construction methods must maintain both maps:

| Method | Forward change | Reverse change |
|---|---|---|
| `empty()` | — | Empty map |
| `vertex(v)` | — | `v -> []` |
| `edge(u, v)` | — | `v -> [u]` |
| `from_edges(edges)` | — | Build reverse in same loop |
| `overlay(g1, g2)` | — | Merge reverse maps |
| `connect(g1, g2)` | — | Cross-edges in reverse direction |
| `transpose()` | Swap maps | Swap maps |
| `remove_self_loops()` | — | Remove self-loops from reverse map too |
| `condensation()` | — | Fix direct `adjacency` mutation (line 183) to also touch `reverse` |

For `DenseGraph`:

| Method | Change |
|---|---|
| `from_edges(n, edges)` | Build predecessors array in same loop |
| `from_adjacency_map(am)` | Copy reverse map into predecessors array |
| `transpose()` | Swap arrays |

## Composability examples

```moonbit
// Reverse reachability: "what can reach vertex v?"
let ancestors = reachable(reversed(g), v)

// Reverse DFS with edge classification
let events = dfs_events(reversed(g))

// Cycle detection on reversed graph (same result, different traversal order)
let has_cycle = has_cycle(reversed(g))

// Reverse topological order
let rev_topo = toposort(reversed(g))

// Double reversal is identity
let same_as_g = reversed(reversed(g))
```

## Performance

| Operation | Cost |
|---|---|
| `AdjacencyMap` / `DenseGraph` construction | +1 insert per edge (negligible) |
| Memory | 2x edge storage. 1000 vertices, 3000 edges: ~24KB → ~36KB |
| `reversed(g)` | Zero — struct wrapping only |
| `Reversed` queries | Same as original (delegation) |
| `transpose()` | O(1) — swap two references (was O(V+E)) |

## API surface

New public items:

```
pub(open) trait Predecessors {
  predecessors(Self, Int) -> Iter[Int]
}

pub struct Reversed[G] { graph : G }

pub fn[G : DirectedGraph + Predecessors] reversed(G) -> Reversed[G]

pub impl Predecessors for AdjacencyMap
pub impl Predecessors for DenseGraph
pub impl[G : DirectedGraph + Predecessors] DirectedGraph for Reversed[G]
pub impl[G : DirectedGraph + Predecessors] Predecessors for Reversed[G]
```

## Testing

### Unit tests

- `predecessors` on `AdjacencyMap`: empty, single vertex, chain, diamond, self-loop
- `predecessors` on `DenseGraph`: same cases
- `Reversed` successors == original predecessors
- `Reversed` predecessors == original successors
- `Reversed(Reversed(g))` produces same traversal as `g`
- `reversed(g)` works with `dfs_events`, `reachable`, `toposort`
- `AdjacencyMap::transpose()` is equivalent to swapping maps (regression)
- `DenseGraph::transpose()` is equivalent to swapping arrays (regression)

### Property tests

- For random graphs: `reversed(g).successors(v).collect()` sorted == `g.predecessors(v).collect()` sorted
- For random graphs: `dfs_events(reversed(reversed(g)))` == `dfs_events(g)` (involution)
- For random graphs: `reversed(g).edge_count()` == `g.edge_count()` (edge preservation)

### Regression

- All 211 existing tests must pass unchanged (bidirectional storage is internal)
