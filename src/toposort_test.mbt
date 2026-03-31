///|
test "toposort linear" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
  let result = @alga.toposort(g)
  assert_true(result is Some(_))
  match result {
    Some(order) => {
      assert_eq(order.length(), 4)
      // Validate: for every edge (u, v), u appears before v
      let pos : Map[Int, Int] = Map::new()
      for i = 0; i < order.length(); i = i + 1 {
        pos[order[i]] = i
      }
      let edges = g.edge_list()
      for i = 0; i < edges.length(); i = i + 1 {
        let u_pos = match pos.get(edges[i].0) {
          Some(p) => p
          None => -1
        }
        let v_pos = match pos.get(edges[i].1) {
          Some(p) => p
          None => -1
        }
        assert_true(u_pos < v_pos)
      }
    }
    None => assert_true(false)
  }
}

///|
test "toposort diamond" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (1, 3), (2, 4), (3, 4)])
  let result = @alga.toposort(g)
  assert_true(result is Some(_))
  match result {
    Some(order) => {
      assert_eq(order.length(), 4)
      // 1 must be first, 4 must be last
      assert_eq(order[0], 1)
      assert_eq(order[3], 4)
    }
    None => assert_true(false)
  }
}

///|
test "toposort cycle" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1)])
  let result = @alga.toposort(g)
  assert_true(result is None)
}

///|
test "toposort self loop" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  let result = @alga.toposort(g)
  assert_true(result is None)
}

///|
test "toposort disconnected" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (3, 4)])
  let result = @alga.toposort(g)
  assert_true(result is Some(_))
  match result {
    Some(order) => assert_eq(order.length(), 4)
    None => assert_true(false)
  }
}

// === toposort_subset ===

///|
test "toposort_subset linear middle" {
  // Graph: 0→1→2→3→4, subset {1,2,3}
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3), (3, 4)])
  let result = @alga.toposort_subset(g, [1, 2, 3])
  match result {
    Some(order) => {
      assert_eq(order.length(), 3)
      // Validate ordering: 1 before 2 before 3
      let pos : Map[Int, Int] = Map::new()
      for i = 0; i < order.length(); i = i + 1 {
        pos[order[i]] = i
      }
      assert_true(pos[1] < pos[2])
      assert_true(pos[2] < pos[3])
    }
    None => assert_true(false)
  }
}

///|
test "toposort_subset full graph matches toposort" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3)])
  let full = @alga.toposort(g)
  let subset = @alga.toposort_subset(g, [0, 1, 2, 3])
  match (full, subset) {
    (Some(f), Some(s)) => {
      assert_eq(f.length(), s.length())
      // Both should be valid topological orderings
      assert_eq(s.length(), 4)
    }
    _ => assert_true(false)
  }
}

///|
test "toposort_subset empty" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2)])
  let result = @alga.toposort_subset(g, [])
  match result {
    Some(order) => assert_eq(order.length(), 0)
    None => assert_true(false)
  }
}

///|
test "toposort_subset cycle in subset" {
  // Graph has cycle 1→2→3→1, subset includes it
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (2, 3), (3, 1)])
  let result = @alga.toposort_subset(g, [1, 2, 3])
  assert_true(result is None)
}

///|
test "toposort_subset disconnected vertices" {
  // Graph: 0→1, 2→3, subset {0, 2} — no edges between them
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (2, 3)])
  let result = @alga.toposort_subset(g, [0, 2])
  match result {
    Some(order) => assert_eq(order.length(), 2)
    None => assert_true(false)
  }
}

///|
test "toposort_subset single vertex" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2)])
  let result = @alga.toposort_subset(g, [1])
  match result {
    Some(order) => {
      assert_eq(order.length(), 1)
      assert_eq(order[0], 1)
    }
    None => assert_true(false)
  }
}

///|
test "toposort_subset ignores edges outside subset" {
  // Graph: 1→2→3→4, subset {1, 3} — edge 1→2 and 2→3 go through 2
  // which is NOT in subset, so no ordering constraint between 1 and 3
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
  let result = @alga.toposort_subset(g, [1, 3])
  match result {
    Some(order) => {
      assert_eq(order.length(), 2)
      // Both 1 and 3 should appear, no ordering required between them
      let has_1 = order.contains(1)
      let has_3 = order.contains(3)
      assert_true(has_1)
      assert_true(has_3)
    }
    None => assert_true(false)
  }
}

///|
test "toposort_subset duplicate vertices" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  // Duplicates in input should not corrupt results
  let result = @alga.toposort_subset(g, [1, 2, 2, 3, 1])
  match result {
    Some(order) => {
      assert_eq(order.length(), 3)
      let pos : Map[Int, Int] = Map::new()
      for i = 0; i < order.length(); i = i + 1 {
        pos[order[i]] = i
      }
      assert_true(pos[1] < pos[2])
      assert_true(pos[2] < pos[3])
    }
    None => assert_true(false)
  }
}

///|
test "toposort_subset nonexistent vertex filtered out" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2)])
  let result = @alga.toposort_subset(g, [0, 1, 99])
  match result {
    Some(order) => {
      assert_eq(order.length(), 2)
      assert_true(!order.contains(99))
      assert_true(order.contains(0))
      assert_true(order.contains(1))
    }
    None => assert_true(false)
  }
}

///|
test "toposort_subset invalid vertex on DenseGraph" {
  let g = @alga.DenseGraph::from_edges(3, [(0, 1), (1, 2)])
  let result = @alga.toposort_subset(g, [0, 1, 99])
  match result {
    Some(order) => {
      assert_eq(order.length(), 2)
      assert_true(!order.contains(99))
    }
    None => assert_true(false)
  }
}

///|
test "toposort_subset negative vertex ID filtered" {
  let g = @alga.DenseGraph::from_edges(3, [(0, 1), (1, 2)])
  let result = @alga.toposort_subset(g, [0, -5, 1])
  match result {
    Some(order) => {
      assert_eq(order.length(), 2)
      assert_true(!order.contains(-5))
    }
    None => assert_true(false)
  }
}

///|
test "toposort_subset self loop in subset" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1), (1, 2)])
  let result = @alga.toposort_subset(g, [1, 2])
  // Self-loop on 1 is a cycle within the subset
  assert_true(result is None)
}

///|
test "has_cycle" {
  let linear = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  assert_true(!@alga.has_cycle(linear))
  let cycle = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1)])
  assert_true(@alga.has_cycle(cycle))
  let self_loop = @alga.AdjacencyMap::from_edges([(1, 1)])
  assert_true(@alga.has_cycle(self_loop))
  let empty = @alga.AdjacencyMap::empty()
  assert_true(!@alga.has_cycle(empty))
  let single = @alga.AdjacencyMap::vertex(1)
  assert_true(!@alga.has_cycle(single))
}

// === topo_levels ===

///|
test "topo_levels linear chain" {
  // 1→2→3→4: each vertex one step further from the source
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 4)])
  let result = @alga.topo_levels(g)
  match result {
    Some(levels) => {
      assert_eq(levels[1], 0)
      assert_eq(levels[2], 1)
      assert_eq(levels[3], 2)
      assert_eq(levels[4], 3)
    }
    None => assert_true(false)
  }
}

///|
test "topo_levels diamond" {
  // 1→2, 1→3, 2→4, 3→4: vertex 4 is at level 2 (longest path)
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (1, 3), (2, 4), (3, 4)])
  let result = @alga.topo_levels(g)
  match result {
    Some(levels) => {
      assert_eq(levels[1], 0)
      assert_eq(levels[2], 1)
      assert_eq(levels[3], 1)
      assert_eq(levels[4], 2)
    }
    None => assert_true(false)
  }
}

///|
test "topo_levels multiple sources" {
  // Two disconnected chains: 1→2, 3→4 — each source at level 0
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (3, 4)])
  let result = @alga.topo_levels(g)
  match result {
    Some(levels) => {
      assert_eq(levels[1], 0)
      assert_eq(levels[2], 1)
      assert_eq(levels[3], 0)
      assert_eq(levels[4], 1)
    }
    None => assert_true(false)
  }
}

///|
test "topo_levels single vertex" {
  let g = @alga.AdjacencyMap::vertex(42)
  let result = @alga.topo_levels(g)
  match result {
    Some(levels) => assert_eq(levels[42], 0)
    None => assert_true(false)
  }
}

///|
test "topo_levels empty graph" {
  let g = @alga.AdjacencyMap::empty()
  let result = @alga.topo_levels(g)
  match result {
    Some(levels) => assert_eq(levels.length(), 0)
    None => assert_true(false)
  }
}

///|
test "topo_levels cycle returns None" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1)])
  let result = @alga.topo_levels(g)
  assert_true(result is None)
}

///|
test "topo_levels self loop returns None" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  let result = @alga.topo_levels(g)
  assert_true(result is None)
}

///|
test "topo_levels DenseGraph" {
  // Verify genericity: same diamond on DenseGraph (dense 0-based IDs)
  let g = @alga.DenseGraph::from_edges(4, [(0, 1), (0, 2), (1, 3), (2, 3)])
  let result = @alga.topo_levels(g)
  match result {
    Some(levels) => {
      assert_eq(levels[0], 0)
      assert_eq(levels[1], 1)
      assert_eq(levels[2], 1)
      assert_eq(levels[3], 2)
    }
    None => assert_true(false)
  }
}

///|
test "topo_levels wide star" {
  // Star: hub 0 → spokes 1,2,3,4 — hub at level 0, all spokes at level 1
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (0, 2), (0, 3), (0, 4)])
  let result = @alga.topo_levels(g)
  match result {
    Some(levels) => {
      assert_eq(levels[0], 0)
      assert_eq(levels[1], 1)
      assert_eq(levels[2], 1)
      assert_eq(levels[3], 1)
      assert_eq(levels[4], 1)
    }
    None => assert_true(false)
  }
}

///|
test "topo_levels asymmetric paths (longest wins)" {
  // Two paths to vertex 5: long arm 1→2→3→5 (length 3) and short arm 1→4→5 (length 2).
  // Level of 5 must be 3 (longest path), not 2 — this is the key property
  // that distinguishes topo_levels from simple BFS distance.
  let g = @alga.AdjacencyMap::from_edges([
    (1, 2),
    (2, 3),
    (3, 5),
    (1, 4),
    (4, 5),
  ])
  let result = @alga.topo_levels(g)
  match result {
    Some(levels) => {
      assert_eq(levels[1], 0)
      assert_eq(levels[2], 1)
      assert_eq(levels[3], 2)
      assert_eq(levels[4], 1)
      assert_eq(levels[5], 3) // longest path: 1→2→3→5, not shortest 1→4→5
    }
    None => assert_true(false)
  }
}
