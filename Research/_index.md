# Buffer Primitives Research

| Document | Topic | Date | Status |
|----------|-------|------|--------|
| [theoretical-buffer-primitives-design](theoretical-buffer-primitives-design.md) | Tier 3: Theoretical buffer-primitives built on storage-primitives and bit-vector-primitives | 2026-02-03 | RECOMMENDATION |
| [dependency-reuse-audit](dependency-reuse-audit.md) | Audit: dependency reuse opportunities in converged buffer design | 2026-02-03 | DECISION |
| [metadata-parametric-slots](metadata-parametric-slots.md) | Tier 2: Metadata-parametric random-access slots buffer discipline | 2026-02-07 | IN_PROGRESS |
| [noncopyable-optional-access-patterns](noncopyable-optional-access-patterns.md) | Tier 2: Access patterns for ~Copyable optionals in borrowing contexts | 2026-02-09 | DECISION |
| [linked-buffer-n-parameterization](linked-buffer-n-parameterization.md) | Tier 1: N-parameter analysis for Buffer.Linked singly/doubly-linked support | 2026-02-11 | DECISION |
| [noncopyable-view-types-for-peek-reversed](noncopyable-view-types-for-peek-reversed.md) | Tier 1: View type design for Peek/Reversed on ~Copyable Buffer.Linked | 2026-02-11 | DECISION |
| [inline-small-linked-buffer-design](inline-small-linked-buffer-design.md) | Tier 2: Inline and Small variants for Buffer.Linked using Storage.Inline | 2026-02-11 | DECISION |
| [arena-buffer-design](arena-buffer-design.md) | Tier 2: Arena buffer discipline with generation-based stale-reference detection | 2026-02-11 | IN_PROGRESS |
| [slab-first-principles](slab-first-principles.md) | Tier 2: First-principles analysis of "slab" in CS literature vs Buffer.Slab implementation | 2026-02-11 | DECISION |
| [buffer-ring-consumer-api-boundary](buffer-ring-consumer-api-boundary.md) | Tier 1: Consumer API boundary design for Buffer.Ring | 2026-02-10 | IN_PROGRESS |
| [buffer-variant-parity-analysis](buffer-variant-parity-analysis.md) | Tier 2: Consistency audit across six buffer disciplines | 2026-02-11 | IN_PROGRESS |
| [linked-cow-safe-overloads](linked-cow-safe-overloads.md) | Tier 1: Add CoW-safe Copyable overloads to Buffer.Linked, consistent with Ring/Linear | 2026-02-12 | DECISION |
