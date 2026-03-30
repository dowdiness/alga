// Benchmarks: AdjacencyMap (Map) vs DenseGraph (flat Array)
// Each algorithm tested with:
//   map/gen      — AdjacencyMap + GenCounter visited (best from Exp 1)
//   flat/trait   — DenseGraph + GenCounter + for_each_successor callback
//   flat/direct  — DenseGraph + GenCounter + direct array iteration
//
// The progression isolates:
//   map/gen → flat/trait  = adjacency lookup overhead (Map vs Array)
//   flat/trait → flat/direct = closure callback overhead (call_ref)

// === Helpers ===

///|
fn build_dense_chain(n : Int) -> DenseGraph {
  let edges : Array[(Int, Int)] = []
  for i = 0; i < n - 1; i = i + 1 {
    edges.push((i, i + 1))
  }
  DenseGraph::from_edges(n, edges)
}

///|
fn build_dense_diamond(n : Int) -> DenseGraph {
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
  DenseGraph::from_edges(n, edges)
}

///|
fn build_dense_cyclic(n : Int) -> DenseGraph {
  let edges : Array[(Int, Int)] = []
  for i = 0; i < n; i = i + 1 {
    edges.push((i, (i + 1) % n))
  }
  for i = 0; i < n / 2; i = i + 1 {
    edges.push((i, (i * 7 + 3) % n))
  }
  DenseGraph::from_edges(n, edges)
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
    b.keep(g.reachable_trait(0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_cb_no_temp/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(g.reachable_callback_no_temp(0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_mark_rev/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(g.reachable_mark_rev(0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_reuse_buf/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(g.reachable_reuse_buf(0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_direct/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(g.reachable_direct(0, visited, gen))
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
    b.keep(g.reachable_trait(0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_cb_no_temp/chain_10000" (b : @bench.T) {
  let g = build_dense_chain(10000)
  let visited = FixedArray::make(10000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(g.reachable_callback_no_temp(0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_direct/chain_10000" (b : @bench.T) {
  let g = build_dense_chain(10000)
  let visited = FixedArray::make(10000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(g.reachable_direct(0, visited, gen))
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
    b.keep(g.reachable_trait(0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_cb_no_temp/diamond_1000" (b : @bench.T) {
  let g = build_dense_diamond(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(g.reachable_callback_no_temp(0, visited, gen))
  })
}

///|
test "bench/flat/reachable/flat_direct/diamond_1000" (b : @bench.T) {
  let g = build_dense_diamond(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(g.reachable_direct(0, visited, gen))
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
    b.keep(g.bfs_count_trait(0, visited, gen))
  })
}

///|
test "bench/flat/bfs/flat_direct/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(g.bfs_count_direct(0, visited, gen))
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
    b.keep(g.bfs_count_trait(0, visited, gen))
  })
}

///|
test "bench/flat/bfs/flat_direct/diamond_1000" (b : @bench.T) {
  let g = build_dense_diamond(1000)
  let visited = FixedArray::make(1000, 0)
  let mut gen = 0
  b.bench(fn() {
    gen = gen + 1
    b.keep(g.bfs_count_direct(0, visited, gen))
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
  b.bench(fn() { b.keep(g.toposort_trait()) })
}

///|
test "bench/flat/toposort/flat_direct/chain_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  b.bench(fn() { b.keep(g.toposort_direct()) })
}

// === SCC — acyclic_1000 ===

///|
test "bench/flat/scc/map_array/acyclic_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(g.scc_array()) })
}

///|
test "bench/flat/scc/flat_direct/acyclic_1000" (b : @bench.T) {
  let g = build_dense_chain(1000)
  b.bench(fn() { b.keep(g.scc_direct()) })
}

// === SCC — cyclic_1000 ===

///|
test "bench/flat/scc/map_array/cyclic_1000" (b : @bench.T) {
  let g = build_cyclic(1000)
  b.bench(fn() { b.keep(g.scc_array()) })
}

///|
test "bench/flat/scc/flat_direct/cyclic_1000" (b : @bench.T) {
  let g = build_dense_cyclic(1000)
  b.bench(fn() { b.keep(g.scc_direct()) })
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
