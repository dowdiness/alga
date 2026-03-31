# Philosophy

Why algebraic graphs? What makes this library different from a typical adjacency list implementation?

## The problem with imperative graph APIs

Most graph libraries give you a mutable container:

```
g = new Graph()
g.add_vertex(1)
g.add_vertex(2)
g.add_edge(1, 2)
```

This works, but the graph has no algebraic structure. You can't compose two graphs, decompose a graph into parts, or reason about graph equality without comparing every vertex and edge. Graphs are opaque blobs of state.

## Algebraic graphs: graphs as expressions

Andrey Mokhov's insight (Haskell Symposium, 2017) is that any directed graph can be built from just four operations:

- **empty** — the graph with nothing
- **vertex(v)** — a single isolated vertex
- **overlay(a, b)** — union of two graphs (vertices + edges from both)
- **connect(a, b)** — overlay + directed edges from every vertex in a to every vertex in b

These four operations satisfy 8 axioms that make them an algebra:

- Overlay is a **commutative monoid** (commutative, associative, empty is identity)
- Connect is a **monoid** (associative, empty is identity, but NOT commutative)
- Connect **distributes** over overlay (left and right)
- Connect **decomposes** into overlay plus cross-edges

This means graph expressions have well-defined equality, can be composed and decomposed algebraically, and the axioms can be machine-verified (we do this with property-based testing).

## Two layers, loosely coupled

The library separates two concerns into independent layers:

**Layer A — Observation ("What does this graph look like?")**

The `DirectedGraph` trait defines how to query any graph: count vertices, iterate vertices, iterate successors. Any type that implements these three methods gets all algorithms (DFS, BFS, toposort, SCC, reachability, cycle detection, degree queries) for free. This layer doesn't know or care how the graph was built.

**Layer B — Construction ("How do I build a graph?")**

The `GraphSym` trait and `Graph` enum provide the four algebraic operations. `Graph` is the free algebra — it preserves the construction history as a syntax tree, enabling transformations (gmap, bind, induce) before evaluation. `AdjacencyMap` also implements `GraphSym`, building the efficient representation directly.

**The bridge: `foldg`**

`foldg` is the universal interpreter — it replaces each constructor with a user-supplied function and evaluates the tree. `Graph::to_adjacency_map()` uses `foldg` to connect construction to observation. In category theory terms, `foldg` is the unique homomorphism from the free algebra to any other algebra satisfying the graph axioms.

## Why fixed vertex type (Int)?

MoonBit traits don't support type parameters or associated types. We can't write `trait DirectedGraph { type Vertex; ... }`. So we fix vertices to `Int` and let users maintain their own `Id → Int` mapping.

This is the same pragmatic choice made by algebraic graph libraries in languages without type families. It keeps the trait simple (3 methods) and the generic algorithms clean.

## Why callback-style iteration?

Without associated types, we can't return `Iter[Vertex]` from trait methods. Instead, `for_each_vertex` and `for_each_successor` push vertices into `(Int) -> Unit` callbacks (continuation-passing style). This avoids intermediate allocations and is natural for fold-based algorithms.

## Why two representations?

`AdjacencyMap` (Map-based) handles sparse, non-contiguous vertex IDs and supports the full algebraic API. `DenseGraph` (Array-based) requires dense 0..n-1 vertex IDs but is 8-23x faster for algorithm execution. Users choose based on their vertex ID structure.

## Design principles

1. **Implement the trait, get all algorithms** — the bar for new graph types is three methods
2. **Construction and observation are independent** — you can use `AdjacencyMap::from_edges` without ever touching `Graph` expressions
3. **Algebraic laws are verified, not assumed** — property-based testing catches implementation bugs that unit tests miss
4. **Performance is measured, not guessed** — every optimization was validated by microbenchmarks before being applied

## References

- Andrey Mokhov, [Algebraic Graphs with Class](https://dl.acm.org/doi/10.1145/3122955.3122956) (Haskell Symposium, 2017)
- Haskell [algebraic-graphs](https://hackage.haskell.org/package/algebraic-graphs) package
