# Reversed Graph Adaptor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a zero-cost `Reversed[G]` graph adaptor that enables reverse-direction traversal on any `DirectedGraph`, powered by a `Predecessors` capability trait and bidirectional adjacency storage.

**Architecture:** `Predecessors` trait (one method: `predecessors`), bidirectional storage in `AdjacencyMap` (dual `Map`) and `DenseGraph` (dual `Array`), `Reversed[G]` newtype that swaps successors/predecessors. All trait impls use uniform `G : DirectedGraph + Predecessors` constraints.

**Tech Stack:** MoonBit, `moonbitlang/quickcheck` for property tests.

**Spec:** `docs/specs/2026-04-01-reversed-graph-adaptor-design.md`

---

## File Map

| File | Change | Responsibility |
|------|--------|---------------|
| `src/traits.mbt` | Modify | Add `Predecessors` trait |
| `src/adjacency_map.mbt` | Modify | Add `reverse` field, update all constructors, impl `Predecessors`, simplify `transpose` |
| `src/dense_graph.mbt` | Modify | Add `predecessors` field, update constructors, impl `Predecessors`, simplify `transpose` |
| `src/reversed.mbt` | Create | `Reversed[G]` struct + `DirectedGraph`/`Predecessors` impls + `reversed()` constructor |
| `src/graph_expr.mbt` | Modify | Fix `to_adjacency_map` to maintain reverse map for isolated vertices |
| `src/scc.mbt` | Modify | Fix `condensation` to maintain reverse map for isolated components |
| `src/dfs_test.mbt` | Modify | Add `Reversed` unit tests |
| `src/adjacency_map_test.mbt` | Modify | Add `predecessors` unit tests |
| `src/graph_expr_qc.mbt` | Modify | Add `Reversed` property tests |

---

### Task 1: Add `Predecessors` trait

**Files:**
- Modify: `src/traits.mbt` (append after line 78)

- [ ] **Step 1: Add the Predecessors trait**

Append to `src/traits.mbt`:

```moonbit
///|
/// # Predecessors — reverse-direction observation capability
///
/// Types that can efficiently answer "which vertices point to v?"
/// implement this trait alongside `DirectedGraph`. No default
/// implementation is provided — an O(V+E) scan default would be
/// a performance trap.
///
/// Used by `Reversed[G]` to swap `successors` and `predecessors`.
pub(open) trait Predecessors {
  predecessors(Self, Int) -> Iter[Int]
}
```

- [ ] **Step 2: Run `moon check`**

Run: `moon check`
Expected: Pass (trait defined but not yet used).

- [ ] **Step 3: Commit**

```bash
git add src/traits.mbt
git commit -m "feat: add Predecessors capability trait"
```

---

### Task 2: Add bidirectional storage to `AdjacencyMap`

**Files:**
- Modify: `src/adjacency_map.mbt`

This task updates the struct and all construction methods to maintain a `reverse` map. Each step edits one method, then runs `moon check`.

- [ ] **Step 1: Add `reverse` field to struct**

Change `src/adjacency_map.mbt:40-42`:

```moonbit
pub struct AdjacencyMap {
  adjacency : Map[Int, Array[Int]]
  reverse : Map[Int, Array[Int]]
}
```

Run: `moon check`
Expected: FAIL — all constructors return `{ adjacency: ... }` without `reverse`.

- [ ] **Step 2: Update `empty()`**

Change `src/adjacency_map.mbt:47-49`:

```moonbit
pub fn AdjacencyMap::empty() -> AdjacencyMap {
  { adjacency: Map::new(), reverse: Map::new() }
}
```

Run: `moon check`
Expected: Still fails (other constructors not yet fixed).

- [ ] **Step 3: Update `vertex(v)`**

Change `src/adjacency_map.mbt:53-57`:

```moonbit
pub fn AdjacencyMap::vertex(v : Int) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  m[v] = []
  let r : Map[Int, Array[Int]] = Map::new()
  r[v] = []
  { adjacency: m, reverse: r }
}
```

- [ ] **Step 4: Update `edge(u, v)`**

Change `src/adjacency_map.mbt:62-69`:

```moonbit
pub fn AdjacencyMap::edge(u : Int, v : Int) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  let r : Map[Int, Array[Int]] = Map::new()
  m[u] = [v]
  r[v] = [u]
  if u != v {
    m[v] = []
    r[u] = []
  }
  { adjacency: m, reverse: r }
}
```

- [ ] **Step 5: Update `from_edges(edges)`**

Change `src/adjacency_map.mbt:77-104`. Build both forward and reverse maps in the same loop:

```moonbit
pub fn AdjacencyMap::from_edges(edges : Array[(Int, Int)]) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  let r : Map[Int, Array[Int]] = Map::new()
  let seen : Map[Int, @hashset.HashSet[Int]] = Map::new()
  for edge in edges {
    let u = edge.0
    let v = edge.1
    match seen.get(u) {
      Some(set) =>
        if !set.contains(v) {
          set.add(v)
          match m.get(u) {
            Some(arr) => arr.push(v)
            None => m[u] = [v]
          }
          match r.get(v) {
            Some(arr) => arr.push(u)
            None => r[v] = [u]
          }
        }
      None => {
        let set : @hashset.HashSet[Int] = @hashset.new()
        set.add(v)
        seen[u] = set
        m[u] = [v]
        match r.get(v) {
          Some(arr) => arr.push(u)
          None => r[v] = [u]
        }
      }
    }
    if !m.contains(v) {
      m[v] = []
    }
    if !r.contains(u) {
      r[u] = []
    }
  }
  { adjacency: m, reverse: r }
}
```

- [ ] **Step 6: Update `overlay(other)`**

Change `src/adjacency_map.mbt:114-158`. Same merge logic, applied to both `adjacency` and `reverse`:

```moonbit
pub fn AdjacencyMap::overlay(
  self : AdjacencyMap,
  other : AdjacencyMap,
) -> AdjacencyMap {
  fn merge_maps(
    a : Map[Int, Array[Int]],
    b : Map[Int, Array[Int]]
  ) -> Map[Int, Array[Int]] {
    let m : Map[Int, Array[Int]] = Map::new()
    let seen : Map[Int, @hashset.HashSet[Int]] = Map::new()
    for k, v in a {
      let arr = v.copy()
      m[k] = arr
      let set : @hashset.HashSet[Int] = @hashset.new()
      for elem in arr {
        set.add(elem)
      }
      seen[k] = set
    }
    for k, v in b {
      match m.get(k) {
        Some(existing) => {
          let set = match seen.get(k) {
            Some(s) => s
            None => {
              let s : @hashset.HashSet[Int] = @hashset.new()
              seen[k] = s
              s
            }
          }
          for elem in v {
            if !set.contains(elem) {
              set.add(elem)
              existing.push(elem)
            }
          }
        }
        None => {
          m[k] = v.copy()
          let set : @hashset.HashSet[Int] = @hashset.new()
          for elem in v {
            set.add(elem)
          }
          seen[k] = set
        }
      }
    }
    m
  }

  {
    adjacency: merge_maps(self.adjacency, other.adjacency),
    reverse: merge_maps(self.reverse, other.reverse),
  }
}
```

- [ ] **Step 7: Update `connect(other)`**

Change `src/adjacency_map.mbt:171-199`. Build cross-edges in both directions:

```moonbit
pub fn AdjacencyMap::connect(
  self : AdjacencyMap,
  other : AdjacencyMap,
) -> AdjacencyMap {
  let base = self.overlay(other)
  let m = base.adjacency
  let r = base.reverse
  let other_vertices : Array[Int] = []
  for k, _ in other.adjacency {
    other_vertices.push(k)
  }
  let self_vertices : Array[Int] = []
  for k, _ in self.adjacency {
    self_vertices.push(k)
  }
  // Forward cross-edges: every self vertex → every other vertex
  for u in self_vertices {
    let current = match m.get(u) {
      Some(s) => s
      None => []
    }
    let set : @hashset.HashSet[Int] = @hashset.new()
    for elem in current {
      set.add(elem)
    }
    for ov in other_vertices {
      if !set.contains(ov) {
        set.add(ov)
        current.push(ov)
      }
    }
    m[u] = current
  }
  // Reverse cross-edges: every other vertex ← every self vertex
  for v in other_vertices {
    let current = match r.get(v) {
      Some(s) => s
      None => []
    }
    let set : @hashset.HashSet[Int] = @hashset.new()
    for elem in current {
      set.add(elem)
    }
    for sv in self_vertices {
      if !set.contains(sv) {
        set.add(sv)
        current.push(sv)
      }
    }
    r[v] = current
  }
  { adjacency: m, reverse: r }
}
```

- [ ] **Step 8: Simplify `transpose()`**

Change `src/adjacency_map.mbt:267-296`:

```moonbit
/// Reverse all edge directions. O(1) — swaps forward and reverse maps.
///
/// The original and transposed graph share underlying map data (shallow copy).
/// This is safe because AdjacencyMap is treated as immutable after construction.
pub fn AdjacencyMap::transpose(self : AdjacencyMap) -> AdjacencyMap {
  { adjacency: self.reverse, reverse: self.adjacency }
}
```

- [ ] **Step 9: Update `remove_self_loops()`**

Change `src/adjacency_map.mbt:301-313`:

```moonbit
pub fn AdjacencyMap::remove_self_loops(self : AdjacencyMap) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  let r : Map[Int, Array[Int]] = Map::new()
  for k, succs in self.adjacency {
    let filtered : Array[Int] = []
    for v in succs {
      if v != k {
        filtered.push(v)
      }
    }
    m[k] = filtered
  }
  for k, preds in self.reverse {
    let filtered : Array[Int] = []
    for v in preds {
      if v != k {
        filtered.push(v)
      }
    }
    r[k] = filtered
  }
  { adjacency: m, reverse: r }
}
```

- [ ] **Step 10: Update `Eq` implementation**

Change `src/adjacency_map.mbt:379-403` — add reverse map comparison:

```moonbit
pub impl Eq for AdjacencyMap with equal(self, other) -> Bool {
  fn maps_equal(
    a : Map[Int, Array[Int]],
    b : Map[Int, Array[Int]]
  ) -> Bool {
    if a.length() != b.length() {
      return false
    }
    for k, v in a {
      match b.get(k) {
        None => return false
        Some(other_v) => {
          if v.length() != other_v.length() {
            return false
          }
          let sorted_self = v.copy()
          sorted_self.sort()
          let sorted_other = other_v.copy()
          sorted_other.sort()
          for i = 0; i < sorted_self.length(); i = i + 1 {
            if sorted_self[i] != sorted_other[i] {
              return false
            }
          }
        }
      }
    }
    true
  }

  maps_equal(self.adjacency, other.adjacency)
}
```

Note: `Eq` only checks `adjacency` (forward edges). The reverse map is derived — if forward edges are equal, reverse edges must be equal too (given correct construction).

- [ ] **Step 11: Impl `Predecessors` for `AdjacencyMap`**

Append to `src/adjacency_map.mbt`:

```moonbit
///|
pub impl Predecessors for AdjacencyMap with predecessors(self, v) {
  match self.reverse.get(v) {
    Some(s) => s.iter()
    None => Iter::empty()
  }
}
```

- [ ] **Step 12: Fix `Graph::to_adjacency_map` isolated vertex registration**

This must be fixed before running tests — existing QC tests call `g.to_adjacency_map().scc()` which would fail with an incomplete reverse map.

Change `src/graph_expr.mbt:145-152`:

```moonbit
  let g = AdjacencyMap::from_edges(all_edges)
  // Register isolated vertices (Vertex nodes with no edges)
  for v in all_vertices {
    if !g.adjacency.contains(v) {
      g.adjacency[v] = []
      g.reverse[v] = []
    }
  }
  g
```

- [ ] **Step 13: Fix `AdjacencyMap::condensation` isolated component registration**

Change `src/scc.mbt:179-186`:

```moonbit
  let dag = AdjacencyMap::from_edges(condensed_edges)
  // Add isolated components (no inter-component edges) as vertices
  for i = 0; i < num_components; i = i + 1 {
    if !dag.adjacency.contains(i) {
      dag.adjacency[i] = []
      dag.reverse[i] = []
    }
  }
  (dag, vertex_to_component)
```

- [ ] **Step 14: Run `moon check`**

Run: `moon check`
Expected: Pass.

- [ ] **Step 15: Run tests**

Run: `moon test`
Expected: All 211 existing tests pass.

- [ ] **Step 16: Commit**

```bash
git add src/adjacency_map.mbt src/graph_expr.mbt src/scc.mbt
git commit -m "feat: bidirectional adjacency storage + Predecessors for AdjacencyMap

Add reverse map to AdjacencyMap, maintained by all constructors.
Fix direct mutation sites in graph_expr and scc to maintain reverse map.
transpose() is now O(1) (swap maps). Impl Predecessors trait.

Note: adding reverse field to pub struct AdjacencyMap is a public API
break for direct construction, acceptable at v0.1.0."
```

---

### Task 3: Add bidirectional storage to `DenseGraph`

**Files:**
- Modify: `src/dense_graph.mbt`

- [ ] **Step 1: Add `predecessors` field**

Change `src/dense_graph.mbt:33-35`:

```moonbit
pub(all) struct DenseGraph {
  successors : Array[Array[Int]]
  predecessors : Array[Array[Int]]
}
```

Run: `moon check`
Expected: FAIL — constructors don't provide `predecessors`.

- [ ] **Step 2: Update `from_edges`**

Change `src/dense_graph.mbt:47-69`:

```moonbit
pub fn DenseGraph::from_edges(
  vertex_count : Int,
  edges : Array[(Int, Int)],
) -> DenseGraph {
  let succs : Array[Array[Int]] = Array::makei(vertex_count, fn(_i) { [] })
  let preds : Array[Array[Int]] = Array::makei(vertex_count, fn(_i) { [] })
  let seen : Array[@hashset.HashSet[Int]] = Array::makei(vertex_count, fn(_i) {
    @hashset.new()
  })
  for edge in edges {
    let u = edge.0
    let v = edge.1
    guard u >= 0 && u < vertex_count && v >= 0 && v < vertex_count else {
      abort(
        "DenseGraph::from_edges: vertex out of range 0..\{vertex_count - 1}: edge (\{u}, \{v})",
      )
    }
    if !seen[u].contains(v) {
      seen[u].add(v)
      succs[u].push(v)
      preds[v].push(u)
    }
  }
  { successors: succs, predecessors: preds }
}
```

- [ ] **Step 3: Update `from_adjacency_map`**

Change `src/dense_graph.mbt:77-97`:

```moonbit
pub fn DenseGraph::from_adjacency_map(am : AdjacencyMap) -> DenseGraph {
  let n = am.vertex_count()
  let succs : Array[Array[Int]] = Array::makei(n, fn(_i) { [] })
  let preds : Array[Array[Int]] = Array::makei(n, fn(_i) { [] })
  for v, s in am.adjacency {
    guard v >= 0 && v < n else {
      abort(
        "DenseGraph::from_adjacency_map: vertex \{v} out of range 0..\{n - 1}",
      )
    }
    succs[v] = s.copy()
    for w in s {
      guard w >= 0 && w < n else {
        abort(
          "DenseGraph::from_adjacency_map: successor \{w} of vertex \{v} out of range 0..\{n - 1}",
        )
      }
      preds[w].push(v)
    }
  }
  { successors: succs, predecessors: preds }
}
```

- [ ] **Step 4: Simplify `transpose()`**

Change `src/dense_graph.mbt:101-110`:

```moonbit
/// Reverse all edge directions. O(1) — swaps successor and predecessor arrays.
pub fn DenseGraph::transpose(self : DenseGraph) -> DenseGraph {
  { successors: self.predecessors, predecessors: self.successors }
}
```

- [ ] **Step 5: Impl `Predecessors` for `DenseGraph`**

Append to `src/dense_graph.mbt` (after the `DirectedGraph` impls):

```moonbit
///|
pub impl Predecessors for DenseGraph with predecessors(self, v) {
  if v >= 0 && v < self.predecessors.length() {
    self.predecessors[v].iter()
  } else {
    Iter::empty()
  }
}
```

- [ ] **Step 6: Fix `DenseGraph::scc` transpose usage**

`DenseGraph::scc` at line 369 calls `self.transpose()` and then accesses `transposed.successors[v]` at line 384. After the `transpose()` change, `transposed.successors` is the old `self.predecessors`, which is correct. No code change needed — just verify.

- [ ] **Step 7: Run `moon check`**

Run: `moon check`
Expected: Pass.

- [ ] **Step 8: Run tests**

Run: `moon test`
Expected: All 211 existing tests pass.

- [ ] **Step 9: Commit**

```bash
git add src/dense_graph.mbt
git commit -m "feat: bidirectional storage + Predecessors for DenseGraph

Add predecessors array to DenseGraph, built during construction.
transpose() is now O(1) (swap arrays). Impl Predecessors trait."
```

---

### Task 4: Add `Reversed[G]` struct and impls

**Files:**
- Create: `src/reversed.mbt`

- [ ] **Step 1: Create `src/reversed.mbt`**

```moonbit
///|
/// # Reversed — zero-cost reverse-direction graph view
///
/// Wraps any graph that implements `DirectedGraph + Predecessors` and
/// swaps the direction of all edge queries. `successors` on the reversed
/// graph returns `predecessors` on the original, and vice versa.
///
/// ## Properties
///
/// - **Lightweight**: holds the original graph value. For alga's types
///   (AdjacencyMap, DenseGraph), this is a shallow handle copy.
/// - **Involution**: `Reversed(Reversed(g))` produces the same traversal as `g`.
/// - **Composable**: implements `DirectedGraph + Predecessors`, works with
///   all algorithms: `dfs_events`, `reachable`, `toposort`, `tarjan_scc`, etc.
pub struct Reversed[G] {
  graph : G
}

///|
pub fn[G : DirectedGraph + Predecessors] reversed(graph : G) -> Reversed[G] {
  { graph, }
}

///|
pub impl[G : DirectedGraph + Predecessors] DirectedGraph for Reversed[G] with iter(self) {
  G::iter(self.graph)
}

///|
pub impl[G : DirectedGraph + Predecessors] DirectedGraph for Reversed[G] with successors(self, v) {
  G::predecessors(self.graph, v)
}

///|
pub impl[G : DirectedGraph + Predecessors] DirectedGraph for Reversed[G] with has_vertex(self, v) {
  G::has_vertex(self.graph, v)
}

///|
pub impl[G : DirectedGraph + Predecessors] DirectedGraph for Reversed[G] with vertex_count(self) {
  G::vertex_count(self.graph)
}

///|
pub impl[G : DirectedGraph + Predecessors] Predecessors for Reversed[G] with predecessors(self, v) {
  G::successors(self.graph, v)
}
```

- [ ] **Step 2: Add `derive(Eq)` to `DfsEvent`**

In `src/dfs.mbt`, change the DfsEvent enum to derive Eq (needed for property tests in Task 6):

```moonbit
pub(all) enum DfsEvent {
  /// Vertex entered — pre-order. Vertex transitions white → gray.
  Discover(Int)
  /// All descendants done — post-order. Vertex transitions gray → black.
  Finish(Int)
  /// (u, v): v was white. v will be discovered on the next `.next()` call.
  TreeEdge(Int, Int)
  /// (u, v): v is gray (ancestor on stack). Indicates a cycle: v →...→ u → v.
  BackEdge(Int, Int)
  /// (u, v): v is black (already finished). Merged forward + cross edges.
  CrossForwardEdge(Int, Int)
} derive(Eq)
```

- [ ] **Step 3: Run `moon check`**

Run: `moon check`
Expected: Pass.

- [ ] **Step 4: Commit**

```bash
git add src/reversed.mbt src/dfs.mbt
git commit -m "feat: add Reversed[G] zero-cost graph adaptor

Newtype wrapper that swaps successors/predecessors. Implements
DirectedGraph + Predecessors for any G : DirectedGraph + Predecessors.
Lightweight (shallow handle copy), involutive, fully composable."
```

---

### Task 5: Add unit tests

**Files:**
- Modify: `src/adjacency_map_test.mbt` (append)
- Modify: `src/dfs_test.mbt` (append)

- [ ] **Step 1: Add `predecessors` tests for AdjacencyMap**

Append to `src/adjacency_map_test.mbt`:

```moonbit
// --- predecessors ---

///|
test "predecessors empty graph" {
  let g = @alga.AdjacencyMap::empty()
  assert_eq(@alga.Predecessors::predecessors(g, 0).collect(), [])
}

///|
test "predecessors single vertex" {
  let g = @alga.AdjacencyMap::vertex(1)
  assert_eq(@alga.Predecessors::predecessors(g, 1).collect(), [])
}

///|
test "predecessors chain" {
  // 1 → 2 → 3
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  assert_eq(@alga.Predecessors::predecessors(g, 1).collect(), [])
  assert_eq(@alga.Predecessors::predecessors(g, 2).collect(), [1])
  assert_eq(@alga.Predecessors::predecessors(g, 3).collect(), [2])
}

///|
test "predecessors diamond" {
  // 0 → 1, 0 → 2, 1 → 3, 2 → 3
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (0, 2), (1, 3), (2, 3)])
  let preds_3 = @alga.Predecessors::predecessors(g, 3).collect()
  assert_eq(preds_3.length(), 2)
  assert_true(preds_3.contains(1))
  assert_true(preds_3.contains(2))
}

///|
test "predecessors self loop" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  assert_eq(@alga.Predecessors::predecessors(g, 1).collect(), [1])
}
```

- [ ] **Step 2: Add `Reversed` tests**

Append to `src/dfs_test.mbt`:

```moonbit
// --- reversed ---

///|
test "reversed successors are predecessors" {
  // 0 → 1 → 2
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2)])
  let rev = @alga.reversed(g)
  // Reversed successors of 2 = predecessors of 2 = [1]
  assert_eq(@alga.DirectedGraph::successors(rev, 2).collect(), [1])
  // Reversed successors of 0 = predecessors of 0 = []
  assert_eq(@alga.DirectedGraph::successors(rev, 0).collect(), [])
}

///|
test "reversed predecessors are successors" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2)])
  let rev = @alga.reversed(g)
  assert_eq(@alga.Predecessors::predecessors(rev, 0).collect(), [1])
}

///|
test "reversed vertex count unchanged" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3)])
  let rev = @alga.reversed(g)
  assert_eq(@alga.DirectedGraph::vertex_count(rev), 4)
}

///|
test "reversed has_vertex unchanged" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1)])
  let rev = @alga.reversed(g)
  assert_true(@alga.DirectedGraph::has_vertex(rev, 0))
  assert_true(@alga.DirectedGraph::has_vertex(rev, 1))
  assert_true(!@alga.DirectedGraph::has_vertex(rev, 99))
}

///|
test "reversed involution" {
  // reversed(reversed(g)) has same successors as g
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (0, 2)])
  let rr = @alga.reversed(@alga.reversed(g))
  for v in @alga.DirectedGraph::iter(g) {
    let orig = @alga.DirectedGraph::successors(g, v).collect()
    let double = @alga.DirectedGraph::successors(rr, v).collect()
    orig.sort()
    double.sort()
    assert_eq(orig, double)
  }
}

///|
test "reversed works with dfs_events" {
  // 0 → 1 → 2: reversed DFS from 2 should discover 2, then 1, then 0
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2)])
  let rev = @alga.reversed(g)
  let events = @alga.dfs_events(rev).collect()
  let mut discovers = 0
  let mut finishes = 0
  for e in events.iter() {
    match e {
      @alga.Discover(_) => discovers = discovers + 1
      @alga.Finish(_) => finishes = finishes + 1
      _ => ()
    }
  }
  assert_eq(discovers, 3)
  assert_eq(finishes, 3)
}

///|
test "reversed works with reachable" {
  // 0 → 1 → 2 → 3: reverse-reachable from 3 = all vertices
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3)])
  let rev = @alga.reversed(g)
  let r = @alga.reachable(rev, 3)
  assert_eq(r.length(), 4)
}

///|
test "reversed DenseGraph" {
  let g = @alga.DenseGraph::from_edges(3, [(0, 1), (1, 2)])
  let rev = @alga.reversed(g)
  assert_eq(@alga.DirectedGraph::successors(rev, 2).collect(), [1])
  assert_eq(@alga.DirectedGraph::successors(rev, 0).collect(), [])
}

///|
test "reversed empty graph" {
  let g = @alga.AdjacencyMap::empty()
  let rev = @alga.reversed(g)
  assert_eq(@alga.dfs_events(rev).collect().length(), 0)
}

///|
test "reversed self loop" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  let rev = @alga.reversed(g)
  // Self-loop stays a self-loop when reversed
  assert_eq(@alga.DirectedGraph::successors(rev, 1).collect(), [1])
}
```

- [ ] **Step 3: Add DenseGraph predecessor tests and overlay/connect/transpose regression tests**

Append to `src/adjacency_map_test.mbt`:

```moonbit
///|
test "predecessors after overlay" {
  let g1 = @alga.AdjacencyMap::from_edges([(0, 1)])
  let g2 = @alga.AdjacencyMap::from_edges([(2, 1)])
  let g = g1.overlay(g2)
  let preds_1 = @alga.Predecessors::predecessors(g, 1).collect()
  assert_eq(preds_1.length(), 2)
  assert_true(preds_1.contains(0))
  assert_true(preds_1.contains(2))
}

///|
test "predecessors after connect" {
  let g1 = @alga.AdjacencyMap::vertex(0)
  let g2 = @alga.AdjacencyMap::vertex(1)
  let g = g1.connect(g2)
  // connect(0, 1) creates edge 0→1
  assert_eq(@alga.Predecessors::predecessors(g, 1).collect(), [0])
  assert_eq(@alga.Predecessors::predecessors(g, 0).collect(), [])
}

///|
test "transpose regression: transpose preserves predecessors" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (0, 2)])
  let t = g.transpose()
  // In transposed graph, successors of 1 = [0]
  assert_eq(t.successor_list(1), [0])
  // Predecessors of 0 in transposed = [1, 2]
  let preds = @alga.Predecessors::predecessors(t, 0).collect()
  assert_eq(preds.length(), 2)
  assert_true(preds.contains(1))
  assert_true(preds.contains(2))
}
```

Append to `src/dfs_test.mbt`:

```moonbit
///|
test "predecessors on DenseGraph" {
  let g = @alga.DenseGraph::from_edges(3, [(0, 1), (1, 2), (0, 2)])
  assert_eq(@alga.Predecessors::predecessors(g, 0).collect(), [])
  assert_eq(@alga.Predecessors::predecessors(g, 1).collect(), [0])
  let preds_2 = @alga.Predecessors::predecessors(g, 2).collect()
  assert_eq(preds_2.length(), 2)
  assert_true(preds_2.contains(1))
  assert_true(preds_2.contains(0))
}

///|
test "DenseGraph transpose regression" {
  let g = @alga.DenseGraph::from_edges(3, [(0, 1), (1, 2)])
  let t = g.transpose()
  assert_eq(@alga.DirectedGraph::successors(t, 2).collect(), [1])
  assert_eq(@alga.Predecessors::predecessors(t, 0).collect(), [1])
}

///|
test "reversed works with toposort" {
  // 0 → 1 → 2: toposort = [0, 1, 2], reversed toposort = [2, 1, 0]
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2)])
  let rev_topo = @alga.toposort(@alga.reversed(g))
  match rev_topo {
    Some(order) => assert_eq(order, [2, 1, 0])
    None => assert_true(false)
  }
}
```

- [ ] **Step 4: Run tests**

Run: `moon test`
Expected: All tests pass (old + new).

- [ ] **Step 5: Commit**

```bash
git add src/adjacency_map_test.mbt src/dfs_test.mbt
git commit -m "test: unit tests for Predecessors and Reversed[G]

Tests cover: predecessors on AdjacencyMap and DenseGraph (empty, single,
chain, diamond, self-loop, overlay, connect), transpose regression,
Reversed successors/predecessors swap, involution, composition with
dfs_events/reachable/toposort, DenseGraph genericity, edge cases."
```

---

### Task 6: Add property tests

**Files:**
- Modify: `src/graph_expr_qc.mbt` (append)

- [ ] **Step 1: Add property tests**

Append to `src/graph_expr_qc.mbt`:

```moonbit
///|
/// Property: reversed(g).successors(v) == g.predecessors(v) for all vertices.
test "prop: reversed successors match predecessors" {
  @qc.quick_check_fn(
    fn(g : Graph) -> Bool {
      let am = g.to_adjacency_map()
      let rev = reversed(am)
      for v in DirectedGraph::iter(am) {
        let preds = Predecessors::predecessors(am, v).collect()
        let rev_succs = DirectedGraph::successors(rev, v).collect()
        preds.sort()
        rev_succs.sort()
        if preds != rev_succs {
          return false
        }
      }
      true
    },
    max_success=100,
  )
}

///|
/// Property: reversed(reversed(g)) produces same dfs_events as g.
test "prop: reversed involution preserves dfs_events" {
  @qc.quick_check_fn(
    fn(g : Graph) -> Bool {
      let am = g.to_adjacency_map()
      let rr = reversed(reversed(am))
      let events_orig = dfs_events(am).collect()
      let events_rr = dfs_events(rr).collect()
      if events_orig.length() != events_rr.length() {
        return false
      }
      for i = 0; i < events_orig.length(); i = i + 1 {
        if events_orig[i] != events_rr[i] {
          return false
        }
      }
      true
    },
    max_success=100,
  )
}

///|
/// Property: edge count is preserved under reversal.
test "prop: reversed preserves edge count" {
  @qc.quick_check_fn(
    fn(g : Graph) -> Bool {
      let am = g.to_adjacency_map()
      let rev = reversed(am)
      let mut orig_edges = 0
      let mut rev_edges = 0
      for e in dfs_events(am) {
        match e {
          TreeEdge(_, _) | BackEdge(_, _) | CrossForwardEdge(_, _) =>
            orig_edges = orig_edges + 1
          _ => ()
        }
      }
      for e in dfs_events(rev) {
        match e {
          TreeEdge(_, _) | BackEdge(_, _) | CrossForwardEdge(_, _) =>
            rev_edges = rev_edges + 1
          _ => ()
        }
      }
      orig_edges == rev_edges
    },
    max_success=100,
  )
}
```

- [ ] **Step 2: Run tests**

Run: `moon test`
Expected: All tests pass including 3 new property tests (300 random graphs).

- [ ] **Step 3: Commit**

```bash
git add src/graph_expr_qc.mbt
git commit -m "test: property tests for Reversed[G]

Three properties verified over 100 random graphs each:
1. reversed(g).successors(v) == g.predecessors(v)
2. reversed(reversed(g)) preserves dfs_events (involution)
3. Edge count preserved under reversal"
```

---

### Task 7: Update interfaces, format, docs, finalize

**Files:**
- Regenerate: `src/pkg.generated.mbti`
- Modify: `docs/TODO.md`

- [ ] **Step 1: Run `moon info && moon fmt`**

Run: `moon info && moon fmt`

- [ ] **Step 2: Verify API changes**

Run: `git diff src/pkg.generated.mbti`

Expected new entries:
- `pub(open) trait Predecessors { predecessors(Self, Int) -> Iter[Int] }`
- `pub struct Reversed[G] { graph : G }`
- `pub fn reversed[G : DirectedGraph + Predecessors](G) -> Reversed[G]`
- `pub impl Predecessors for AdjacencyMap`
- `pub impl Predecessors for DenseGraph`
- `pub impl DirectedGraph for Reversed[...]`
- `pub impl Predecessors for Reversed[...]`
- `DenseGraph` struct now has `predecessors` field

- [ ] **Step 3: Run full test suite**

Run: `moon test`
Expected: All tests pass.

- [ ] **Step 4: Update TODO**

In `docs/TODO.md`, move "Zero-copy graph adaptors" from Investigate. Remove the line:
```
- **Zero-copy graph adaptors** — `Reversed[G]`, `NodeFiltered[G]` implementing `DirectedGraph` without allocation. Enables generic SCC (no transpose copy) and cheap subgraph views. Source: [petgraph analysis](specs/2026-04-01-petgraph-analysis.md#1-zero-copy-graph-adaptors)
```

Add to Done section:
```
- **~~Reversed graph adaptor~~** — `Reversed[G]` zero-cost newtype + `Predecessors` capability trait + bidirectional adjacency in `AdjacencyMap`/`DenseGraph`. `transpose()` is now O(1). Source: [spec](specs/2026-04-01-reversed-graph-adaptor-design.md)
```

Add to Investigate (remaining from the original item):
```
- **NodeFiltered graph adaptor** — `NodeFiltered[G]` implementing `DirectedGraph` without allocation. Cheap subgraph views for scope-restricted traversals. Source: [petgraph analysis](specs/2026-04-01-petgraph-analysis.md#1-zero-copy-graph-adaptors)
```

- [ ] **Step 5: Commit**

```bash
git add src/pkg.generated.mbti docs/TODO.md
git commit -m "chore: regenerate interfaces, update TODO for Reversed adaptor"
```
