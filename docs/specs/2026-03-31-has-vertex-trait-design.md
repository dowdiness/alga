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
- Both `AdjacencyMap` and `DenseGraph` override with O(1) implementations, so no regression for existing code

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

```moonbit
// O(V) — counts by iterating all vertices
pub impl DirectedGraph with vertex_count(self) {
  let mut n = 0
  self.for_each_vertex(fn(_) { n = n + 1 })
  n
}

// O(V) — scans all vertices looking for a match
pub impl DirectedGraph with has_vertex(self, v) {
  let mut found = false
  self.for_each_vertex(fn(u) { if u == v { found = true } })
  found
}
```

## Algorithm changes

### toposort_subset

Add input validation using `has_vertex`:

```moonbit
// Before processing, filter out vertices not in the graph.
// This makes behavior consistent: invalid IDs are skipped
// instead of silently ignored (AdjacencyMap) or panicking (DenseGraph).
```

The validation cost is O(k) where k = number of input vertices, using the graph's `has_vertex` (O(1) for both existing types).

### Other algorithms

No other algorithms currently accept user-provided vertex IDs that need validation. `dfs_fold`, `bfs_fold`, and `reachable` take a `start` vertex — these could optionally validate, but returning empty results for invalid starts is already safe behavior. No changes needed now.

## Existing implementations — changes

### AdjacencyMap

Already has `has_vertex` and `vertex_count` as standalone methods. These become trait method overrides:

```moonbit
// No code change needed — existing impl signatures already match.
// pub impl DirectedGraph for AdjacencyMap with vertex_count(self) { ... }
// pub impl DirectedGraph for AdjacencyMap with has_vertex(self, v) { ... }
// These were standalone methods; now they're also trait overrides.
```

Verify: the existing `pub fn AdjacencyMap::has_vertex` must be changed to `pub impl DirectedGraph for AdjacencyMap with has_vertex`. Check if both can coexist or if the standalone method must be removed.

### DenseGraph

Same situation — standalone `has_vertex` and `vertex_count` become trait overrides.

### integration_wbtest.mbt ArrayGraph

Currently implements `vertex_count` explicitly. Still works — override takes precedence over default.

## Benchmarks

### New benchmarks

| Benchmark | What it measures | Expected |
|---|---|---|
| `has_vertex/AdjacencyMap/1000` | O(1) override | ~0 µs |
| `has_vertex/DenseGraph/1000` | O(1) override | ~0 µs |
| `has_vertex/default/1000` | O(V) default fallback | ~few µs |
| `vertex_count/default/1000` | O(V) default fallback | ~few µs |

Default benchmarks use a minimal 2-method-only type (similar to `ArrayGraph` from integration tests) to measure the actual cost users pay when they don't override.

### Regression check

Run full `moon bench --release` before and after to verify no performance regression on existing benchmarks.

## Testing

1. **Default impls work** — implement a type with only `for_each_vertex` + `for_each_successor`, verify `vertex_count` and `has_vertex` return correct results
2. **Overrides take precedence** — verify AdjacencyMap and DenseGraph still use O(1) implementations
3. **toposort_subset with invalid vertex IDs** — verify consistent behavior (skip, don't panic) on both AdjacencyMap and DenseGraph
4. **Property tests still pass** — all 8 algebraic law tests, 146+ existing tests
5. **Benchmark defaults** — measure O(V) fallback cost for documentation

## Breaking change assessment

- **Existing DirectedGraph implementors:** NOT broken. `vertex_count` becomes optional (gets a default). `has_vertex` is new but also defaulted.
- **Existing callers:** NOT broken. `has_vertex` is additive — new method, previously didn't exist on trait.
- **API surface:** `has_vertex` moves from type-specific methods to trait, gaining generic accessibility. The standalone methods may need to be removed if MoonBit doesn't allow both a trait impl and a standalone method with the same name.

## Open questions

1. Can MoonBit have both `pub fn AdjacencyMap::has_vertex(self, v)` (standalone) and `pub impl DirectedGraph for AdjacencyMap with has_vertex(self, v)` (trait)? If not, the standalone must be removed/converted.
2. Does `vertex_count` defaulting change the `.mbti` interface in a way that affects downstream consumers?
