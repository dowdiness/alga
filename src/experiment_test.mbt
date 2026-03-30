// Correctness tests: verify all variants produce identical results

// === Helper: sort and compare vertex sets ===

///|
fn sorted(arr : Array[Int]) -> Array[Int] {
  let copy = arr.copy()
  copy.sort()
  copy
}

///|
fn sorted_components(comps : Array[Array[Int]]) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  for c in comps {
    result.push(sorted(c))
  }
  result.sort_by(fn(a, b) { a[0].compare(b[0]) })
  result
}

// === DFS reachable — linear chain ===

///|
test "correctness/reachable/chain" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3), (3, 4)])
  let expected = sorted(@alga.reachable(g, 0))
  inspect(sorted(@alga.reachable_array(g, 0)) == expected, content="true")
  inspect(sorted(@alga.reachable_fixedarray(g, 0)) == expected, content="true")
  inspect(sorted(@alga.reachable_bitset(g, 0)) == expected, content="true")
  let visited = FixedArray::make(5, 0)
  inspect(
    sorted(@alga.reachable_gen(g, 0, visited, 1)) == expected,
    content="true",
  )
}

// === DFS reachable — diamond graph ===

///|
test "correctness/reachable/diamond" {
  let g = @alga.AdjacencyMap::from_edges([
    (0, 1),
    (0, 2),
    (1, 3),
    (2, 3),
    (3, 4),
  ])
  let expected = sorted(@alga.reachable(g, 0))
  inspect(sorted(@alga.reachable_array(g, 0)) == expected, content="true")
  inspect(sorted(@alga.reachable_fixedarray(g, 0)) == expected, content="true")
  inspect(sorted(@alga.reachable_bitset(g, 0)) == expected, content="true")
  let visited = FixedArray::make(5, 0)
  inspect(
    sorted(@alga.reachable_gen(g, 0, visited, 1)) == expected,
    content="true",
  )
}

// === DFS reachable — disconnected graph ===

///|
test "correctness/reachable/disconnected" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (3, 4), (4, 5)])
  // From vertex 0: should only reach 0, 1, 2
  let expected = sorted(@alga.reachable(g, 0))
  inspect(sorted(@alga.reachable_array(g, 0)) == expected, content="true")
  inspect(sorted(@alga.reachable_fixedarray(g, 0)) == expected, content="true")
  inspect(sorted(@alga.reachable_bitset(g, 0)) == expected, content="true")
  let visited = FixedArray::make(6, 0)
  inspect(
    sorted(@alga.reachable_gen(g, 0, visited, 1)) == expected,
    content="true",
  )
  // From vertex 3: should reach 3, 4, 5
  let expected3 = sorted(@alga.reachable(g, 3))
  inspect(sorted(@alga.reachable_array(g, 3)) == expected3, content="true")
  inspect(sorted(@alga.reachable_fixedarray(g, 3)) == expected3, content="true")
  inspect(sorted(@alga.reachable_bitset(g, 3)) == expected3, content="true")
  inspect(
    sorted(@alga.reachable_gen(g, 3, visited, 2)) == expected3,
    content="true",
  )
}

// === DFS reachable — single vertex ===

///|
test "correctness/reachable/single" {
  let g = @alga.AdjacencyMap::vertex(42)
  let expected = sorted(@alga.reachable(g, 42))
  inspect(sorted(@alga.reachable_array(g, 42)) == expected, content="true")
  inspect(sorted(@alga.reachable_fixedarray(g, 42)) == expected, content="true")
  inspect(sorted(@alga.reachable_bitset(g, 42)) == expected, content="true")
  let visited = FixedArray::make(43, 0)
  inspect(
    sorted(@alga.reachable_gen(g, 42, visited, 1)) == expected,
    content="true",
  )
}

// === DFS reachable — cycle ===

///|
test "correctness/reachable/cycle" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3), (3, 0)])
  let expected = sorted(@alga.reachable(g, 0))
  inspect(sorted(@alga.reachable_array(g, 0)) == expected, content="true")
  inspect(sorted(@alga.reachable_fixedarray(g, 0)) == expected, content="true")
  inspect(sorted(@alga.reachable_bitset(g, 0)) == expected, content="true")
  let visited = FixedArray::make(4, 0)
  inspect(
    sorted(@alga.reachable_gen(g, 0, visited, 1)) == expected,
    content="true",
  )
}

// === Generation counter — reuse across multiple calls ===

///|
test "correctness/gen/reuse" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (3, 4)])
  let visited = FixedArray::make(5, 0)
  // Call 1: from vertex 0
  let r1 = sorted(@alga.reachable_gen(g, 0, visited, 1))
  inspect(r1 == sorted(@alga.reachable(g, 0)), content="true")
  // Call 2: from vertex 3 — must not be confused by previous call's marks
  let r2 = sorted(@alga.reachable_gen(g, 3, visited, 2))
  inspect(r2 == sorted(@alga.reachable(g, 3)), content="true")
  // Call 3: from vertex 0 again — still works after gen bump
  let r3 = sorted(@alga.reachable_gen(g, 0, visited, 3))
  inspect(r3 == sorted(@alga.reachable(g, 0)), content="true")
}

// === BFS — vertex count agreement ===

///|
test "correctness/bfs/chain" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3)])
  let count_fn : (Int, Int) -> (Int, Bool) = fn(acc, _v) { (acc + 1, true) }
  let expected = @alga.bfs_fold(g, 0, 0, count_fn)
  inspect(@alga.bfs_fold_array(g, 0, 0, count_fn) == expected, content="true")
  inspect(
    @alga.bfs_fold_fixedarray(g, 0, 0, count_fn) == expected,
    content="true",
  )
  inspect(@alga.bfs_fold_bitset(g, 0, 0, count_fn) == expected, content="true")
  let visited = FixedArray::make(4, 0)
  inspect(
    @alga.bfs_fold_gen(g, 0, 0, count_fn, visited, 1) == expected,
    content="true",
  )
}

///|
test "correctness/bfs/diamond" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (0, 2), (1, 3), (2, 3)])
  let count_fn : (Int, Int) -> (Int, Bool) = fn(acc, _v) { (acc + 1, true) }
  let expected = @alga.bfs_fold(g, 0, 0, count_fn)
  inspect(@alga.bfs_fold_array(g, 0, 0, count_fn) == expected, content="true")
  inspect(
    @alga.bfs_fold_fixedarray(g, 0, 0, count_fn) == expected,
    content="true",
  )
  inspect(@alga.bfs_fold_bitset(g, 0, 0, count_fn) == expected, content="true")
  let visited = FixedArray::make(4, 0)
  inspect(
    @alga.bfs_fold_gen(g, 0, 0, count_fn, visited, 1) == expected,
    content="true",
  )
}

// === BFS — gen counter reuse ===

///|
test "correctness/bfs/gen_reuse" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (3, 4)])
  let count_fn : (Int, Int) -> (Int, Bool) = fn(acc, _v) { (acc + 1, true) }
  let visited = FixedArray::make(5, 0)
  let r1 = @alga.bfs_fold_gen(g, 0, 0, count_fn, visited, 1)
  inspect(r1 == @alga.bfs_fold(g, 0, 0, count_fn), content="true")
  let r2 = @alga.bfs_fold_gen(g, 3, 0, count_fn, visited, 2)
  inspect(r2 == @alga.bfs_fold(g, 3, 0, count_fn), content="true")
}

// === SCC — component set agreement ===

///|
test "correctness/scc/dag" {
  // DAG: each vertex is its own SCC
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3)])
  let expected = sorted_components(g.scc())
  inspect(sorted_components(g.scc_array()) == expected, content="true")
  inspect(sorted_components(g.scc_fixedarray()) == expected, content="true")
  inspect(sorted_components(g.scc_bitset()) == expected, content="true")
  let visited = FixedArray::make(4, 0)
  inspect(sorted_components(g.scc_gen(visited, 1)) == expected, content="true")
}

///|
test "correctness/scc/single_cycle" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 0)])
  let expected = sorted_components(g.scc())
  inspect(sorted_components(g.scc_array()) == expected, content="true")
  inspect(sorted_components(g.scc_fixedarray()) == expected, content="true")
  inspect(sorted_components(g.scc_bitset()) == expected, content="true")
  let visited = FixedArray::make(3, 0)
  inspect(sorted_components(g.scc_gen(visited, 1)) == expected, content="true")
}

///|
test "correctness/scc/multiple_components" {
  // Two SCCs: {0,1,2} cycle and {3,4} cycle, connected by 2->3
  let g = @alga.AdjacencyMap::from_edges([
    (0, 1),
    (1, 2),
    (2, 0),
    (2, 3),
    (3, 4),
    (4, 3),
  ])
  let expected = sorted_components(g.scc())
  inspect(sorted_components(g.scc_array()) == expected, content="true")
  inspect(sorted_components(g.scc_fixedarray()) == expected, content="true")
  inspect(sorted_components(g.scc_bitset()) == expected, content="true")
  let visited = FixedArray::make(5, 0)
  inspect(sorted_components(g.scc_gen(visited, 1)) == expected, content="true")
}

///|
test "correctness/scc/self_loop" {
  let g = @alga.AdjacencyMap::from_edges([(0, 0), (0, 1)])
  let expected = sorted_components(g.scc())
  inspect(sorted_components(g.scc_array()) == expected, content="true")
  inspect(sorted_components(g.scc_fixedarray()) == expected, content="true")
  inspect(sorted_components(g.scc_bitset()) == expected, content="true")
  let visited = FixedArray::make(2, 0)
  inspect(sorted_components(g.scc_gen(visited, 1)) == expected, content="true")
}

// === SCC — gen counter reuse ===

///|
test "correctness/scc/gen_reuse" {
  let g1 = @alga.AdjacencyMap::from_edges([(0, 1), (1, 0)])
  let g2 = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 0)])
  let visited = FixedArray::make(3, 0)
  // Call 1
  let r1 = sorted_components(g1.scc_gen(visited, 1))
  inspect(r1 == sorted_components(g1.scc()), content="true")
  // Call 2 — reuses same buffer with bumped gen (need +2 since scc uses gen and gen+1)
  let r2 = sorted_components(g2.scc_gen(visited, 3))
  inspect(r2 == sorted_components(g2.scc()), content="true")
}

// === Large graph correctness (not just small examples) ===

///|
test "correctness/reachable/large_chain" {
  let edges : Array[(Int, Int)] = []
  for i = 0; i < 999; i = i + 1 {
    edges.push((i, i + 1))
  }
  let g = @alga.AdjacencyMap::from_edges(edges)
  let expected = sorted(@alga.reachable(g, 0))
  inspect(expected.length(), content="1000")
  inspect(sorted(@alga.reachable_array(g, 0)) == expected, content="true")
  inspect(sorted(@alga.reachable_fixedarray(g, 0)) == expected, content="true")
  inspect(sorted(@alga.reachable_bitset(g, 0)) == expected, content="true")
  let visited = FixedArray::make(1000, 0)
  inspect(
    sorted(@alga.reachable_gen(g, 0, visited, 1)) == expected,
    content="true",
  )
}

///|
test "correctness/scc/large_cycle" {
  let edges : Array[(Int, Int)] = []
  for i = 0; i < 100; i = i + 1 {
    edges.push((i, (i + 1) % 100))
  }
  let g = @alga.AdjacencyMap::from_edges(edges)
  let expected = sorted_components(g.scc())
  // Should be one component with all 100 vertices
  inspect(expected.length(), content="1")
  inspect(expected[0].length(), content="100")
  inspect(sorted_components(g.scc_array()) == expected, content="true")
  inspect(sorted_components(g.scc_fixedarray()) == expected, content="true")
  inspect(sorted_components(g.scc_bitset()) == expected, content="true")
  let visited = FixedArray::make(100, 0)
  inspect(sorted_components(g.scc_gen(visited, 1)) == expected, content="true")
}

// === Bitset edge case: vertex ID at word boundary (31, 32, 63, 64) ===

///|
test "correctness/bitset/word_boundary" {
  let g = @alga.AdjacencyMap::from_edges([(0, 31), (31, 32), (32, 63), (63, 64)])
  let expected = sorted(@alga.reachable(g, 0))
  inspect(expected, content="[0, 31, 32, 63, 64]")
  inspect(sorted(@alga.reachable_bitset(g, 0)) == expected, content="true")
}

// === Toposort variants (from round 1) ===

///|
test "correctness/toposort/chain" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3)])
  let expected = @alga.toposort(g)
  inspect(expected is Some(_), content="true")
  inspect(@alga.toposort_array(g) == expected, content="true")
  inspect(@alga.toposort_hashset(g) is Some(_), content="true")
  // hashset may produce different valid ordering — just check it's valid
  match @alga.toposort_hashset(g) {
    Some(order) => inspect(order.length(), content="4")
    None => inspect(false, content="true")
  }
}

///|
test "correctness/toposort/cycle_detection" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 0)])
  inspect(@alga.toposort(g) is None, content="true")
  inspect(@alga.toposort_array(g) is None, content="true")
  inspect(@alga.toposort_hashset(g) is None, content="true")
  inspect(@alga.has_cycle_array(g), content="true")
  inspect(@alga.has_cycle_hashset(g), content="true")
}

///|
test "correctness/toposort/acyclic" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (0, 2), (1, 3), (2, 3)])
  inspect(@alga.toposort(g) is Some(_), content="true")
  inspect(@alga.toposort_array(g) is Some(_), content="true")
  inspect(@alga.toposort_hashset(g) is Some(_), content="true")
  inspect(@alga.has_cycle_array(g), content="false")
  inspect(@alga.has_cycle_hashset(g), content="false")
}
