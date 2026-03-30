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
  graph : Graph,
  empty : B,
  vertex : (Int) -> B,
  overlay : (B, B) -> B,
  connect : (B, B) -> B,
) -> B {
  fn go(g : Graph) -> B {
    match g {
      Empty => empty
      Vertex(v) => vertex(v)
      Overlay(a, b) => overlay(go(a), go(b))
      Connect(a, b) => connect(go(a), go(b))
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
  graph : Graph,
  empty : B,
  vertex : (Int) -> B,
  overlay : (B, B) -> B,
  connect : (B, B) -> B,
) -> B {
  letrec go = fn(g : Graph) -> B {
    match g {
      Empty => empty
      Vertex(v) => vertex(v)
      Overlay(a, b) => overlay(go(a), go(b))
      Connect(a, b) => connect(go(a), go(b))
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
  graph : Graph,
  empty : B,
  vertex : (Int) -> B,
  overlay : (B, B) -> B,
  connect : (B, B) -> B,
) -> B {
  letrec go = fn(g : Graph, k : (B) -> B) -> B {
    match g {
      Empty => k(empty)
      Vertex(v) => k(vertex(v))
      Overlay(a, b) => go(a, fn(ra) { go(b, fn(rb) { k(overlay(ra, rb)) }) })
      Connect(a, b) => go(a, fn(ra) { go(b, fn(rb) { k(connect(ra, rb)) }) })
    }
  }
  go(graph, fn(x) { x })
}

///|
pub fn Graph::to_adjacency_map_cps(self : Graph) -> AdjacencyMap {
  foldg_cps(
    self,
    AdjacencyMap::empty(),
    fn(v) { AdjacencyMap::vertex(v) },
    fn(a, b) { a.overlay(b) },
    fn(a, b) { a.connect(b) },
  )
}

///|
pub fn Graph::to_adjacency_map_inner_fn(self : Graph) -> AdjacencyMap {
  foldg_inner_fn(
    self,
    AdjacencyMap::empty(),
    fn(v) { AdjacencyMap::vertex(v) },
    fn(a, b) { a.overlay(b) },
    fn(a, b) { a.connect(b) },
  )
}

///|
pub fn Graph::to_adjacency_map_letrec(self : Graph) -> AdjacencyMap {
  foldg_letrec(
    self,
    AdjacencyMap::empty(),
    fn(v) { AdjacencyMap::vertex(v) },
    fn(a, b) { a.overlay(b) },
    fn(a, b) { a.connect(b) },
  )
}
