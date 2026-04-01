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

// --- condensation tests ---

///|
test "condensation dag - each vertex is its own component" {
  // In a DAG, every vertex is its own SCC.
  // The condensation should preserve the same edge structure.
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
  let (dag, vtoc) = g.condensation()
  // 4 components (one per vertex)
  assert_eq(dag.vertex_count(), 4)
  // 3 edges preserved
  assert_eq(dag.edge_count(), 3)
  // Each vertex maps to a distinct component
  let c1 = vtoc[1]
  let c2 = vtoc[2]
  let c3 = vtoc[3]
  let c4 = vtoc[4]
  assert_true(c1 != c2 && c2 != c3 && c3 != c4 && c1 != c4)
  // Edge structure: c1 -> c2 -> c3 -> c4
  assert_true(dag.has_edge(c1, c2))
  assert_true(dag.has_edge(c2, c3))
  assert_true(dag.has_edge(c3, c4))
}

///|
test "condensation single SCC - collapses to one vertex" {
  // All vertices in one cycle => single component, no edges
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1)])
  let (dag, vtoc) = g.condensation()
  assert_eq(dag.vertex_count(), 1)
  assert_eq(dag.edge_count(), 0)
  // All vertices map to the same component
  assert_eq(vtoc[1], vtoc[2])
  assert_eq(vtoc[2], vtoc[3])
}

///|
test "condensation two SCCs with edge" {
  // {1,2} cycle + {3,4} cycle with edge 2->3
  let g = @alga.AdjacencyMap::from_edges([
    (1, 2),
    (2, 1),
    (2, 3),
    (3, 4),
    (4, 3),
  ])
  let (dag, vtoc) = g.condensation()
  assert_eq(dag.vertex_count(), 2)
  assert_eq(dag.edge_count(), 1)
  // Vertices 1,2 in same component; vertices 3,4 in same component
  assert_eq(vtoc[1], vtoc[2])
  assert_eq(vtoc[3], vtoc[4])
  assert_true(vtoc[1] != vtoc[3])
  // Edge from {1,2}'s component to {3,4}'s component
  let c12 = vtoc[1]
  let c34 = vtoc[3]
  assert_true(dag.has_edge(c12, c34))
  assert_false(dag.has_edge(c34, c12))
}

///|
test "condensation chain of SCCs" {
  // Three SCCs connected linearly: {1,2} -> {3,4} -> {5,6}
  let g = @alga.AdjacencyMap::from_edges([
    (1, 2),
    (2, 1), // SCC A
    (2, 3), // A -> B
    (3, 4),
    (4, 3), // SCC B
    (4, 5), // B -> C
    (5, 6),
    (6, 5), // SCC C
  ])
  let (dag, vtoc) = g.condensation()
  assert_eq(dag.vertex_count(), 3)
  assert_eq(dag.edge_count(), 2)
  let ca = vtoc[1]
  let cb = vtoc[3]
  let cc = vtoc[5]
  assert_true(ca != cb && cb != cc && ca != cc)
  assert_true(dag.has_edge(ca, cb))
  assert_true(dag.has_edge(cb, cc))
  // No transitive shortcut — condensation preserves only direct
  // inter-component edges, not the transitive closure
  assert_false(dag.has_edge(ca, cc))
}

///|
test "condensation disconnected SCCs" {
  // Two separate cycles with no inter-component edges
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 1), (3, 4), (4, 3)])
  let (dag, vtoc) = g.condensation()
  assert_eq(dag.vertex_count(), 2)
  assert_eq(dag.edge_count(), 0)
  assert_eq(vtoc[1], vtoc[2])
  assert_eq(vtoc[3], vtoc[4])
  assert_true(vtoc[1] != vtoc[3])
}

///|
test "condensation single vertex" {
  let g = @alga.AdjacencyMap::vertex(42)
  let (dag, vtoc) = g.condensation()
  assert_eq(dag.vertex_count(), 1)
  assert_eq(dag.edge_count(), 0)
  assert_eq(vtoc[42], 0)
}

///|
test "condensation self-loop" {
  // A self-loop forms its own SCC
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  let (dag, vtoc) = g.condensation()
  assert_eq(dag.vertex_count(), 1)
  assert_eq(dag.edge_count(), 0)
  assert_eq(vtoc[1], 0)
}

///|
test "condensation empty graph" {
  let g = @alga.AdjacencyMap::empty()
  let (dag, vtoc) = g.condensation()
  assert_eq(dag.vertex_count(), 0)
  assert_eq(dag.edge_count(), 0)
  assert_eq(vtoc.length(), 0)
}

///|
test "condensation deduplicates parallel inter-component edges" {
  // Multiple original edges between the same pair of components
  // should collapse to a single condensed edge.
  // Vertices 1,2,3,4 are each their own SCC (no cycles).
  // Edges: 1→3, 1→4, 2→3, 2→4 — but since each vertex is its own
  // component, there are 4 distinct component pairs. No dedup needed here.
  // Better: {1,2} cycle → component A, {3,4} cycle → component B
  // Edges 1→3 and 2→4 both map to A→B — should produce ONE condensed edge.
  let g = @alga.AdjacencyMap::from_edges([
    (1, 2),
    (2, 1), // SCC A: {1,2}
    (3, 4),
    (4, 3), // SCC B: {3,4}
    (1, 3), // A→B via 1→3
    (2, 4), // A→B via 2→4 (same component pair, should dedup)
  ])
  let (dag, vtoc) = g.condensation()
  assert_eq(dag.vertex_count(), 2)
  // Only 1 edge despite 2 original inter-component edges
  assert_eq(dag.edge_count(), 1)
  assert_eq(vtoc[1], vtoc[2]) // same component
  assert_eq(vtoc[3], vtoc[4]) // same component
  assert_true(dag.has_edge(vtoc[1], vtoc[3]))
}

// --- tarjan_scc tests ---

///|
test "tarjan_scc dag - each vertex is its own component" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 4)
  for i = 0; i < components.length(); i = i + 1 {
    assert_eq(components[i].length(), 1)
  }
}

///|
test "tarjan_scc single cycle" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1)])
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 1)
  assert_eq(components[0].length(), 3)
  assert_true(components[0].contains(1))
  assert_true(components[0].contains(2))
  assert_true(components[0].contains(3))
}

///|
test "tarjan_scc two components connected" {
  let g = @alga.AdjacencyMap::from_edges([
    (1, 2),
    (2, 1),
    (2, 3),
    (3, 4),
    (4, 3),
  ])
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 2)
  let mut comp12 : Array[Int] = []
  let mut comp34 : Array[Int] = []
  for c in components {
    if c.contains(1) {
      comp12 = c
    }
    if c.contains(3) {
      comp34 = c
    }
  }
  assert_eq(comp12.length(), 2)
  assert_true(comp12.contains(1))
  assert_true(comp12.contains(2))
  assert_eq(comp34.length(), 2)
  assert_true(comp34.contains(3))
  assert_true(comp34.contains(4))
}

///|
test "tarjan_scc self loop" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 1)
  assert_eq(components[0].length(), 1)
  assert_eq(components[0][0], 1)
}

///|
test "tarjan_scc disconnected acyclic" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (3, 4)])
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 4)
}

///|
test "tarjan_scc empty graph" {
  let g = @alga.AdjacencyMap::empty()
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 0)
}

///|
test "tarjan_scc single vertex" {
  let g = @alga.AdjacencyMap::vertex(42)
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 1)
  assert_eq(components[0].length(), 1)
  assert_eq(components[0][0], 42)
}

///|
test "tarjan_scc works on DenseGraph" {
  let g = @alga.DenseGraph::from_edges(4, [(0, 1), (1, 2), (2, 0), (2, 3)])
  let components = @alga.tarjan_scc(g)
  assert_eq(components.length(), 2)
  let mut cycle_comp : Array[Int] = []
  let mut singleton_comp : Array[Int] = []
  for c in components {
    if c.length() == 3 {
      cycle_comp = c
    }
    if c.length() == 1 {
      singleton_comp = c
    }
  }
  assert_true(cycle_comp.contains(0))
  assert_true(cycle_comp.contains(1))
  assert_true(cycle_comp.contains(2))
  assert_eq(singleton_comp[0], 3)
}
