# petgraph Analysis — Lessons for alga

Date: 2026-04-01

Sources:
- [petgraph docs.rs](https://docs.rs/petgraph/latest/petgraph/)
- [compiler-crates petgraph overview](https://sdiehl.github.io/compiler-crates/petgraph.html)
- Mokhov 2017, [Algebraic Graphs with Class](https://dl.acm.org/doi/10.1145/3122955.3122956)

## Context

petgraph is the dominant graph library in Rust, used heavily in compilers, package managers, and build systems. Its strengths are: 5 graph representations, ~35 algorithms, trait-generic design, zero-copy adaptors, and DOT export. This document identifies which ideas translate well to alga's algebraic foundation and MoonBit's constraints.

## Recommended — high confidence

### 1. Zero-copy graph adaptors

petgraph wraps a graph reference to present a different view without allocation:

| Adaptor | What it does |
|---------|-------------|
| `Reversed` | Swaps successor/predecessor queries |
| `NodeFiltered` | Hides vertices not matching a predicate |
| `EdgeFiltered` | Hides edges not matching a predicate |

**Why this matters for alga:**

- `Reversed[G : DirectedGraph]` implementing `DirectedGraph` would let Kosaraju SCC work on any `DirectedGraph`, not just `AdjacencyMap`. Currently `transpose()` allocates a full copy. A `Reversed` wrapper needs the underlying graph to support predecessor queries — for `AdjacencyMap` this means building a reverse-adjacency index, but for `DenseGraph` it's trivial.
- `NodeFiltered[G]` would replace `Graph::induce(pred)` for observation-layer use cases without building a new expression tree.
- Adaptors compose: `Reversed(NodeFiltered(g, pred))` is a valid `DirectedGraph`.

**Design consideration:** These adaptors require a `for_each_predecessor` method (or equivalent) on the underlying graph, which `DirectedGraph` doesn't currently expose. Options:
1. Add `for_each_predecessor` to `DirectedGraph` with a default O(V+E) scan
2. Make `Reversed` only work on types that expose predecessors (separate trait or method)
3. Build the reverse index lazily on first `Reversed` access

### 2. DFS edge classification

petgraph's `depth_first_search` fires typed events:

| Event | Meaning | Use |
|-------|---------|-----|
| `Discover(v)` | First visit | Pre-order traversal |
| `TreeEdge(u, v)` | DFS tree edge | Spanning tree |
| `BackEdge(u, v)` | Edge to ancestor | Cycle detection |
| `CrossForwardEdge(u, v)` | Edge to finished vertex | DAG analysis |
| `Finish(v)` | All descendants done | Post-order, toposort |

Many algorithms reduce to "DFS + classify edges":
- Cycle detection = found a `BackEdge`
- Bridges = tree edges where no back edge crosses below
- 2-edge-connected components = grouping by bridges
- Topological sort = reverse `Finish` order

alga's `dfs_fold` only sees vertices. A `dfs_classify` function that reports edge types would make DFS a universal building block.

**MoonBit approach:** Use an enum `DfsEvent` and a callback `(DfsEvent) -> Unit` (or with `ControlFlow` return for early termination).

### 3. Tarjan SCC (single-pass, no transpose)

petgraph offers both Kosaraju and Tarjan SCC. Tarjan is single-pass and doesn't need `transpose`, meaning it works on any `DirectedGraph` — not just `AdjacencyMap`. This would lift alga's "SCC is AdjacencyMap-only" limitation.

Tarjan uses a single DFS with a lowlink array and an explicit stack. Complexity: O(V+E), same as Kosaraju but one pass instead of two.

**Trade-off:** Kosaraju produces SCCs in reverse topological order (useful for condensation). Tarjan produces them in forward topological order. Both are correct; the output ordering differs.

## Recommended — medium confidence

### 4. Traversal control flow

petgraph uses `Control` enum: `Continue`, `Break(value)`, `Prune` (skip subtree). alga's CPS callbacks return `Unit` with no way to stop early.

Impact: `has_vertex` always scans O(V) even when the target is found immediately. Early termination would also benefit algorithms that search for a specific vertex or path.

**Options for alga:**
- Change callback return type to `Bool` (true = continue) — simple but limited
- Use `ControlFlow` enum — more expressive but heavier
- Breaking change to `DirectedGraph` trait — would need migration

### 5. Walker pattern (incremental traversal)

petgraph's `Walker` trait yields one item at a time (like an iterator, but takes the graph as argument each step). Enables lazy processing, interleaving with external work, and composing traversals.

alga's fold-based approach processes everything eagerly. A `DfsWalker` / `BfsWalker` struct with `next(g) -> Int?` would complement the existing folds.

**Feasibility:** Straightforward in MoonBit — a struct holding the stack/queue and visited set, with a `next` method.

### 6. DOT/Graphviz output

Trivial to implement over `DirectedGraph`. Extremely useful for debugging.

```
digraph {
  0 -> 1
  0 -> 2
  1 -> 2
}
```

Could be a `to_dot(g : G) -> String` function, generic over `DirectedGraph`.

### 7. Reusable workspace (amortized allocation)

petgraph's `DfsSpace` pre-allocates visited set + stack, reusable across calls. alga's `experiment/visited_set.mbt` already explores generation-counter reuse — promoting this to a first-class pattern would close the loop.

Particularly valuable when running many traversals on the same graph (e.g., reachability from every vertex).

## Not recommended for alga

### Multiple graph representations with index instability

petgraph's `NodeIndex` invalidation on removal is a known footgun. alga's `Int` vertices are simpler and more predictable. No need to replicate this complexity.

### Weighted graph infrastructure

petgraph's `Measure`/`FloatMeasure` traits are Rust-specific. For MoonBit, a weight function parameter `(Int, Int) -> Double` on individual algorithms (like Dijkstra) is simpler than a trait hierarchy. Consider this only when adding shortest-path algorithms.

### Kitchen-sink algorithms

PageRank, Steiner trees, max matching, graph coloring, isomorphism — useful but would dilute alga's algebraic focus. Better to keep the core tight and let users compose from primitives.

## Algorithm wishlist (if pursuing)

Prioritized by value-to-effort ratio:

| Priority | Algorithm | Depends on | Effort |
|----------|-----------|-----------|--------|
| 1 | Tarjan SCC | — | Medium (single DFS + lowlink) |
| 2 | Bridges | DFS edge classification | Medium |
| 3 | Bipartiteness | — | Easy (BFS coloring) |
| 4 | All simple paths | — | Easy (DFS backtracking) |
| 5 | Dijkstra | Weight function design | Medium |
| 6 | Feedback arc set | — | Medium |
| 7 | Union-Find | — | Easy, standalone utility |

## Summary

The highest-leverage ideas from petgraph for alga are **architectural**, not algorithmic:

1. **Zero-copy adaptors** — `Reversed`, `NodeFiltered` — biggest win, unlocks generic SCC and cheap subgraph views
2. **DFS edge classification** — makes DFS a universal algorithm substrate
3. **Tarjan SCC** — removes the AdjacencyMap-only limitation

These three reinforce alga's existing trait-generic design rather than fighting it. They would make the `DirectedGraph` trait more powerful as an abstraction point, which is the library's core differentiator from petgraph's index-heavy approach.
