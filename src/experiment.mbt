// Experiment: Map[Int, Bool] vs HashSet[Int] vs Array[Bool] vs
// FixedArray[Bool] vs generation counter vs bitset for visited sets
//
// Hypothesis: Replacing tree-map visited sets with flat data structures
// will reduce indirection overhead, per the CST Transform report finding
// that "indirection is not free in wasm-gc."
//
// Round 2: Array[Bool] won 2.4x over Map. Now testing three alternatives
// against Array[Bool]:
//   - FixedArray[Bool]: raw fixed buffer, no capacity/resize overhead
//   - Generation counter: FixedArray[Int] reused across calls, O(1) reset
//   - Bitset: packed bits in FixedArray[Int], 32x less memory

// === Helpers ===

///|
fn[G : DirectedGraph] max_vertex_id(graph : G) -> Int {
  let mut max_id = 0
  G::for_each_vertex(graph, fn(v) { if v > max_id { max_id = v } })
  max_id
}

///|
fn AdjacencyMap::max_vertex(self : AdjacencyMap) -> Int {
  let mut max_id = 0
  for k, _ in self.adjacency {
    if k > max_id {
      max_id = k
    }
  }
  max_id
}

// === Bitset helpers ===

///|
fn bitset_size(max_id : Int) -> Int {
  max_id / 32 + 1
}

///|
fn bitset_set(words : FixedArray[Int], v : Int) -> Unit {
  let idx = v / 32
  let bit = v % 32
  words[idx] = words[idx] | (1 << bit)
}

///|
fn bitset_test(words : FixedArray[Int], v : Int) -> Bool {
  let idx = v / 32
  let bit = v % 32
  (words[idx] & (1 << bit)) != 0
}

// ============================================================
// DFS — HashSet variant
// ============================================================

///|
pub fn[G : DirectedGraph, Acc] dfs_fold_hashset(
  graph : G,
  start : Int,
  init : Acc,
  f : (Acc, Int) -> (Acc, Bool),
) -> Acc {
  let visited : @hashset.HashSet[Int] = @hashset.new()
  let stack : Array[Int] = [start]
  let mut acc = init
  while stack.length() > 0 {
    let v = stack.unsafe_pop()
    if visited.contains(v) {
      continue
    }
    visited.add(v)
    let result = f(acc, v)
    acc = result.0
    if not(result.1) {
      break
    }
    let succs : Array[Int] = []
    G::for_each_successor(graph, v, fn(w) {
      if not(visited.contains(w)) {
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
pub fn[G : DirectedGraph] reachable_hashset(
  graph : G,
  start : Int,
) -> Array[Int] {
  dfs_fold_hashset(graph, start, [], fn(arr, v) {
    arr.push(v)
    (arr, true)
  })
}

// ============================================================
// DFS — Array[Bool] variant
// ============================================================

///|
pub fn[G : DirectedGraph, Acc] dfs_fold_array(
  graph : G,
  start : Int,
  init : Acc,
  f : (Acc, Int) -> (Acc, Bool),
) -> Acc {
  let max_id = max_vertex_id(graph)
  let visited = Array::make(max_id + 1, false)
  let stack : Array[Int] = [start]
  let mut acc = init
  while stack.length() > 0 {
    let v = stack.unsafe_pop()
    if visited[v] {
      continue
    }
    visited[v] = true
    let result = f(acc, v)
    acc = result.0
    if not(result.1) {
      break
    }
    let succs : Array[Int] = []
    G::for_each_successor(graph, v, fn(w) {
      if not(visited[w]) {
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
pub fn[G : DirectedGraph] reachable_array(graph : G, start : Int) -> Array[Int] {
  dfs_fold_array(graph, start, [], fn(arr, v) {
    arr.push(v)
    (arr, true)
  })
}

// ============================================================
// BFS — HashSet variant
// ============================================================

///|
pub fn[G : DirectedGraph, Acc] bfs_fold_hashset(
  graph : G,
  start : Int,
  init : Acc,
  f : (Acc, Int) -> (Acc, Bool),
) -> Acc {
  let visited : @hashset.HashSet[Int] = @hashset.new()
  let queue : Array[Int] = [start]
  visited.add(start)
  let mut acc = init
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    let result = f(acc, v)
    acc = result.0
    if not(result.1) {
      break
    }
    G::for_each_successor(graph, v, fn(w) {
      if not(visited.contains(w)) {
        visited.add(w)
        queue.push(w)
      }
    })
  }
  acc
}

// ============================================================
// BFS — Array[Bool] variant
// ============================================================

///|
pub fn[G : DirectedGraph, Acc] bfs_fold_array(
  graph : G,
  start : Int,
  init : Acc,
  f : (Acc, Int) -> (Acc, Bool),
) -> Acc {
  let max_id = max_vertex_id(graph)
  let visited = Array::make(max_id + 1, false)
  let queue : Array[Int] = [start]
  visited[start] = true
  let mut acc = init
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    let result = f(acc, v)
    acc = result.0
    if not(result.1) {
      break
    }
    G::for_each_successor(graph, v, fn(w) {
      if not(visited[w]) {
        visited[w] = true
        queue.push(w)
      }
    })
  }
  acc
}

// ============================================================
// Toposort — HashSet variant (uses HashMap for in_degree)
// ============================================================

///|
pub fn[G : DirectedGraph] toposort_hashset(graph : G) -> Array[Int]? {
  let in_degree : @hashmap.HashMap[Int, Int] = @hashmap.new()
  G::for_each_vertex(graph, fn(v) { in_degree[v] = 0 })
  G::for_each_vertex(graph, fn(v) {
    G::for_each_successor(graph, v, fn(w) {
      match in_degree.get(w) {
        Some(n) => in_degree[w] = n + 1
        None => in_degree[w] = 1
      }
    })
  })
  let queue : Array[Int] = []
  in_degree.each(fn(v, d) { if d == 0 { queue.push(v) } })
  let result : Array[Int] = []
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    result.push(v)
    G::for_each_successor(graph, v, fn(w) {
      match in_degree.get(w) {
        Some(n) => {
          in_degree[w] = n - 1
          if n - 1 == 0 {
            queue.push(w)
          }
        }
        None => ()
      }
    })
  }
  let vc = G::vertex_count(graph)
  if result.length() == vc {
    Some(result)
  } else {
    None
  }
}

// ============================================================
// Toposort — Array[Int] variant (in_degree as flat array)
// ============================================================

///|
pub fn[G : DirectedGraph] toposort_array(graph : G) -> Array[Int]? {
  let max_id = max_vertex_id(graph)
  // -1 sentinel = "not a vertex"
  let in_degree = Array::make(max_id + 1, -1)
  G::for_each_vertex(graph, fn(v) { in_degree[v] = 0 })
  G::for_each_vertex(graph, fn(v) {
    G::for_each_successor(graph, v, fn(w) { in_degree[w] = in_degree[w] + 1 })
  })
  let queue : Array[Int] = []
  for v = 0; v <= max_id; v = v + 1 {
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
    G::for_each_successor(graph, v, fn(w) {
      in_degree[w] = in_degree[w] - 1
      if in_degree[w] == 0 {
        queue.push(w)
      }
    })
  }
  let vc = G::vertex_count(graph)
  if result.length() == vc {
    Some(result)
  } else {
    None
  }
}

///|
pub fn[G : DirectedGraph] has_cycle_hashset(graph : G) -> Bool {
  toposort_hashset(graph) is None
}

///|
pub fn[G : DirectedGraph] has_cycle_array(graph : G) -> Bool {
  toposort_array(graph) is None
}

// ============================================================
// SCC — HashSet variant (visited sets only)
// ============================================================

///|
pub fn AdjacencyMap::scc_hashset(self : AdjacencyMap) -> Array[Array[Int]] {
  let visited : @hashset.HashSet[Int] = @hashset.new()
  let finish_order : Array[Int] = []
  for root, _ in self.adjacency {
    if visited.contains(root) {
      continue
    }
    let stack : Array[(Int, Int)] = [(root, 0)]
    visited.add(root)
    while stack.length() > 0 {
      let top_idx = stack.length() - 1
      let v = stack[top_idx].0
      let si = stack[top_idx].1
      let succs = match self.adjacency.get(v) {
        Some(s) => s
        None => []
      }
      if si < succs.length() {
        stack[top_idx] = (v, si + 1)
        let w = succs[si]
        if not(visited.contains(w)) {
          visited.add(w)
          stack.push((w, 0))
        }
      } else {
        let _ = stack.unsafe_pop()
        finish_order.push(v)
      }
    }
  }
  let transposed = self.transpose()
  let visited2 : @hashset.HashSet[Int] = @hashset.new()
  let components : Array[Array[Int]] = []
  for i in (finish_order.length() - 1)>=..0 {
    let root = finish_order[i]
    if visited2.contains(root) {
      continue
    }
    let component : Array[Int] = []
    let stack : Array[Int] = [root]
    visited2.add(root)
    while stack.length() > 0 {
      let v = stack.unsafe_pop()
      component.push(v)
      match transposed.adjacency.get(v) {
        Some(succs) =>
          for j in (succs.length() - 1)>=..0 {
            let w = succs[j]
            if not(visited2.contains(w)) {
              visited2.add(w)
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

// ============================================================
// SCC — Array[Bool] variant (visited sets only)
// ============================================================

///|
pub fn AdjacencyMap::scc_array(self : AdjacencyMap) -> Array[Array[Int]] {
  let max_id = self.max_vertex()
  let visited = Array::make(max_id + 1, false)
  let finish_order : Array[Int] = []
  for root, _ in self.adjacency {
    if visited[root] {
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
  let transposed = self.transpose()
  let visited2 = Array::make(max_id + 1, false)
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
      match transposed.adjacency.get(v) {
        Some(succs) =>
          for j in (succs.length() - 1)>=..0 {
            let w = succs[j]
            if not(visited2[w]) {
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

// ============================================================
// DFS — FixedArray[Bool] variant
// ============================================================

///|
pub fn[G : DirectedGraph, Acc] dfs_fold_fixedarray(
  graph : G,
  start : Int,
  init : Acc,
  f : (Acc, Int) -> (Acc, Bool),
) -> Acc {
  let max_id = max_vertex_id(graph)
  let visited = FixedArray::make(max_id + 1, false)
  let stack : Array[Int] = [start]
  let mut acc = init
  while stack.length() > 0 {
    let v = stack.unsafe_pop()
    if visited[v] {
      continue
    }
    visited[v] = true
    let result = f(acc, v)
    acc = result.0
    if not(result.1) {
      break
    }
    let succs : Array[Int] = []
    G::for_each_successor(graph, v, fn(w) {
      if not(visited[w]) {
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
pub fn[G : DirectedGraph] reachable_fixedarray(
  graph : G,
  start : Int,
) -> Array[Int] {
  dfs_fold_fixedarray(graph, start, [], fn(arr, v) {
    arr.push(v)
    (arr, true)
  })
}

// ============================================================
// DFS — Generation counter variant (amortized O(1) reset)
// ============================================================

///|
pub fn[G : DirectedGraph] reachable_gen(
  graph : G,
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
    let succs : Array[Int] = []
    G::for_each_successor(graph, v, fn(w) {
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
// DFS — Bitset variant (packed bits, 32x less memory)
// ============================================================

///|
pub fn[G : DirectedGraph] reachable_bitset(
  graph : G,
  start : Int,
) -> Array[Int] {
  let max_id = max_vertex_id(graph)
  let words = FixedArray::make(bitset_size(max_id), 0)
  let stack : Array[Int] = [start]
  let result : Array[Int] = []
  while stack.length() > 0 {
    let v = stack.unsafe_pop()
    if bitset_test(words, v) {
      continue
    }
    bitset_set(words, v)
    result.push(v)
    let succs : Array[Int] = []
    G::for_each_successor(graph, v, fn(w) {
      if not(bitset_test(words, w)) {
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
// BFS — FixedArray[Bool] variant
// ============================================================

///|
pub fn[G : DirectedGraph, Acc] bfs_fold_fixedarray(
  graph : G,
  start : Int,
  init : Acc,
  f : (Acc, Int) -> (Acc, Bool),
) -> Acc {
  let max_id = max_vertex_id(graph)
  let visited = FixedArray::make(max_id + 1, false)
  let queue : Array[Int] = [start]
  visited[start] = true
  let mut acc = init
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    let result = f(acc, v)
    acc = result.0
    if not(result.1) {
      break
    }
    G::for_each_successor(graph, v, fn(w) {
      if not(visited[w]) {
        visited[w] = true
        queue.push(w)
      }
    })
  }
  acc
}

// ============================================================
// BFS — Generation counter variant
// ============================================================

///|
pub fn[G : DirectedGraph, Acc] bfs_fold_gen(
  graph : G,
  start : Int,
  init : Acc,
  f : (Acc, Int) -> (Acc, Bool),
  visited : FixedArray[Int],
  gen : Int,
) -> Acc {
  let queue : Array[Int] = [start]
  visited[start] = gen
  let mut acc = init
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    let result = f(acc, v)
    acc = result.0
    if not(result.1) {
      break
    }
    G::for_each_successor(graph, v, fn(w) {
      if visited[w] != gen {
        visited[w] = gen
        queue.push(w)
      }
    })
  }
  acc
}

// ============================================================
// BFS — Bitset variant
// ============================================================

///|
pub fn[G : DirectedGraph, Acc] bfs_fold_bitset(
  graph : G,
  start : Int,
  init : Acc,
  f : (Acc, Int) -> (Acc, Bool),
) -> Acc {
  let max_id = max_vertex_id(graph)
  let words = FixedArray::make(bitset_size(max_id), 0)
  let queue : Array[Int] = [start]
  bitset_set(words, start)
  let mut acc = init
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    let result = f(acc, v)
    acc = result.0
    if not(result.1) {
      break
    }
    G::for_each_successor(graph, v, fn(w) {
      if not(bitset_test(words, w)) {
        bitset_set(words, w)
        queue.push(w)
      }
    })
  }
  acc
}

// ============================================================
// SCC — FixedArray[Bool] variant
// ============================================================

///|
pub fn AdjacencyMap::scc_fixedarray(self : AdjacencyMap) -> Array[Array[Int]] {
  let max_id = self.max_vertex()
  let visited = FixedArray::make(max_id + 1, false)
  let finish_order : Array[Int] = []
  for root, _ in self.adjacency {
    if visited[root] {
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
  let transposed = self.transpose()
  let visited2 = FixedArray::make(max_id + 1, false)
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
      match transposed.adjacency.get(v) {
        Some(succs) =>
          for j in (succs.length() - 1)>=..0 {
            let w = succs[j]
            if not(visited2[w]) {
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

// ============================================================
// SCC — Generation counter variant
// ============================================================

///|
pub fn AdjacencyMap::scc_gen(
  self : AdjacencyMap,
  visited_buf : FixedArray[Int],
  gen : Int,
) -> Array[Array[Int]] {
  let gen1 = gen
  let gen2 = gen + 1
  let finish_order : Array[Int] = []
  for root, _ in self.adjacency {
    if visited_buf[root] == gen1 {
      continue
    }
    let stack : Array[(Int, Int)] = [(root, 0)]
    visited_buf[root] = gen1
    while stack.length() > 0 {
      let top_idx = stack.length() - 1
      let v = stack[top_idx].0
      let si = stack[top_idx].1
      let succs = match self.adjacency.get(v) {
        Some(s) => s
        None => []
      }
      if si < succs.length() {
        stack[top_idx] = (v, si + 1)
        let w = succs[si]
        if visited_buf[w] != gen1 {
          visited_buf[w] = gen1
          stack.push((w, 0))
        }
      } else {
        let _ = stack.unsafe_pop()
        finish_order.push(v)
      }
    }
  }
  let transposed = self.transpose()
  let components : Array[Array[Int]] = []
  for i in (finish_order.length() - 1)>=..0 {
    let root = finish_order[i]
    if visited_buf[root] == gen2 {
      continue
    }
    let component : Array[Int] = []
    let stack : Array[Int] = [root]
    visited_buf[root] = gen2
    while stack.length() > 0 {
      let v = stack.unsafe_pop()
      component.push(v)
      match transposed.adjacency.get(v) {
        Some(succs) =>
          for j in (succs.length() - 1)>=..0 {
            let w = succs[j]
            if visited_buf[w] != gen2 {
              visited_buf[w] = gen2
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

// ============================================================
// SCC — Bitset variant
// ============================================================

///|
pub fn AdjacencyMap::scc_bitset(self : AdjacencyMap) -> Array[Array[Int]] {
  let max_id = self.max_vertex()
  let sz = bitset_size(max_id)
  let visited = FixedArray::make(sz, 0)
  let finish_order : Array[Int] = []
  for root, _ in self.adjacency {
    if bitset_test(visited, root) {
      continue
    }
    let stack : Array[(Int, Int)] = [(root, 0)]
    bitset_set(visited, root)
    while stack.length() > 0 {
      let top_idx = stack.length() - 1
      let v = stack[top_idx].0
      let si = stack[top_idx].1
      let succs = match self.adjacency.get(v) {
        Some(s) => s
        None => []
      }
      if si < succs.length() {
        stack[top_idx] = (v, si + 1)
        let w = succs[si]
        if not(bitset_test(visited, w)) {
          bitset_set(visited, w)
          stack.push((w, 0))
        }
      } else {
        let _ = stack.unsafe_pop()
        finish_order.push(v)
      }
    }
  }
  let transposed = self.transpose()
  let visited2 = FixedArray::make(sz, 0)
  let components : Array[Array[Int]] = []
  for i in (finish_order.length() - 1)>=..0 {
    let root = finish_order[i]
    if bitset_test(visited2, root) {
      continue
    }
    let component : Array[Int] = []
    let stack : Array[Int] = [root]
    bitset_set(visited2, root)
    while stack.length() > 0 {
      let v = stack.unsafe_pop()
      component.push(v)
      match transposed.adjacency.get(v) {
        Some(succs) =>
          for j in (succs.length() - 1)>=..0 {
            let w = succs[j]
            if not(bitset_test(visited2, w)) {
              bitset_set(visited2, w)
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
