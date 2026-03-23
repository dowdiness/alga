///|
test "scc dag - each vertex is its own component" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
  let components = g.scc()
  assert_eq(components.length(), 4)
  // Each component has exactly one vertex
  for i = 0; i < components.length(); i = i + 1 {
    assert_eq(components[i].length(), 1)
  }
}

///|
test "scc single cycle" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1)])
  let components = g.scc()
  assert_eq(components.length(), 1)
  assert_eq(components[0].length(), 3)
  assert_true(components[0].contains(1))
  assert_true(components[0].contains(2))
  assert_true(components[0].contains(3))
}

///|
test "scc two components connected" {
  // {1->2->1} -> {3->4->3}
  let g = @alga.AdjacencyMap::from_edges([
    (1, 2),
    (2, 1),
    (2, 3),
    (3, 4),
    (4, 3),
  ])
  let components = g.scc()
  assert_eq(components.length(), 2)
  // Find which component has vertex 1
  let mut comp1_idx = 0
  for i = 0; i < components.length(); i = i + 1 {
    if components[i].contains(1) {
      comp1_idx = i
    }
  }
  let mut comp2_idx = 0
  for i = 0; i < components.length(); i = i + 1 {
    if components[i].contains(3) {
      comp2_idx = i
    }
  }
  assert_eq(components[comp1_idx].length(), 2)
  assert_true(components[comp1_idx].contains(1))
  assert_true(components[comp1_idx].contains(2))
  assert_eq(components[comp2_idx].length(), 2)
  assert_true(components[comp2_idx].contains(3))
  assert_true(components[comp2_idx].contains(4))
}

///|
test "scc self loop" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  let components = g.scc()
  assert_eq(components.length(), 1)
  assert_eq(components[0].length(), 1)
  assert_eq(components[0][0], 1)
}

///|
test "scc disconnected acyclic" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (3, 4)])
  let components = g.scc()
  assert_eq(components.length(), 4)
}
