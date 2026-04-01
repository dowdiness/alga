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

///|
/// # Condensation — DAG of strongly connected components
///
/// Condensation collapses each strongly connected component (SCC) into a
/// single vertex, producing a directed acyclic graph (DAG). The result is
/// always a DAG because any cycle in the condensed graph would imply that
/// the involved components should have been merged into a single SCC.
///
/// ## Returns
///
/// A tuple `(condensed_dag, vertex_to_component)`:
///
/// - `condensed_dag`: An `AdjacencyMap` whose vertices are component IDs
///   `0..k-1`, where `k` is the number of SCCs. There is an edge from
///   component `i` to component `j` if and only if some vertex in
///   component `i` has an edge to some vertex in component `j` in the
///   original graph.
///
/// - `vertex_to_component`: A `Map[Int, Int]` mapping each original vertex
///   to its component ID. Component IDs correspond to the indices of the
///   arrays returned by `scc()` (Kosaraju's reverse-finish order).
///
/// ## Use cases
///
/// Condensation reduces cyclic graphs to DAGs, enabling topological
/// analysis (toposort, longest path, dependency ordering) on graphs
/// that would otherwise contain cycles. For example, in a module
/// dependency graph, mutually-recursive modules form SCCs that can be
/// collapsed to reason about the overall build order.
///
/// Time: O(V + E). Space: O(V + E).
pub fn AdjacencyMap::condensation(
  self : AdjacencyMap,
) -> (AdjacencyMap, Map[Int, Int]) {
  let components = self.scc()
  // Build vertex → component_id mapping
  let vertex_to_component : Map[Int, Int] = Map::new()
  for i, component in components {
    for v in component {
      vertex_to_component[v] = i
    }
  }
  // Collect inter-component edges. Duplicates are fine — from_edges deduplicates.
  let num_components = components.length()
  let condensed_edges : Array[(Int, Int)] = []
  for u, succs in self.adjacency {
    let cu = match vertex_to_component.get(u) {
      Some(c) => c
      None => continue
    }
    for v in succs {
      let cv = match vertex_to_component.get(v) {
        Some(c) => c
        None => continue
      }
      if cu != cv {
        condensed_edges.push((cu, cv))
      }
    }
  }
  // Build the condensed AdjacencyMap — from_edges handles edge dedup internally
  let dag = AdjacencyMap::from_edges(condensed_edges)
  // Add isolated components (no inter-component edges) as vertices
  for i = 0; i < num_components; i = i + 1 {
    if !dag.adjacency.contains(i) {
      dag.adjacency[i] = []
    }
  }
  (dag, vertex_to_component)
}

///|
/// # Strongly Connected Components (Tarjan's Algorithm)
///
/// Generic over `DirectedGraph` — works on any graph type without requiring
/// `transpose`. Single DFS pass using lowlink values.
///
/// ## Algorithm: Tarjan (1972)
///
/// Performs one DFS, maintaining for each vertex:
/// - `index`: discovery time (monotonically increasing)
/// - `lowlink`: smallest index reachable from the subtree rooted at this vertex
///
/// When all successors of vertex v are processed, if `lowlink[v] == index[v]`,
/// then v is the root of an SCC — pop the SCC stack until v to extract it.
///
/// ## Implementation: fully iterative
///
/// Uses `Iter[Int].next()` for pause/resume of successor iteration. Each stack
/// frame stores `(vertex, Iter[Int])` — the iterator carries its position via
/// closure state. This avoids recursion (safe for 10K+ vertices in WASM) and
/// avoids collecting successors into temp arrays.
///
/// ## Output ordering
///
/// Produces SCCs in **forward topological order**: if component A has an edge
/// to component B, B appears before A in the result. This is the opposite of
/// Kosaraju's `scc()` which produces reverse topological order.
///
/// Time: O(V + E). Space: O(V) — no transpose allocation.
pub fn[G : DirectedGraph] tarjan_scc(graph : G) -> Array[Array[Int]] {
  let index_map : Map[Int, Int] = Map::new()
  let lowlink_map : Map[Int, Int] = Map::new()
  let on_stack : Map[Int, Bool] = Map::new()
  let scc_stack : Array[Int] = []
  let result : Array[Array[Int]] = []
  let mut counter = 0
  // Stack frames: (vertex, successor_iterator)
  // lowlink/index stored in maps — need updates after "recursive" returns.
  let frames : Array[(Int, Iter[Int])] = []
  for root in G::iter(graph) {
    if index_map.contains(root) {
      continue
    }
    // Initialize root
    index_map[root] = counter
    lowlink_map[root] = counter
    counter = counter + 1
    on_stack[root] = true
    scc_stack.push(root)
    frames.push((root, G::successors(graph, root)))
    while frames.length() > 0 {
      let top_idx = frames.length() - 1
      let v = frames[top_idx].0
      let iter = frames[top_idx].1
      match iter.next() {
        Some(w) =>
          if !index_map.contains(w) {
            // Tree edge: "recurse" into w
            index_map[w] = counter
            lowlink_map[w] = counter
            counter = counter + 1
            on_stack[w] = true
            scc_stack.push(w)
            frames.push((w, G::successors(graph, w)))
          } else if on_stack.get(w) == Some(true) {
            // Back edge: update lowlink
            let v_low = match lowlink_map.get(v) {
              Some(l) => l
              None => 0
            }
            let w_idx = match index_map.get(w) {
              Some(i) => i
              None => 0
            }
            if w_idx < v_low {
              lowlink_map[v] = w_idx
            }
          }
        None => {
          // All successors processed — check if v is SCC root
          let v_low = match lowlink_map.get(v) {
            Some(l) => l
            None => 0
          }
          let v_idx = match index_map.get(v) {
            Some(i) => i
            None => 0
          }
          if v_low == v_idx {
            // v is root of an SCC — pop scc_stack until v
            let component : Array[Int] = []
            while true {
              let w = scc_stack.unsafe_pop()
              on_stack[w] = false
              component.push(w)
              if w == v {
                break
              }
            }
            result.push(component)
          }
          // Pop this frame and propagate lowlink to parent
          let _ = frames.unsafe_pop()
          if frames.length() > 0 {
            let parent_v = frames[frames.length() - 1].0
            let parent_low = match lowlink_map.get(parent_v) {
              Some(l) => l
              None => 0
            }
            if v_low < parent_low {
              lowlink_map[parent_v] = v_low
            }
          }
        }
      }
    }
  }
  result
}
