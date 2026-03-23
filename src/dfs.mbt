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
/// Successors are pushed in reverse order so the first successor is
/// processed first (matching the order of recursive DFS).
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
    if not(result.1) {
      break
    }
    // Push successors in reverse so the first successor is on top of the stack
    let succs : Array[Int] = []
    G::for_each_successor(graph, v, fn(w) {
      if visited.get(w) != Some(true) {
        succs.push(w)
      }
    })
    for i in (succs.length() - 1)>=..0 {
      stack.push(succs[i])
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
