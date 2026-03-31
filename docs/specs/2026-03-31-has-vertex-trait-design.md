# Design: DirectedGraph trait with default methods

**Date:** 2026-03-31
**Issue:** [#20](https://github.com/dowdiness/alga/issues/20)
**Status:** Draft

## Problem

The `DirectedGraph` trait has 3 required methods. `has_vertex` exists on both `AdjacencyMap` (O(1)) and `DenseGraph` (O(1)) as standalone methods, but is not on the trait. This means:

1. Generic algorithms can't validate vertex IDs — `toposort_subset` silently ignores invalid IDs on AdjacencyMap but panics on DenseGraph
2. Generic code can't check vertex membership without knowing the concrete type

## Decision

Restructure the trait from 3-required to **2-required + 2-defaulted**:

```moonbit
pub(open) trait DirectedGraph {
  // Required — the irreducible core
  for_each_vertex(Self, (Int) -> Unit) -> Unit
  for_each_successor(Self, Int, (Int) -> Unit) -> Unit
  // Defaulted — correct but O(V), override for O(1)
  vertex_count(Self) -> Int = _
  has_vertex(Self, Int) -> Bool = _
}
```

### Why this split

- `for_each_vertex` and `for_each_successor` are irreducible — they can't be derived from anything else
- `vertex_count` can be derived by counting `for_each_vertex` callbacks — O(V) but correct
- `has_vertex` can be derived by scanning `for_each_vertex` — O(V) but correct
- Both `AdjacencyMap` and `DenseGraph` provide O(1) overrides, so no regression for existing code

### Contract

`for_each_vertex` must yield each vertex exactly once. The default `vertex_count` and `has_vertex` depend on this invariant.

### Implementor experience

Minimum viable implementation drops from 3 methods to 2:

```moonbit
struct MyGraph { edges : Array[Array[Int]] }

impl DirectedGraph for MyGraph with for_each_vertex(self, f) {
  for i in 0..<self.edges.length() { f(i) }
}

impl DirectedGraph for MyGraph with for_each_successor(self, v, f) {
  for w in self.edges[v] { f(w) }
}

// vertex_count and has_vertex work automatically via defaults
// Override for O(1) if performance matters:
// impl DirectedGraph for MyGraph with vertex_count(self) { self.edges.length() }
// impl DirectedGraph for MyGraph with has_vertex(self, v) { v >= 0 && v < self.edges.length() }
```

## Default implementations

Default implementations must NOT use `pub` (MoonBit error E4010). Use trait-qualified calls to avoid dot-syntax method resolution ambiguity.

```moonbit
// O(V) — counts by iterating all vertices
impl DirectedGraph with vertex_count(self) {
  let mut n = 0
  DirectedGraph::for_each_vertex(self, fn(_) { n = n + 1 })
  n
}

// O(V) — scans all vertices looking for a match
impl DirectedGraph with has_vertex(self, v) {
  let mut found = false
  DirectedGraph::for_each_vertex(self, fn(u) { if u == v { found = true } })
  found
}
```

**Why trait-qualified calls:** MoonBit's dot syntax (`self.for_each_vertex(...)`) prefers standalone methods over trait methods. Inside a default trait implementation, this could dispatch to an unrelated standalone method on the concrete type. Using `DirectedGraph::for_each_vertex(self, ...)` ensures the trait method is always called.

## Algorithm changes

### toposort_subset — behavior change

**Current behavior:** invalid vertex IDs are silently included in the output on AdjacencyMap (treated as isolated vertices with in-degree 0) but panic on DenseGraph.

**New behavior:** invalid vertex IDs are filtered out before processing. This is a semantic change — tests that relied on unknown IDs appearing in the output must be updated.

Validation cost:
- O(k) with O(1) `has_vertex` override (AdjacencyMap, DenseGraph)
- O(k * V) with O(V) default `has_vertex` (minimal implementors)

The spec documents this trade-off so implementors know to override `has_vertex` for performance-sensitive subset operations.

### Other algorithms

No other algorithms currently accept user-provided vertex IDs that need validation. `dfs_fold`, `bfs_fold`, and `reachable` take a `start` vertex — returning empty results for invalid starts is already safe behavior. No changes needed now.

## Existing implementations — required changes

### AdjacencyMap

`has_vertex` currently exists as a standalone method (`pub fn AdjacencyMap::has_vertex`). Must add an explicit trait impl:

```moonbit
pub impl DirectedGraph for AdjacencyMap with has_vertex(self, v) {
  self.adjacency.contains(v)
}
```

The standalone method can coexist — MoonBit allows both. Dot syntax on a concrete `AdjacencyMap` value will prefer the standalone method; generic `G : DirectedGraph` code will use the trait impl. Both have the same body, so behavior is identical.

`vertex_count` already has a trait impl (`pub impl DirectedGraph for AdjacencyMap with vertex_count`). No change needed — it becomes an override of the new default.

### DenseGraph

Same pattern — add explicit trait impl for `has_vertex`:

```moonbit
pub impl DirectedGraph for DenseGraph with has_vertex(self, v) {
  v >= 0 && v < self.successors.length()
}
```

`vertex_count` already has a trait impl. No change needed.

### integration_wbtest.mbt ArrayGraph

Currently implements `vertex_count` explicitly. Still works — explicit impl overrides the default. Does NOT implement `has_vertex`, so it will use the O(V) default. This is acceptable for a test type.

## Benchmarks

### New benchmarks

| Benchmark | What it measures | Expected |
|---|---|---|
| `has_vertex/AdjacencyMap/1000` | O(1) trait override | ~0 µs |
| `has_vertex/DenseGraph/1000` | O(1) trait override | ~0 µs |
| `has_vertex/default/1000` | O(V) default fallback | ~few µs |
| `vertex_count/default/1000` | O(V) default fallback | ~few µs |

Default benchmarks use a minimal 2-method-only type (whitebox test, similar to `ArrayGraph`) to measure the actual cost users pay when they don't override.

### Regression check

Run full `moon bench --release` before and after to verify no performance regression on existing benchmarks.

## Testing

1. **Default impls work** — implement a type with only `for_each_vertex` + `for_each_successor`, verify `vertex_count` and `has_vertex` return correct results
2. **Overrides take precedence** — verify AdjacencyMap and DenseGraph use O(1) trait impls via generic function calls
3. **toposort_subset with invalid vertex IDs** — verify invalid IDs are filtered out (not included in output, not panicking) on both AdjacencyMap and DenseGraph
4. **Negative vertex IDs** — verify `has_vertex` returns false for negative IDs on DenseGraph
5. **Property tests still pass** — all 8 algebraic law tests, 146+ existing tests
6. **Benchmark defaults** — measure O(V) fallback cost

## Breaking change assessment

- **Existing DirectedGraph implementors:** NOT broken. `vertex_count` becomes optional (gets a default). `has_vertex` is new but also defaulted.
- **Existing callers:** NOT broken. `has_vertex` is additive.
- **toposort_subset callers:** BEHAVIOR CHANGE. Invalid vertex IDs were previously included in output (AdjacencyMap) or caused panics (DenseGraph). Now they are silently filtered out. Update tests accordingly.
- **API surface:** Standalone `has_vertex` methods on AdjacencyMap and DenseGraph remain. New trait impls are added alongside them. The `.mbti` interface will show both the standalone methods and the trait impls.

## Trait documentation update

Update `src/traits.mbt` doc comment:
- Change "Three methods, no more" to "Two required methods + two defaulted"
- Update example to show 2-method minimum
- Document `for_each_vertex` contract (each vertex yielded exactly once)
- Note that `vertex_count` and `has_vertex` have O(V) defaults; override for O(1)
