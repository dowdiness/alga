# GenCounter for DenseGraph

**Date:** 2026-06-22 (revised after review)
**Status:** implemented
**Source:** [perf experiment report](../archive/2026-03-31-perf-experiment-report.md#visited-set-conclusions), [TODO](../TODO.md)

## Motivation

DenseGraph algorithms allocate a fresh `FixedArray[Bool]` visited set on every
call. For repeated-call hot paths, the O(V) allocation + zeroing adds up.

GenCounter replaces this with a reusable `FixedArray[Int]` buffer and a
generation counter. Instead of zeroing the array between calls, bump `gen` and
check `marks[v] == gen`. Reset cost drops from O(V) to O(1).

## Performance (wasm-gc --release, 2026-06-22)

Production `DenseGraph::reachable` vs GenCounter prototype:

| Graph | Production (FixedArray[Bool]) | GenCounter | Speedup |
|-------|------------------------------|------------|---------|
| chain_1000 | 26.58 µs ± 4.40 µs | 22.19 µs ± 2.40 µs | **1.20×** |
| chain_10000 | 339.00 µs ± 48.81 µs | 315.48 µs ± 59.53 µs | 1.07× (overlapping σ) |
| diamond_1000 | 17.78 µs ± 2.49 µs | 17.94 µs ± 2.82 µs | 0.99× (noise) |

1.2× win on chain_1000 is real (non-overlapping σ ranges). Win disappears on
wide/shallow graphs where visited-set cost is dwarfed by edge traversal.

Earlier experiment data (vs `Array[Bool]`) showed up to 1.42×, but production
already uses the faster `FixedArray[Bool]`. SCC shows no measurable win
(transpose + adjacency traversal dominate).

## API

```moonbit
// New — full reachable set:
pub fn DenseGraph::reachable_gen(self, start, marks : FixedArray[Int], gen : Int) -> Array[Int]

// New — early-exit boolean query:
pub fn DenseGraph::is_reachable_gen(self, from, to, marks : FixedArray[Int], gen : Int) -> Bool
```

### Contract

- `marks.length()` ≥ vertex count. Aborts otherwise.
- `gen` ≠ 0 (0 = initial blank state). Start at 1, bump between calls.
- `reachable_gen` / `is_reachable_gen` consume one generation token each.

### Overflow

In wasm32, `Int` wraps at 2³¹ (~35 min at 1M calls/sec). Reset periodically:
```moonbit
gen = 1
for i = 0; i < n; i = i + 1 { marks[i] = 0 }
```

## What's deferred

- **scc_gen** — Experiment showed 0.98× (no win). Production DenseGraph SCC
  already uses flat arrays and O(1) transpose.
- **dfs_events_gen** — Iter lifetime issue. Deferred until a consumer asks.
- **Trait-level GenCounter** — Would need a capability trait. DenseGraph-specific
  methods cover the known use case.
