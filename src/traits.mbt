///|
/// # DirectedGraph — the observation layer
///
/// This trait defines the minimal interface for observing a directed graph.
/// Implement `for_each_vertex` and `for_each_successor` to get every
/// algorithm in the library for free. `vertex_count` and `has_vertex`
/// have O(V) defaults that you can override for O(1) performance.
///
/// ## Contract
///
/// `for_each_vertex` must yield each vertex exactly once. The default
/// `vertex_count` and `has_vertex` depend on this invariant.
///
/// ## Design decisions
///
/// **Fixed vertex type (Int):**
/// MoonBit traits cannot have type parameters or associated types, so we
/// fix vertices to `Int`. If your vertices are strings or custom IDs,
/// map them to `Int` indices.
///
/// **Callback-style iteration:**
/// Without associated types, we cannot return `Iter[Vertex]` from a trait
/// method. Instead, we push vertices into `(Int) -> Unit` callbacks (CPS).
/// This avoids allocating intermediate collections.
///
/// **Two required + two defaulted:**
/// `for_each_vertex` and `for_each_successor` are irreducible — they
/// can't be derived from anything else. `vertex_count` and `has_vertex`
/// can be derived by iterating vertices, so they have O(V) defaults.
/// Override them for O(1) when your data structure supports it.
///
/// ## Example: minimal implementation (2 methods)
///
/// ```
/// struct MyGraph { edges : Array[Array[Int]] }
///
/// impl DirectedGraph for MyGraph with for_each_vertex(self, f) {
///   for i in 0..<self.edges.length() { f(i) }
/// }
/// impl DirectedGraph for MyGraph with for_each_successor(self, v, f) {
///   for w in self.edges[v] { f(w) }
/// }
/// // vertex_count and has_vertex work via defaults.
/// // Override for O(1): impl DirectedGraph for MyGraph with vertex_count(self) { self.edges.length() }
/// ```
pub(open) trait DirectedGraph {
  for_each_vertex(Self, (Int) -> Unit) -> Unit
  for_each_successor(Self, Int, (Int) -> Unit) -> Unit
  vertex_count(Self) -> Int = _
  has_vertex(Self, Int) -> Bool = _
}

///|
/// Default vertex_count: O(V) — counts by iterating all vertices.
/// Override for O(1) if your type tracks vertex count directly.
impl DirectedGraph with vertex_count(self) {
  let mut n = 0
  DirectedGraph::for_each_vertex(self, fn(_) { n = n + 1 })
  n
}

///|
/// Default has_vertex: O(V) — scans all vertices looking for a match.
/// Override for O(1) if your type supports constant-time membership.
impl DirectedGraph with has_vertex(self, v) {
  let mut found = false
  DirectedGraph::for_each_vertex(self, fn(u) { if u == v { found = true } })
  found
}
