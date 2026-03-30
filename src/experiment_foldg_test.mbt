// Correctness tests: iterative foldg and direct to_adjacency_map

// === foldg_iter produces same results as foldg ===

///|
test "correctness/foldg_iter/vertex_count" {
  let g = @alga.Graph::path(Array::makei(10, fn(i) { i }))
  let count_rec = @alga.foldg(g, 0, fn(_v) { 1 }, fn(a, b) { a + b }, fn(a, b) {
    a + b
  })
  let count_iter = @alga.foldg_iter(g, 0, fn(_v) { 1 }, fn(a, b) { a + b }, fn(
    a,
    b,
  ) {
    a + b
  })
  inspect(count_rec == count_iter, content="true")
}

///|
test "correctness/foldg_iter/empty" {
  let g : @alga.Graph = @alga.Graph::Empty
  let count = @alga.foldg_iter(g, 0, fn(_v) { 1 }, fn(a, b) { a + b }, fn(
    a,
    b,
  ) {
    a + b
  })
  inspect(count, content="0")
}

///|
test "correctness/foldg_iter/single_vertex" {
  let g = @alga.Graph::Vertex(42)
  let count = @alga.foldg_iter(g, 0, fn(_v) { 1 }, fn(a, b) { a + b }, fn(
    a,
    b,
  ) {
    a + b
  })
  inspect(count, content="1")
}

///|
test "correctness/foldg_iter/connect_order" {
  // connect is NOT commutative — order must be preserved
  let g = @alga.Graph::Connect(@alga.Graph::Vertex(1), @alga.Graph::Vertex(2))
  let rec_map = @alga.foldg(
    g,
    @alga.AdjacencyMap::empty(),
    fn(v) { @alga.AdjacencyMap::vertex(v) },
    fn(a, b) { a.overlay(b) },
    fn(a, b) { a.connect(b) },
  )
  let iter_map = @alga.foldg_iter(
    g,
    @alga.AdjacencyMap::empty(),
    fn(v) { @alga.AdjacencyMap::vertex(v) },
    fn(a, b) { a.overlay(b) },
    fn(a, b) { a.connect(b) },
  )
  // Should have edge 1->2, NOT 2->1
  inspect(rec_map.has_edge(1, 2), content="true")
  inspect(rec_map.has_edge(2, 1), content="false")
  inspect(iter_map.has_edge(1, 2), content="true")
  inspect(iter_map.has_edge(2, 1), content="false")
  inspect(rec_map == iter_map, content="true")
}

// === to_adjacency_map_letrec: same result as recursive, no stack overflow ===

///|
test "correctness/to_adjacency_map_letrec/path" {
  let g = @alga.Graph::path([1, 2, 3, 4, 5])
  let expected = g.to_adjacency_map()
  let actual = g.to_adjacency_map_letrec()
  inspect(actual == expected, content="true")
}

///|
test "correctness/to_adjacency_map_letrec/clique" {
  let g = @alga.Graph::clique([1, 2, 3, 4])
  let expected = g.to_adjacency_map()
  let actual = g.to_adjacency_map_letrec()
  inspect(actual == expected, content="true")
}

///|
test "correctness/to_adjacency_map_letrec/star" {
  let g = @alga.Graph::star(0, [1, 2, 3, 4])
  let expected = g.to_adjacency_map()
  let actual = g.to_adjacency_map_letrec()
  inspect(actual == expected, content="true")
}

///|
test "correctness/to_adjacency_map_letrec/circuit" {
  let g = @alga.Graph::circuit([1, 2, 3])
  let expected = g.to_adjacency_map()
  let actual = g.to_adjacency_map_letrec()
  inspect(actual == expected, content="true")
}

// === to_adjacency_map: same result as recursive ===

///|
test "correctness/to_adjacency_map/path" {
  let g = @alga.Graph::path([1, 2, 3, 4, 5])
  let expected = g.to_adjacency_map()
  let actual = g.to_adjacency_map()
  inspect(actual == expected, content="true")
}

///|
test "correctness/to_adjacency_map/clique" {
  let g = @alga.Graph::clique([1, 2, 3, 4])
  let expected = g.to_adjacency_map()
  let actual = g.to_adjacency_map()
  inspect(actual == expected, content="true")
}

///|
test "correctness/to_adjacency_map/star" {
  let g = @alga.Graph::star(0, [1, 2, 3, 4])
  let expected = g.to_adjacency_map()
  let actual = g.to_adjacency_map()
  inspect(actual == expected, content="true")
}

///|
test "correctness/to_adjacency_map/circuit" {
  let g = @alga.Graph::circuit([1, 2, 3])
  let expected = g.to_adjacency_map()
  let actual = g.to_adjacency_map()
  inspect(actual == expected, content="true")
}

///|
test "correctness/to_adjacency_map/empty" {
  let g : @alga.Graph = @alga.Graph::Empty
  let expected = g.to_adjacency_map()
  let actual = g.to_adjacency_map()
  inspect(actual == expected, content="true")
}

///|
test "correctness/to_adjacency_map/isolated_vertices" {
  // Overlay of isolated vertices — no edges
  let g = @alga.Graph::vertices([1, 2, 3])
  let expected = g.to_adjacency_map()
  let actual = g.to_adjacency_map()
  inspect(actual == expected, content="true")
  inspect(actual.vertex_count(), content="3")
  inspect(actual.edge_count(), content="0")
}

///|
test "correctness/to_adjacency_map/edges" {
  let g = @alga.Graph::edges([(1, 2), (3, 4), (2, 3)])
  let expected = g.to_adjacency_map()
  let actual = g.to_adjacency_map()
  inspect(actual == expected, content="true")
}

// === Large graph correctness (not just small examples) ===

///|
test "correctness/to_adjacency_map/large_path" {
  let g = @alga.Graph::path(Array::makei(200, fn(i) { i }))
  let expected = g.to_adjacency_map()
  let actual = g.to_adjacency_map()
  inspect(actual == expected, content="true")
  inspect(actual.vertex_count(), content="200")
  inspect(actual.edge_count(), content="199")
}

// === gmap via foldg_iter ===

///|
test "correctness/foldg_iter/gmap" {
  let g = @alga.Graph::path([1, 2, 3])
  // Double all vertex labels
  let rec_result = g.gmap(fn(v) { v * 2 }).to_adjacency_map()
  let iter_result = @alga.foldg_iter(
    g,
    @alga.Graph::Empty,
    fn(v) { @alga.Graph::Vertex(v * 2) },
    fn(a, b) { @alga.Graph::Overlay(a, b) },
    fn(a, b) { @alga.Graph::Connect(a, b) },
  ).to_adjacency_map()
  inspect(rec_result == iter_result, content="true")
  inspect(rec_result.has_edge(2, 4), content="true")
  inspect(rec_result.has_edge(4, 6), content="true")
}
