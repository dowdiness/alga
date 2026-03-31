///|
// Path graph: 1 -> 2 -> 3
test "outdegree path graph" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  inspect(@alga.outdegree(g, 1), content="1")
  inspect(@alga.outdegree(g, 2), content="1")
  inspect(@alga.outdegree(g, 3), content="0")
}

///|
test "indegree path graph" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  inspect(@alga.indegree(g, 1), content="0")
  inspect(@alga.indegree(g, 2), content="1")
  inspect(@alga.indegree(g, 3), content="1")
}

///|
// Star graph: 0 -> 1, 0 -> 2, 0 -> 3
test "outdegree star graph" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (0, 2), (0, 3)])
  inspect(@alga.outdegree(g, 0), content="3")
  inspect(@alga.outdegree(g, 1), content="0")
  inspect(@alga.outdegree(g, 2), content="0")
  inspect(@alga.outdegree(g, 3), content="0")
}

///|
test "indegree star graph" {
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (0, 2), (0, 3)])
  inspect(@alga.indegree(g, 0), content="0")
  inspect(@alga.indegree(g, 1), content="1")
  inspect(@alga.indegree(g, 2), content="1")
  inspect(@alga.indegree(g, 3), content="1")
}

///|
// Complete graph K3: all pairs connected
test "outdegree clique K3" {
  let g = @alga.AdjacencyMap::from_edges([
    (0, 1),
    (0, 2),
    (1, 0),
    (1, 2),
    (2, 0),
    (2, 1),
  ])
  inspect(@alga.outdegree(g, 0), content="2")
  inspect(@alga.outdegree(g, 1), content="2")
  inspect(@alga.outdegree(g, 2), content="2")
}

///|
test "indegree clique K3" {
  let g = @alga.AdjacencyMap::from_edges([
    (0, 1),
    (0, 2),
    (1, 0),
    (1, 2),
    (2, 0),
    (2, 1),
  ])
  inspect(@alga.indegree(g, 0), content="2")
  inspect(@alga.indegree(g, 1), content="2")
  inspect(@alga.indegree(g, 2), content="2")
}

///|
// Empty graph — no vertices at all
test "degree empty graph" {
  let g = @alga.AdjacencyMap::empty()
  inspect(@alga.outdegree(g, 0), content="0")
  inspect(@alga.indegree(g, 0), content="0")
}

///|
// Isolated vertex — vertex exists but has no edges
test "degree isolated vertex" {
  let g = @alga.AdjacencyMap::vertex(42)
  inspect(@alga.outdegree(g, 42), content="0")
  inspect(@alga.indegree(g, 42), content="0")
}

///|
// Self-loop: vertex 1 has edge to itself
test "outdegree self-loop" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  inspect(@alga.outdegree(g, 1), content="1")
}

///|
test "indegree self-loop" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  inspect(@alga.indegree(g, 1), content="1")
}

///|
// Self-loop combined with other edges
test "degree self-loop with other edges" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1), (1, 2), (3, 1)])
  inspect(@alga.outdegree(g, 1), content="2") // 1->1 and 1->2
  inspect(@alga.indegree(g, 1), content="2") // 1->1 and 3->1
}

///|
// DenseGraph — verify trait genericity
test "outdegree DenseGraph" {
  let g = @alga.DenseGraph::from_edges(4, [(0, 1), (0, 2), (0, 3), (2, 3)])
  inspect(@alga.outdegree(g, 0), content="3")
  inspect(@alga.outdegree(g, 1), content="0")
  inspect(@alga.outdegree(g, 2), content="1")
  inspect(@alga.outdegree(g, 3), content="0")
}

///|
test "indegree DenseGraph" {
  let g = @alga.DenseGraph::from_edges(4, [(0, 1), (0, 2), (0, 3), (2, 3)])
  inspect(@alga.indegree(g, 0), content="0")
  inspect(@alga.indegree(g, 1), content="1")
  inspect(@alga.indegree(g, 2), content="1")
  inspect(@alga.indegree(g, 3), content="2")
}
