///|
/// Strongly connected components via Kosaraju's algorithm (iterative).
/// Returns components in reverse topological order of the component DAG.
/// SCC is an AdjacencyMap method because it requires transpose.
pub fn AdjacencyMap::scc(self : AdjacencyMap) -> Array[Array[Int]] {
  // Step 1: Iterative DFS on original graph, record finish order
  let visited : Map[Int, Bool] = Map::new()
  let finish_order : Array[Int] = []
  // Use explicit stack with frame tracking for post-order
  // Stack entries: (vertex, successor_index)
  // When all successors processed, vertex goes to finish_order
  self.adjacency.each(fn(root, _) {
    if visited.get(root) == Some(true) {
      return
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
        // Advance successor index
        stack[top_idx] = (v, si + 1)
        let w = succs[si]
        if visited.get(w) != Some(true) {
          visited[w] = true
          stack.push((w, 0))
        }
      } else {
        // All successors processed — record finish
        let _ = stack.unsafe_pop()
        finish_order.push(v)
      }
    }
  })
  // Step 2: Transpose the graph
  let transposed = self.transpose()
  // Step 3: Iterative DFS on transposed graph in reverse finish order
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
