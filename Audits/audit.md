# Audit: swift-buffer-primitives

## Accepted Compiler Warnings — 2026-03-25

### Scope

- **Target**: swift-buffer-primitives (inline buffer variants)
- **Trigger**: Build log warning triage from `swift test` on swift-foundations
- **Files**: `Buffer.Arena.Small.swift`, `Buffer.Linear.Small.swift`, `Buffer.Linear.Small Copyable.swift`, `Buffer.Ring.Small Copyable.swift`, `Buffer.Linked.Small Copyable.swift`

### Context

During a full warning audit of the swift-foundations test build, 17 "variable was never mutated" warnings across 5 files in the small buffer variants were identified as **not fixable**. Accepted as a compiler limitation pending future Swift evolution.

### Findings

| # | Severity | Diagnostic | Location | Finding | Status |
|---|----------|------------|----------|---------|--------|
| 1 | — | "variable was never mutated" | `Buffer.Arena.Small.swift`, `Buffer.Linear.Small.swift`, `Buffer.Linear.Small Copyable.swift`, `Buffer.Ring.Small Copyable.swift`, `Buffer.Linked.Small Copyable.swift` (17 sites) | All flagged `var buf` / `var inlineBuf` declarations use `consume buf` for ownership transfer. `consume` requires a `var` binding — `let` produces "'buf' is borrowed and cannot be consumed." The compiler's mutation analysis does not recognize `consume` as requiring mutability. | ACCEPTED |

### Rationale

The `consume` keyword performs a move — transferring ownership out of a binding. This is semantically distinct from mutation, but syntactically requires `var` because the binding's value is invalidated after the consume. The compiler's "never mutated" analysis predates ownership annotations and does not account for `consume`. This is a known false positive that will be resolved when the warning analysis is updated to recognize ownership operations.

### Re-evaluation trigger

Re-evaluate when the compiler's mutation analysis recognizes `consume` as requiring `var`.

### Summary

1 finding (17 sites): 0 critical, 0 high, 0 medium, 0 low, 1 ACCEPTED. Compiler false positive on `consume` pattern in small buffer variants. No code action possible.

### Provenance

Extracted 2026-04-08 from `swift-institute/Research/audit.md` "Accepted Compiler Warnings — 2026-03-25" (finding #4) per [AUDIT-002] scope location correction.

---

## Legacy — Consolidated 2026-04-08

### From: implementation-skill-audit.md (2026-02-12)

**Original status**: RECOMMENDATION. 100%-strictness audit against `/implementation` skill. 97 source files across 8 modules. 72+ violations.

| Module | Violations | MUST | SHOULD |
|--------|-----------|------|--------|
| Buffer Primitives Core | 0 | 0 | 0 |
| Buffer Slots Primitives | 0 | 0 | 0 |
| Buffer Linear Primitives | 4+ | 3 | 1+ |
| Buffer Ring Primitives | 6+ | 3 | 3+ |
| Buffer Slab Primitives | 14 | 8 | 6 |
| Buffer Arena Primitives | 24 | 18 | 6 |
| Buffer Linked Primitives | 24 | 18 | 6 |

**Systemic patterns**:

| Pattern | Sites | Rule |
|---------|-------|------|
| `Int(bitPattern:)` at call sites | ~64 | [IMPL-010] |
| `.rawValue.rawValue` chains (Arena) | ~13 | [IMPL-002], [PATTERN-017] |
| Compound public identifiers (Linked) | ~12 | [API-NAME-002] |

**Core finding**: Most violations are **import gaps**, not infrastructure gaps. Adding dependencies on `Cardinal_Primitives_Standard_Library_Integration` and `Ordinal_Primitives_Standard_Library_Integration` resolves ~45 sites via existing typed overloads (`Span`, `UnsafeBufferPointer`, `UnsafeMutableBufferPointer`, `Int`, `ContiguousArray`, `MutableSpan` cardinal-typed inits + `UnsafePointer[Ordinal]` subscripts).

**Classification of all violations**:
- **Pure import gaps** (~45 sites): resolved by adding integration module dependencies
- **Use existing infra** (~8 sites): `Affine.Discrete.Ratio` for capacity doubling (3 sites: Linear, Ring, Linked); `.retag(Bit.self)` for Slab Bit.Index (2 sites); ordinal subscripts for pointer access (3 sites)
- **Genuine infrastructure gaps** (~3 sites): `UnsafeMutablePointer<T>.moveInitialize(from:, count: Cardinal.Protocol)` needs adding to Cardinal Primitives Standard Library Integration
- **Design decision required** (~13 sites): Arena `UInt32(slot.rawValue.rawValue)` pattern — options include (a) `UInt32.init(bitPattern: Index<T>)` boundary overload, (b) change Meta subscript to accept `Index<Element>`, (c) accept as same-package implementation detail
- **Naming violations** (~12 sites): Buffer.Linked compound public identifiers (`insertFront`/`insertBack`/`removeFront`/`removeBack`) require Property.View nested accessors

### From: AUDIT-HANDOFF.md (package root, undated)

**Status at handoff**: Two phases of fixes applied, 333/333 tests passing. Remaining work tracked.

**Completed fixes** (verified by build + tests):
- **Capacity doubling → `Affine.Discrete.Ratio`** (3 sites): `Buffer.Linear.swift:111`, `Buffer.Ring.swift:102`, `Buffer.Linked ~Copyable.swift:244-247`
- **Pointer subscript `base[slot]` via [INFRA-003]** (3 sites): `Buffer.Slab.Inline Copyable.swift:71`, `Buffer.Ring.Inline Copyable.swift:79`, `Buffer.Linear.Inline Copyable.swift:67`
- **Span/MutableSpan typed count via [INFRA-002]** (18 sites across 5 files): `Linear+Span`, `Linear.Small+Span`, `Ring+Span`, `Ring.Small+Span`, `Linear.Inline+Span`
- **UnsafeBufferPointer typed count** (10 sites across 3 files): `Linear+Memory.Contiguous`, `Linear.Bounded+Memory.Contiguous`, `Linear.Inline+Memory.Contiguous`
- **Bounded Copyable MutableSpan** (2 sites): `Linear.Bounded Copyable.swift`

**Remaining tasks**:

| # | Task | Rule | Sites |
|---|------|------|-------|
| 1 | Refactor Linked compound identifiers to nested accessors (Property.View `insert.front()`, `insert.back()`, `remove.front()`, `remove.back()`) | [API-NAME-002] | 12 in 3 files: `Buffer.Linked ~Copyable.swift:90,100,113,122`; `Buffer.Linked Copyable.swift:48,61,72,82`; `Buffer.Linked.Inline ~Copyable.swift:109,142,178,209`. Static methods in `Buffer.Linked+Pool ~Copyable.swift` may keep compound names per [IMPL-024]. |
| 2 | Add `UnsafeMutablePointer<T>.moveInitialize(from:, count: Cardinal.Protocol)` to Cardinal Primitives Standard Library Integration (NOT buffer-primitives) | [INFRA-gap] | 3 sites: `Buffer.Linear+Heap ~Copyable.swift:75`, `Buffer.Slots Copyable.swift:21,73` |
| 3 | Add `UInt32.init<T: ~Copyable>(bitPattern: Index<T>)` to Ordinal Primitives Standard Library Integration or a new Arena-specific boundary | [INFRA-gap] | 13 Arena sites: `Buffer.Arena.Inline.swift:115,128,166,174`; `Buffer.Arena+Heap ~Copyable.swift:51,74,109,146,157,168,179`; `Buffer.Arena+Drain.swift:12,44` |

**Accepted `Int(bitPattern:)` sites** (legitimate boundaries per [INFRA-020]):
- `underestimatedCount` → `Int` for `Swift.Sequence` (4 sites)
- `hasher.combine(Int(bitPattern:))` in Linked Copyable (1 site)
- Pointer advance `base + Int(bitPattern: take)` in Span iterators (8 sites — no `UnsafePointer + Cardinal` overload)
- `storageBase + Int(bitPattern: range.lowerBound)` in Ring Span inits (6 sites)
- Arena loop bounds `for i in 0..<Int(bitPattern: highWater)` (6 sites)
- Linked growth `Swift.max(Int(bitPattern:), ...)` (2 sites)
- Arena stride calc (1 site)

### From: dependency-reuse-audit.md (2026-02-03)

**Original status**: DECISION. "No missing delegation found." Audit verified that the converged buffer design correctly identifies all dependencies and calls for their use. Identified 5 implementation hazards where a developer might inadvertently reimplement existing primitives:

1. **Ring modular arithmetic**: Use `Modular.successor`/`predecessor`/`physical` from `cyclic-index-primitives`, NOT manual `%`
2. **Slab index bridge**: Use `Tagged.retag()` from `identity-primitives`, NOT rawValue extraction
3. **Linear element shift**: Use `Storage.Heap.move(range:to:)` from `storage-primitives`, NOT element-by-element loop
4. **Count subtraction**: Use `Cardinal.subtract.exact()` from `cardinal-primitives`, NOT `rawValue - 1`
5. **Page-aligned growth**: Use `Memory.Alignment.alignUp()` from `memory-primitives`, NOT manual rounding

These are implementation constraints that should be enforced at code review time or via grep checks.

---

### From: swift-institute/Research/audits/implementation-naming-2026-03-20/swift-buffer-primitives.md (2026-03-20)

**Implementation + naming audit**

HIGH=8, MEDIUM=22, LOW=12, INFO=0
Finding IDs: BUF-001, BUF-002, BUF-003, BUF-004, BUF-005, BUF-006, BUF-007, BUF-008, BUF-009, BUF-010, BUF-011, BUF-012, BUF-013, BUF-014, BUF-015 (+19 more)

| Severity | Count | Categories |
|----------|-------|------------|
| CRITICAL | 0 | — |
| HIGH | 5 | .rawValue chains, __unchecked boundary, for-loop mechanism |
| MEDIUM | 15 | Int(bitPattern:) at non-boundary call sites, while-loop mechanism |
| LOW | 7 | Minor naming, duplication |
