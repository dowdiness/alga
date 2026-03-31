///|
/// # DirectedGraph — the observation layer
///
/// This trait defines the minimal interface for observing a directed graph.
/// Any data structure that implements these three methods gains access to
/// every algorithm in the library (DFS, BFS, toposort, subset toposort, cycle detection, etc.)
/// via trait-bounded generic functions.
///
/// ## Design decisions
///
/// **Fixed vertex type (Int):**
/// MoonBit traits cannot have type parameters or associated types, so we
/// fix vertices to `Int`. This is the "fixed-type projection" pattern —
/// the same approach used in algebraic graph libraries when the host
/// language's type system doesn't support type families.
/// If your vertices are strings or custom IDs, map them to `Int` indices.
///
/// **Callback-style iteration:**
/// Without associated types, we cannot return `Iter[Vertex]` from a trait
/// method. Instead, we push vertices into `(Int) -> Unit` callbacks (CPS).
/// This avoids allocating intermediate collections and lets the caller
/// control traversal (e.g., early termination via mutable flags).
///
/// **Three methods, no more:**
/// `vertex_count`, `for_each_vertex`, and `for_each_successor` are the
/// minimal observation interface. Everything else (in-degree, edge count,
/// predecessor queries) can be derived from these three. Keeping the trait
/// small makes it easy to implement for new data structures.
///
/// ## Example implementation
///
/// ```
/// struct MyGraph { edges : Array[Array[Int]] }
///
/// impl DirectedGraph for MyGraph with vertex_count(self) {
///   self.edges.length()
/// }
/// impl DirectedGraph for MyGraph with for_each_vertex(self, f) {
///   for i in 0..<self.edges.length() { f(i) }
/// }
/// impl DirectedGraph for MyGraph with for_each_successor(self, v, f) {
///   for w in self.edges[v] { f(w) }
/// }
/// ```
///
/// Once implemented, you can call `toposort(my_graph)`,
/// `toposort_subset(my_graph, vertices)`, `reachable(my_graph, 0)`,
/// etc. — no modifications to the library needed.
pub(open) trait DirectedGraph {
  vertex_count(Self) -> Int
  for_each_vertex(Self, (Int) -> Unit) -> Unit
  for_each_successor(Self, Int, (Int) -> Unit) -> Unit
}
