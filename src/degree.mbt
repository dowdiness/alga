///|
/// # Degree functions — outdegree and indegree
///
/// In a directed graph, every vertex has two degree measures:
///
/// - **outdegree** = number of edges going OUT (how many successors)
/// - **indegree** = number of edges coming IN (how many predecessors)
///
/// These are fundamentally asymmetric in cost because the `DirectedGraph`
/// trait stores adjacency in the forward direction only (vertex → successors).
///
/// `outdegree` is cheap — just count one vertex's successors: O(degree(v)).
/// `indegree` is expensive — must scan ALL vertices' successor lists to
/// find who points to v: O(V + E). This is an inherent cost of
/// forward-only adjacency; a reverse index would make it O(1) but
/// would double storage and complicate the trait interface.
///
/// For algorithms that need indegree for ALL vertices (like Kahn's
/// toposort), it's more efficient to compute a full indegree array
/// in one O(V+E) pass rather than calling `indegree(g, v)` per vertex
/// (which would be O(V*(V+E))).

///|
/// Number of outgoing edges from vertex `v`.
///
/// Returns 0 if `v` is not in the graph or has no successors.
/// Self-loops count: if v→v exists, it contributes 1 to outdegree.
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
/// Self-loops count: if v→v exists, it contributes 1 to indegree.
///
/// Time: O(V + E) — must scan every vertex's successor list because
/// the `DirectedGraph` trait only exposes forward adjacency.
/// For bulk indegree computation, prefer a single-pass array approach.
pub fn[G : DirectedGraph] indegree(graph : G, v : Int) -> Int {
  let mut count = 0
  G::for_each_vertex(graph, fn(u) {
    G::for_each_successor(graph, u, fn(w) { if w == v { count = count + 1 } })
  })
  count
}
