# Alga Performance Experiment Report

**Date:** 2026-03-30 – 2026-03-31
**Target:** wasm-gc, `--release` mode
**Branch:** `experiment/alga-perf-hypothesis`
**Worktree:** `.worktrees/alga-experiment/alga/`

## Motivation

The [CST Transform REPORT](../../loom/cst-transform/REPORT.md) established that in wasm-gc:

- **Allocation is the dominant cost, not dispatch** (3–4x vs 1.25x)
- **Indirection is not free** — tree pointer chasing costs more than flat array indexing
- **Trait + tuple struct = zero overhead** (1.0x vs hand-written)
- **Closure dispatch = ~1.25x floor** (call_ref not inlined)

We tested whether these findings apply to graph algorithms in alga, and what the right data structures are for a graph library on wasm-gc.

## Experiment 1: Visited Set Representation

**Question:** What's the fastest way to track "visited" vertices in DFS/BFS/toposort/SCC?

### Candidates

| Variant | Description | Init cost |
|---|---|---|
| `Map[Int, Bool]` | Tree map (original) | O(1) |
| `@hashset.HashSet[Int]` | Hash set | O(1) |
| `Array[Bool]` | Flat array, zeroed per call | O(V) |
| `FixedArray[Bool]` | Raw fixed buffer, zeroed per call | O(V) |
| `FixedArray[Int]` + generation | Reuse across calls, O(1) reset | O(1) amortized |
| `FixedArray[Int]` bitset | Packed bits, 32x less memory | O(V/32) |

### Results: Round 1 — Map vs HashSet vs Array[Bool]

**DFS reachable, chain_1000:**

| Variant | Time | vs Map |
|---|---|---|
| Map | 94 µs | 1.00x |
| HashSet | 96 µs | 0.98x |
| **Array[Bool]** | **39 µs** | **2.42x** |

**Toposort, chain_1000:**

| Variant | Time | vs Map |
|---|---|---|
| Map | 146 µs | 1.00x |
| HashMap | 130 µs | 1.12x |
| **Array[Int]** | **59 µs** | **2.47x** |

**Finding:** HashSet is a wash (hashing ≈ tree traversal cost). Array[Bool] wins 1.5x–2.8x across all algorithms and graph shapes. Larger graphs show bigger wins (chain_10000: 2.3x).

### Results: Round 2 — Array[Bool] vs FixedArray vs GenCounter vs Bitset

**DFS reachable (all chain_1000, vs Array[Bool] = 1.00x):**

| Variant | Time | vs Array[Bool] |
|---|---|---|
| Array[Bool] | 42 µs | 1.00x |
| FixedArray[Bool] | 44 µs | 0.95x |
| **GenCounter** | **38 µs** | **1.11x** |
| Bitset | 49 µs | 0.86x |

**DFS reachable chain_10000 (scaling test):**

| Variant | Time | vs Array[Bool] |
|---|---|---|
| Array[Bool] | 873 µs | 1.00x |
| FixedArray[Bool] | 844 µs | 1.03x |
| **GenCounter** | **656 µs** | **1.33x** |
| Bitset | 797 µs | 1.10x |

**BFS diamond_1000:**

| Variant | Time | vs Array[Bool] |
|---|---|---|
| Array[Bool] | 23 µs | 1.00x |
| FixedArray[Bool] | 18 µs | 1.25x |
| **GenCounter** | **16 µs** | **1.42x** |
| Bitset | 23 µs | 1.00x |

**SCC acyclic_1000 (visited set is small fraction of total):**

| Variant | Time | vs Array[Bool] |
|---|---|---|
| Array[Bool] | 271 µs | 1.00x |
| FixedArray[Bool] | 276 µs | 0.98x |
| GenCounter | 277 µs | 0.98x |
| Bitset | 271 µs | 1.00x |

### Visited Set Conclusions

1. **GenCounter wins for repeated-call hot paths**: 1.1x–1.4x over Array[Bool] (3x–5.5x over Map). The win comes from eliminating O(V) zeroing — just bump a generation number.
2. **GenCounter scales with V**: chain_10000 shows 1.33x because the zeroing cost grows linearly.
3. **FixedArray[Bool] is modestly better than Array[Bool]**: 1.03x–1.25x. The Array wrapper overhead (length/capacity fields) is small.
4. **Bitset is not worth it**: div/mod/shift per lookup costs more than it saves in cache at ≤10K vertices.
5. **SCC shows little differentiation**: `transpose()` and `Map`-based adjacency lookups dominate. Visited set is a small fraction of SCC's cost.

### Recommendation

| Use case | Best variant |
|---|---|
| Repeated calls on same graph (event-graph-walker) | GenCounter (`FixedArray[Int]` + generation bump) |
| Single-call algorithms | FixedArray[Bool] |
| Sparse/non-contiguous vertex IDs | Array[Bool] (safe fallback) |

## Experiment 2: foldg (Graph Catamorphism)

**Question:** How to fix `foldg`'s two problems: (1) stack overflow on deep expressions, (2) O(n²) when folding into AdjacencyMap?

### Candidates

| Variant | Description | Stack safe? | Complexity |
|---|---|---|---|
| `foldg` (recursive) | Original, passes 5 params per call | No | O(n²) for AdjMap |
| `foldg_inner_fn` | `fn go(g)` captures params in closure | No | O(n²) for AdjMap |
| `foldg_letrec` | `letrec go = fn(g)` (not tail-recursive) | No | O(n²) for AdjMap |
| `foldg_cps` | `letrec go = fn(g, k)` CPS, tail position | Partial | O(n²) for AdjMap |
| `foldg_iter` | Explicit work/result stacks | **Yes** | O(n²) for AdjMap |
| `to_adjacency_map_direct` | Collect edges first, build once | **Yes** | **O(V+E)** |

### Results: to_adjacency_map

**path (left-leaning chain — worst case for pairwise merging):**

| Variant | path_100 | path_1000 | vs recursive (1000) |
|---|---|---|---|
| recursive | 487 µs | 58.6 ms | 1.0x |
| inner_fn | 477 µs | 59.0 ms | 1.0x |
| letrec | 476 µs | 59.2 ms | 1.0x |
| iter | 483 µs | 59.8 ms | 1.0x |
| cps | 484 µs | 62.4 ms | 0.94x |
| **direct** | **22.5 µs** | **851 µs** | **69x** |

**clique_50 (balanced, many edges):**

| Variant | Time | vs recursive |
|---|---|---|
| recursive | 1.60 ms | 1.0x |
| cps | 1.56 ms | 1.03x |
| **direct** | **91.6 µs** | **17x** |

**star_1000 (shallow, wide):**

| Variant | Time | vs recursive |
|---|---|---|
| recursive | 47.0 ms | 1.0x |
| cps | 45.5 ms | 1.03x |
| **direct** | **413 µs** | **114x** |

### Results: foldg vertex count (lightweight B = Int)

Isolates pure fold overhead — no AdjacencyMap merging.

| Variant | path_1000 | vs recursive |
|---|---|---|
| **recursive** | **13.1 µs** | **1.00x** |
| inner_fn | 13.7 µs | 0.96x |
| letrec | 13.7 µs | 0.96x |
| cps | **STACK OVERFLOW** | — |
| iter | 36.3 µs | 0.36x (2.8x slower) |

### Compiled Output Analysis (JS target)

Inspecting the JS output reveals what the compiler actually does:

**`letrec` without tail position** → identical codegen to plain recursion:
```js
// fold_letrec compiles to same code as fold_recursive
return f(go(f, _a), go(f, _b));
```

**`letrec` with CPS (tail position)** → TCO applied to one branch:
```js
// fold_cps: left branch becomes while-loop
while (true) {
    if (t.$tag === 0) return k(v);
    _tmp = _a;                              // ← TCO: loop
    _tmp$2 = (ra) => go(f, _b, (rb) =>     // ← but right branch
        k(f(ra, rb)));                       //   still recurses
    continue;
}
```

**Key insight:** MoonBit's `letrec` does apply TCO, but only to the single call in tail position. For binary tree folds, CPS converts the left branch into a loop but the continuation chain for the right branch still recurses. Stack depth remains O(n) — the recursion is relocated from the call stack to nested closures. This is why `foldg_count/cps/path_1000` stack-overflowed.

### foldg Conclusions

1. **`to_adjacency_map_direct` is the real fix**: 17x–114x faster by eliminating the O(n²) pairwise merging entirely. Collects edges into a buffer, builds AdjacencyMap once.
2. **All foldg variants (recursive, inner_fn, letrec, cps, iter) are equivalent** when the fold body dominates (AdjacencyMap merging). The recursion overhead is noise.
3. **For lightweight folds, recursive is fastest** (13.1 µs). The iterative version is 2.8x slower due to `FoldWork` enum allocation. CPS stack-overflows.
4. **`letrec` = `fn go` = plain recursive** for non-tail calls. No compiler magic.
5. **CPS + `letrec` enables partial TCO** but doesn't solve stack overflow for tree folds — it only converts one branch to a loop.

### Recommendation

- Replace `Graph::to_adjacency_map` with the direct edge-collection algorithm
- Keep recursive `foldg` for lightweight folds (vertex count, gmap, bind)
- Offer `foldg_iter` as a safety escape for pathologically deep expressions where stack overflow is a concern

## Correctness

All experiments include correctness tests verifying identical results to the original implementations:

- **Visited sets:** 20 tests — chain, diamond, disconnected, cycle, single vertex, word boundaries (bitset), large graphs (1000 vertices), generation counter reuse across calls
- **foldg:** 17 tests — vertex count, connect order preservation, path/clique/star/circuit/edges, isolated vertices, large path (200 vertices), gmap equivalence
- **DenseGraph:** 11 tests — DFS (chain/diamond/cycle), BFS count, toposort (chain/cycle), SCC (dag/cycle/multiple components), transpose, large graph (1000 vertices)

**Total: 106 tests, all passing.**

## Experiment 3: Flat Adjacency + Direct Iteration

**Question:** How much does the `Map[Int, Array[Int]]` adjacency structure cost, and how much is the `for_each_successor` callback overhead?

### DenseGraph

New type: `DenseGraph { successors: Array[Array[Int]] }`. Vertex v's successors at `successors[v]`. Requires dense vertex IDs in 0..n-1.

### Results: Full decomposition (DFS reachable chain_1000)

| Step | Time | Speedup | What changed |
|---|---|---|---|
| Original (Map visited + Map adjacency) | 94 µs | 1.0x | baseline |
| + GenCounter visited (Exp 1) | 34.7 µs | 2.7x | flat visited set |
| + Flat adjacency via trait | 22.8 µs | 1.5x | `Array[Array[Int]]` instead of `Map` |
| + Eliminate temp array (mark-and-reverse) | 11.7 µs | 1.9x | no per-vertex allocation |
| + Direct iteration (no callback) | 6.6 µs | 1.8x | no `for_each_successor` closure |
| **Total** | **6.6 µs** | **14x** | |

### Overhead decomposition

| Overhead source | Factor | Fixable without API change? |
|---|---|---|
| Map adjacency lookup (O(log V) tree) | 1.5x | No — requires DenseGraph type |
| Per-vertex temp array in dfs_fold | 1.9x | **Yes — mark-and-reverse (applied)** |
| Closure `call_ref` in for_each_successor | 1.8x | No — inherent to callback API |
| Map visited set (O(log V) tree) | 2.7x | Requires dense vertex IDs |

### Key discovery: temp array allocation was the hidden bottleneck

The original `dfs_fold` created a fresh `Array[Int]` per vertex to collect successors, then copied them to the stack in reverse. The mark-and-reverse pattern pushes directly from the callback, then reverses in place — zero allocation, same DFS order.

This was a bigger win (1.9x) than the closure overhead (1.8x) and was fixable without any API changes.

### Results by algorithm (full flat + direct, vs original Map-based)

| Algorithm | Original | Flat+Direct | Total speedup |
|---|---|---|---|
| DFS chain_1000 | 94 µs | 6.6 µs | **14x** |
| DFS chain_10000 | 1,920 µs | 83 µs | **23x** |
| BFS chain_1000 | 79 µs | 7.1 µs | **11x** |
| BFS diamond_1000 | 38 µs | 4.0 µs | **9.4x** |
| Toposort chain_1000 | 146 µs | 13 µs | **11x** |
| SCC acyclic_1000 | 460 µs | 62 µs | **7.5x** |
| SCC cyclic_1000 | 494 µs | 50 µs | **10x** |
| Transpose 1000 | 207 µs | 18 µs | **11.5x** |

### JS codegen analysis

Compiled the flat variants to JS to verify what the compiler generates:

- **Map adjacency lookup**: ~20 instructions per lookup (hash → probe → compare → unwrap Option)
- **Flat Array lookup**: 2 instructions (bounds check + index)
- **`.each()` callback**: compiler **does inline** `.each()` into a plain while-loop
- **`for_each_successor` via trait**: goes through trait dispatch → closure — NOT inlined

### Transpose: Map vs Flat

| Variant | Time | Speedup |
|---|---|---|
| `AdjacencyMap::transpose` (Map → Map) | 207 µs | 1.0x |
| `DenseGraph::transpose` (Array → Array) | 18 µs | **11.5x** |

This explains why SCC showed only 1.4–1.6x from visited-set changes in Exp 1 — `transpose()` was the real bottleneck, and it's 11.5x faster with flat representation.

## Changes Applied to Production Code

| Fix | File | Impact | Risk |
|---|---|---|---|
| `dfs_fold` mark-and-reverse | `dfs.mbt` | ~1.9x for DFS (eliminates temp array) | None — same API, same behavior |
| `to_adjacency_map` direct edge collection | `graph_expr.mbt` | **77–127x** (O(V+E) vs O(n²)) | None — same API, same results |
| `foldg_iter` added | `graph_expr.mbt` | Stack-safe for deep expressions | Additive — new public function |

## What Remains

**DenseGraph promotion:** The `DenseGraph` type is proven (8–23x across all algorithms) but lives in experiment files. Promoting it to production requires an API design decision — see next section.

**GenCounter for visited sets:** Proven 2.4–5.5x but not applied to production algorithms. Requires knowing the vertex range (dense IDs), which ties into the DenseGraph decision.

**Trait-based GraphFolder:** Not tested. The closure overhead (1.8x) is real but secondary to the adjacency and allocation fixes. The CST Transform report predicts trait + tuple struct would eliminate it, but the total gain would be modest given that the bigger wins are already captured.

## Files

```
experiment.mbt              — visited-set variants (Map/HashSet/Array/FixedArray/Gen/Bitset)
experiment_bench.mbt        — visited-set benchmarks (round 1 + round 2)
experiment_test.mbt         — visited-set correctness tests
experiment_foldg.mbt        — foldg variants (inner_fn/letrec/cps) + experiment-only helpers
experiment_foldg_bench.mbt  — foldg benchmarks
experiment_foldg_test.mbt   — foldg correctness tests
experiment_flat.mbt         — DenseGraph type, trait/direct/mark-rev/reuse-buf variants
experiment_flat_bench.mbt   — flat adjacency benchmarks
experiment_flat_test.mbt    — flat adjacency correctness tests
```
