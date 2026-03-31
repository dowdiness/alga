///|
/// # Topological Sort (Kahn's Algorithm)
///
/// A topological ordering of a directed acyclic graph (DAG) is a linear
/// ordering of vertices such that for every edge u → v, u comes before v.
/// If the graph has a cycle, no topological ordering exists.
///
/// ## Algorithm: Kahn (1962)
///
/// 1. Compute in-degree (number of incoming edges) for each vertex.
/// 2. Enqueue all vertices with in-degree 0 (no dependencies).
/// 3. Repeatedly dequeue a vertex, add it to the result, and decrement
///    the in-degree of all its successors. When a successor's in-degree
///    reaches 0, enqueue it.
/// 4. If the result contains all vertices, return it. Otherwise, the
///    remaining vertices form a cycle — return None.
///
/// This is equivalent to repeatedly removing "ready" nodes — nodes with
/// no unsatisfied dependencies. It's the same principle behind build
/// systems (Make), package managers (dependency resolution), and
/// spreadsheet recalculation order.
///
/// ## Cycle detection
///
/// Kahn's algorithm naturally detects cycles: if the result is shorter
/// than the vertex count, some vertices could never reach in-degree 0
/// because they're in a cycle. `has_cycle` is simply
/// `toposort(graph) is None`.
///
/// Time: O(V + E). Space: O(V).

///|
/// Topological sort via Kahn's algorithm.
/// Returns `Some(ordering)` for DAGs, `None` if the graph has a cycle.
///
/// **Warning:** Self-loops (edges v -> v) are treated as cycles and cause
/// this function to return `None`. If your graph may contain self-loops
/// that you want to ignore, call `remove_self_loops()` first.
pub fn[G : DirectedGraph] toposort(graph : G) -> Array[Int]? {
  // Step 1: Compute in-degrees
  let in_degree : Map[Int, Int] = Map::new()
  G::for_each_vertex(graph, fn(v) { in_degree[v] = 0 })
  G::for_each_vertex(graph, fn(v) {
    G::for_each_successor(graph, v, fn(w) {
      let d = match in_degree.get(w) {
        Some(n) => n
        None => 0
      }
      in_degree[w] = d + 1
    })
  })
  // Step 2: Seed queue with zero-in-degree vertices
  let queue : Array[Int] = []
  for v, d in in_degree {
    if d == 0 {
      queue.push(v)
    }
  }
  // Step 3: Process queue, building topological order
  let result : Array[Int] = []
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    result.push(v)
    G::for_each_successor(graph, v, fn(w) {
      let d = match in_degree.get(w) {
        Some(n) => n
        None => 0
      }
      in_degree[w] = d - 1
      if d - 1 == 0 {
        queue.push(w)
      }
    })
  }
  // Step 4: Check completeness — incomplete means a cycle exists
  let vc = G::vertex_count(graph)
  if result.length() == vc {
    Some(result)
  } else {
    None
  }
}

///|
/// Returns true if the graph contains a directed cycle.
/// A self-loop (v → v) counts as a cycle.
pub fn[G : DirectedGraph] has_cycle(graph : G) -> Bool {
  toposort(graph) is None
}

///|
/// Topological sort over the induced subgraph of `vertices`.
///
/// Only edges where both endpoints are in `vertices` are considered.
/// Returns `Some(ordering)` if the induced subgraph is a DAG, `None`
/// if it contains a cycle. Returns `Some([])` for an empty vertex set.
///
/// Time: O(V_sub + E_sub). Space: O(V_sub).
pub fn[G : DirectedGraph] toposort_subset(
  graph : G,
  vertices : Array[Int],
) -> Array[Int]? {
  // Build membership set (deduplicates) for O(1) lookup
  let member : @hashset.HashSet[Int] = @hashset.new()
  for v in vertices {
    member.add(v)
  }
  let n = member.size()
  if n == 0 {
    return Some([])
  }
  // Compute in-degrees within the induced subgraph
  let in_degree : @hashmap.HashMap[Int, Int] = @hashmap.new()
  member.each(fn(v) {
    G::for_each_successor(graph, v, fn(w) {
      if member.contains(w) {
        match in_degree.get(w) {
          Some(d) => in_degree[w] = d + 1
          None => in_degree[w] = 1
        }
      }
    })
  })
  // Seed queue with zero-in-degree subset vertices
  let queue : Array[Int] = []
  member.each(fn(v) { if not(in_degree.contains(v)) { queue.push(v) } })
  // Process queue
  let result : Array[Int] = []
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    result.push(v)
    G::for_each_successor(graph, v, fn(w) {
      if member.contains(w) {
        match in_degree.get(w) {
          Some(d) => {
            in_degree[w] = d - 1
            if d - 1 == 0 {
              queue.push(w)
            }
          }
          None => ()
        }
      }
    })
  }
  if result.length() == n {
    Some(result)
  } else {
    None
  }
}
