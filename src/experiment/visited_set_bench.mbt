// Comparative benchmarks for visited-set implementations
// Run with: moon bench --release
//
// Round 1: Map vs HashSet vs Array[Bool]
// Round 2: Array[Bool] vs FixedArray[Bool] vs GenCounter vs Bitset
//
// Naming: bench/<algorithm>/<variant>/<graph_shape>

// === Graph builders (shared edge generators + type-specific wrappers) ===

///|
fn build_chain_edges(n : Int) -> Array[(Int, Int)] {
  let edges : Array[(Int, Int)] = []
  for i = 0; i < n - 1; i = i + 1 {
    edges.push((i, i + 1))
  }
  edges
}

///|
fn build_diamond_edges(n : Int) -> Array[(Int, Int)] {
  let edges : Array[(Int, Int)] = []
  let width = 10
  let layers = n / width
  for layer = 0; layer < layers - 1; layer = layer + 1 {
    for i = 0; i < width; i = i + 1 {
      let from = layer * width + i
      for j = 0; j < width; j = j + 1 {
        let to = (layer + 1) * width + j
        if (i + j) % 3 == 0 {
          edges.push((from, to))
        }
      }
    }
  }
  edges
}

///|
fn build_cyclic_edges(n : Int) -> Array[(Int, Int)] {
  let edges : Array[(Int, Int)] = []
  for i = 0; i < n; i = i + 1 {
    edges.push((i, (i + 1) % n))
  }
  for i = 0; i < n / 2; i = i + 1 {
    edges.push((i, (i * 7 + 3) % n))
  }
  edges
}

///|
fn build_chain(n : Int) -> @alga.AdjacencyMap {
  @alga.AdjacencyMap::from_edges(build_chain_edges(n))
}

///|
fn build_diamond(n : Int) -> @alga.AdjacencyMap {
  @alga.AdjacencyMap::from_edges(build_diamond_edges(n))
}

///|
fn build_cyclic(n : Int) -> @alga.AdjacencyMap {
  @alga.AdjacencyMap::from_edges(build_cyclic_edges(n))
}

// === DFS reachable ===

///|
test "bench/reachable/map/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(@alga.reachable(g, 0)) })
}

///|
test "bench/reachable/hashset/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(reachable_hashset(g, 0)) })
}

///|
test "bench/reachable/array/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(reachable_array(g, 0)) })
}

///|
test "bench/reachable/map/chain_10000" (b : @bench.T) {
  let g = build_chain(10000)
  b.bench(fn() { b.keep(@alga.reachable(g, 0)) })
}

///|
test "bench/reachable/hashset/chain_10000" (b : @bench.T) {
  let g = build_chain(10000)
  b.bench(fn() { b.keep(reachable_hashset(g, 0)) })
}

///|
test "bench/reachable/array/chain_10000" (b : @bench.T) {
  let g = build_chain(10000)
  b.bench(fn() { b.keep(reachable_array(g, 0)) })
}

///|
test "bench/reachable/map/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() { b.keep(@alga.reachable(g, 0)) })
}

///|
test "bench/reachable/hashset/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() { b.keep(reachable_hashset(g, 0)) })
}

///|
test "bench/reachable/array/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() { b.keep(reachable_array(g, 0)) })
}

// === BFS ===

///|
test "bench/bfs/map/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() {
    b.keep(@alga.bfs_fold(g, 0, 0, fn(acc, _v) { (acc + 1, true) }))
  })
}

///|
test "bench/bfs/hashset/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() {
    b.keep(bfs_fold_hashset(g, 0, 0, fn(acc, _v) { (acc + 1, true) }))
  })
}

///|
test "bench/bfs/array/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() {
    b.keep(bfs_fold_array(g, 0, 0, fn(acc, _v) { (acc + 1, true) }))
  })
}

///|
test "bench/bfs/map/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() {
    b.keep(@alga.bfs_fold(g, 0, 0, fn(acc, _v) { (acc + 1, true) }))
  })
}

///|
test "bench/bfs/hashset/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() {
    b.keep(bfs_fold_hashset(g, 0, 0, fn(acc, _v) { (acc + 1, true) }))
  })
}

///|
test "bench/bfs/array/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() {
    b.keep(bfs_fold_array(g, 0, 0, fn(acc, _v) { (acc + 1, true) }))
  })
}

// === Toposort ===

///|
test "bench/toposort/map/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(@alga.toposort(g)) })
}

///|
test "bench/toposort/hashset/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(toposort_hashset(g)) })
}

///|
test "bench/toposort/array/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(toposort_array(g)) })
}

///|
test "bench/toposort/map/chain_10000" (b : @bench.T) {
  let g = build_chain(10000)
  b.bench(fn() { b.keep(@alga.toposort(g)) })
}

///|
test "bench/toposort/hashset/chain_10000" (b : @bench.T) {
  let g = build_chain(10000)
  b.bench(fn() { b.keep(toposort_hashset(g)) })
}

///|
test "bench/toposort/array/chain_10000" (b : @bench.T) {
  let g = build_chain(10000)
  b.bench(fn() { b.keep(toposort_array(g)) })
}

///|
test "bench/toposort/map/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() { b.keep(@alga.toposort(g)) })
}

///|
test "bench/toposort/hashset/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() { b.keep(toposort_hashset(g)) })
}

///|
test "bench/toposort/array/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() { b.keep(toposort_array(g)) })
}

// === has_cycle ===

///|
test "bench/has_cycle/map/acyclic_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(@alga.has_cycle(g)) })
}

///|
test "bench/has_cycle/hashset/acyclic_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(has_cycle_hashset(g)) })
}

///|
test "bench/has_cycle/array/acyclic_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(has_cycle_array(g)) })
}

///|
test "bench/has_cycle/map/cyclic_1000" (b : @bench.T) {
  let g = build_cyclic(1000)
  b.bench(fn() { b.keep(@alga.has_cycle(g)) })
}

///|
test "bench/has_cycle/hashset/cyclic_1000" (b : @bench.T) {
  let g = build_cyclic(1000)
  b.bench(fn() { b.keep(has_cycle_hashset(g)) })
}

///|
test "bench/has_cycle/array/cyclic_1000" (b : @bench.T) {
  let g = build_cyclic(1000)
  b.bench(fn() { b.keep(has_cycle_array(g)) })
}

// === SCC ===

///|
test "bench/scc/map/acyclic_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(g.scc()) })
}

///|
test "bench/scc/hashset/acyclic_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(scc_hashset(g)) })
}

///|
test "bench/scc/array/acyclic_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(scc_array(g)) })
}

///|
test "bench/scc/map/cyclic_1000" (b : @bench.T) {
  let g = build_cyclic(1000)
  b.bench(fn() { b.keep(g.scc()) })
}

///|
test "bench/scc/hashset/cyclic_1000" (b : @bench.T) {
  let g = build_cyclic(1000)
  b.bench(fn() { b.keep(scc_hashset(g)) })
}

///|
test "bench/scc/array/cyclic_1000" (b : @bench.T) {
  let g = build_cyclic(1000)
  b.bench(fn() { b.keep(scc_array(g)) })
}

// ============================================================
// Round 2: Array[Bool] vs FixedArray vs GenCounter vs Bitset
// ============================================================

// === DFS reachable — chain_1000 ===

///|
test "bench/reachable/fixedarray/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(reachable_fixedarray(g, 0)) })
}

///|
test "bench/reachable/gen/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_gen(g, 0, visited, gen))
  })
}

///|
test "bench/reachable/bitset/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(reachable_bitset(g, 0)) })
}

// === DFS reachable — chain_10000 ===

///|
test "bench/reachable/fixedarray/chain_10000" (b : @bench.T) {
  let g = build_chain(10000)
  b.bench(fn() { b.keep(reachable_fixedarray(g, 0)) })
}

///|
test "bench/reachable/gen/chain_10000" (b : @bench.T) {
  let g = build_chain(10000)
  let visited = FixedArray::make(10000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_gen(g, 0, visited, gen))
  })
}

///|
test "bench/reachable/bitset/chain_10000" (b : @bench.T) {
  let g = build_chain(10000)
  b.bench(fn() { b.keep(reachable_bitset(g, 0)) })
}

// === DFS reachable — diamond_1000 ===

///|
test "bench/reachable/fixedarray/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() { b.keep(reachable_fixedarray(g, 0)) })
}

///|
test "bench/reachable/gen/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_gen(g, 0, visited, gen))
  })
}

///|
test "bench/reachable/bitset/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() { b.keep(reachable_bitset(g, 0)) })
}

// === BFS — chain_1000 ===

///|
test "bench/bfs/fixedarray/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() {
    b.keep(bfs_fold_fixedarray(g, 0, 0, fn(acc, _v) { (acc + 1, true) }))
  })
}

///|
test "bench/bfs/gen/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(bfs_fold_gen(g, 0, 0, fn(acc, _v) { (acc + 1, true) }, visited, gen))
  })
}

///|
test "bench/bfs/bitset/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() {
    b.keep(bfs_fold_bitset(g, 0, 0, fn(acc, _v) { (acc + 1, true) }))
  })
}

// === BFS — diamond_1000 ===

///|
test "bench/bfs/fixedarray/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() {
    b.keep(bfs_fold_fixedarray(g, 0, 0, fn(acc, _v) { (acc + 1, true) }))
  })
}

///|
test "bench/bfs/gen/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(bfs_fold_gen(g, 0, 0, fn(acc, _v) { (acc + 1, true) }, visited, gen))
  })
}

///|
test "bench/bfs/bitset/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() {
    b.keep(bfs_fold_bitset(g, 0, 0, fn(acc, _v) { (acc + 1, true) }))
  })
}

// === SCC — acyclic_1000 ===

///|
test "bench/scc/fixedarray/acyclic_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(scc_fixedarray(g)) })
}

///|
test "bench/scc/gen/acyclic_1000" (b : @bench.T) {
  let g = build_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 2
    b.keep(scc_gen(g, visited, gen))
  })
}

///|
test "bench/scc/bitset/acyclic_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(scc_bitset(g)) })
}

// === SCC — cyclic_1000 ===

///|
test "bench/scc/fixedarray/cyclic_1000" (b : @bench.T) {
  let g = build_cyclic(1000)
  b.bench(fn() { b.keep(scc_fixedarray(g)) })
}

///|
test "bench/scc/gen/cyclic_1000" (b : @bench.T) {
  let g = build_cyclic(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 2
    b.keep(scc_gen(g, visited, gen))
  })
}

///|
test "bench/scc/bitset/cyclic_1000" (b : @bench.T) {
  let g = build_cyclic(1000)
  b.bench(fn() { b.keep(scc_bitset(g)) })
}
