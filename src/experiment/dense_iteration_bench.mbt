// Benchmarks: AdjacencyMap (Map) vs DenseGraph (flat Array)
// Each algorithm tested with:
//   map/gen      — AdjacencyMap + GenCounter visited (best from Exp 1)
//   flat/trait   — DenseGraph + GenCounter + for_each_successor callback
//   flat/direct  — DenseGraph + GenCounter + direct array iteration
//
// The progression isolates:
//   map/gen → flat/trait  = adjacency lookup overhead (Map vs Array)
//   flat/trait → flat/direct = closure callback overhead (call_ref)

// === Helpers (use shared edge generators from visited_set_bench.mbt) ===

///|
fn build_dense_chain(n : Int) -> @alga.DenseGraph {
  @alga.DenseGraph::from_edges(n, build_chain_edges(n))
}

///|
fn build_dense_diamond(n : Int) -> @alga.DenseGraph {
  @alga.DenseGraph::from_edges(n, build_diamond_edges(n))
}

///|
fn build_dense_cyclic(n : Int) -> @alga.DenseGraph {
  @alga.DenseGraph::from_edges(n, build_cyclic_edges(n))
}

// === DFS reachable — chain_1000 ===

///|
test "bench/flat/reachable/map_gen/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_gen(g, 0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_trait/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_trait(g, 0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_cb_no_temp/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_callback_no_temp(g, 0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_mark_rev/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_mark_rev(g, 0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_reuse_buf/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_reuse_buf(g, 0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_direct/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_direct(g, 0, visited, gen))
  })
}

// === DFS reachable — chain_10000 ===

///|
test "bench/flat/reachable/map_gen/chain_10000" (b : @bench.T) {
  let g = build_chain(10000)
  let visited = FixedArray::make(10000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_gen(g, 0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_trait/chain_10000" (b : @bench.T) {
  let g = build_dense_chain(10000)
  let visited = FixedArray::make(10000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_trait(g, 0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_cb_no_temp/chain_10000" (b : @bench.T) {
  let g = build_dense_chain(10000)
  let visited = FixedArray::make(10000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_callback_no_temp(g, 0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_direct/chain_10000" (b : @bench.T) {
  let g = build_dense_chain(10000)
  let visited = FixedArray::make(10000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_direct(g, 0, visited, gen))
  })
}

// === DFS reachable — diamond_1000 ===

///|
test "bench/flat/reachable/map_gen/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_gen(g, 0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_trait/diamond_1000" (b : @bench.T) {
  let g = build_dense_diamond(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_trait(g, 0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_cb_no_temp/diamond_1000" (b : @bench.T) {
  let g = build_dense_diamond(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_callback_no_temp(g, 0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_direct/diamond_1000" (b : @bench.T) {
  let g = build_dense_diamond(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(reachable_direct(g, 0, visited, gen))
  })
}

// === BFS — chain_1000 ===

///|
test "bench/flat/bfs/map_gen/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(bfs_fold_gen(g, 0, 0, fn(acc, _v) { (acc + 1, true) }, visited, gen))
  })
}

///|
test "bench/flat/bfs/flat_trait/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(bfs_count_trait(g, 0, visited, gen))
  })
}

///|
test "bench/flat/bfs/flat_direct/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(bfs_count_direct(g, 0, visited, gen))
  })
}

// === BFS — diamond_1000 ===

///|
test "bench/flat/bfs/map_gen/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(bfs_fold_gen(g, 0, 0, fn(acc, _v) { (acc + 1, true) }, visited, gen))
  })
}

///|
test "bench/flat/bfs/flat_trait/diamond_1000" (b : @bench.T) {
  let g = build_dense_diamond(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(bfs_count_trait(g, 0, visited, gen))
  })
}

///|
test "bench/flat/bfs/flat_direct/diamond_1000" (b : @bench.T) {
  let g = build_dense_diamond(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(bfs_count_direct(g, 0, visited, gen))
  })
}

// === Toposort — chain_1000 ===

///|
test "bench/flat/toposort/map_array/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(toposort_array(g)) })
}

///|
test "bench/flat/toposort/flat_trait/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  b.bench(fn() { b.keep(toposort_trait(g)) })
}

///|
test "bench/flat/toposort/flat_direct/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  b.bench(fn() { b.keep(toposort_direct(g)) })
}

// === SCC — acyclic_1000 ===

///|
test "bench/flat/scc/map_array/acyclic_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(scc_array(g)) })
}

///|
test "bench/flat/scc/flat_direct/acyclic_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  b.bench(fn() { b.keep(scc_direct(g)) })
}

// === SCC — cyclic_1000 ===

///|
test "bench/flat/scc/map_array/cyclic_1000" (b : @bench.T) {
  let g = build_cyclic(1000)
  b.bench(fn() { b.keep(scc_array(g)) })
}

///|
test "bench/flat/scc/flat_direct/cyclic_1000" (b : @bench.T) {
  let g = build_dense_cyclic(1000)
  b.bench(fn() { b.keep(scc_direct(g)) })
}

// === Transpose — 1000 ===

///|
test "bench/flat/transpose/map/1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(g.transpose()) })
}

///|
test "bench/flat/transpose/flat/1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  b.bench(fn() { b.keep(g.transpose()) })
}
