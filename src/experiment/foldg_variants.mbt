// Experiment-only foldg variants.
// foldg_iter, FoldWork, and to_adjacency_map (direct) are now in graph_expr.mbt.

// ============================================================
// Inner fn — local recursive function captures parameters
// ============================================================

///|
/// foldg with `fn go` inner function. Captures empty/vertex/overlay/connect
/// in the closure, so each recursive call passes only the Graph argument
/// instead of all 5 parameters.
pub fn[B] foldg_inner_fn(
  graph : @alga.Graph,
  empty : B,
  vertex : (Int) -> B,
  overlay : (B, B) -> B,
  connect : (B, B) -> B,
) -> B {
  fn go(g : @alga.Graph) -> B {
    match g {
      @alga.Graph::Empty => empty
      @alga.Graph::Vertex(v) => vertex(v)
      @alga.Graph::Overlay(a, b) => overlay(go(a), go(b))
      @alga.Graph::Connect(a, b) => connect(go(a), go(b))
    }
  }

  go(graph)
}

// ============================================================
// Letrec — uses `letrec` keyword for recursive local binding
// ============================================================

///|
/// foldg with `letrec` binding. Same closure capture as inner fn,
/// but uses MoonBit's letrec syntax which may enable different
/// compiler optimizations.
pub fn[B] foldg_letrec(
  graph : @alga.Graph,
  empty : B,
  vertex : (Int) -> B,
  overlay : (B, B) -> B,
  connect : (B, B) -> B,
) -> B {
  letrec go = fn(g : @alga.Graph) -> B {
    match g {
      @alga.Graph::Empty => empty
      @alga.Graph::Vertex(v) => vertex(v)
      @alga.Graph::Overlay(a, b) => overlay(go(a), go(b))
      @alga.Graph::Connect(a, b) => connect(go(a), go(b))
    }
  }
  go(graph)
}

// ============================================================
// CPS foldg — continuation-passing style, all calls in tail position
// ============================================================

///|
/// foldg in continuation-passing style. Every recursive call to `go`
/// is in tail position, enabling TCO via `letrec`. Trades stack frames
/// for heap-allocated continuations (closures).
pub fn[B] foldg_cps(
  graph : @alga.Graph,
  empty : B,
  vertex : (Int) -> B,
  overlay : (B, B) -> B,
  connect : (B, B) -> B,
) -> B {
  letrec go = fn(g : @alga.Graph, k : (B) -> B) -> B {
    match g {
      @alga.Graph::Empty => k(empty)
      @alga.Graph::Vertex(v) => k(vertex(v))
      @alga.Graph::Overlay(a, b) =>
        go(a, fn(ra) { go(b, fn(rb) { k(overlay(ra, rb)) }) })
      @alga.Graph::Connect(a, b) =>
        go(a, fn(ra) { go(b, fn(rb) { k(connect(ra, rb)) }) })
    }
  }
  go(graph, fn(x) { x })
}

///|
/// Recursive foldg with pairwise AdjacencyMap merge (the original slow path).
pub fn to_adjacency_map_recursive(graph : @alga.Graph) -> @alga.AdjacencyMap {
  @alga.foldg(
    graph,
    @alga.AdjacencyMap::empty(),
    fn(v) { @alga.AdjacencyMap::vertex(v) },
    fn(a, b) { a.overlay(b) },
    fn(a, b) { a.connect(b) },
  )
}

///|
pub fn to_adjacency_map_cps(graph : @alga.Graph) -> @alga.AdjacencyMap {
  foldg_cps(
    graph,
    @alga.AdjacencyMap::empty(),
    fn(v) { @alga.AdjacencyMap::vertex(v) },
    fn(a, b) { a.overlay(b) },
    fn(a, b) { a.connect(b) },
  )
}

///|
pub fn to_adjacency_map_inner_fn(graph : @alga.Graph) -> @alga.AdjacencyMap {
  foldg_inner_fn(
    graph,
    @alga.AdjacencyMap::empty(),
    fn(v) { @alga.AdjacencyMap::vertex(v) },
    fn(a, b) { a.overlay(b) },
    fn(a, b) { a.connect(b) },
  )
}

///|
pub fn to_adjacency_map_letrec(graph : @alga.Graph) -> @alga.AdjacencyMap {
  foldg_letrec(
    graph,
    @alga.AdjacencyMap::empty(),
    fn(v) { @alga.AdjacencyMap::vertex(v) },
    fn(a, b) { a.overlay(b) },
    fn(a, b) { a.connect(b) },
  )
}

///|
pub fn to_adjacency_map_iter(graph : @alga.Graph) -> @alga.AdjacencyMap {
  @alga.foldg_iter(
    graph,
    @alga.AdjacencyMap::empty(),
    fn(v) { @alga.AdjacencyMap::vertex(v) },
    fn(a, b) { a.overlay(b) },
    fn(a, b) { a.connect(b) },
  )
}
