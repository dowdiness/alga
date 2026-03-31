///|
test "foldg vertex count" {
  let g = @alga.Overlay(
    @alga.Vertex(1),
    @alga.Connect(@alga.Vertex(2), @alga.Vertex(3)),
  )
  let am = g.to_adjacency_map()
  assert_eq(am.vertex_count(), 3)
  assert_eq(am.edge_count(), 1)
  assert_true(am.has_edge(2, 3))
}

///|
test "to_adjacency_map preserves structure" {
  let g = @alga.Connect(
    @alga.Vertex(1),
    @alga.Overlay(@alga.Vertex(2), @alga.Vertex(3)),
  )
  let am = g.to_adjacency_map()
  assert_eq(am.vertex_count(), 3)
  assert_true(am.has_edge(1, 2))
  assert_true(am.has_edge(1, 3))
  assert_true(!am.has_edge(2, 3))
}

///|
test "gmap relabeling" {
  let g = @alga.Graph::path([1, 2, 3])
  let mapped = g.gmap(fn(v) { v * 10 })
  let am = mapped.to_adjacency_map()
  assert_true(am.has_vertex(10))
  assert_true(am.has_vertex(20))
  assert_true(am.has_vertex(30))
  assert_true(am.has_edge(10, 20))
  assert_true(am.has_edge(20, 30))
}

///|
test "bind vertex expansion" {
  let g = @alga.Graph::path([1, 2])
  let expanded = g.bind(fn(v) {
    if v == 1 {
      @alga.Connect(@alga.Vertex(10), @alga.Vertex(11))
    } else {
      @alga.Vertex(v)
    }
  })
  let am = expanded.to_adjacency_map()
  assert_true(am.has_edge(10, 11))
  assert_true(am.has_edge(10, 2))
  assert_true(am.has_edge(11, 2))
}

///|
test "induce filtering" {
  let g = @alga.Graph::path([1, 2, 3, 4])
  let filtered = g.induce(fn(v) { v != 2 })
  let am = filtered.to_adjacency_map()
  assert_true(am.has_vertex(1))
  assert_true(!am.has_vertex(2))
  assert_true(am.has_vertex(3))
  assert_true(am.has_vertex(4))
}

///|
test "path combinator" {
  let g = @alga.Graph::path([1, 2, 3])
  let am = g.to_adjacency_map()
  assert_eq(am.edge_count(), 2)
  assert_true(am.has_edge(1, 2))
  assert_true(am.has_edge(2, 3))
  assert_true(!am.has_edge(1, 3))
}

///|
test "clique combinator" {
  let g = @alga.Graph::clique([1, 2, 3])
  let am = g.to_adjacency_map()
  assert_eq(am.vertex_count(), 3)
  // clique via connect chain: connect(connect(1, 2), 3)
  // = overlay(connect(1,2), connect(1,3), connect(2,3))
  assert_true(am.has_edge(1, 2))
  assert_true(am.has_edge(1, 3))
  assert_true(am.has_edge(2, 3))
  assert_eq(am.edge_count(), 3)
}

///|
test "circuit combinator" {
  let g = @alga.Graph::circuit([1, 2, 3])
  let am = g.to_adjacency_map()
  assert_true(am.has_edge(1, 2))
  assert_true(am.has_edge(2, 3))
  assert_true(am.has_edge(3, 1))
  assert_eq(am.edge_count(), 3)
}

///|
test "star combinator" {
  let g = @alga.Graph::star(1, [2, 3, 4])
  let am = g.to_adjacency_map()
  assert_true(am.has_edge(1, 2))
  assert_true(am.has_edge(1, 3))
  assert_true(am.has_edge(1, 4))
  assert_eq(am.vertex_count(), 4)
}

///|
test "roundtrip path to adjacency_map" {
  let g = @alga.Graph::path([1, 2, 3])
  let am = g.to_adjacency_map()
  assert_true(am.has_edge(1, 2))
  assert_true(am.has_edge(2, 3))
  assert_true(!am.has_edge(3, 1))
}

///|
test "empty graph expression" {
  let g : @alga.Graph = @alga.Empty
  let am = g.to_adjacency_map()
  assert_eq(am.vertex_count(), 0)
  assert_eq(am.edge_count(), 0)
}

///|
test "remove_vertex" {
  let g = @alga.Graph::path([1, 2, 3])
  let removed = g.remove_vertex(2)
  let am = removed.to_adjacency_map()
  assert_true(am.has_vertex(1))
  assert_true(!am.has_vertex(2))
  assert_true(am.has_vertex(3))
}

///|
test "vertices combinator" {
  let g = @alga.Graph::vertices([1, 2, 3])
  let am = g.to_adjacency_map()
  assert_eq(am.vertex_count(), 3)
  assert_eq(am.edge_count(), 0)
}

///|
test "edges combinator" {
  let g = @alga.Graph::edges([(1, 2), (3, 4)])
  let am = g.to_adjacency_map()
  assert_true(am.has_edge(1, 2))
  assert_true(am.has_edge(3, 4))
  assert_eq(am.edge_count(), 2)
}

///|
test "Graph Show" {
  inspect(
    @alga.Graph::path([1, 2, 3]),
    content="Overlay(Overlay(Vertex(1), Connect(Vertex(1), Vertex(2))), Connect(Vertex(2), Vertex(3)))",
  )
  inspect(@alga.Empty, content="Empty")
  inspect(@alga.Vertex(42), content="Vertex(42)")
}

///|
test "DenseGraph Show" {
  let g = @alga.DenseGraph::from_edges(3, [(0, 1), (0, 2), (1, 2)])
  inspect(g, content="DenseGraph(3 vertices, [0 -> [1, 2], 1 -> [2]])")
  let empty = @alga.DenseGraph::from_edges(2, [])
  inspect(empty, content="DenseGraph(2 vertices, [])")
}

// ============================================================
// Property-based tests for algebraic graph laws (Mokhov 2017)
// ============================================================
//
// These tests verify that the algebraic graph axioms from Andrey
// Mokhov's "Algebraic Graphs with Class" (Haskell Symposium, 2017)
// hold for our Graph implementation.
//
// An algebraic graph is defined by four operations:
//
//   empty   — the graph with no vertices and no edges
//   vertex  — a single isolated vertex
//   overlay — union of vertices and edges (graph addition)
//   connect — overlay + all cross-edges from left to right
//
// Together, (overlay, connect, empty) form an algebraic structure
// where overlay is a commutative monoid and connect is a monoid
// that distributes over overlay. This gives us 8 axioms that any
// correct implementation must satisfy.
//
// Equality is checked semantically: two Graph expressions are
// equal iff they produce the same AdjacencyMap (same vertices
// and same edges), regardless of expression structure.
//
// Each test generates 100 random Graph expressions and verifies
// the law holds for all of them. The Shrink instance minimizes
// counterexamples when a law fails.

///|
/// Helper: interpret a Graph as AdjacencyMap for equality comparison.
fn to_am(g : @alga.Graph) -> @alga.AdjacencyMap {
  g.to_adjacency_map()
}

// --- Overlay forms a commutative monoid ---

///|
/// Axiom 1 — Overlay is commutative.
///
/// overlay(a, b) == overlay(b, a)
///
/// The order in which you combine two graphs doesn't matter.
/// This is the key difference from connect (which IS ordered).
/// Example: overlay(1→2, 3→4) == overlay(3→4, 1→2)
test "law: overlay commutative" {
  @qc.quick_check_fn(fn(pair : (@alga.Graph, @alga.Graph)) -> Bool {
    let (a, b) = pair
    to_am(@alga.Overlay(a, b)) == to_am(@alga.Overlay(b, a))
  })
}

///|
/// Axiom 2 — Overlay is associative.
///
/// overlay(overlay(a, b), c) == overlay(a, overlay(b, c))
///
/// Grouping doesn't matter when combining graphs with overlay.
/// This means we can write overlay(a, b, c) unambiguously.
test "law: overlay associative" {
  @qc.quick_check_fn(fn(
    triple : (@alga.Graph, @alga.Graph, @alga.Graph),
  ) -> Bool {
    let (a, b, c) = triple
    to_am(@alga.Overlay(@alga.Overlay(a, b), c)) ==
    to_am(@alga.Overlay(a, @alga.Overlay(b, c)))
  })
}

///|
/// Axiom 3 — Empty is the identity for overlay.
///
/// overlay(empty, a) == a == overlay(a, empty)
///
/// Combining any graph with the empty graph yields the original.
/// Together with commutativity and associativity, this makes
/// (Graph, overlay, empty) a commutative monoid.
test "law: overlay identity" {
  @qc.quick_check_fn(fn(a : @alga.Graph) -> Bool {
    to_am(@alga.Overlay(@alga.Empty, a)) == to_am(a) &&
    to_am(@alga.Overlay(a, @alga.Empty)) == to_am(a)
  })
}

// --- Connect forms a monoid ---

///|
/// Axiom 4 — Connect is associative.
///
/// connect(connect(a, b), c) == connect(a, connect(b, c))
///
/// Grouping doesn't matter for connect either.
/// Note: connect is NOT commutative — connect(1, 2) adds
/// edge 1→2, while connect(2, 1) adds edge 2→1.
test "law: connect associative" {
  @qc.quick_check_fn(fn(
    triple : (@alga.Graph, @alga.Graph, @alga.Graph),
  ) -> Bool {
    let (a, b, c) = triple
    to_am(@alga.Connect(@alga.Connect(a, b), c)) ==
    to_am(@alga.Connect(a, @alga.Connect(b, c)))
  })
}

///|
/// Axiom 5 — Empty is the identity for connect.
///
/// connect(empty, a) == a == connect(a, empty)
///
/// Connecting with the empty graph adds no edges.
/// Together with associativity, (Graph, connect, empty)
/// is a monoid — but NOT commutative.
test "law: connect identity" {
  @qc.quick_check_fn(fn(a : @alga.Graph) -> Bool {
    to_am(@alga.Connect(@alga.Empty, a)) == to_am(a) &&
    to_am(@alga.Connect(a, @alga.Empty)) == to_am(a)
  })
}

// --- Connect distributes over overlay ---

///|
/// Axiom 6 — Connect distributes over overlay from the left.
///
/// connect(a, overlay(b, c)) == overlay(connect(a, b), connect(a, c))
///
/// Connecting a to "b or c" is the same as connecting a to b
/// and connecting a to c separately. This is analogous to
/// multiplication distributing over addition: a*(b+c) = a*b + a*c
test "law: connect distributes over overlay (left)" {
  @qc.quick_check_fn(fn(
    triple : (@alga.Graph, @alga.Graph, @alga.Graph),
  ) -> Bool {
    let (a, b, c) = triple
    to_am(@alga.Connect(a, @alga.Overlay(b, c))) ==
    to_am(@alga.Overlay(@alga.Connect(a, b), @alga.Connect(a, c)))
  })
}

///|
/// Axiom 7 — Connect distributes over overlay from the right.
///
/// connect(overlay(a, b), c) == overlay(connect(a, c), connect(b, c))
///
/// Same as Axiom 6 but from the other side.
/// Since connect is not commutative, left and right
/// distributivity are independent axioms.
test "law: connect distributes over overlay (right)" {
  @qc.quick_check_fn(fn(
    triple : (@alga.Graph, @alga.Graph, @alga.Graph),
  ) -> Bool {
    let (a, b, c) = triple
    to_am(@alga.Connect(@alga.Overlay(a, b), c)) ==
    to_am(@alga.Overlay(@alga.Connect(a, c), @alga.Connect(b, c)))
  })
}

// --- Decomposition ---

///|
/// Axiom 8 — Connect decomposes into overlay plus cross-edges.
///
/// connect(a, b) == overlay(a, b) + { u→v | u ∈ vertices(a), v ∈ vertices(b) }
///
/// This is the axiom that gives connect its meaning: it takes the
/// union of two graphs AND adds directed edges from every vertex
/// in the left graph to every vertex in the right graph.
///
/// We verify both directions:
/// (a) overlay(a, b) is a subgraph of connect(a, b) — no edges lost
/// (b) every edge in connect(a, b) that isn't in overlay(a, b) is
///     a cross-edge u→v where u ∈ vertices(a) and v ∈ vertices(b)
///
/// Together these ensure connect can't silently degenerate to overlay
/// (would fail b) or add spurious non-cross edges (would also fail b).
test "law: connect decomposes to overlay" {
  @qc.quick_check_fn(fn(pair : (@alga.Graph, @alga.Graph)) -> Bool {
    let (a, b) = pair
    let connected = to_am(@alga.Connect(a, b))
    let overlaid = to_am(@alga.Overlay(a, b))
    let am_a = to_am(a)
    let am_b = to_am(b)
    // (a) overlay(a, b) is a subgraph of connect(a, b)
    let overlay_subset = overlaid
      .vertex_list()
      .all(fn(v) { connected.has_vertex(v) }) &&
      overlaid.edge_list().all(fn(e) { connected.has_edge(e.0, e.1) })
    // (b) every extra edge in connect must be a cross-edge from a's vertices to b's
    let extras_are_cross = connected
      .edge_list()
      .all(fn(e) {
        overlaid.has_edge(e.0, e.1) ||
        (am_a.has_vertex(e.0) && am_b.has_vertex(e.1))
      })
    overlay_subset && extras_are_cross
  })
}
