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

///|
test "has_cycle" {
  let linear = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  assert_true(not(@alga.has_cycle(linear)))
  let cycle = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1)])
  assert_true(@alga.has_cycle(cycle))
  let self_loop = @alga.AdjacencyMap::from_edges([(1, 1)])
  assert_true(@alga.has_cycle(self_loop))
  let empty = @alga.AdjacencyMap::empty()
  assert_true(not(@alga.has_cycle(empty)))
  let single = @alga.AdjacencyMap::vertex(1)
  assert_true(not(@alga.has_cycle(single)))
}
