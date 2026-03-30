// Experiment 3: Flat adjacency — experiment-only variants.
// DenseGraph type and its core methods are now in dense_graph.mbt.

// ============================================================
// DFS via DirectedGraph trait (uses for_each_successor callback)
// ============================================================

///|
/// DFS reachable on DenseGraph via the generic DirectedGraph trait.
/// Uses GenCounter for visited set.
/// This goes through for_each_successor callback AND uses a temp array
/// to collect successors (same pattern as original dfs_fold).
pub fn DenseGraph::reachable_trait(
  self : DenseGraph,
  start : Int,
  visited : FixedArray[Int],
  gen : Int,
) -> Array[Int] {
  reachable_gen(self, start, visited, gen)
}

// ============================================================
// DFS via callback but NO temp array (pushes directly to stack)
// ============================================================

///|
/// Same for_each_successor callback, but pushes directly to stack
/// instead of collecting into a temp array first. Isolates the temp
/// array allocation cost from the closure call_ref cost.
/// Note: visits successors in forward order (not reversed like dfs_fold).
pub fn DenseGraph::reachable_callback_no_temp(
  self : DenseGraph,
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
    DenseGraph::for_each_successor(self, v, fn(w) {
      if visited[w] != gen {
        stack.push(w)
      }
    })
  }
  result
}

// ============================================================
// DFS with direct iteration (no callback, no trait)
// ============================================================

///|
/// DFS reachable with direct array access — no for_each_successor callback,
/// no DirectedGraph trait dispatch. Measures the closure overhead floor.
pub fn DenseGraph::reachable_direct(
  self : DenseGraph,
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
    let succs = self.successors[v]
    for i in (succs.length() - 1)>=..0 {
      let w = succs[i]
      if visited[w] != gen {
        stack.push(w)
      }
    }
  }
  result
}

// ============================================================
// DFS — mark-and-reverse: push to stack, reverse in place
// ============================================================

///|
/// Push successors directly to stack via callback, then reverse the
/// newly-pushed section in place. Zero per-vertex allocation.
/// Preserves DFS visit order (first successor visited first).
pub fn DenseGraph::reachable_mark_rev(
  self : DenseGraph,
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
    // Mark position before pushing successors
    let mark = stack.length()
    DenseGraph::for_each_successor(self, v, fn(w) {
      if visited[w] != gen {
        stack.push(w)
      }
    })
    // Reverse newly-pushed section so first successor is on top
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

// ============================================================
// DFS — reusable buffer: move temp array outside loop
// ============================================================

///|
/// Same callback pattern, but reuses a single temp array across iterations.
/// Avoids per-vertex allocation; only the first iteration allocates.
pub fn DenseGraph::reachable_reuse_buf(
  self : DenseGraph,
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
    // Clear and reuse the buffer
    while succs.length() > 0 {
      let _ = succs.unsafe_pop()
    }
    DenseGraph::for_each_successor(self, v, fn(w) {
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

// ============================================================
// BFS via DirectedGraph trait (callback)
// ============================================================

///|
pub fn DenseGraph::bfs_count_trait(
  self : DenseGraph,
  start : Int,
  visited : FixedArray[Int],
  gen : Int,
) -> Int {
  bfs_fold_gen(self, start, 0, fn(acc, _v) { (acc + 1, true) }, visited, gen)
}

// ============================================================
// BFS with direct iteration (no callback)
// ============================================================

///|
pub fn DenseGraph::bfs_count_direct(
  self : DenseGraph,
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
    let succs = self.successors[v]
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

// ============================================================
// Toposort via DirectedGraph trait (callback)
// ============================================================

///|
pub fn DenseGraph::toposort_trait(self : DenseGraph) -> Array[Int]? {
  toposort_array(self)
}

// ============================================================
// Toposort with direct iteration (no callback)
// ============================================================

///|
pub fn DenseGraph::toposort_direct(self : DenseGraph) -> Array[Int]? {
  let n = self.successors.length()
  let in_degree = Array::make(n, 0)
  for u = 0; u < n; u = u + 1 {
    for v in self.successors[u] {
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
    for w in self.successors[v] {
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

// ============================================================
// SCC via DenseGraph (flat visited + flat adjacency + flat transpose)
// ============================================================

///|
pub fn DenseGraph::scc_direct(self : DenseGraph) -> Array[Array[Int]] {
  let n = self.successors.length()
  let visited = FixedArray::make(n, false)
  let finish_order : Array[Int] = []
  // Pass 1: forward DFS
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
      let succs = self.successors[v]
      if si < succs.length() {
        stack[top_idx] = (v, si + 1)
        let w = succs[si]
        if not(visited[w]) {
          visited[w] = true
          stack.push((w, 0))
        }
      } else {
        let _ = stack.unsafe_pop()
        finish_order.push(v)
      }
    }
  }
  // Pass 2: transpose (flat → flat, no Map)
  let transposed = self.transpose()
  // Pass 3: backward DFS
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
        if not(visited2[w]) {
          visited2[w] = true
          stack.push(w)
        }
      }
    }
    components.push(component)
  }
  components
}
