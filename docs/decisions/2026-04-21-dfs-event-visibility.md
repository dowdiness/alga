# DfsEvent enum visibility — keep `pub(all)`

**Date:** 2026-04-21
**Status:** Accepted

## Question

`moon ide analyze` flags `pub(all) enum DfsEvent` in `src/dfs.mbt` with the hint *"(all) or (open) can be removed"*. An earlier revision of [the Graph visibility decision](2026-04-21-graph-enum-visibility.md) dismissed DfsEvent as "a separate conversation — narrowing may be fine there." Is it?

## Decision

Keep `pub(all)`. Same verdict as Graph, arrived at from a narrower direction: DfsEvent is *pure output* — users never construct values, only inspect them.

## Why

DfsEvent is the return payload of `dfs_events() -> Iter[DfsEvent]`. The function exists so consumers can pattern-match on the event stream (tree vs back vs cross-forward edges, discover vs finish). For that to work:

**1. Constructors must be visible downstream.**

Pattern-matching on an opaque enum doesn't work — if we narrowed to `pub`, the type would survive as a name but the `Discover | Finish | TreeEdge | BackEdge | CrossForwardEdge` arms would be unreachable from outside the module. `src/dfs_test.mbt` (15+ match sites) and `src/graph_expr_qc.mbt` property tests already pattern-match DfsEvent from a separate package — both would break.

**2. `pub(open)` is wrong for the same reason as Graph.**

DFS edge classification is algorithmically fixed: a target vertex is white / gray / black, yielding tree / back / cross-or-forward. There's no meaningful 6th variant a downstream library could add. `pub(open)` would also force every match site, forever, to carry a wildcard arm.

**3. `derive(Eq)` signals a caller-facing value.**

Comparison and pattern-matching by callers is the whole point — not a private implementation detail.

**4. The linter hint is module-internal only.**

`moon ide analyze` doesn't see the downstream pattern-match sites.

## What changed vs. the earlier note

The Graph decision originally claimed *"DfsEvent (also flagged) is a separate conversation — its variant set is less universal and narrowing may be fine there."* That was a gut call. Under scrutiny, the "universal algebra vs ad-hoc event stream" distinction doesn't change the verdict — both types are consumed by external pattern-matching, and `pub(all)` is what permits it in both cases. DfsEvent happens to need it for *only* pattern-matching (no external construction), whereas Graph needs it for both. The Graph doc has been corrected to point here instead.

## Reference

- `src/dfs.mbt:194` — DfsEvent definition with the white/gray/black coloring docstring
- `src/dfs_test.mbt` — external pattern-match sites
- `src/graph_expr_qc.mbt` — property-based tests that pattern-match on events
- [Graph enum visibility](2026-04-21-graph-enum-visibility.md) — prior art with the closely related reasoning
