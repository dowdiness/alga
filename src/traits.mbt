///|
/// # DirectedGraph — the observation layer
///
/// This trait defines the minimal interface for observing a directed graph.
/// Implement `iter` and `successors` to get every algorithm in the library
/// for free. `each_vertex`, `each_successor`, `vertex_count`, and `has_vertex`
/// all have defaults derived from the two required methods.
///
/// ## Contract
///
/// `iter` must yield each vertex exactly once.
///
/// ## Design decisions
///
/// **Fixed vertex type (Int):**
/// MoonBit traits cannot have type parameters or associated types, so we
/// fix vertices to `Int`. If your vertices are strings or custom IDs,
/// map them to `Int` indices.
///
/// **Iter-based iteration:**
/// `iter` and `successors` return `Iter[Int]` — MoonBit's external iterator
/// (`struct Iter[X](fn() -> X?)`). Pull-based: call `.next()` for one vertex
/// at a time. Enables pause/resume (Tarjan SCC), early termination
/// (`has_vertex` short-circuits via `Iter::contains`), and lazy composition.
///
/// **Callback methods defaulted:**
/// `each_vertex` and `each_successor` delegate to `Iter::each` for push-style
/// algorithms (DFS, BFS, toposort).
///
/// ## Example: minimal implementation (2 methods)
///
/// ```
/// struct MyGraph { edges : Array[Array[Int]] }
///
/// impl DirectedGraph for MyGraph with iter(self) {
///   (0).until(self.edges.length())
/// }
/// impl DirectedGraph for MyGraph with successors(self, v) {
///   self.edges[v].iter()
/// }
/// // vertex_count, has_vertex, each_vertex, each_successor all work via defaults.
/// ```
pub(open) trait DirectedGraph {
  iter(Self) -> Iter[Int]
  successors(Self, Int) -> Iter[Int]
  each_vertex(Self, (Int) -> Unit) -> Unit = _
  each_successor(Self, Int, (Int) -> Unit) -> Unit = _
  vertex_count(Self) -> Int = _
  has_vertex(Self, Int) -> Bool = _
}

///|
/// Default each_vertex: delegates to `Iter::each`.
/// Uses trait-qualified `DirectedGraph::iter(self)` to guarantee correct dispatch.
impl DirectedGraph with each_vertex(self, f) {
  DirectedGraph::iter(self).each(f)
}

///|
/// Default each_successor: delegates to `Iter::each`.
impl DirectedGraph with each_successor(self, v, f) {
  DirectedGraph::successors(self, v).each(f)
}

///|
/// Default vertex_count: O(V) — counts via `Iter::count`.
/// Override for O(1) if your type tracks vertex count directly.
impl DirectedGraph with vertex_count(self) {
  DirectedGraph::iter(self).count()
}

///|
/// Default has_vertex: uses `Iter::contains` which short-circuits on match.
/// O(1) best case, O(V) worst case. Override for O(1) if your type
/// supports constant-time membership.
impl DirectedGraph with has_vertex(self, v) {
  DirectedGraph::iter(self).contains(v)
}

///|
/// # Predecessors — reverse-direction observation capability
///
/// Types that can efficiently answer "which vertices point to v?"
/// implement this trait alongside `DirectedGraph`. No default
/// implementation is provided — an O(V+E) scan default would be
/// a performance trap.
///
/// Used by `Reversed[G]` to swap `successors` and `predecessors`.
pub(open) trait Predecessors {
  predecessors(Self, Int) -> Iter[Int]
}
