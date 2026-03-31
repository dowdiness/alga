///|
/// # Degree functions — outdegree and indegree
///
/// Generic degree queries over `DirectedGraph`.
///
/// `outdegree(g, v)` counts the number of outgoing edges from vertex `v`
/// by iterating `for_each_successor`. O(degree(v)).
///
/// `indegree(g, v)` counts the number of incoming edges to vertex `v`
/// by scanning all vertices and their successors. O(V + E) because
/// the `DirectedGraph` trait has no predecessor index — every vertex's
/// successor list must be checked.

///|
/// Number of outgoing edges from vertex `v`.
///
/// Returns 0 if `v` is not in the graph or has no successors.
///
/// Time: O(degree(v)) — counts via `for_each_successor`.
pub fn[G : DirectedGraph] outdegree(graph : G, v : Int) -> Int {
  let mut count = 0
  G::for_each_successor(graph, v, fn(_w) { count = count + 1 })
  count
}

///|
/// Number of incoming edges to vertex `v`.
///
/// Returns 0 if `v` has no predecessors (or is not in the graph).
///
/// Time: O(V + E) — scans every vertex's successor list because
/// the `DirectedGraph` trait does not expose predecessor information.
pub fn[G : DirectedGraph] indegree(graph : G, v : Int) -> Int {
  let mut count = 0
  G::for_each_vertex(graph, fn(u) {
    G::for_each_successor(graph, u, fn(w) { if w == v { count = count + 1 } })
  })
  count
}
