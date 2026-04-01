# DFS Edge Classification

Date: 2026-04-01

References:
- [petgraph analysis](2026-04-01-petgraph-analysis.md#2-dfs-edge-classification) — motivation
- [MoonBit Iter source](https://github.com/moonbitlang/core/blob/main/builtin/iterator.mbt) — `struct Iter[X](fn() -> X?)`
- Tarjan SCC implementation in `src/scc.mbt` — same iterative Iter.next() pattern

## Problem

`dfs_fold` only reports vertex discovery (pre-order). Many graph algorithms need to know **what kind of edge** was traversed:

- **Cycle detection**: found a `BackEdge` (edge to gray ancestor)
- **Bridges**: tree edges where no back edge crosses below
- **Topological sort**: reverse `Finish` order (alternative to Kahn)
- **2-edge-connected components**: grouping by bridges

## Design

### DfsEvent enum

```moonbit
pub(all) enum DfsEvent {
  Discover(Int)              // vertex entered (pre-order), set to gray
  Finish(Int)                // all descendants done (post-order), set to black
  TreeEdge(Int, Int)         // (u, v): v undiscovered, will be entered next
  BackEdge(Int, Int)         // (u, v): v is gray ancestor on stack (= cycle)
  CrossForwardEdge(Int, Int) // (u, v): v already finished (black)
}
```

Five events, matching petgraph's `DfsEvent`. Forward and cross edges are merged — distinguishing them requires comparing discovery times for marginal benefit.

### dfs_events function

```moonbit
pub fn[G : DirectedGraph] dfs_events(graph : G) -> Iter[DfsEvent]
```

Generic over `DirectedGraph`. Returns lazy `Iter[DfsEvent]` — pull-based, one event per `.next()` call. Handles disconnected components (iterates all vertices from `graph.iter()`).

### State machine

The state machine uses `enter_pending: Int?` for vertices awaiting discovery, and a stack of `(vertex, Iter[Int])` frames for successor processing.

Vertex states: white (undiscovered), gray (in progress), black (finished).

```
.next():
  enter_pending is Some(v):
    set v to gray, clear enter_pending
    push frame (v, graph.successors(v))
    return Some(Discover(v))

  stack top is (v, iter):
    match iter.next():
      Some(w) if w is white:
        set enter_pending = w
        return Some(TreeEdge(v, w))
      Some(w) if w is gray:
        return Some(BackEdge(v, w))
      Some(w) if w is black:
        return Some(CrossForwardEdge(v, w))
      None:
        set v to black
        pop frame
        return Some(Finish(v))

  stack is empty:
    advance graph.iter() to next unvisited root
    if found: set enter_pending = root, loop back to top
    if exhausted: return None
```

`TreeEdge(v, w)` and `Discover(w)` are separate events on separate `.next()` calls. `enter_pending` is checked before the stack, so `Discover(w)` fires before v's remaining successors — correct DFS order.

### Event ordering example

Graph: `0→1→2, 0→2`

```
Discover(0)
  TreeEdge(0, 1)
  Discover(1)
    TreeEdge(1, 2)
    Discover(2)
    Finish(2)
  Finish(1)
  CrossForwardEdge(0, 2)   // 2 already finished (black)
Finish(0)
```

### Vertex state encoding

Single `Map[Int, Bool]`:
- Key absent → white (undiscovered)
- `true` → gray (on stack, in progress)
- `false` → black (finished)

### Implementation: Iter closure

```moonbit
pub fn[G : DirectedGraph] dfs_events(graph : G) -> Iter[DfsEvent] {
  // state captured by closure:
  // - frames: Array[(Int, Iter[Int])]  (vertex + successor iterator)
  // - enter_pending: Int?              (vertex needing Discover event)
  // - state: Map[Int, Bool]            (absent=white, true=gray, false=black)
  // - roots: Iter[Int]                 (graph.iter() for disconnected components)
  Iter::new(fn() { ... })
}
```

`enter_pending` is checked first on each `.next()` call — when set, it emits `Discover` and pushes a processing frame. This avoids storing an enum variant on the stack.

### Relationship to existing code

- **`dfs_fold` stays.** It's the simple tool for vertex-only traversal with early termination. No change.
- **`dfs_events` is additive.** New function in `src/dfs.mbt`, new `DfsEvent` enum.
- **`tarjan_scc` stays.** It has its own optimized state machine (lowlink, SCC stack). No reason to rewrite it on top of `dfs_events`.
- **Future**: `has_cycle` could be reimplemented as `dfs_events(g).any(fn(e) { e is BackEdge(_, _) })` but the existing Kahn-based version is fine.

### Composability with Iter API

```moonbit
// Cycle detection
dfs_events(g).any(fn(e) { e is BackEdge(_, _) })

// All back edges
dfs_events(g).filter_map(fn(e) {
  match e { BackEdge(u, v) => Some((u, v)); _ => None }
}).collect()

// Post-order traversal
dfs_events(g).filter_map(fn(e) {
  match e { Finish(v) => Some(v); _ => None }
}).collect()

// Pre-order traversal
dfs_events(g).filter_map(fn(e) {
  match e { Discover(v) => Some(v); _ => None }
}).collect()

// Early termination — just break
for event in dfs_events(g) {
  match event {
    BackEdge(u, v) => { println("cycle: \{u} -> \{v}"); break }
    _ => ()
  }
}
```

## Performance

Benchmarked on 1000-vertex `AdjacencyMap` graphs (`moon bench --release`, 2026-04-01):

| Graph shape | Time |
|---|---|
| chain (999 edges) | ~155 µs |
| cyclic (1500 edges) | ~179 µs |
| diamond (~3300 edges) | ~257 µs |

## Testing

- Unit tests: same graph patterns as existing DFS tests (chain, cycle, diamond, disconnected, self-loop, empty)
- Verify event ordering matches textbook DFS
- Verify all edges are classified (sum of tree + back + cross/forward = total edge count)
- Property test: `dfs_events` Discover/Finish counts match `vertex_count`
- Property test: TreeEdge count = vertex_count - number_of_roots (spanning forest)
