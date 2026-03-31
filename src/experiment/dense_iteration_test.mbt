// Correctness tests for DenseGraph
// (sorted / sorted_components helpers are in visited_set_test.mbt in the same package)

// === DFS reachable ===

///|
test "correctness/flat/reachable/chain" {
  let am = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3), (3, 4)])
  let dg = @alga.DenseGraph::from_adjacency_map(am)
  let expected = sorted(@alga.reachable(am, 0))
  let visited = FixedArray::make(5, 0)
  inspect(
    sorted(reachable_trait(dg, 0, visited, 1)) == expected,
    content="true",
  )
  inspect(
    sorted(reachable_direct(dg, 0, visited, 2)) == expected,
    content="true",
  )
}

///|
test "correctness/flat/reachable/diamond" {
  let am = @alga.AdjacencyMap::from_edges([
    (0, 1),
    (0, 2),
    (1, 3),
    (2, 3),
    (3, 4),
  ])
  let dg = @alga.DenseGraph::from_adjacency_map(am)
  let expected = sorted(@alga.reachable(am, 0))
  let visited = FixedArray::make(5, 0)
  inspect(
    sorted(reachable_trait(dg, 0, visited, 1)) == expected,
    content="true",
  )
  inspect(
    sorted(reachable_direct(dg, 0, visited, 2)) == expected,
    content="true",
  )
}

///|
test "correctness/flat/reachable/cycle" {
  let am = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3), (3, 0)])
  let dg = @alga.DenseGraph::from_adjacency_map(am)
  let expected = sorted(@alga.reachable(am, 0))
  let visited = FixedArray::make(4, 0)
  inspect(
    sorted(reachable_trait(dg, 0, visited, 1)) == expected,
    content="true",
  )
  inspect(
    sorted(reachable_direct(dg, 0, visited, 2)) == expected,
    content="true",
  )
}

// === BFS count ===

///|
test "correctness/flat/bfs/chain" {
  let am = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3)])
  let dg = @alga.DenseGraph::from_adjacency_map(am)
  let expected = @alga.bfs_fold(am, 0, 0, fn(acc, _v) { (acc + 1, true) })
  let visited = FixedArray::make(4, 0)
  inspect(bfs_count_trait(dg, 0, visited, 1) == expected, content="true")
  inspect(bfs_count_direct(dg, 0, visited, 2) == expected, content="true")
}

// === Toposort ===

///|
test "correctness/flat/toposort/chain" {
  let am = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3)])
  let dg = @alga.DenseGraph::from_adjacency_map(am)
  // Both should produce valid topological orderings
  inspect(toposort_trait(dg) is Some(_), content="true")
  inspect(toposort_direct(dg) is Some(_), content="true")
  match toposort_direct(dg) {
    Some(order) => inspect(order.length(), content="4")
    None => inspect(false, content="true")
  }
}

///|
test "correctness/flat/toposort/cycle" {
  let dg = @alga.DenseGraph::from_edges(3, [(0, 1), (1, 2), (2, 0)])
  inspect(toposort_trait(dg) is None, content="true")
  inspect(toposort_direct(dg) is None, content="true")
}

// === SCC ===

///|
test "correctness/flat/scc/dag" {
  let am = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3)])
  let dg = @alga.DenseGraph::from_adjacency_map(am)
  let expected = sorted_components(am.scc())
  inspect(sorted_components(scc_direct(dg)) == expected, content="true")
}

///|
test "correctness/flat/scc/single_cycle" {
  let am = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 0)])
  let dg = @alga.DenseGraph::from_adjacency_map(am)
  let expected = sorted_components(am.scc())
  inspect(sorted_components(scc_direct(dg)) == expected, content="true")
}

///|
test "correctness/flat/scc/multiple_components" {
  let am = @alga.AdjacencyMap::from_edges([
    (0, 1),
    (1, 2),
    (2, 0),
    (2, 3),
    (3, 4),
    (4, 3),
  ])
  let dg = @alga.DenseGraph::from_adjacency_map(am)
  let expected = sorted_components(am.scc())
  inspect(sorted_components(scc_direct(dg)) == expected, content="true")
}

// === Transpose ===

///|
test "correctness/flat/transpose" {
  let dg = @alga.DenseGraph::from_edges(4, [(0, 1), (1, 2), (2, 3)])
  let t = dg.transpose()
  // 0→1 becomes 1→0, etc.
  inspect(t.successors[0], content="[]")
  inspect(t.successors[1], content="[0]")
  inspect(t.successors[2], content="[1]")
  inspect(t.successors[3], content="[2]")
}

// === Large graph ===

///|
test "correctness/flat/reachable/large" {
  let edges : Array[(Int, Int)] = []
  for i = 0; i < 999; i = i + 1 {
    edges.push((i, i + 1))
  }
  let am = @alga.AdjacencyMap::from_edges(edges)
  let dg = @alga.DenseGraph::from_edges(1000, edges)
  let expected = sorted(@alga.reachable(am, 0))
  let visited = FixedArray::make(1000, 0)
  inspect(
    sorted(reachable_direct(dg, 0, visited, 1)) == expected,
    content="true",
  )
  inspect(expected.length(), content="1000")
}
