///|
test "bfs_fold diamond order" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (1, 3), (2, 4), (3, 4)])
  let order : Array[Int] = @alga.bfs_fold(g, 1, [], fn(arr : Array[Int], v) {
    arr.push(v)
    (arr, true)
  })
  assert_eq(order.length(), 4)
  assert_eq(order[0], 1)
  assert_eq(order[3], 4)
  assert_true(
    (order[1] == 2 && order[2] == 3) || (order[1] == 3 && order[2] == 2),
  )
}

///|
test "bfs_fold reachability" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
  let visited : Array[Int] = @alga.bfs_fold(g, 1, [], fn(arr : Array[Int], v) {
    arr.push(v)
    (arr, true)
  })
  assert_eq(visited.length(), 4)
}

///|
test "bfs_fold early termination" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
  let mut count = 0
  let _ = @alga.bfs_fold(g, 1, 0, fn(acc, _v) {
    count = count + 1
    if count >= 2 {
      (acc + 1, false)
    } else {
      (acc + 1, true)
    }
  })
  assert_eq(count, 2)
}

// --- bfs_fold_multi ---

///|
test "bfs_fold_multi single start matches bfs_fold" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (1, 3), (2, 4), (3, 4)])
  let single : Array[Int] = @alga.bfs_fold(g, 1, [], fn(arr : Array[Int], v) {
    arr.push(v)
    (arr, true)
  })
  let multi : Array[Int] = @alga.bfs_fold_multi(g, [1], [], fn(
    arr : Array[Int],
    v,
  ) {
    arr.push(v)
    (arr, true)
  })
  assert_eq(single, multi)
}

///|
test "bfs_fold_multi multiple starts" {
  // Two disconnected chains: 1->2->3 and 10->11->12
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (10, 11), (11, 12)])
  let visited : Array[Int] = @alga.bfs_fold_multi(g, [1, 10], [], fn(
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
test "bfs_fold_multi overlapping reachability" {
  // Diamond: both 1 and 2 can reach 4
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (1, 3), (2, 4), (3, 4)])
  let visited : Array[Int] = @alga.bfs_fold_multi(g, [1, 2], [], fn(
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
test "bfs_fold_multi empty starts" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  let result = @alga.bfs_fold_multi(g, [], 0, fn(acc, _v) { (acc + 1, true) })
  assert_eq(result, 0)
}

///|
test "bfs_fold_multi invalid starts filtered" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  let visited : Array[Int] = @alga.bfs_fold_multi(g, [99, 100], [], fn(
    arr : Array[Int],
    v,
  ) {
    arr.push(v)
    (arr, true)
  })
  assert_eq(visited.length(), 0)
}

///|
test "bfs_fold_multi disconnected components" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (3, 4)])
  let visited : Array[Int] = @alga.bfs_fold_multi(g, [1, 3], [], fn(
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
test "bfs_fold_multi DenseGraph genericity" {
  let am = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (3, 4)])
  let g = @alga.DenseGraph::from_adjacency_map(am)
  let visited : Array[Int] = @alga.bfs_fold_multi(g, [0, 3], [], fn(
    arr : Array[Int],
    v,
  ) {
    arr.push(v)
    (arr, true)
  })
  assert_eq(visited.length(), 5)
}

///|
test "bfs_fold_multi early termination" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (10, 11), (11, 12)])
  let mut count = 0
  let _ = @alga.bfs_fold_multi(g, [1, 10], 0, fn(acc, _v) {
    count = count + 1
    if count >= 3 {
      (acc + 1, false)
    } else {
      (acc + 1, true)
    }
  })
  assert_eq(count, 3)
}
