///|
/// # GraphSym — the construction layer (Finally Tagless style)
///
/// While `DirectedGraph` lets you *observe* a graph (query vertices,
/// traverse edges), `GraphSym` lets you *construct* a graph using four
/// algebraic operations. This is the "Finally Tagless" encoding —
/// instead of building a syntax tree and interpreting it, you write
/// graph expressions that are polymorphic over the representation.
///
/// ## The four operations
///
/// - `empty()` — the graph with no vertices and no edges
/// - `vertex(v)` — a single isolated vertex
/// - `overlay(a, b)` — union of vertices and edges from both graphs
/// - `connect(a, b)` — overlay + edges from every a-vertex to every b-vertex
///
/// ## Algebraic laws (from Mokhov 2017)
///
/// These operations satisfy the axioms of an algebraic graph:
///
/// - overlay is commutative: `overlay(a, b) = overlay(b, a)`
/// - overlay is associative: `overlay(overlay(a, b), c) = overlay(a, overlay(b, c))`
/// - overlay has identity: `overlay(empty, a) = a`
/// - connect is associative: `connect(connect(a, b), c) = connect(a, connect(b, c))`
/// - connect has identity: `connect(empty, a) = a`
/// - connect distributes over overlay (left and right)
/// - connect(a, b) implies overlay(a, b) (decomposition)
///
/// ## Why "Finally Tagless"?
///
/// In the "initial" (tagged) encoding, you build a `Graph` enum (see
/// `graph_expr.mbt`) and interpret it later. In the "final" (tagless)
/// encoding, the graph expression IS the interpretation — the trait
/// methods directly produce the result type.
///
/// Both `AdjacencyMap` and `Graph` implement `GraphSym`, but they
/// produce different things: AdjacencyMap produces an efficient
/// representation directly, while Graph produces a syntax tree
/// that can be transformed before interpretation.
///
/// ## Reference
///
/// Andrey Mokhov, "Algebraic Graphs with Class" (Haskell Symposium, 2017)
/// https://dl.acm.org/doi/10.1145/3122955.3122956
pub(open) trait GraphSym {
  empty() -> Self
  vertex(Int) -> Self
  overlay(Self, Self) -> Self
  connect(Self, Self) -> Self
}

///|
/// AdjacencyMap implements GraphSym by directly building the adjacency
/// representation — no intermediate syntax tree needed.
pub impl GraphSym for AdjacencyMap with empty() {
  AdjacencyMap::empty()
}

///|
pub impl GraphSym for AdjacencyMap with vertex(v) {
  AdjacencyMap::vertex(v)
}

///|
pub impl GraphSym for AdjacencyMap with overlay(a, b) {
  a.overlay(b)
}

///|
pub impl GraphSym for AdjacencyMap with connect(a, b) {
  a.connect(b)
}
