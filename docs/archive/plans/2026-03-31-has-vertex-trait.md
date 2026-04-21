# has_vertex on DirectedGraph Trait — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `has_vertex` and default `vertex_count` to the `DirectedGraph` trait, making the minimum implementation 2 methods instead of 3, and enabling generic input validation.

**Architecture:** Restructure `DirectedGraph` from 3-required to 2-required + 2-defaulted methods. Add trait impls for `has_vertex` on existing types. Update `toposort_subset` to filter invalid vertices. Add benchmarks for default fallback cost.

**Tech Stack:** MoonBit, moonbitlang/quickcheck for property tests

**Spec:** [docs/specs/2026-03-31-has-vertex-trait-design.md](../../specs/2026-03-31-has-vertex-trait-design.md)

---

### Task 1: Update trait definition + default implementations

**Files:**
- Modify: `src/traits.mbt`

- [ ] **Step 1: Update the trait definition**

Replace the current trait with 2-required + 2-defaulted:

```moonbit
pub(open) trait DirectedGraph {
  for_each_vertex(Self, (Int) -> Unit) -> Unit
  for_each_successor(Self, Int, (Int) -> Unit) -> Unit
  vertex_count(Self) -> Int = _
  has_vertex(Self, Int) -> Bool = _
}
```

- [ ] **Step 2: Add default implementations**

Add below the trait definition (no `pub` — MoonBit error E4010):

```moonbit
///|
/// Default vertex_count: O(V) — counts by iterating all vertices.
/// Override for O(1) if your type tracks vertex count directly.
impl DirectedGraph with vertex_count(self) {
  let mut n = 0
  DirectedGraph::for_each_vertex(self, fn(_) { n = n + 1 })
  n
}

///|
/// Default has_vertex: O(V) — scans all vertices looking for a match.
/// Override for O(1) if your type supports constant-time membership.
impl DirectedGraph with has_vertex(self, v) {
  let mut found = false
  DirectedGraph::for_each_vertex(self, fn(u) { if u == v { found = true } })
  found
}
```

- [ ] **Step 3: Update the doc comment**

Replace the doc comment header to reflect the new design. Key changes:
- "Two required methods + two with defaults" instead of "Three methods, no more"
- Document `for_each_vertex` contract: each vertex yielded exactly once
- Show 2-method minimum example
- Note O(V) defaults and override advice

```moonbit
///|
/// # DirectedGraph — the observation layer
///
/// This trait defines the minimal interface for observing a directed graph.
/// Implement `for_each_vertex` and `for_each_successor` to get every
/// algorithm in the library for free. `vertex_count` and `has_vertex`
/// have O(V) defaults that you can override for O(1) performance.
///
/// ## Contract
///
/// `for_each_vertex` must yield each vertex exactly once. The default
/// `vertex_count` and `has_vertex` depend on this invariant.
///
/// ## Design decisions
///
/// **Fixed vertex type (Int):**
/// MoonBit traits cannot have type parameters or associated types, so we
/// fix vertices to `Int`. If your vertices are strings or custom IDs,
/// map them to `Int` indices.
///
/// **Callback-style iteration:**
/// Without associated types, we cannot return `Iter[Vertex]` from a trait
/// method. Instead, we push vertices into `(Int) -> Unit` callbacks (CPS).
/// This avoids allocating intermediate collections.
///
/// **Two required + two defaulted:**
/// `for_each_vertex` and `for_each_successor` are irreducible — they
/// can't be derived from anything else. `vertex_count` and `has_vertex`
/// can be derived by iterating vertices, so they have O(V) defaults.
/// Override them for O(1) when your data structure supports it.
///
/// ## Example: minimal implementation (2 methods)
///
/// ```
/// struct MyGraph { edges : Array[Array[Int]] }
///
/// impl DirectedGraph for MyGraph with for_each_vertex(self, f) {
///   for i in 0..<self.edges.length() { f(i) }
/// }
/// impl DirectedGraph for MyGraph with for_each_successor(self, v, f) {
///   for w in self.edges[v] { f(w) }
/// }
/// // vertex_count and has_vertex work via defaults.
/// // Override for O(1): impl DirectedGraph for MyGraph with vertex_count(self) { self.edges.length() }
/// ```
```

- [ ] **Step 4: Run moon check**

Run: `moon check`
Expected: passes (existing impls already have `vertex_count`; `has_vertex` gets the default)

- [ ] **Step 5: Commit**

```bash
git add src/traits.mbt
git commit -m "feat: add has_vertex and default vertex_count to DirectedGraph trait"
```

---

### Task 2: Add trait impls for has_vertex on AdjacencyMap and DenseGraph

**Files:**
- Modify: `src/adjacency_map.mbt`
- Modify: `src/dense_graph.mbt`

- [ ] **Step 1: Add has_vertex trait impl for AdjacencyMap**

Add after the existing `DirectedGraph` trait impls (around line 400):

```moonbit
///|
pub impl DirectedGraph for AdjacencyMap with has_vertex(self, v) {
  self.adjacency.contains(v)
}
```

The standalone `pub fn AdjacencyMap::has_vertex` at line 233 stays — it coexists. Dot syntax on concrete types uses the standalone; generic code uses the trait impl.

- [ ] **Step 2: Run moon check**

Run: `moon check`
Expected: passes

- [ ] **Step 3: Add has_vertex trait impl for DenseGraph**

Add after the existing `DirectedGraph` trait impls:

```moonbit
///|
pub impl DirectedGraph for DenseGraph with has_vertex(self, v) {
  v >= 0 && v < self.successors.length()
}
```

Same coexistence pattern — standalone method stays.

- [ ] **Step 4: Run moon check**

Run: `moon check`
Expected: passes

- [ ] **Step 5: Run full test suite**

Run: `moon test`
Expected: all 146 tests pass (no behavior changes yet)

- [ ] **Step 6: Commit**

```bash
git add src/adjacency_map.mbt src/dense_graph.mbt
git commit -m "feat: add has_vertex trait impls for AdjacencyMap and DenseGraph"
```

---

### Task 3: Add tests for default impls and trait behavior

**Files:**
- Modify: `src/integration_wbtest.mbt`

- [ ] **Step 1: Add test for default has_vertex on ArrayGraph**

ArrayGraph in `integration_wbtest.mbt` only implements 2 required methods + `vertex_count` override. It does NOT implement `has_vertex`, so it uses the O(V) default. Add after the existing tests:

```moonbit
///|
test "default has_vertex works on ArrayGraph" {
  let g = ArrayGraph::{
    successors: [[1, 2], [2], [3], []],
  }
  // Valid vertices
  assert_true(DirectedGraph::has_vertex(g, 0))
  assert_true(DirectedGraph::has_vertex(g, 3))
  // Invalid vertices
  assert_true(!DirectedGraph::has_vertex(g, 4))
  assert_true(!DirectedGraph::has_vertex(g, -1))
  assert_true(!DirectedGraph::has_vertex(g, 999))
}

///|
test "default vertex_count works without override" {
  // Create a MinimalGraph with only for_each_vertex + for_each_successor
  // to prove the default vertex_count works
  let g = ArrayGraph::{
    successors: [[1], [2], []],
  }
  assert_eq(DirectedGraph::vertex_count(g), 3)
}
```

- [ ] **Step 2: Add test for trait impl override on AdjacencyMap**

```moonbit
///|
test "has_vertex via trait on AdjacencyMap" {
  let g = AdjacencyMap::from_edges([(0, 1), (1, 2)])
  // Call via trait-qualified syntax to ensure trait impl is used
  assert_true(DirectedGraph::has_vertex(g, 0))
  assert_true(DirectedGraph::has_vertex(g, 1))
  assert_true(DirectedGraph::has_vertex(g, 2))
  assert_true(!DirectedGraph::has_vertex(g, 3))
  assert_true(!DirectedGraph::has_vertex(g, -1))
}

///|
test "has_vertex via trait on DenseGraph" {
  let g = DenseGraph::from_edges(3, [(0, 1), (1, 2)])
  assert_true(DirectedGraph::has_vertex(g, 0))
  assert_true(DirectedGraph::has_vertex(g, 2))
  assert_true(!DirectedGraph::has_vertex(g, 3))
  assert_true(!DirectedGraph::has_vertex(g, -1))
}
```

- [ ] **Step 3: Run moon check and moon test**

Run: `moon check && moon test`
Expected: all tests pass

- [ ] **Step 4: Commit**

```bash
git add src/integration_wbtest.mbt
git commit -m "test: add tests for default has_vertex and trait impls"
```

---

### Task 4: Update toposort_subset to filter invalid vertices

**Files:**
- Modify: `src/toposort.mbt`
- Modify: `src/toposort_test.mbt`

- [ ] **Step 1: Update toposort_subset to filter invalid IDs**

In `src/toposort.mbt`, add validation after deduplication (around line 119-124):

```moonbit
pub fn[G : DirectedGraph] toposort_subset(
  graph : G,
  vertices : Array[Int],
) -> Array[Int]? {
  // Build membership set and deduplicated vertex list
  // Filter out invalid vertex IDs for consistent behavior
  let subset : @hashset.HashSet[Int] = @hashset.new()
  let unique : Array[Int] = []
  for v in vertices {
    if !subset.contains(v) && G::has_vertex(graph, v) {
      subset.add(v)
      unique.push(v)
    }
  }
  // ... rest unchanged
```

Also update the doc comment — remove the precondition warning and document the new filtering behavior:

```moonbit
/// **Input validation:** Invalid vertex IDs (not present in the graph)
/// are silently filtered out. This ensures consistent behavior across
/// all `DirectedGraph` implementations.
```

- [ ] **Step 2: Run moon check**

Run: `moon check`
Expected: passes

- [ ] **Step 3: Update the nonexistent vertex test**

In `src/toposort_test.mbt`, update the test at line 190:

```moonbit
test "toposort_subset nonexistent vertex filtered out" {
  // Invalid vertex IDs are filtered out — they don't appear in the result
  // and don't cause panics, regardless of the graph implementation.
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2)])
  let result = @alga.toposort_subset(g, [0, 1, 99])
  match result {
    Some(order) => {
      assert_eq(order.length(), 2) // only 0, 1 — vertex 99 filtered out
      assert_true(!order.contains(99))
      assert_true(order.contains(0))
      assert_true(order.contains(1))
    }
    None => assert_true(false)
  }
}
```

- [ ] **Step 4: Add DenseGraph test for invalid vertex IDs**

Add a new test that proves DenseGraph no longer panics:

```moonbit
test "toposort_subset invalid vertex on DenseGraph" {
  let g = @alga.DenseGraph::from_edges(3, [(0, 1), (1, 2)])
  // Previously would panic on vertex 99 — now filtered out
  let result = @alga.toposort_subset(g, [0, 1, 99])
  match result {
    Some(order) => {
      assert_eq(order.length(), 2)
      assert_true(!order.contains(99))
    }
    None => assert_true(false)
  }
}
```

- [ ] **Step 5: Add negative ID test**

```moonbit
test "toposort_subset negative vertex ID filtered" {
  let g = @alga.DenseGraph::from_edges(3, [(0, 1), (1, 2)])
  let result = @alga.toposort_subset(g, [0, -5, 1])
  match result {
    Some(order) => {
      assert_eq(order.length(), 2)
      assert_true(!order.contains(-5))
    }
    None => assert_true(false)
  }
}
```

- [ ] **Step 6: Run moon check and moon test**

Run: `moon check && moon test`
Expected: all tests pass (old test updated, new tests added)

- [ ] **Step 7: Commit**

```bash
git add src/toposort.mbt src/toposort_test.mbt
git commit -m "feat: toposort_subset filters invalid vertex IDs via has_vertex

BREAKING: Invalid vertex IDs are now filtered out instead of being
included as isolated vertices (AdjacencyMap) or panicking (DenseGraph)."
```

---

### Task 5: Add benchmarks

**Files:**
- Modify: `src/benchmark.mbt`

- [ ] **Step 1: Add has_vertex benchmarks for existing types**

```moonbit
// --- has_vertex ---

///|
test "bench/has_vertex/AdjacencyMap_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(DirectedGraph::has_vertex(g, 500)) })
}

///|
test "bench/has_vertex/DenseGraph_1000" (b : @bench.T) {
  let am = build_chain(1000)
  let g = DenseGraph::from_adjacency_map(am)
  b.bench(fn() { b.keep(DirectedGraph::has_vertex(g, 500)) })
}
```

- [ ] **Step 2: Add default fallback benchmarks**

These need a minimal type that only implements the 2 required methods. Since benchmarks run in whitebox test context, define a simple type:

```moonbit
///|
priv struct BenchMinimalGraph {
  n : Int
  edges : Array[Array[Int]]
}

///|
impl DirectedGraph for BenchMinimalGraph with for_each_vertex(self, f) {
  for i = 0; i < self.n; i = i + 1 {
    f(i)
  }
}

///|
impl DirectedGraph for BenchMinimalGraph with for_each_successor(self, v, f) {
  if v >= 0 && v < self.n {
    for w in self.edges[v] { f(w) }
  }
}

///|
fn build_minimal_chain(n : Int) -> BenchMinimalGraph {
  let edges : Array[Array[Int]] = Array::makei(n, fn(i) {
    if i < n - 1 { [i + 1] } else { [] }
  })
  { n, edges }
}

///|
test "bench/has_vertex/default_1000" (b : @bench.T) {
  let g = build_minimal_chain(1000)
  b.bench(fn() { b.keep(DirectedGraph::has_vertex(g, 500)) })
}

///|
test "bench/vertex_count/default_1000" (b : @bench.T) {
  let g = build_minimal_chain(1000)
  b.bench(fn() { b.keep(DirectedGraph::vertex_count(g)) })
}
```

- [ ] **Step 3: Run moon check**

Run: `moon check`
Expected: passes

- [ ] **Step 4: Run benchmarks**

Run: `moon bench --release 2>&1 | grep -E "bench/(has_vertex|vertex_count)"`
Expected: O(1) overrides ~0 µs, defaults ~few µs

- [ ] **Step 5: Run full benchmark regression check**

Run: `moon bench --release`
Expected: no regression on existing benchmarks

- [ ] **Step 6: Commit**

```bash
git add src/benchmark.mbt
git commit -m "bench: add has_vertex and default fallback benchmarks"
```

---

### Task 6: Update interfaces, format, and final checks

**Files:**
- Modify: `src/pkg.generated.mbti` (auto-generated)
- Modify: various (formatting)

- [ ] **Step 1: Regenerate interfaces and format**

Run: `moon info && moon fmt`

- [ ] **Step 2: Check API changes**

Run: `git diff -- '*.mbti'`
Expected: trait definition changes (2 new defaulted methods), new `has_vertex` trait impls for AdjacencyMap and DenseGraph

- [ ] **Step 3: Run full test suite**

Run: `moon test`
Expected: all tests pass (146+ existing + new tests)

- [ ] **Step 4: Run property tests specifically**

Verify the 8 algebraic law tests still pass — these exercise `to_adjacency_map` which uses the trait internally.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: update interfaces and formatting"
```

---

### Task 7: Update documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/architecture.md`
- Modify: `docs/TODO.md`

- [ ] **Step 1: Update README**

In the "Implementing DirectedGraph for your types" section, update the example to show 2-method minimum and mention `has_vertex`:

```markdown
The trait has two required methods. Implement them and all algorithms just work:

... (show 2-method example)

`vertex_count` and `has_vertex` have O(V) defaults. Override for O(1):

... (show override example)
```

Add `has_vertex` to the algorithm table.

- [ ] **Step 2: Update architecture.md**

Update the trait definition shown in the architecture doc to reflect 2-required + 2-defaulted.

- [ ] **Step 3: Update TODO.md**

Add #20 to the Done section.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/architecture.md docs/TODO.md
git commit -m "docs: update docs for has_vertex trait change

Closes #20"
```
