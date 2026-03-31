// Benchmarks for alga graph algorithms
// Run with: moon bench --release

///|
fn build_chain(n : Int) -> AdjacencyMap {
  let edges : Array[(Int, Int)] = []
  for i = 0; i < n - 1; i = i + 1 {
    edges.push((i, i + 1))
  }
  AdjacencyMap::from_edges(edges)
}

///|
fn build_diamond(n : Int) -> AdjacencyMap {
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
  AdjacencyMap::from_edges(edges)
}

///|
fn build_cyclic(n : Int) -> AdjacencyMap {
  let edges : Array[(Int, Int)] = []
  for i = 0; i < n; i = i + 1 {
    edges.push((i, (i + 1) % n))
  }
  for i = 0; i < n / 2; i = i + 1 {
    edges.push((i, (i * 7 + 3) % n))
  }
  AdjacencyMap::from_edges(edges)
}

// --- from_edges construction ---

///|
test "bench/from_edges/100" (b : @bench.T) {
  let edges : Array[(Int, Int)] = []
  for i = 0; i < 99; i = i + 1 {
    edges.push((i, i + 1))
  }
  b.bench(fn() { b.keep(AdjacencyMap::from_edges(edges)) })
}

///|
test "bench/from_edges/1000" (b : @bench.T) {
  let edges : Array[(Int, Int)] = []
  for i = 0; i < 999; i = i + 1 {
    edges.push((i, i + 1))
  }
  b.bench(fn() { b.keep(AdjacencyMap::from_edges(edges)) })
}

///|
test "bench/from_edges/10000" (b : @bench.T) {
  let edges : Array[(Int, Int)] = []
  for i = 0; i < 9999; i = i + 1 {
    edges.push((i, i + 1))
  }
  b.bench(fn() { b.keep(AdjacencyMap::from_edges(edges)) })
}

// --- toposort ---

///|
test "bench/toposort/chain_100" (b : @bench.T) {
  let g = build_chain(100)
  b.bench(fn() { b.keep(toposort(g)) })
}

///|
test "bench/toposort/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(toposort(g)) })
}

///|
test "bench/toposort/chain_10000" (b : @bench.T) {
  let g = build_chain(10000)
  b.bench(fn() { b.keep(toposort(g)) })
}

///|
test "bench/toposort/diamond_100" (b : @bench.T) {
  let g = build_diamond(100)
  b.bench(fn() { b.keep(toposort(g)) })
}

///|
test "bench/toposort/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() { b.keep(toposort(g)) })
}

// --- toposort_subset ---

///|
test "bench/toposort_subset/chain_1000_full" (b : @bench.T) {
  let g = build_chain(1000)
  let vertices = Array::makei(1000, fn(i) { i })
  b.bench(fn() { b.keep(toposort_subset(g, vertices)) })
}

///|
test "bench/toposort_subset/chain_1000_half" (b : @bench.T) {
  let g = build_chain(1000)
  let vertices = Array::makei(500, fn(i) { i * 2 })
  b.bench(fn() { b.keep(toposort_subset(g, vertices)) })
}

///|
test "bench/toposort_subset/diamond_1000_full" (b : @bench.T) {
  let g = build_diamond(1000)
  let vertices = Array::makei(1000, fn(i) { i })
  b.bench(fn() { b.keep(toposort_subset(g, vertices)) })
}

// --- dfs reachable ---

///|
test "bench/reachable/chain_100" (b : @bench.T) {
  let g = build_chain(100)
  b.bench(fn() { b.keep(reachable(g, 0)) })
}

///|
test "bench/reachable/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(reachable(g, 0)) })
}

///|
test "bench/reachable/chain_10000" (b : @bench.T) {
  let g = build_chain(10000)
  b.bench(fn() { b.keep(reachable(g, 0)) })
}

///|
test "bench/reachable/diamond_100" (b : @bench.T) {
  let g = build_diamond(100)
  b.bench(fn() { b.keep(reachable(g, 0)) })
}

///|
test "bench/reachable/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() { b.keep(reachable(g, 0)) })
}

// --- bfs ---

///|
test "bench/bfs/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(bfs_fold(g, 0, 0, fn(acc, _v) { (acc + 1, true) })) })
}

///|
test "bench/bfs/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() { b.keep(bfs_fold(g, 0, 0, fn(acc, _v) { (acc + 1, true) })) })
}

// --- has_cycle ---

///|
test "bench/has_cycle/acyclic_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(has_cycle(g)) })
}

///|
test "bench/has_cycle/cyclic_1000" (b : @bench.T) {
  let g = build_cyclic(1000)
  b.bench(fn() { b.keep(has_cycle(g)) })
}

// --- scc ---

///|
test "bench/scc/acyclic_100" (b : @bench.T) {
  let g = build_chain(100)
  b.bench(fn() { b.keep(g.scc()) })
}

///|
test "bench/scc/acyclic_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(g.scc()) })
}

///|
test "bench/scc/cyclic_100" (b : @bench.T) {
  let g = build_cyclic(100)
  b.bench(fn() { b.keep(g.scc()) })
}

///|
test "bench/scc/cyclic_1000" (b : @bench.T) {
  let g = build_cyclic(1000)
  b.bench(fn() { b.keep(g.scc()) })
}

// --- foldg ---

///|
test "bench/foldg/path_100" (b : @bench.T) {
  let g = Graph::path(Array::makei(100, fn(i) { i }))
  b.bench(fn() { b.keep(g.to_adjacency_map()) })
}

///|
test "bench/foldg/path_1000" (b : @bench.T) {
  let g = Graph::path(Array::makei(1000, fn(i) { i }))
  b.bench(fn() { b.keep(g.to_adjacency_map()) })
}

// --- outdegree ---

///|
test "bench/outdegree/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(outdegree(g, 0)) })
}

///|
test "bench/outdegree/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() { b.keep(outdegree(g, 0)) })
}

// --- indegree ---

///|
test "bench/indegree/chain_1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(indegree(g, 500)) })
}

///|
test "bench/indegree/diamond_1000" (b : @bench.T) {
  let g = build_diamond(1000)
  b.bench(fn() { b.keep(indegree(g, 500)) })
}

// --- transpose ---

///|
test "bench/transpose/1000" (b : @bench.T) {
  let g = build_chain(1000)
  b.bench(fn() { b.keep(g.transpose()) })
}
