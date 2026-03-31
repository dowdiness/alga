///|
test "reachable linear" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
  let r = @alga.reachable(g, 1)
  assert_eq(r.length(), 4)
  assert_true(r.contains(1))
  assert_true(r.contains(2))
  assert_true(r.contains(3))
  assert_true(r.contains(4))
}

///|
test "reachable from middle" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
  let r = @alga.reachable(g, 3)
  assert_eq(r.length(), 2)
  assert_true(r.contains(3))
  assert_true(r.contains(4))
  assert_true(!r.contains(1))
}

///|
test "reachable diamond" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (1, 3), (2, 4), (3, 4)])
  let r = @alga.reachable(g, 1)
  assert_eq(r.length(), 4)
}

///|
test "reachable disconnected" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (3, 4)])
  let r = @alga.reachable(g, 1)
  assert_eq(r.length(), 2)
  assert_true(r.contains(1))
  assert_true(r.contains(2))
  assert_true(!r.contains(3))
}

///|
test "reachable single" {
  let g = @alga.AdjacencyMap::vertex(1)
  let r = @alga.reachable(g, 1)
  assert_eq(r.length(), 1)
  assert_eq(r[0], 1)
}

///|
test "dfs_fold early termination" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
  let mut count = 0
  let _ = @alga.dfs_fold(g, 1, 0, fn(acc, _v) {
    count = count + 1
    if count >= 2 {
      (acc + 1, false)
    } else {
      (acc + 1, true)
    }
  })
  assert_eq(count, 2)
}

// --- dfs_fold_multi ---

///|
test "dfs_fold_multi single start matches dfs_fold" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
  let single : Array[Int] = @alga.dfs_fold(g, 1, [], fn(arr : Array[Int], v) {
    arr.push(v)
    (arr, true)
  })
  let multi : Array[Int] = @alga.dfs_fold_multi(g, [1], [], fn(
    arr : Array[Int],
    v,
  ) {
    arr.push(v)
    (arr, true)
  })
  assert_eq(single, multi)
}

///|
test "dfs_fold_multi multiple starts" {
  // Two disconnected chains: 1->2->3 and 10->11->12
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (10, 11), (11, 12)])
  let visited : Array[Int] = @alga.dfs_fold_multi(g, [1, 10], [], fn(
    arr : Array[Int],
    v,
  ) {
    arr.push(v)
    (arr, true)
  })
  assert_eq(visited.length(), 6)
  assert_true(visited.contains(1))
  assert_true(visited.contains(3))
  assert_true(visited.contains(10))
  assert_true(visited.contains(12))
}

///|
test "dfs_fold_multi overlapping reachability" {
  // Diamond: both 1 and 3 can reach 4
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (1, 3), (2, 4), (3, 4)])
  let visited : Array[Int] = @alga.dfs_fold_multi(g, [1, 3], [], fn(
    arr : Array[Int],
    v,
  ) {
    arr.push(v)
    (arr, true)
  })
  // Each vertex appears exactly once
  assert_eq(visited.length(), 4)
}

///|
test "dfs_fold_multi empty starts" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  let result = @alga.dfs_fold_multi(g, [], 0, fn(acc, _v) { (acc + 1, true) })
  assert_eq(result, 0)
}

///|
test "dfs_fold_multi invalid starts filtered" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  let visited : Array[Int] = @alga.dfs_fold_multi(g, [99, 100], [], fn(
    arr : Array[Int],
    v,
  ) {
    arr.push(v)
    (arr, true)
  })
  assert_eq(visited.length(), 0)
}

///|
test "dfs_fold_multi disconnected components" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (3, 4)])
  let visited : Array[Int] = @alga.dfs_fold_multi(g, [1, 3], [], fn(
    arr : Array[Int],
    v,
  ) {
    arr.push(v)
    (arr, true)
  })
  assert_eq(visited.length(), 4)
  assert_true(visited.contains(1))
  assert_true(visited.contains(2))
  assert_true(visited.contains(3))
  assert_true(visited.contains(4))
}

///|
test "dfs_fold_multi DenseGraph genericity" {
  let am = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (3, 4)])
  let g = @alga.DenseGraph::from_adjacency_map(am)
  let visited : Array[Int] = @alga.dfs_fold_multi(g, [0, 3], [], fn(
    arr : Array[Int],
    v,
  ) {
    arr.push(v)
    (arr, true)
  })
  assert_eq(visited.length(), 5)
}

///|
test "dfs_fold_multi early termination" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (10, 11), (11, 12)])
  let mut count = 0
  let _ = @alga.dfs_fold_multi(g, [1, 10], 0, fn(acc, _v) {
    count = count + 1
    if count >= 3 {
      (acc + 1, false)
    } else {
      (acc + 1, true)
    }
  })
  assert_eq(count, 3)
}

// --- reachable_multi ---

///|
test "reachable_multi single start matches reachable" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
  let single = @alga.reachable(g, 1)
  let multi = @alga.reachable_multi(g, [1])
  assert_eq(single, multi)
}

///|
test "reachable_multi disconnected components" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (3, 4)])
  let r = @alga.reachable_multi(g, [1, 3])
  assert_eq(r.length(), 4)
  assert_true(r.contains(1))
  assert_true(r.contains(2))
  assert_true(r.contains(3))
  assert_true(r.contains(4))
}

///|
test "reachable_multi empty starts" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  let r = @alga.reachable_multi(g, [])
  assert_eq(r.length(), 0)
}

///|
test "reachable_multi overlapping" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (1, 3), (2, 4), (3, 4)])
  let r = @alga.reachable_multi(g, [1, 2])
  // No duplicates
  assert_eq(r.length(), 4)
}
