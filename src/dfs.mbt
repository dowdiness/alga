///|
/// # Depth-First Search (DFS)
///
/// DFS explores a graph by going as deep as possible along each branch
/// before backtracking. It's the foundation of many graph algorithms
/// (cycle detection, topological sort, SCC, path finding).
///
/// ## Implementation: iterative with explicit stack
///
/// Classic DFS is recursive, but recursion depth equals the longest path
/// in the graph — which can blow the call stack on deep graphs (we hit
/// this at ~10K vertices in WASM). The iterative version uses an explicit
/// `Array` as a stack, making it safe for arbitrarily deep graphs.
///
/// Successors are pushed directly from the `for_each_successor` callback
/// then reversed in place (mark-and-reverse), so the first successor is
/// processed first (matching recursive DFS order) without per-vertex
/// temporary array allocation.
///
/// ## The fold pattern
///
/// `dfs_fold` is a generalization: instead of collecting vertices into a
/// list, it folds an accumulator over visited vertices. The callback
/// returns `(new_acc, should_continue)` — returning `false` for
/// `should_continue` stops traversal early (useful for "find first" queries).
///
/// `reachable` is the common case — collects all reachable vertices.

///|
/// DFS fold over vertices reachable from `start`.
///
/// Visits each vertex exactly once. `f` receives the current accumulator
/// and the visited vertex, and returns `(new_acc, should_continue)`.
/// When `should_continue` is `false`, traversal halts immediately.
///
/// Time: O(V + E) where V and E are the reachable vertices and edges.
pub fn[G : DirectedGraph, Acc] dfs_fold(
  graph : G,
  start : Int,
  init : Acc,
  f : (Acc, Int) -> (Acc, Bool),
) -> Acc {
  let visited : Map[Int, Bool] = Map::new()
  let stack : Array[Int] = [start]
  let mut acc = init
  while stack.length() > 0 {
    let v = stack.unsafe_pop()
    if visited.get(v) == Some(true) {
      continue
    }
    visited[v] = true
    let result = f(acc, v)
    acc = result.0
    if !result.1 {
      break
    }
    // Push successors directly, then reverse in place so first successor
    // is on top of the stack. Avoids per-vertex temporary array allocation.
    let mark = stack.length()
    G::for_each_successor(graph, v, fn(w) {
      if visited.get(w) != Some(true) {
        stack.push(w)
      }
    })
    let mut lo = mark
    let mut hi = stack.length() - 1
    while lo < hi {
      let tmp = stack[lo]
      stack[lo] = stack[hi]
      stack[hi] = tmp
      lo = lo + 1
      hi = hi - 1
    }
  }
  acc
}

///|
/// All vertices reachable from `start`, in DFS pre-order.
pub fn[G : DirectedGraph] reachable(graph : G, start : Int) -> Array[Int] {
  dfs_fold(graph, start, [], fn(arr, v) {
    arr.push(v)
    (arr, true)
  })
}

///|
/// Multi-source DFS fold over vertices reachable from any vertex in `starts`.
///
/// Seeds the DFS stack with all start vertices instead of one, enabling
/// frontier-based traversal — e.g. in CRDTs where an event-graph-walker
/// walks from a set of frontier LVs, not a single root.
///
/// Start vertices are pushed in reverse order so the first valid start
/// is processed first (matching natural traversal order).
///
/// Invalid starts (not in the graph) are silently skipped. Duplicate starts
/// are visited only once.
///
/// Time: O(V + E) where V and E are the reachable vertices and edges.
/// Seed validation calls `has_vertex` — override it for O(1) on custom types.
pub fn[G : DirectedGraph, Acc] dfs_fold_multi(
  graph : G,
  starts : Array[Int],
  init : Acc,
  f : (Acc, Int) -> (Acc, Bool),
) -> Acc {
  let visited : Map[Int, Bool] = Map::new()
  let stack : Array[Int] = []
  // Seed in reverse order so starts[0] ends up on top of the stack (LIFO).
  // Use visited for dedup — seeds are pushed but NOT marked as visited,
  // so the main loop's visited-check + fold runs normally for each seed.
  // After seeding, clear visited so the main loop starts fresh.
  let seen : @hashset.HashSet[Int] = @hashset.new()
  let mut i = starts.length() - 1
  while i >= 0 {
    let s = starts[i]
    if !seen.contains(s) && G::has_vertex(graph, s) {
      seen.add(s)
      stack.push(s)
    }
    i = i - 1
  }
  let mut acc = init
  while stack.length() > 0 {
    let v = stack.unsafe_pop()
    if visited.contains(v) {
      continue
    }
    visited[v] = true
    let result = f(acc, v)
    acc = result.0
    if !result.1 {
      break
    }
    // Push successors directly, then reverse in place so first successor
    // is on top of the stack. Avoids per-vertex temporary array allocation.
    let mark = stack.length()
    G::for_each_successor(graph, v, fn(w) {
      if !visited.contains(w) {
        stack.push(w)
      }
    })
    let mut lo = mark
    let mut hi = stack.length() - 1
    while lo < hi {
      let tmp = stack[lo]
      stack[lo] = stack[hi]
      stack[hi] = tmp
      lo = lo + 1
      hi = hi - 1
    }
  }
  acc
}

///|
/// All vertices reachable from any vertex in `starts`, in DFS pre-order.
///
/// Convenience wrapper around `dfs_fold_multi` — collects all reachable
/// vertices into an array. Same relationship as `reachable` to `dfs_fold`.
pub fn[G : DirectedGraph] reachable_multi(
  graph : G,
  starts : Array[Int],
) -> Array[Int] {
  dfs_fold_multi(graph, starts, [], fn(arr, v) {
    arr.push(v)
    (arr, true)
  })
}
