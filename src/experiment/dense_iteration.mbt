// Experiment 3: Flat adjacency — experiment-only variants.
// DenseGraph type and its core methods are now in dense_graph.mbt.

///|
// DFS via DirectedGraph trait (uses for_each_successor callback)
pub fn reachable_trait(
  graph : @alga.DenseGraph,
  start : Int,
  visited : FixedArray[Int],
  gen : Int,
) -> Array[Int] {
  reachable_gen(graph, start, visited, gen)
}

///|
// DFS via callback but NO temp array
pub fn reachable_callback_no_temp(
  graph : @alga.DenseGraph,
  start : Int,
  visited : FixedArray[Int],
  gen : Int,
) -> Array[Int] {
  let stack : Array[Int] = [start]
  let result : Array[Int] = []
  while stack.length() > 0 {
    let v = stack.unsafe_pop()
    if visited[v] == gen {
      continue
    }
    visited[v] = gen
    result.push(v)
    @alga.DirectedGraph::for_each_successor(graph, v, fn(w) {
      if visited[w] != gen {
        stack.push(w)
      }
    })
  }
  result
}

///|
// DFS with direct iteration (no callback, no trait)
pub fn reachable_direct(
  graph : @alga.DenseGraph,
  start : Int,
  visited : FixedArray[Int],
  gen : Int,
) -> Array[Int] {
  let stack : Array[Int] = [start]
  let result : Array[Int] = []
  while stack.length() > 0 {
    let v = stack.unsafe_pop()
    if visited[v] == gen {
      continue
    }
    visited[v] = gen
    result.push(v)
    let succs = graph.successors[v]
    for i in (succs.length() - 1)>=..0 {
      let w = succs[i]
      if visited[w] != gen {
        stack.push(w)
      }
    }
  }
  result
}

///|
// DFS — mark-and-reverse
pub fn reachable_mark_rev(
  graph : @alga.DenseGraph,
  start : Int,
  visited : FixedArray[Int],
  gen : Int,
) -> Array[Int] {
  let stack : Array[Int] = [start]
  let result : Array[Int] = []
  while stack.length() > 0 {
    let v = stack.unsafe_pop()
    if visited[v] == gen {
      continue
    }
    visited[v] = gen
    result.push(v)
    let mark = stack.length()
    @alga.DirectedGraph::for_each_successor(graph, v, fn(w) {
      if visited[w] != gen {
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
  result
}

///|
// DFS — reusable buffer
pub fn reachable_reuse_buf(
  graph : @alga.DenseGraph,
  start : Int,
  visited : FixedArray[Int],
  gen : Int,
) -> Array[Int] {
  let stack : Array[Int] = [start]
  let result : Array[Int] = []
  let succs : Array[Int] = []
  while stack.length() > 0 {
    let v = stack.unsafe_pop()
    if visited[v] == gen {
      continue
    }
    visited[v] = gen
    result.push(v)
    while succs.length() > 0 {
      let _ = succs.unsafe_pop()
    }
    @alga.DirectedGraph::for_each_successor(graph, v, fn(w) {
      if visited[w] != gen {
        succs.push(w)
      }
    })
    for i in (succs.length() - 1)>=..0 {
      stack.push(succs[i])
    }
  }
  result
}

///|
// BFS via DirectedGraph trait
pub fn bfs_count_trait(
  graph : @alga.DenseGraph,
  start : Int,
  visited : FixedArray[Int],
  gen : Int,
) -> Int {
  bfs_fold_gen(graph, start, 0, fn(acc, _v) { (acc + 1, true) }, visited, gen)
}

///|
// BFS with direct iteration
pub fn bfs_count_direct(
  graph : @alga.DenseGraph,
  start : Int,
  visited : FixedArray[Int],
  gen : Int,
) -> Int {
  let queue : Array[Int] = [start]
  visited[start] = gen
  let mut count = 0
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    count = count + 1
    let succs = graph.successors[v]
    for i = 0; i < succs.length(); i = i + 1 {
      let w = succs[i]
      if visited[w] != gen {
        visited[w] = gen
        queue.push(w)
      }
    }
  }
  count
}

///|
// Toposort via DirectedGraph trait
pub fn toposort_trait(graph : @alga.DenseGraph) -> Array[Int]? {
  toposort_array(graph)
}

///|
// Toposort with direct iteration
pub fn toposort_direct(graph : @alga.DenseGraph) -> Array[Int]? {
  let n = graph.successors.length()
  let in_degree = Array::make(n, 0)
  for u = 0; u < n; u = u + 1 {
    for v in graph.successors[u] {
      in_degree[v] = in_degree[v] + 1
    }
  }
  let queue : Array[Int] = []
  for v = 0; v < n; v = v + 1 {
    if in_degree[v] == 0 {
      queue.push(v)
    }
  }
  let result : Array[Int] = []
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    result.push(v)
    for w in graph.successors[v] {
      in_degree[w] = in_degree[w] - 1
      if in_degree[w] == 0 {
        queue.push(w)
      }
    }
  }
  if result.length() == n {
    Some(result)
  } else {
    None
  }
}

///|
// SCC via DenseGraph (flat visited + flat adjacency + flat transpose)
pub fn scc_direct(graph : @alga.DenseGraph) -> Array[Array[Int]] {
  let n = graph.successors.length()
  let visited = FixedArray::make(n, false)
  let finish_order : Array[Int] = []
  for root = 0; root < n; root = root + 1 {
    if visited[root] {
      continue
    }
    let stack : Array[(Int, Int)] = [(root, 0)]
    visited[root] = true
    while stack.length() > 0 {
      let top_idx = stack.length() - 1
      let v = stack[top_idx].0
      let si = stack[top_idx].1
      let succs = graph.successors[v]
      if si < succs.length() {
        stack[top_idx] = (v, si + 1)
        let w = succs[si]
        if !visited[w] {
          visited[w] = true
          stack.push((w, 0))
        }
      } else {
        let _ = stack.unsafe_pop()
        finish_order.push(v)
      }
    }
  }
  let transposed = graph.transpose()
  let visited2 = FixedArray::make(n, false)
  let components : Array[Array[Int]] = []
  for i in (finish_order.length() - 1)>=..0 {
    let root = finish_order[i]
    if visited2[root] {
      continue
    }
    let component : Array[Int] = []
    let stack : Array[Int] = [root]
    visited2[root] = true
    while stack.length() > 0 {
      let v = stack.unsafe_pop()
      component.push(v)
      let succs = transposed.successors[v]
      for j in (succs.length() - 1)>=..0 {
        let w = succs[j]
        if !visited2[w] {
          visited2[w] = true
          stack.push(w)
        }
      }
    }
    components.push(component)
  }
  components
}
