///|
/// DFS fold. Visits each reachable vertex exactly once (iterative).
/// f returns (new_accumulator, should_continue).
/// If should_continue is false, traversal stops early.
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
    // Collect successors, then push in reverse so first successor is on top
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
/// All vertices reachable from start, in DFS order.
pub fn[G : DirectedGraph] reachable(graph : G, start : Int) -> Array[Int] {
  dfs_fold(graph, start, [], fn(arr, v) {
    arr.push(v)
    (arr, true)
  })
}
