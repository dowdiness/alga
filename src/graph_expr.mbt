///|
/// # Graph — the free algebra for directed graphs
///
/// `Graph` is the "initial" (tagged) encoding of algebraic graphs.
/// It represents graph expressions as a syntax tree that can be
/// inspected, transformed, and eventually interpreted.
///
/// The four constructors correspond exactly to the four `GraphSym`
/// operations:
///
/// - `Empty` — the empty graph
/// - `Vertex(v)` — a single vertex
/// - `Overlay(a, b)` — union of two graphs
/// - `Connect(a, b)` — overlay + cross-edges from a to b
///
/// ## Why a syntax tree?
///
/// Unlike `AdjacencyMap` which eagerly computes the adjacency structure,
/// `Graph` preserves the *construction history*. This enables:
///
/// - **Transformations** before evaluation: `gmap`, `bind`, `induce`
///   work on the expression tree without materializing intermediate graphs
/// - **Multiple interpretations**: the same `Graph` can be folded into
///   an `AdjacencyMap`, a vertex count, an edge list, or a visualization
/// - **Deferred evaluation**: build the expression cheaply, evaluate once
///
/// ## The catamorphism: foldg
///
/// `foldg` is the universal interpreter — it replaces each constructor
/// with a user-supplied function and recursively evaluates the tree.
/// Every derived operation (`to_adjacency_map`, `gmap`, `bind`, `induce`)
/// is implemented via `foldg`.
///
/// In category theory, `foldg` is the unique homomorphism from the free
/// algebra (Graph) to any other algebra satisfying the graph axioms.
///
/// ## Performance note
///
/// `foldg` on a deeply nested expression (e.g., `path([1..1000])`)
/// creates O(n) intermediate results. For large graphs, build an
/// `AdjacencyMap` directly with `from_edges` instead of going through
/// `Graph` expressions.
pub(all) enum Graph {
  Empty
  Vertex(Int)
  Overlay(Graph, Graph)
  Connect(Graph, Graph)
}

///|
/// Work stack item for iterative foldg.
priv enum FoldWork {
  Eval(Graph)
  DoOverlay
  DoConnect
}

///|
/// Catamorphism: fold a Graph expression into any type B.
///
/// Replaces `Empty` with `empty`, `Vertex(v)` with `vertex(v)`,
/// `Overlay(a, b)` with `overlay(fold(a), fold(b))`, and
/// `Connect(a, b)` with `connect(fold(a), fold(b))`.
///
/// This is the universal evaluator — every graph interpretation
/// (to_adjacency_map, vertex_count, gmap, etc.) can be expressed as
/// a single call to `foldg` with appropriate replacement functions.
///
/// **Performance warning:** When folding into `AdjacencyMap`, each
/// `Overlay` or `Connect` node creates an intermediate `AdjacencyMap`
/// and merges it, resulting in O(n^2) total work for a chain of n
/// operations (e.g., `path([1..1000])`). For large graphs, prefer
/// `AdjacencyMap::from_edges` which builds the representation directly
/// in O(E) time.
pub fn[B] foldg(
  graph : Graph,
  empty : B,
  vertex : (Int) -> B,
  overlay : (B, B) -> B,
  connect : (B, B) -> B,
) -> B {
  match graph {
    Empty => empty
    Vertex(v) => vertex(v)
    Overlay(a, b) =>
      overlay(
        foldg(a, empty, vertex, overlay, connect),
        foldg(b, empty, vertex, overlay, connect),
      )
    Connect(a, b) =>
      connect(
        foldg(a, empty, vertex, overlay, connect),
        foldg(b, empty, vertex, overlay, connect),
      )
  }
}

///|
/// Convert a Graph expression to AdjacencyMap.
///
/// This is THE bridge between the construction layer (Graph/GraphSym)
/// and the observation layer (DirectedGraph). Once converted, you can
/// run any algorithm (toposort, DFS, SCC, etc.) on the result.
///
/// Uses direct edge collection via `foldg_iter`: walks the expression
/// tree iteratively (stack-safe for arbitrarily deep expressions) to
/// collect all vertices and edges, then builds the AdjacencyMap once.
///
/// For `path` and `star` expressions this is dramatically faster than
/// pairwise AdjacencyMap merging (77–127x measured). The vertex-set
/// arrays still grow via `append` during the fold, so total work is
/// O(E + n * avg_vertex_set_size) where n is the expression tree size.
/// For typical expressions (path, star, edges) this is effectively
/// linear; for pathological cases (deeply nested cliques) the
/// cross-product in Connect dominates.
pub fn Graph::to_adjacency_map(self : Graph) -> AdjacencyMap {
  let all_edges : Array[(Int, Int)] = []
  let all_vertices : Array[Int] = []
  // Fold where each subtree returns its vertex set (Array[Int]).
  // Connect accumulates cross-edges as a side effect.
  // Uses foldg_iter for stack safety on deep expressions.
  let _vertex_set : Array[Int] = foldg_iter(
    self,
    [],
    fn(v) {
      all_vertices.push(v)
      [v]
    },
    fn(a, b) {
      a.append(b)
      a
    },
    fn(a, b) {
      for u in a {
        for v in b {
          all_edges.push((u, v))
        }
      }
      a.append(b)
      a
    },
  )
  let g = AdjacencyMap::from_edges(all_edges)
  // Register isolated vertices (Vertex nodes with no edges)
  for v in all_vertices {
    if not(g.adjacency.contains(v)) {
      g.adjacency[v] = []
    }
  }
  g
}

///|
/// Iterative catamorphism over Graph expressions.
/// Same semantics as recursive `foldg`, but uses an explicit stack
/// so it handles arbitrarily deep expressions without stack overflow.
///
/// For lightweight folds (B = Int), this is ~2.8x slower than recursive
/// `foldg` due to work-item enum allocation. For heavyweight folds
/// (B = AdjacencyMap), the overhead is negligible. Use this when the
/// expression tree may be deeper than the call stack allows (~10K on WASM).
pub fn[B] foldg_iter(
  graph : Graph,
  empty : B,
  vertex : (Int) -> B,
  overlay : (B, B) -> B,
  connect : (B, B) -> B,
) -> B {
  let work : Array[FoldWork] = [Eval(graph)]
  let results : Array[B] = []
  while work.length() > 0 {
    match work.unsafe_pop() {
      Eval(g) =>
        match g {
          Empty => results.push(empty)
          Vertex(v) => results.push(vertex(v))
          Overlay(a, b) => {
            work.push(DoOverlay)
            work.push(Eval(b))
            work.push(Eval(a))
          }
          Connect(a, b) => {
            work.push(DoConnect)
            work.push(Eval(b))
            work.push(Eval(a))
          }
        }
      DoOverlay => {
        let b = results.unsafe_pop()
        let a = results.unsafe_pop()
        results.push(overlay(a, b))
      }
      DoConnect => {
        let b = results.unsafe_pop()
        let a = results.unsafe_pop()
        results.push(connect(a, b))
      }
    }
  }
  results.unsafe_pop()
}

///|
/// Transform every vertex label. Structure is preserved.
///
/// `gmap(f)` applies `f` to every `Vertex(v)`, producing `Vertex(f(v))`.
/// Overlay/Connect structure is unchanged.
pub fn Graph::gmap(self : Graph, f : (Int) -> Int) -> Graph {
  foldg(self, Empty, fn(v) { Vertex(f(v)) }, fn(a, b) { Overlay(a, b) }, fn(
    a,
    b,
  ) {
    Connect(a, b)
  })
}

///|
/// Monadic bind: replace each vertex with a subgraph.
///
/// `bind(f)` substitutes every `Vertex(v)` with `f(v)` (which returns
/// a Graph). This is the graph analogue of `flatMap` / `>>=`.
///
/// Example: `edge(1, 2).bind(fn(v) { path([v*10, v*10+1]) })`
/// expands vertex 1 into path(10, 11) and vertex 2 into path(20, 21),
/// preserving the connect structure between them.
pub fn Graph::bind(self : Graph, f : (Int) -> Graph) -> Graph {
  foldg(self, Empty, f, fn(a, b) { Overlay(a, b) }, fn(a, b) { Connect(a, b) })
}

///|
/// Subgraph induced by a predicate: keep only vertices where `pred(v)` is true.
/// Edges between removed vertices are also removed.
pub fn Graph::induce(self : Graph, pred : (Int) -> Bool) -> Graph {
  self.bind(fn(v) { if pred(v) { Vertex(v) } else { Empty } })
}

///|
/// Remove a single vertex (and all its edges).
pub fn Graph::remove_vertex(self : Graph, target : Int) -> Graph {
  self.induce(fn(v) { v != target })
}

// === Construction combinators ===
//
// These build common graph patterns from vertex arrays.
// All use the for..in loop with accumulator variables for
// functional-style folding without mutable state.

///|
/// Overlay of isolated vertices: {v1} + {v2} + ... (no edges).
pub fn Graph::vertices(vs : Array[Int]) -> Graph {
  if vs.length() == 0 {
    return Empty
  }
  for v in vs[1:]; acc = Vertex(vs[0]) {
    continue Overlay(acc, Vertex(v))
  } nobreak {
    acc
  }
}

///|
/// Graph from explicit edge list.
pub fn Graph::edges(es : Array[(Int, Int)]) -> Graph {
  if es.length() == 0 {
    return Empty
  }
  for e in es[1:]; acc = Connect(Vertex(es[0].0), Vertex(es[0].1)) {
    continue Overlay(acc, Connect(Vertex(e.0), Vertex(e.1)))
  } nobreak {
    acc
  }
}

///|
/// Complete directed graph: every vertex has an edge to every later vertex.
///
/// `clique([1, 2, 3])` = connect(connect(vertex(1), vertex(2)), vertex(3))
/// = edges [(1,2), (1,3), (2,3)]
pub fn Graph::clique(vs : Array[Int]) -> Graph {
  if vs.length() == 0 {
    return Empty
  }
  for v in vs[1:]; acc = Vertex(vs[0]) {
    continue Connect(acc, Vertex(v))
  } nobreak {
    acc
  }
}

///|
/// Star graph: center → each satellite. No edges between satellites.
pub fn Graph::star(center : Int, satellites : Array[Int]) -> Graph {
  if satellites.length() == 0 {
    return Vertex(center)
  }
  Connect(Vertex(center), Graph::vertices(satellites))
}

///|
/// Path: v1 → v2 → ... → vn (linear chain).
pub fn Graph::path(vs : Array[Int]) -> Graph {
  if vs.length() == 0 {
    return Empty
  }
  if vs.length() == 1 {
    return Vertex(vs[0])
  }
  for v in vs[1:]; acc = Vertex(vs[0]), prev = vs[0] {
    continue Overlay(acc, Connect(Vertex(prev), Vertex(v))), v
  } nobreak {
    acc
  }
}

///|
/// Circuit: path that loops back — v1 → v2 → ... → vn → v1.
pub fn Graph::circuit(vs : Array[Int]) -> Graph {
  if vs.length() == 0 {
    return Empty
  }
  if vs.length() == 1 {
    return Connect(Vertex(vs[0]), Vertex(vs[0]))
  }
  let p = Graph::path(vs)
  Overlay(p, Connect(Vertex(vs[vs.length() - 1]), Vertex(vs[0])))
}

///|
/// Graph also implements GraphSym — it IS the free algebra.
/// The constructors are the interpretation.
pub impl GraphSym for Graph with empty() {
  Empty
}

///|
pub impl GraphSym for Graph with vertex(v) {
  Vertex(v)
}

///|
pub impl GraphSym for Graph with overlay(a, b) {
  Overlay(a, b)
}

///|
pub impl GraphSym for Graph with connect(a, b) {
  Connect(a, b)
}
