///|
pub struct AdjacencyMap {
  adjacency : Map[Int, Array[Int]]
}

///|
pub fn AdjacencyMap::empty() -> AdjacencyMap {
  { adjacency: Map::new() }
}

///|
pub fn AdjacencyMap::vertex(v : Int) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  m[v] = []
  { adjacency: m }
}

///|
pub fn AdjacencyMap::edge(u : Int, v : Int) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  m[u] = [v]
  if not(m.contains(u) && u == v) {
    if not(m.contains(v)) {
      m[v] = []
    }
  }
  { adjacency: m }
}

///|
pub fn AdjacencyMap::from_edges(edges : Array[(Int, Int)]) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  for edge in edges {
    let u = edge.0
    let v = edge.1
    match m.get(u) {
      Some(arr) => if not(arr.contains(v)) { arr.push(v) }
      None => m[u] = [v]
    }
    if not(m.contains(v)) {
      m[v] = []
    }
  }
  { adjacency: m }
}

///|
pub fn array_contains(arr : Array[Int], val : Int) -> Bool {
  arr.contains(val)
}

///|
pub fn AdjacencyMap::overlay(
  self : AdjacencyMap,
  other : AdjacencyMap,
) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  for k, v in self.adjacency {
    m[k] = v.copy()
  }
  for k, v in other.adjacency {
    match m.get(k) {
      Some(existing) =>
        for elem in v {
          if not(existing.contains(elem)) {
            existing.push(elem)
          }
        }
      None => m[k] = v.copy()
    }
  }
  { adjacency: m }
}

///|
pub fn AdjacencyMap::connect(
  self : AdjacencyMap,
  other : AdjacencyMap,
) -> AdjacencyMap {
  let base = self.overlay(other)
  let m = base.adjacency
  let other_vertices : Array[Int] = []
  for k, _ in other.adjacency {
    other_vertices.push(k)
  }
  for u, _ in self.adjacency {
    let current = match m.get(u) {
      Some(s) => s
      None => []
    }
    for ov in other_vertices {
      if not(current.contains(ov)) {
        current.push(ov)
      }
    }
    m[u] = current
  }
  { adjacency: m }
}

///|
pub fn AdjacencyMap::vertex_list(self : AdjacencyMap) -> Array[Int] {
  let result : Array[Int] = []
  for k, _ in self.adjacency {
    result.push(k)
  }
  result
}

///|
pub fn AdjacencyMap::edge_list(self : AdjacencyMap) -> Array[(Int, Int)] {
  let result : Array[(Int, Int)] = []
  for u, succs in self.adjacency {
    for v in succs {
      result.push((u, v))
    }
  }
  result
}

///|
pub fn AdjacencyMap::successors(self : AdjacencyMap, v : Int) -> Array[Int] {
  match self.adjacency.get(v) {
    Some(s) => s.copy()
    None => []
  }
}

///|
pub fn AdjacencyMap::has_vertex(self : AdjacencyMap, v : Int) -> Bool {
  self.adjacency.contains(v)
}

///|
pub fn AdjacencyMap::has_edge(self : AdjacencyMap, u : Int, v : Int) -> Bool {
  match self.adjacency.get(u) {
    Some(s) => s.contains(v)
    None => false
  }
}

///|
pub fn AdjacencyMap::vertex_count(self : AdjacencyMap) -> Int {
  self.adjacency.length()
}

///|
pub fn AdjacencyMap::edge_count(self : AdjacencyMap) -> Int {
  for _, v in self.adjacency; count = 0 {
    continue count + v.length()
  } nobreak {
    count
  }
}

///|
pub fn AdjacencyMap::transpose(self : AdjacencyMap) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  for k, _ in self.adjacency {
    if not(m.contains(k)) {
      m[k] = []
    }
  }
  for u, succs in self.adjacency {
    for v in succs {
      match m.get(v) {
        Some(arr) => if not(arr.contains(u)) { arr.push(u) }
        None => m[v] = [u]
      }
    }
  }
  { adjacency: m }
}

///|
pub impl DirectedGraph for AdjacencyMap with vertex_count(self) {
  self.adjacency.length()
}

///|
pub impl DirectedGraph for AdjacencyMap with for_each_vertex(self, f) {
  for k, _ in self.adjacency {
    f(k)
  }
}

///|
pub impl DirectedGraph for AdjacencyMap with for_each_successor(self, v, f) {
  match self.adjacency.get(v) {
    Some(s) =>
      for x in s {
        f(x)
      }
    None => ()
  }
}
