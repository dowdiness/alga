# Iter-Based DirectedGraph Trait + Tarjan SCC

Date: 2026-04-01

References:
- [MoonBit Iter source](https://github.com/moonbitlang/core/blob/main/builtin/iterator.mbt) — `struct Iter[X](fn() -> X?)`, full API
- [MoonBit Iter tests](https://github.com/moonbitlang/core/blob/main/builtin/iter_test.mbt) — usage patterns, `next()`, `for..in` with `break`
- [MoonBit iter helpers](https://github.com/moonbitlang/core/blob/main/builtin/iter.mbt) — `Int::until`, range iterators
- [petgraph analysis](2026-04-01-petgraph-analysis.md) — motivation for Tarjan SCC and iter-based design

## Problem

1. `DirectedGraph` requires CPS callback methods (`for_each_vertex`, `for_each_successor`) as the only interface. Algorithms that need pause/resume (Tarjan SCC) or indexing must collect successors into temp arrays — wasting the abstraction.

2. `has_vertex` default is O(V) with no early termination because `(Int) -> Unit` callbacks can't signal "stop."

3. SCC is `AdjacencyMap`-only (Kosaraju requires `transpose`). There's no generic SCC over `DirectedGraph`.

## Design

### Phase 1: Refactor DirectedGraph to iter-based required methods

**Before:**

```moonbit
pub(open) trait DirectedGraph {
  for_each_vertex(Self, (Int) -> Unit) -> Unit      // required
  for_each_successor(Self, Int, (Int) -> Unit) -> Unit  // required
  vertex_count(Self) -> Int = _
  has_vertex(Self, Int) -> Bool = _
}
```

**After:**

```moonbit
pub(open) trait DirectedGraph {
  // Required: 2 iter-based methods
  iter(Self) -> Iter[Int]                              // vertices
  successors(Self, Int) -> Iter[Int]                   // outgoing neighbors

  // Defaulted from iter/successors:
  each_vertex(Self, (Int) -> Unit raise?) -> Unit raise? = _
  each_successor(Self, Int, (Int) -> Unit raise?) -> Unit raise? = _
  vertex_count(Self) -> Int = _
  has_vertex(Self, Int) -> Bool = _
}
```

**Defaults (using Iter API):**

`Iter[X]` is `struct Iter[X](fn() -> X?)` — a closure wrapper. `next()` calls the closure.
`Iter::contains` short-circuits on match. `Iter::count` folds internally.
`Iter::each` has signature `(Iter[X], (X) -> Unit raise?) -> Unit raise?` — effect-polymorphic:
when the callback doesn't raise, the call doesn't raise either. This matches MoonBit stdlib
convention (`Map::each`, `HashSet::each`).

```moonbit
impl DirectedGraph with each_vertex(self, f) {
  DirectedGraph::iter(self).each(f)
}

impl DirectedGraph with each_successor(self, v, f) {
  DirectedGraph::successors(self, v).each(f)
}

impl DirectedGraph with vertex_count(self) {
  DirectedGraph::iter(self).count()
}

impl DirectedGraph with has_vertex(self, v) {
  DirectedGraph::iter(self).contains(v)   // short-circuits — O(1) best case
}
```

**Implementations to update:**

| Type | `iter()` | `successors(v)` |
|------|----------|-----------------|
| `AdjacencyMap` | `self.adjacency.iter().map(fn(pair) { pair.0 })` | `match self.adjacency.get(v) { Some(s) => s.iter(); None => Iter::empty() }` |
| `DenseGraph` | `0.until(self.successors.length())` | `self.successors[v].iter()` |
| `ArrayGraph` (whitebox test) | `0.until(self.edges.length())` | `self.edges[v].iter()` |
| `BenchMinimalGraph` (benchmark) | `0.until(self.succs.length())` | `self.succs[v].iter()` |

Notes:
- `Map::iter()` returns `Iter[(K, V)]`, so `.map(fn(pair) { pair.0 })` extracts keys lazily
- `Int::until(end)` returns `Iter[Int]` for range `0..<end`
- `Array::iter()` returns `Iter[T]`
- `Iter::empty()` returns `() => None` for missing vertices

**Rename call sites:**

All algorithms currently using `G::for_each_vertex(graph, ...)` and `G::for_each_successor(graph, ...)` migrate to either:
- `G::each_vertex(graph, ...)` / `G::each_successor(graph, ...)` — drop-in rename for push-based algorithms (DFS, BFS, toposort, degree)
- `G::iter(graph)` / `G::successors(graph, v)` — for algorithms that benefit from pull-based (Tarjan, future Walker)

Most existing algorithms (DFS fold, BFS fold, toposort, degree) work fine with push-based callbacks. The rename from `for_each_*` to `each_*` follows MoonBit stdlib convention (`Map::each`, `HashSet::each`).

**`AdjacencyMap::successors` conflict:** Currently `AdjacencyMap::successors(self, v) -> Array[Int]`. The trait method `DirectedGraph::successors` returns `Iter[Int]`. Resolution: rename the standalone method to `successor_list()`. The trait impl `successors` returns `Iter[Int]` via `s.iter()`. Users who need the array use `successor_list()` or access `self.adjacency[v]` directly.

### Phase 2: Tarjan SCC generic over DirectedGraph

```moonbit
pub fn[G : DirectedGraph] tarjan_scc(graph : G) -> Array[Array[Int]]
```

**Algorithm:** Tarjan's SCC (1972). Single DFS pass using lowlink values. No transpose needed.

**Key data structures:**
- Stack frame: `(vertex, Iter[Int], index, lowlink)` — `Iter[Int]` is `struct Iter[Int](fn() -> Int?)`, a closure wrapper. Storing it in an array and calling `.next()` later correctly advances the shared mutable state captured by the closure. Single-pass, no reset needed.
- SCC stack: vertices in current DFS path
- Index counter: monotonically increasing discovery time

**Pseudocode (iterative):**

```
stack_frames = []
scc_stack = []
on_stack = {}
index_map = {}
lowlink_map = {}
counter = 0
result = []

for root in graph.iter():
  if root already indexed: skip
  push (root, graph.successors(root), counter, counter) onto stack_frames
  index_map[root] = counter; lowlink_map[root] = counter; counter++
  scc_stack.push(root); on_stack[root] = true

  while stack_frames not empty:
    (v, iter, idx, low) = top of stack_frames
    match iter.next():
      Some(w) =>
        if w not indexed:
          // "recurse" into w
          index_map[w] = counter; lowlink_map[w] = counter; counter++
          scc_stack.push(w); on_stack[w] = true
          push (w, graph.successors(w), counter-1, counter-1)
        else if on_stack[w]:
          lowlink_map[v] = min(lowlink_map[v], index_map[w])
      None =>
        // all successors done
        if lowlink_map[v] == index_map[v]:
          // v is root of an SCC — pop scc_stack until v
          component = []
          loop:
            w = scc_stack.pop()
            on_stack[w] = false
            component.push(w)
            if w == v: break
          result.push(component)
        pop stack_frames
        if stack_frames not empty:
          // propagate lowlink to parent
          parent = top of stack_frames
          lowlink_map[parent.v] = min(lowlink_map[parent.v], lowlink_map[v])
```

**Output ordering:** Tarjan produces SCCs in **forward topological order** (leaves first, roots last). This is the opposite of Kosaraju's reverse topological order. Document the difference; do not reverse — forward order is natural for Tarjan and equally useful.

**Iter semantics verified against core tests:**
- `for x in iter { break }` works — early exit from `for .. in` loops (intersperse test)
- `iter.next()` returns `Some(x)` and advances, `None` when done (filter_map test)
- Single-pass: after consuming elements, calling `next()` picks up where it left off (contains test)
- Custom iterators via `Iter::new(fn() -> X?)` with mutable closure state (Tree::iter example)

**Complexity:** O(V + E) time, O(V) space (no transpose allocation).

## Migration

**Breaking changes:**
- `for_each_vertex` → `each_vertex` (rename, now `raise?`-polymorphic)
- `for_each_successor` → `each_successor` (rename, now `raise?`-polymorphic)
- Required methods change from callback-based to iter-based (`iter`, `successors`)
- `AdjacencyMap::successors` renamed to `successor_list()` (returns `Array[Int]`); trait `successors` returns `Iter[Int]`

**Non-breaking additions:**
- `iter()` method on trait
- `successors()` returns `Iter[Int]`
- `tarjan_scc()` free function

**Call sites to update (src/ only, excluding experiment/):**
- `dfs.mbt` — 2 call sites → `each_successor`
- `bfs.mbt` — 2 call sites → `each_successor`
- `toposort.mbt` — 6 call sites → `each_vertex` + `each_successor`
- `degree.mbt` — 3 call sites → `each_vertex` + `each_successor`
- `traits.mbt` — defaults rewritten
- `adjacency_map.mbt` — impl updated
- `dense_graph.mbt` — impl updated
- `integration_wbtest.mbt` — `ArrayGraph` impl updated
- `benchmark.mbt` — `BenchMinimalGraph` impl updated

**Experiment files:** Update in batch — same mechanical rename.

## Validation

- All existing tests pass after rename + trait refactor
- `has_vertex` now short-circuits (verify with benchmark or test)
- New `tarjan_scc` tests: same graphs as existing Kosaraju tests, verify same components (order within components may differ, topological ordering of components is reversed)
- Property test: `tarjan_scc(g)` and `kosaraju_scc(g)` produce same component sets on random graphs
