# Iter-Based DirectedGraph + Tarjan SCC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `DirectedGraph` trait from CPS callbacks to `Iter[Int]`-based required methods, then implement Tarjan SCC generic over `DirectedGraph`.

**Architecture:** Two-phase change. Phase 1 swaps the trait's required methods from `for_each_vertex`/`for_each_successor` to `iter`/`successors` returning `Iter[Int]`, with callback methods becoming defaulted. Phase 2 adds `tarjan_scc` — a single-pass iterative SCC algorithm using `Iter[Int].next()` for pause/resume.

**Tech Stack:** MoonBit, `Iter[Int]` (`struct Iter[X](fn() -> X?)`), `moonbitlang/quickcheck` for property tests.

**Spec:** `docs/specs/2026-04-01-iter-based-trait-and-tarjan-design.md`

---

## File Map

| File | Change | Responsibility |
|------|--------|---------------|
| `src/traits.mbt` | Rewrite | Trait definition + 4 defaults |
| `src/adjacency_map.mbt` | Modify | `iter`/`successors` impls, rename `successors` → `successor_list` |
| `src/dense_graph.mbt` | Modify | `iter`/`successors` impls |
| `src/dfs.mbt` | Rename | `for_each_successor` → `each_successor` (2 sites) |
| `src/bfs.mbt` | Rename | `for_each_successor` → `each_successor` (2 sites) |
| `src/toposort.mbt` | Rename | `for_each_vertex`/`for_each_successor` → `each_vertex`/`each_successor` (6 sites) |
| `src/degree.mbt` | Rename | `for_each_vertex`/`for_each_successor` → `each_vertex`/`each_successor` (3 sites) |
| `src/adjacency_map_test.mbt` | Rename | `successors` → `successor_list` (2 call sites, lines 91, 106) |
| `src/scc.mbt` | Modify | Rename call sites in Kosaraju, add `tarjan_scc` |
| `src/scc_test.mbt` | Modify | Add Tarjan tests |
| `src/integration_wbtest.mbt` | Rewrite impls | `ArrayGraph` → `iter`/`successors` |
| `src/benchmark.mbt` | Rewrite impls | `BenchMinimalGraph` → `iter`/`successors` |
| `src/graph_expr_qc.mbt` | No change | Property tests use `AdjacencyMap` directly, not trait methods |
| `src/experiment/*.mbt` | Batch rename | `for_each_vertex`/`for_each_successor` → `each_vertex`/`each_successor` |

---

### Task 1: Rewrite trait definition and defaults

**Files:**
- Modify: `src/traits.mbt` (full rewrite, lines 1-85)

- [ ] **Step 1: Rewrite the trait and defaults**

Replace the entire content of `src/traits.mbt` with:

```moonbit
///|
/// # DirectedGraph — the observation layer
///
/// This trait defines the minimal interface for observing a directed graph.
/// Implement `iter` and `successors` to get every algorithm in the library
/// for free. `each_vertex`, `each_successor`, `vertex_count`, and `has_vertex`
/// all have defaults derived from the two required methods.
///
/// ## Contract
///
/// `iter` must yield each vertex exactly once.
///
/// ## Design decisions
///
/// **Fixed vertex type (Int):**
/// MoonBit traits cannot have type parameters or associated types, so we
/// fix vertices to `Int`. If your vertices are strings or custom IDs,
/// map them to `Int` indices.
///
/// **Iter-based iteration:**
/// `iter` and `successors` return `Iter[Int]` — MoonBit's external iterator
/// (`struct Iter[X](fn() -> X?)`). Pull-based: call `.next()` for one vertex
/// at a time. Enables pause/resume (Tarjan SCC), early termination
/// (`has_vertex` short-circuits via `Iter::contains`), and lazy composition.
///
/// **Callback methods defaulted:**
/// `each_vertex` and `each_successor` delegate to `Iter::each` for push-style
/// algorithms (DFS, BFS, toposort). Effect-polymorphic `raise?` matches
/// MoonBit stdlib convention (`Map::each`, `HashSet::each`).
///
/// ## Example: minimal implementation (2 methods)
///
/// ```
/// struct MyGraph { edges : Array[Array[Int]] }
///
/// impl DirectedGraph for MyGraph with iter(self) {
///   0.until(self.edges.length())
/// }
/// impl DirectedGraph for MyGraph with successors(self, v) {
///   self.edges[v].iter()
/// }
/// // vertex_count, has_vertex, each_vertex, each_successor all work via defaults.
/// ```
pub(open) trait DirectedGraph {
  iter(Self) -> Iter[Int]
  successors(Self, Int) -> Iter[Int]
  each_vertex(Self, (Int) -> Unit raise?) -> Unit raise? = _
  each_successor(Self, Int, (Int) -> Unit raise?) -> Unit raise? = _
  vertex_count(Self) -> Int = _
  has_vertex(Self, Int) -> Bool = _
}

///|
/// Default each_vertex: delegates to `Iter::each`.
/// Uses trait-qualified `DirectedGraph::iter(self)` to guarantee correct dispatch.
impl DirectedGraph with each_vertex(self, f) {
  DirectedGraph::iter(self).each(f)
}

///|
/// Default each_successor: delegates to `Iter::each`.
impl DirectedGraph with each_successor(self, v, f) {
  DirectedGraph::successors(self, v).each(f)
}

///|
/// Default vertex_count: O(V) — counts via `Iter::count`.
/// Override for O(1) if your type tracks vertex count directly.
impl DirectedGraph with vertex_count(self) {
  DirectedGraph::iter(self).count()
}

///|
/// Default has_vertex: uses `Iter::contains` which short-circuits on match.
/// O(1) best case, O(V) worst case. Override for O(1) if your type
/// supports constant-time membership.
impl DirectedGraph with has_vertex(self, v) {
  DirectedGraph::iter(self).contains(v)
}
```

- [ ] **Step 2: Run `moon check` to verify trait compiles**

Run: `moon check`
Expected: Errors in files that still reference `for_each_vertex`/`for_each_successor` — that's expected. The trait itself should compile.

- [ ] **Step 3: Commit trait change**

```bash
git add src/traits.mbt
git commit -m "refactor: rewrite DirectedGraph trait with iter-based required methods

Required: iter(Self) -> Iter[Int], successors(Self, Int) -> Iter[Int]
Defaulted: each_vertex, each_successor (raise?-polymorphic), vertex_count, has_vertex
has_vertex now short-circuits via Iter::contains."
```

---

### Task 2: Update AdjacencyMap implementation

**Files:**
- Modify: `src/adjacency_map.mbt` (lines 223-433)

- [ ] **Step 1: Rename `successors` to `successor_list`**

In `src/adjacency_map.mbt`, replace lines 223-230:

```moonbit
///|
/// Successor vertices of v as an array (copy).
pub fn AdjacencyMap::successor_list(self : AdjacencyMap, v : Int) -> Array[Int] {
  match self.adjacency.get(v) {
    Some(s) => s.copy()
    None => []
  }
}
```

- [ ] **Step 2: Replace trait impls**

Replace lines 406-433 (`DirectedGraph` impls) with:

```moonbit
///|
/// DirectedGraph trait implementation — delegates to the adjacency map.
pub impl DirectedGraph for AdjacencyMap with vertex_count(self) {
  self.adjacency.length()
}

///|
pub impl DirectedGraph for AdjacencyMap with iter(self) {
  self.adjacency.iter().map(fn(pair) { pair.0 })
}

///|
pub impl DirectedGraph for AdjacencyMap with successors(self, v) {
  match self.adjacency.get(v) {
    Some(s) => s.iter()
    None => Iter::empty()
  }
}

///|
/// O(1) override — Map key lookup, bypasses the O(V) default scan.
pub impl DirectedGraph for AdjacencyMap with has_vertex(self, v) {
  self.adjacency.contains(v)
}
```

- [ ] **Step 3: Update `adjacency_map_test.mbt` call sites**

In `src/adjacency_map_test.mbt`, rename `g.successors(` to `g.successor_list(` at lines 91 and 106.

- [ ] **Step 4: Run `moon check`**

Run: `moon check`
Expected: Errors from other files still referencing old names. AdjacencyMap itself should be clean.

- [ ] **Step 5: Commit**

```bash
git add src/adjacency_map.mbt src/adjacency_map_test.mbt
git commit -m "refactor: update AdjacencyMap for iter-based DirectedGraph

- Rename successors() -> successor_list() (Array return)
- Add iter() and successors() returning Iter[Int]
- Keep vertex_count and has_vertex O(1) overrides"
```

---

### Task 3: Update DenseGraph implementation

**Files:**
- Modify: `src/dense_graph.mbt` (lines 187-204)

- [ ] **Step 1: Replace DenseGraph trait impls**

Replace lines 187-204:

```moonbit
///|
pub impl DirectedGraph for DenseGraph with iter(self) {
  0.until(self.successors.length())
}

///|
pub impl DirectedGraph for DenseGraph with successors(self, v) {
  self.successors[v].iter()
}

///|
/// O(1) override — range check on dense 0..n-1 vertex IDs.
pub impl DirectedGraph for DenseGraph with has_vertex(self, v) {
  v >= 0 && v < self.successors.length()
}
```

- [ ] **Step 2: Run `moon check`**

Run: `moon check`
Expected: Errors from algorithm files, not from DenseGraph.

- [ ] **Step 3: Commit**

```bash
git add src/dense_graph.mbt
git commit -m "refactor: update DenseGraph for iter-based DirectedGraph

- Add iter() via Int::until, successors() via Array::iter
- Keep has_vertex O(1) override"
```

---

### Task 4: Rename call sites in algorithm files

**Files:**
- Modify: `src/dfs.mbt` (lines 60, 146)
- Modify: `src/bfs.mbt` (lines 54, 111)
- Modify: `src/toposort.mbt` (lines 43, 44, 45, 79, 163, 231, 254)
- Modify: `src/degree.mbt` (lines 32, 47, 48)
- Modify: `src/scc.mbt` (no trait call sites — Kosaraju uses `self.adjacency` directly)

- [ ] **Step 1: Rename in `dfs.mbt`**

Replace `G::for_each_successor` with `G::each_successor` at two call sites (lines 60, 146).

- [ ] **Step 2: Rename in `bfs.mbt`**

Replace `G::for_each_successor` with `G::each_successor` at two call sites (lines 54, 111).

- [ ] **Step 3: Rename in `toposort.mbt`**

Replace all `G::for_each_vertex` with `G::each_vertex` and all `G::for_each_successor` with `G::each_successor`. In `compute_in_degrees` (lines 43-45), `toposort` (line 79), `topo_levels` (line 163), and `toposort_subset` (lines 231, 254).

- [ ] **Step 4: Rename in `degree.mbt`**

Replace `G::for_each_successor` with `G::each_successor` (line 32) and `G::for_each_vertex`/`G::for_each_successor` with `G::each_vertex`/`G::each_successor` (lines 47-48).

- [ ] **Step 5: Run `moon check`**

Run: `moon check`
Expected: Only errors from test/benchmark files (integration_wbtest.mbt, benchmark.mbt) and experiment files.

- [ ] **Step 6: Commit**

```bash
git add src/dfs.mbt src/bfs.mbt src/toposort.mbt src/degree.mbt
git commit -m "refactor: rename for_each_vertex/for_each_successor to each_vertex/each_successor

Mechanical rename in DFS, BFS, toposort, and degree algorithms.
Follows MoonBit stdlib convention (Map::each, HashSet::each)."
```

---

### Task 5: Update test and benchmark files

**Files:**
- Modify: `src/integration_wbtest.mbt` (lines 10-29)
- Modify: `src/benchmark.mbt` (lines 316-329)

- [ ] **Step 1: Update ArrayGraph in `integration_wbtest.mbt`**

Replace lines 10-29 with:

```moonbit
///|
impl DirectedGraph for ArrayGraph with iter(self) {
  0.until(self.successors.length())
}

///|
impl DirectedGraph for ArrayGraph with successors(self, v) {
  if v >= 0 && v < self.successors.length() {
    self.successors[v].iter()
  } else {
    Iter::empty()
  }
}
```

Remove the `vertex_count` override (line 10-12) — the default `Iter::count` will work, and `ArrayGraph` doesn't need O(1) for tests.

- [ ] **Step 2: Update BenchMinimalGraph in `benchmark.mbt`**

Replace lines 316-329 with:

```moonbit
///|
impl DirectedGraph for BenchMinimalGraph with iter(self) {
  0.until(self.edges.length())
}

///|
impl DirectedGraph for BenchMinimalGraph with successors(self, v) {
  if v >= 0 && v < self.edges.length() {
    self.edges[v].iter()
  } else {
    Iter::empty()
  }
}
```

- [ ] **Step 3: Run `moon check && moon test`**

Run: `moon check && moon test`
Expected: All non-experiment tests pass. Experiment files may still have errors.

- [ ] **Step 4: Commit**

```bash
git add src/integration_wbtest.mbt src/benchmark.mbt
git commit -m "refactor: update ArrayGraph and BenchMinimalGraph for iter-based trait"
```

---

### Task 6: Update experiment files

**Files:**
- Modify: `src/experiment/dense_iteration.mbt`
- Modify: `src/experiment/visited_set.mbt`
- Modify: `src/experiment/dense_iteration_bench.mbt`

- [ ] **Step 1: Batch rename in experiment files**

In all experiment `.mbt` files, replace:
- `@alga.DirectedGraph::for_each_vertex` → `@alga.DirectedGraph::each_vertex`
- `@alga.DirectedGraph::for_each_successor` → `@alga.DirectedGraph::each_successor`

- [ ] **Step 2: Run `moon check && moon test`**

Run: `moon check && moon test`
Expected: All tests pass. Zero errors.

- [ ] **Step 3: Run `moon info && moon fmt`**

Run: `moon info && moon fmt`
Then check: `git diff src/pkg.generated.mbti` — verify the trait signature changed as expected.

- [ ] **Step 4: Commit Phase 1 complete**

```bash
git add src/experiment/ src/pkg.generated.mbti
git commit -m "refactor: complete iter-based DirectedGraph migration

All call sites updated. Trait now requires iter/successors (Iter[Int]),
defaults each_vertex/each_successor/vertex_count/has_vertex.
has_vertex short-circuits via Iter::contains."
```

---

### Task 7: Write Tarjan SCC failing tests

**Files:**
- Modify: `src/scc_test.mbt`

- [ ] **Step 1: Add Tarjan tests (same graphs as Kosaraju)**

Append to `src/scc_test.mbt`:

```moonbit
// --- tarjan_scc tests ---

///|
test "tarjan_scc dag - each vertex is its own component" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 4)
  for i = 0; i < components.length(); i = i + 1 {
    assert_eq(components[i].length(), 1)
  }
}

///|
test "tarjan_scc single cycle" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1)])
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 1)
  assert_eq(components[0].length(), 3)
  assert_true(components[0].contains(1))
  assert_true(components[0].contains(2))
  assert_true(components[0].contains(3))
}

///|
test "tarjan_scc two components connected" {
  let g = @alga.AdjacencyMap::from_edges([
    (1, 2), (2, 1), (2, 3), (3, 4), (4, 3),
  ])
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 2)
  // Find components by membership
  let mut comp12 : Array[Int] = []
  let mut comp34 : Array[Int] = []
  for c in components {
    if c.contains(1) {
      comp12 = c
    }
    if c.contains(3) {
      comp34 = c
    }
  }
  assert_eq(comp12.length(), 2)
  assert_true(comp12.contains(1))
  assert_true(comp12.contains(2))
  assert_eq(comp34.length(), 2)
  assert_true(comp34.contains(3))
  assert_true(comp34.contains(4))
}

///|
test "tarjan_scc self loop" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 1)
  assert_eq(components[0].length(), 1)
  assert_eq(components[0][0], 1)
}

///|
test "tarjan_scc disconnected acyclic" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (3, 4)])
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 4)
}

///|
test "tarjan_scc empty graph" {
  let g = @alga.AdjacencyMap::empty()
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 0)
}

///|
test "tarjan_scc single vertex" {
  let g = @alga.AdjacencyMap::vertex(42)
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 1)
  assert_eq(components[0].length(), 1)
  assert_eq(components[0][0], 42)
}

///|
test "tarjan_scc works on DenseGraph" {
  let g = @alga.DenseGraph::from_edges(4, [(0, 1), (1, 2), (2, 0), (2, 3)])
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 2)
  let mut cycle_comp : Array[Int] = []
  let mut singleton_comp : Array[Int] = []
  for c in components {
    if c.length() == 3 { cycle_comp = c }
    if c.length() == 1 { singleton_comp = c }
  }
  assert_true(cycle_comp.contains(0))
  assert_true(cycle_comp.contains(1))
  assert_true(cycle_comp.contains(2))
  assert_eq(singleton_comp[0], 3)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test`
Expected: FAIL — `tarjan_scc` is not defined yet.

- [ ] **Step 3: Commit failing tests**

```bash
git add src/scc_test.mbt
git commit -m "test: add failing tests for tarjan_scc

Same graphs as Kosaraju tests plus DenseGraph test.
Verifies component membership regardless of internal ordering."
```

---

### Task 8: Implement Tarjan SCC

**Files:**
- Modify: `src/scc.mbt` (append after condensation)

- [ ] **Step 1: Implement `tarjan_scc`**

Append to `src/scc.mbt`:

```moonbit
///|
/// # Strongly Connected Components (Tarjan's Algorithm)
///
/// Generic over `DirectedGraph` — works on any graph type without requiring
/// `transpose`. Single DFS pass using lowlink values.
///
/// ## Algorithm: Tarjan (1972)
///
/// Performs one DFS, maintaining for each vertex:
/// - `index`: discovery time (monotonically increasing)
/// - `lowlink`: smallest index reachable from the subtree rooted at this vertex
///
/// When all successors of vertex v are processed, if `lowlink[v] == index[v]`,
/// then v is the root of an SCC — pop the SCC stack until v to extract it.
///
/// ## Implementation: fully iterative
///
/// Uses `Iter[Int].next()` for pause/resume of successor iteration. Each stack
/// frame stores `(vertex, Iter[Int])` — the iterator carries its position via
/// closure state. This avoids recursion (safe for 10K+ vertices in WASM) and
/// avoids collecting successors into temp arrays.
///
/// ## Output ordering
///
/// Produces SCCs in **forward topological order**: if component A has an edge
/// to component B, B appears before A in the result. This is the opposite of
/// Kosaraju's `scc()` which produces reverse topological order.
///
/// Time: O(V + E). Space: O(V) — no transpose allocation.
pub fn[G : DirectedGraph] tarjan_scc(graph : G) -> Array[Array[Int]] {
  let index_map : Map[Int, Int] = Map::new()
  let lowlink_map : Map[Int, Int] = Map::new()
  let on_stack : Map[Int, Bool] = Map::new()
  let scc_stack : Array[Int] = []
  let result : Array[Array[Int]] = []
  let mut counter = 0
  // Stack frames: (vertex, successor_iterator)
  // lowlink/index are stored in maps, not in the frame, because
  // they need to be updated after returning from "recursive" calls.
  let frames : Array[(Int, Iter[Int])] = []
  for root in G::iter(graph) {
    if index_map.contains(root) {
      continue
    }
    // Initialize root
    index_map[root] = counter
    lowlink_map[root] = counter
    counter = counter + 1
    on_stack[root] = true
    scc_stack.push(root)
    frames.push((root, G::successors(graph, root)))
    while frames.length() > 0 {
      let top_idx = frames.length() - 1
      let v = frames[top_idx].0
      let iter = frames[top_idx].1
      match iter.next() {
        Some(w) =>
          if !index_map.contains(w) {
            // Tree edge: "recurse" into w
            index_map[w] = counter
            lowlink_map[w] = counter
            counter = counter + 1
            on_stack[w] = true
            scc_stack.push(w)
            frames.push((w, G::successors(graph, w)))
          } else if on_stack.get(w) == Some(true) {
            // Back edge: update lowlink
            let v_low = match lowlink_map.get(v) {
              Some(l) => l
              None => 0
            }
            let w_idx = match index_map.get(w) {
              Some(i) => i
              None => 0
            }
            if w_idx < v_low {
              lowlink_map[v] = w_idx
            }
          }
        None => {
          // All successors processed — check if v is SCC root
          let v_low = match lowlink_map.get(v) {
            Some(l) => l
            None => 0
          }
          let v_idx = match index_map.get(v) {
            Some(i) => i
            None => 0
          }
          if v_low == v_idx {
            // v is root of an SCC — pop scc_stack until v
            let component : Array[Int] = []
            while true {
              let w = scc_stack.unsafe_pop()
              on_stack[w] = false
              component.push(w)
              if w == v {
                break
              }
            }
            result.push(component)
          }
          // Pop this frame and propagate lowlink to parent
          let _ = frames.unsafe_pop()
          if frames.length() > 0 {
            let parent_v = frames[frames.length() - 1].0
            let parent_low = match lowlink_map.get(parent_v) {
              Some(l) => l
              None => 0
            }
            if v_low < parent_low {
              lowlink_map[parent_v] = v_low
            }
          }
        }
      }
    }
  }
  result
}
```

- [ ] **Step 2: Run `moon check`**

Run: `moon check`
Expected: Clean compile.

- [ ] **Step 3: Run tests**

Run: `moon test`
Expected: All tests pass, including the new Tarjan tests.

- [ ] **Step 4: Commit**

```bash
git add src/scc.mbt
git commit -m "feat: add tarjan_scc generic over DirectedGraph

Single-pass iterative Tarjan's algorithm using Iter[Int].next()
for pause/resume. No transpose needed. O(V+E) time, O(V) space.
Works on any DirectedGraph (AdjacencyMap, DenseGraph, custom types).
Produces SCCs in forward topological order."
```

---

### Task 9: Add property test — Tarjan matches Kosaraju

**Files:**
- Modify: `src/graph_expr_qc.mbt` (append)

- [ ] **Step 1: Add property test**

Append to `src/graph_expr_qc.mbt`:

```moonbit
///|
/// Property: tarjan_scc and Kosaraju scc produce the same component sets.
/// Components may appear in different order, and vertices within a component
/// may appear in different order, but the sets of sets must be equal.
test "prop: tarjan_scc matches kosaraju scc" {
  @qc.quick_check(fn(g : Graph) {
    let am = g.to_adjacency_map()
    let kosaraju = am.scc()
    let tarjan = tarjan_scc(am)
    // Normalize: sort each component, then sort the list of components
    let normalize = fn(components : Array[Array[Int]]) -> Array[Array[Int]] {
      let sorted = components.map(fn(c) {
        let copy = c.copy()
        copy.sort()
        copy
      })
      sorted.sort_by(fn(a, b) {
        if a.length() == 0 && b.length() == 0 {
          return 0
        }
        if a.length() == 0 {
          return -1
        }
        if b.length() == 0 {
          return 1
        }
        a[0].compare(b[0])
      })
      sorted
    }
    let k_norm = normalize(kosaraju)
    let t_norm = normalize(tarjan)
    assert_eq(k_norm.length(), t_norm.length())
    for i = 0; i < k_norm.length(); i = i + 1 {
      assert_eq(k_norm[i], t_norm[i])
    }
  }, config=@qc.default_config.update(max_tests=100))
}
```

- [ ] **Step 2: Run property test**

Run: `moon test`
Expected: All 100 random cases pass.

- [ ] **Step 3: Commit**

```bash
git add src/graph_expr_qc.mbt
git commit -m "test: property test that tarjan_scc matches kosaraju scc

100 random algebraic graph expressions verified: both algorithms
produce identical component sets (normalized for order differences)."
```

---

### Task 10: Update interfaces, format, and finalize

**Files:**
- Regenerate: `src/pkg.generated.mbti`

- [ ] **Step 1: Run `moon info && moon fmt`**

Run: `moon info && moon fmt`

- [ ] **Step 2: Verify API changes**

Run: `git diff src/pkg.generated.mbti`

Expected changes:
- `DirectedGraph` trait: `for_each_vertex`/`for_each_successor` → `iter`/`successors` + `each_vertex`/`each_successor`
- `AdjacencyMap::successors` → `AdjacencyMap::successor_list`
- New: `pub fn tarjan_scc`

- [ ] **Step 3: Run full test suite**

Run: `moon test`
Expected: All tests pass.

- [ ] **Step 4: Run benchmarks**

Run: `moon bench --release`
Expected: No regressions. `has_vertex` benchmark may show improvement for the default case.

- [ ] **Step 5: Commit**

```bash
git add src/pkg.generated.mbti
git commit -m "chore: regenerate interfaces after iter-based trait + tarjan_scc"
```

---

### Task 11: Update TODO

**Files:**
- Modify: `docs/TODO.md`

- [ ] **Step 1: Move Tarjan SCC to Done, update Investigate items**

Move "Tarjan SCC" from Investigate to Done. Update "Traversal control flow" to note that `has_vertex` short-circuiting is now solved by `Iter::contains`.

- [ ] **Step 2: Commit**

```bash
git add docs/TODO.md
git commit -m "docs: update TODO — tarjan_scc done, trait migrated to iter-based"
```
