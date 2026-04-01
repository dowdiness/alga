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

// --- dfs_events ---

///|
test "dfs_events empty graph" {
  let g = @alga.AdjacencyMap::empty()
  let events = @alga.dfs_events(g).collect()
  assert_eq(events.length(), 0)
}

///|
test "dfs_events single vertex" {
  let g = @alga.AdjacencyMap::vertex(1)
  let events = @alga.dfs_events(g).collect()
  assert_eq(events.length(), 2)
  assert_true(events[0] is @alga.Discover(1))
  assert_true(events[1] is @alga.Finish(1))
}

///|
test "dfs_events chain" {
  // 1 → 2 → 3
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  let events = @alga.dfs_events(g).collect()
  // Expected: Discover(1), TreeEdge(1,2), Discover(2), TreeEdge(2,3),
  //           Discover(3), Finish(3), Finish(2), Finish(1)
  assert_eq(events.length(), 8)
  // Count event types
  let mut discovers = 0
  let mut finishes = 0
  let mut tree_edges = 0
  for e in events.iter() {
    match e {
      @alga.Discover(_) => discovers = discovers + 1
      @alga.Finish(_) => finishes = finishes + 1
      @alga.TreeEdge(_, _) => tree_edges = tree_edges + 1
      _ => ()
    }
  }
  assert_eq(discovers, 3)
  assert_eq(finishes, 3)
  assert_eq(tree_edges, 2)
}

///|
test "dfs_events back edge (cycle)" {
  // 1 → 2 → 3 → 1
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1)])
  let events = @alga.dfs_events(g).collect()
  // Should contain exactly one BackEdge(3, 1)
  let back_edges : Array[(Int, Int)] = []
  for e in events.iter() {
    match e {
      @alga.BackEdge(u, v) => back_edges.push((u, v))
      _ => ()
    }
  }
  assert_eq(back_edges.length(), 1)
  assert_eq(back_edges[0], (3, 1))
}

///|
test "dfs_events cross/forward edge" {
  // 0 → 1 → 2, 0 → 2
  // Edge 0→2 is a cross/forward edge (2 is black when 0 examines it)
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (0, 2)])
  let events = @alga.dfs_events(g).collect()
  let cf_edges : Array[(Int, Int)] = []
  for e in events.iter() {
    match e {
      @alga.CrossForwardEdge(u, v) => cf_edges.push((u, v))
      _ => ()
    }
  }
  assert_eq(cf_edges.length(), 1)
  assert_eq(cf_edges[0], (0, 2))
}

///|
test "dfs_events self loop" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  let events = @alga.dfs_events(g).collect()
  // Self-loop: 1 is gray when edge 1→1 is examined → BackEdge
  let back_edges : Array[(Int, Int)] = []
  for e in events.iter() {
    match e {
      @alga.BackEdge(u, v) => back_edges.push((u, v))
      _ => ()
    }
  }
  assert_eq(back_edges.length(), 1)
  assert_eq(back_edges[0], (1, 1))
}

///|
test "dfs_events disconnected components" {
  // Two disconnected edges: 1→2, 3→4
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (3, 4)])
  let events = @alga.dfs_events(g).collect()
  let mut discovers = 0
  let mut finishes = 0
  for e in events.iter() {
    match e {
      @alga.Discover(_) => discovers = discovers + 1
      @alga.Finish(_) => finishes = finishes + 1
      _ => ()
    }
  }
  // All 4 vertices discovered and finished
  assert_eq(discovers, 4)
  assert_eq(finishes, 4)
}

///|
test "dfs_events works on DenseGraph" {
  // 0→1→2→0 (cycle)
  let g = @alga.DenseGraph::from_edges(3, [(0, 1), (1, 2), (2, 0)])
  let events = @alga.dfs_events(g).collect()
  let mut back_count = 0
  for e in events.iter() {
    if e is @alga.BackEdge(_, _) {
      back_count = back_count + 1
    }
  }
  assert_eq(back_count, 1)
}

///|
test "dfs_events early termination via break" {
  // Large chain, but we break after first BackEdge
  let g = @alga.AdjacencyMap::from_edges([
    (1, 2),
    (2, 3),
    (3, 1),
    (3, 4),
    (4, 5),
  ])
  let mut found_cycle = false
  for event in @alga.dfs_events(g) {
    if event is @alga.BackEdge(_, _) {
      found_cycle = true
      break
    }
  }
  assert_true(found_cycle)
}

///|
test "dfs_events total edge count" {
  // Diamond: 1→2, 1→3, 2→4, 3→4 (4 edges)
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (1, 3), (2, 4), (3, 4)])
  let events = @alga.dfs_events(g).collect()
  let mut edge_count = 0
  for e in events.iter() {
    match e {
      @alga.TreeEdge(_, _)
      | @alga.BackEdge(_, _)
      | @alga.CrossForwardEdge(_, _) => edge_count = edge_count + 1
      _ => ()
    }
  }
  assert_eq(edge_count, 4)
}

// --- reversed ---

///|
test "reversed successors are predecessors" {
  // 0 → 1 → 2
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2)])
  let rev = @alga.reversed(g)
  // Reversed successors of 2 = predecessors of 2 = [1]
  assert_eq(@alga.DirectedGraph::successors(rev, 2).collect(), [1])
  // Reversed successors of 0 = predecessors of 0 = []
  assert_eq(@alga.DirectedGraph::successors(rev, 0).collect(), [])
}

///|
test "reversed predecessors are successors" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2)])
  let rev = @alga.reversed(g)
  assert_eq(@alga.Predecessors::predecessors(rev, 0).collect(), [1])
}

///|
test "reversed vertex count unchanged" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3)])
  let rev = @alga.reversed(g)
  assert_eq(@alga.DirectedGraph::vertex_count(rev), 4)
}

///|
test "reversed has_vertex unchanged" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1)])
  let rev = @alga.reversed(g)
  assert_true(@alga.DirectedGraph::has_vertex(rev, 0))
  assert_true(@alga.DirectedGraph::has_vertex(rev, 1))
  assert_true(!@alga.DirectedGraph::has_vertex(rev, 99))
}

///|
test "reversed involution" {
  // reversed(reversed(g)) has same successors as g
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (0, 2)])
  let rr = @alga.reversed(@alga.reversed(g))
  for v in @alga.DirectedGraph::iter(g) {
    let orig = @alga.DirectedGraph::successors(g, v).collect()
    let double = @alga.DirectedGraph::successors(rr, v).collect()
    orig.sort()
    double.sort()
    assert_eq(orig, double)
  }
}

///|
test "reversed works with dfs_events" {
  // 0 → 1 → 2: reversed DFS from 2 should discover 2, then 1, then 0
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2)])
  let rev = @alga.reversed(g)
  let events = @alga.dfs_events(rev).collect()
  let mut discovers = 0
  let mut finishes = 0
  for e in events.iter() {
    match e {
      @alga.Discover(_) => discovers = discovers + 1
      @alga.Finish(_) => finishes = finishes + 1
      _ => ()
    }
  }
  assert_eq(discovers, 3)
  assert_eq(finishes, 3)
}

///|
test "reversed works with reachable" {
  // 0 → 1 → 2 → 3: reverse-reachable from 3 = all vertices
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3)])
  let rev = @alga.reversed(g)
  let r = @alga.reachable(rev, 3)
  assert_eq(r.length(), 4)
}

///|
test "reversed DenseGraph" {
  let g = @alga.DenseGraph::from_edges(3, [(0, 1), (1, 2)])
  let rev = @alga.reversed(g)
  assert_eq(@alga.DirectedGraph::successors(rev, 2).collect(), [1])
  assert_eq(@alga.DirectedGraph::successors(rev, 0).collect(), [])
}

///|
test "reversed empty graph" {
  let g = @alga.AdjacencyMap::empty()
  let rev = @alga.reversed(g)
  assert_eq(@alga.dfs_events(rev).collect().length(), 0)
}

///|
test "reversed self loop" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  let rev = @alga.reversed(g)
  // Self-loop stays a self-loop when reversed
  assert_eq(@alga.DirectedGraph::successors(rev, 1).collect(), [1])
}

///|
test "predecessors on DenseGraph" {
  let g = @alga.DenseGraph::from_edges(3, [(0, 1), (1, 2), (0, 2)])
  assert_eq(@alga.Predecessors::predecessors(g, 0).collect(), [])
  assert_eq(@alga.Predecessors::predecessors(g, 1).collect(), [0])
  let preds_2 = @alga.Predecessors::predecessors(g, 2).collect()
  assert_eq(preds_2.length(), 2)
  assert_true(preds_2.contains(1))
  assert_true(preds_2.contains(0))
}

///|
test "DenseGraph transpose regression" {
  let g = @alga.DenseGraph::from_edges(3, [(0, 1), (1, 2)])
  let t = g.transpose()
  assert_eq(@alga.DirectedGraph::successors(t, 2).collect(), [1])
  assert_eq(@alga.Predecessors::predecessors(t, 0).collect(), [1])
}

///|
test "reversed works with toposort" {
  // 0 → 1 → 2: toposort = [0, 1, 2], reversed toposort = [2, 1, 0]
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2)])
  let rev_topo = @alga.toposort(@alga.reversed(g))
  match rev_topo {
    Some(order) => assert_eq(order, [2, 1, 0])
    None => assert_true(false)
  }
}

///|
test "reversed works with tarjan_scc" {
  // 0→1→2→0 (cycle), 3→4: reversed has same SCCs
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 0), (3, 4)])
  let orig_sccs = @alga.tarjan_scc(g)
  let rev_sccs = @alga.tarjan_scc(@alga.reversed(g))
  // Same number of SCCs
  assert_eq(orig_sccs.length(), rev_sccs.length())
  // The cyclic SCC {0,1,2} should appear in both (order may differ)
  fn find_scc_containing(sccs : Array[Array[Int]], v : Int) -> Array[Int] {
    for scc in sccs {
      if scc.contains(v) {
        return scc
      }
    }
    []
  }

  let orig_cycle = find_scc_containing(orig_sccs, 0)
  let rev_cycle = find_scc_containing(rev_sccs, 0)
  orig_cycle.sort()
  rev_cycle.sort()
  assert_eq(orig_cycle, rev_cycle)
}

///|
test "reversed preserves has_cycle" {
  // Cycles are invariant under reversal
  let cyclic = @alga.AdjacencyMap::from_edges([(0, 1), (1, 0)])
  assert_true(@alga.has_cycle(@alga.reversed(cyclic)))
  let acyclic = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2)])
  assert_true(!@alga.has_cycle(@alga.reversed(acyclic)))
}
