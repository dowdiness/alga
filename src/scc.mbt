///|
/// # Strongly Connected Components (Kosaraju's Algorithm)
///
/// A strongly connected component (SCC) is a maximal set of vertices
/// where every vertex is reachable from every other vertex. In other
/// words, vertices u and v are in the same SCC if and only if there
/// exist paths u → ... → v and v → ... → u.
///
/// ## Algorithm: Kosaraju-Sharir (1978)
///
/// Kosaraju's algorithm finds all SCCs in two DFS passes:
///
/// 1. **Forward DFS**: Run DFS on the original graph, recording the
///    order in which vertices *finish* (all successors explored).
///    This is the "reverse post-order" — vertices that finish later
///    are closer to the DAG roots of the component graph.
///
/// 2. **Transpose**: Reverse all edges. If u → v existed, now v → u.
///
/// 3. **Backward DFS**: Process vertices in reverse finish order,
///    running DFS on the transposed graph. Each DFS tree discovered
///    this way is exactly one SCC.
///
/// The key insight: if vertex u finishes after v in the forward DFS,
/// and u can reach v in the transposed graph, then u and v must be
/// in the same SCC (because reachability in the transpose means
/// reverse-reachability in the original).
///
/// ## Why AdjacencyMap, not DirectedGraph?
///
/// SCC requires `transpose()`, which inverts all edges. Not every data
/// structure can efficiently compute its transpose — it's not part of
/// the `DirectedGraph` observation trait. Since `AdjacencyMap` stores
/// the full adjacency structure, it can compute transpose in O(V + E).
///
/// ## Implementation: fully iterative
///
/// Both DFS passes use explicit stacks instead of recursion.
/// The forward DFS uses `(vertex, successor_index)` frames to simulate
/// the recursive call stack and correctly record post-order finish times.
///
/// Time: O(V + E). Space: O(V + E) for the transposed graph.

///|
/// Compute all strongly connected components.
///
/// Returns components in reverse topological order of the component DAG
/// (if A's component has an edge to B's component, A's component appears
/// first in the result).
pub fn AdjacencyMap::scc(self : AdjacencyMap) -> Array[Array[Int]] {
  // Pass 1: Forward DFS — record finish order
  // Uses (vertex, successor_index) stack frames to track post-order
  let visited : Map[Int, Bool] = Map::new()
  let finish_order : Array[Int] = []
  for root, _ in self.adjacency {
    if visited.get(root) == Some(true) {
      continue
    }
    let stack : Array[(Int, Int)] = [(root, 0)]
    visited[root] = true
    while stack.length() > 0 {
      let top_idx = stack.length() - 1
      let v = stack[top_idx].0
      let si = stack[top_idx].1
      let succs = match self.adjacency.get(v) {
        Some(s) => s
        None => []
      }
      if si < succs.length() {
        // Advance to next successor
        stack[top_idx] = (v, si + 1)
        let w = succs[si]
        if visited.get(w) != Some(true) {
          visited[w] = true
          stack.push((w, 0))
        }
      } else {
        // All successors explored — record finish time
        let _ = stack.unsafe_pop()
        finish_order.push(v)
      }
    }
  }
  // Pass 2: Transpose the graph (reverse all edges)
  let transposed = self.transpose()
  // Pass 3: Backward DFS in reverse finish order
  // Each DFS tree on the transposed graph is one SCC
  let visited2 : Map[Int, Bool] = Map::new()
  let components : Array[Array[Int]] = []
  for i in (finish_order.length() - 1)>=..0 {
    let root = finish_order[i]
    if visited2.get(root) == Some(true) {
      continue
    }
    let component : Array[Int] = []
    let stack : Array[Int] = [root]
    visited2[root] = true
    while stack.length() > 0 {
      let v = stack.unsafe_pop()
      component.push(v)
      match transposed.adjacency.get(v) {
        Some(succs) =>
          for j in (succs.length() - 1)>=..0 {
            let w = succs[j]
            if visited2.get(w) != Some(true) {
              visited2[w] = true
              stack.push(w)
            }
          }
        None => ()
      }
    }
    components.push(component)
  }
  components
}
