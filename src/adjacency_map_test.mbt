///|
test "empty graph" {
  let g = @alga.AdjacencyMap::empty()
  assert_eq(g.vertex_count(), 0)
  assert_eq(g.edge_count(), 0)
}

///|
test "single vertex" {
  let g = @alga.AdjacencyMap::vertex(42)
  assert_eq(g.vertex_count(), 1)
  assert_eq(g.edge_count(), 0)
  assert_true(g.has_vertex(42))
  assert_true(!g.has_vertex(0))
}

///|
test "single edge" {
  let g = @alga.AdjacencyMap::edge(1, 2)
  assert_eq(g.vertex_count(), 2)
  assert_eq(g.edge_count(), 1)
  assert_true(g.has_vertex(1))
  assert_true(g.has_vertex(2))
  assert_true(g.has_edge(1, 2))
  assert_true(!g.has_edge(2, 1))
}

///|
test "from_edges" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (1, 3)])
  assert_eq(g.vertex_count(), 3)
  assert_eq(g.edge_count(), 3)
  assert_true(g.has_edge(1, 2))
  assert_true(g.has_edge(2, 3))
  assert_true(g.has_edge(1, 3))
}

///|
test "overlay" {
  let a = @alga.AdjacencyMap::edge(1, 2)
  let b = @alga.AdjacencyMap::edge(3, 4)
  let g = a.overlay(b)
  assert_eq(g.vertex_count(), 4)
  assert_true(g.has_edge(1, 2))
  assert_true(g.has_edge(3, 4))
  assert_true(!g.has_edge(1, 3))
}

///|
test "connect" {
  let a = @alga.AdjacencyMap::vertex(1)
  let b = @alga.AdjacencyMap::vertex(2)
  let g = a.connect(b)
  assert_eq(g.vertex_count(), 2)
  assert_true(g.has_edge(1, 2))
  assert_true(!g.has_edge(2, 1))
}

///|
test "connect multiple" {
  let a = @alga.AdjacencyMap::from_edges([(1, 2)])
  let b = @alga.AdjacencyMap::from_edges([(3, 4)])
  let g = a.connect(b)
  assert_eq(g.vertex_count(), 4)
  assert_true(g.has_edge(1, 2))
  assert_true(g.has_edge(3, 4))
  assert_true(g.has_edge(1, 3))
  assert_true(g.has_edge(1, 4))
  assert_true(g.has_edge(2, 3))
  assert_true(g.has_edge(2, 4))
  assert_true(!g.has_edge(3, 1))
}

///|
test "transpose" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  let t = g.transpose()
  assert_eq(t.vertex_count(), 3)
  assert_true(t.has_edge(2, 1))
  assert_true(t.has_edge(3, 2))
  assert_true(!t.has_edge(1, 2))
  assert_true(t.has_vertex(1))
  assert_true(t.has_vertex(2))
  assert_true(t.has_vertex(3))
}

///|
test "invariant: edge targets exist as keys" {
  let g = @alga.AdjacencyMap::edge(1, 2)
  assert_true(g.has_vertex(2))
  assert_eq(g.successor_list(2).length(), 0)
}

///|
test "vertex_list and edge_list" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  let verts = g.vertex_list()
  assert_eq(verts.length(), 3)
  let edges = g.edge_list()
  assert_eq(edges.length(), 2)
}

///|
test "successor_list" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (1, 3), (2, 3)])
  let s = g.successor_list(1)
  assert_eq(s.length(), 2)
  assert_true(s.contains(2))
  assert_true(s.contains(3))
}

///|
test "show adjacency_map" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (1, 3)])
  let s = g.to_string()
  assert_true(s.contains("AdjacencyMap("))
  assert_true(s.contains("1: [2, 3]"))
}

///|
test "show empty adjacency_map" {
  let g = @alga.AdjacencyMap::empty()
  assert_eq(g.to_string(), "AdjacencyMap({})")
}

///|
test "eq same graph" {
  let g1 = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  let g2 = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  assert_true(g1 == g2)
}

///|
test "eq different graphs" {
  let g1 = @alga.AdjacencyMap::from_edges([(1, 2)])
  let g2 = @alga.AdjacencyMap::from_edges([(1, 3)])
  assert_true(g1 != g2)
}

///|
test "eq different vertex count" {
  let g1 = @alga.AdjacencyMap::from_edges([(1, 2)])
  let g2 = @alga.AdjacencyMap::from_edges([(1, 2), (3, 4)])
  assert_true(g1 != g2)
}

///|
test "remove_self_loops" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1), (1, 2), (2, 2), (2, 3)])
  let cleaned = g.remove_self_loops()
  assert_eq(cleaned.vertex_count(), 3)
  assert_true(cleaned.has_edge(1, 2))
  assert_true(cleaned.has_edge(2, 3))
  assert_true(!cleaned.has_edge(1, 1))
  assert_true(!cleaned.has_edge(2, 2))
  assert_eq(cleaned.edge_count(), 2)
}

///|
test "remove_self_loops then toposort" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1), (1, 2), (2, 3)])
  // With self-loop, toposort returns None
  assert_true(@alga.toposort(g) is None)
  // After removing self-loops, toposort succeeds
  let cleaned = g.remove_self_loops()
  assert_true(@alga.toposort(cleaned) is Some(_))
}

// --- predecessors ---

///|
test "predecessors empty graph" {
  let g = @alga.AdjacencyMap::empty()
  assert_eq(@alga.Predecessors::predecessors(g, 0).collect(), [])
}

///|
test "predecessors single vertex" {
  let g = @alga.AdjacencyMap::vertex(1)
  assert_eq(@alga.Predecessors::predecessors(g, 1).collect(), [])
}

///|
test "predecessors chain" {
  // 1 → 2 → 3
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  assert_eq(@alga.Predecessors::predecessors(g, 1).collect(), [])
  assert_eq(@alga.Predecessors::predecessors(g, 2).collect(), [1])
  assert_eq(@alga.Predecessors::predecessors(g, 3).collect(), [2])
}

///|
test "predecessors diamond" {
  // 0 → 1, 0 → 2, 1 → 3, 2 → 3
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (0, 2), (1, 3), (2, 3)])
  let preds_3 = @alga.Predecessors::predecessors(g, 3).collect()
  assert_eq(preds_3.length(), 2)
  assert_true(preds_3.contains(1))
  assert_true(preds_3.contains(2))
}

///|
test "predecessors self loop" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  assert_eq(@alga.Predecessors::predecessors(g, 1).collect(), [1])
}

///|
test "predecessors after overlay" {
  let g1 = @alga.AdjacencyMap::from_edges([(0, 1)])
  let g2 = @alga.AdjacencyMap::from_edges([(2, 1)])
  let g = g1.overlay(g2)
  let preds_1 = @alga.Predecessors::predecessors(g, 1).collect()
  assert_eq(preds_1.length(), 2)
  assert_true(preds_1.contains(0))
  assert_true(preds_1.contains(2))
}

///|
test "predecessors after connect" {
  let g1 = @alga.AdjacencyMap::vertex(0)
  let g2 = @alga.AdjacencyMap::vertex(1)
  let g = g1.connect(g2)
  // connect(0, 1) creates edge 0→1
  assert_eq(@alga.Predecessors::predecessors(g, 1).collect(), [0])
  assert_eq(@alga.Predecessors::predecessors(g, 0).collect(), [])
}

///|
test "transpose regression: transpose preserves predecessors" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (0, 2)])
  let t = g.transpose()
  // In transposed graph, successors of 1 = [0]
  assert_eq(t.successor_list(1), [0])
  // Predecessors of 0 in transposed = [1, 2]
  let preds = @alga.Predecessors::predecessors(t, 0).collect()
  assert_eq(preds.length(), 2)
  assert_true(preds.contains(1))
  assert_true(preds.contains(2))
}
