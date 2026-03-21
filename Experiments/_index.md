# Buffer Primitives Experiments

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| [ring-buffer-architecture-validation](ring-buffer-architecture-validation/) | Validate three-layer architecture (Header / Static Ops / Composed Type) with Storage.Heap | 2026-02-03 | Apple Swift 6.2.3 | CONFIRMED |
| [initialization-consistency](initialization-consistency/) | Verify Storage.Initialization consistency across Linear, Ring, and Slab disciplines | 2026-02-03 | Apple Swift 6.2.3 | CONFIRMED |
| [composed-vs-static-benchmark](composed-vs-static-benchmark/) | Benchmark composed type (Ring.Growable) vs direct static method calls | 2026-02-03 | Apple Swift 6.2.3 | CONFIRMED |
| [static-property-view-pattern](static-property-view-pattern/) | Validate static + Property.View pattern: consuming ~Copyable, CoW overloads, _modify, callAsFunction, overload coexistence | 2026-02-12 | Apple Swift 6.2.3 | CONFIRMED |
| [spill-building-block](spill-building-block/) | Test generic Spill\<Inline, Heap\> building block for factoring Small buffer pattern — mechanically feasible but net savings marginal | 2026-02-12 | Apple Swift 6.2.3 | CONFIRMED |
| [builtin-address-of-borrow](builtin-address-of-borrow/) | Builtin.addressOfBorrow for ~Copyable types | 2026-02-12 | Apple Swift 6.2.3 | CONFIRMED |
| [consuming-bitmap-transfer](consuming-bitmap-transfer/) | Consuming transfer of bitmap between ~Copyable types | 2026-02-12 | Apple Swift 6.2.3 | CONFIRMED |
| [growth-policy-typed-arithmetic](growth-policy-typed-arithmetic/) | Growth policy with typed arithmetic | 2026-02-12 | Apple Swift 6.2.3 | STALE |
| [noncopyable-optional-access](noncopyable-optional-access/) | Optional access patterns for ~Copyable types | 2026-02-12 | Apple Swift 6.2.3 | CONFIRMED |
| [peek-non-mutating](peek-non-mutating/) | Non-mutating peek implementation | 2026-02-12 | Apple Swift 6.2.3 | CONFIRMED |
| [slab-foreach-nonmutating](slab-foreach-nonmutating/) | Non-mutating forEach on Slab | 2026-02-12 | Apple Swift 6.2.3 | CONFIRMED |
| **[rawlayout-llvm-verifier-crash](rawlayout-llvm-verifier-crash/)** | **Consolidated**: LLVM verifier crash — 8 variants (V01-V08) covering baseline, struct-body threshold, extension-file, cross-module, class-ref, wrapper patterns, ~Copyable elements, pre-compiled deinit | 2026-03-21 | Swift 6.2.4 | CONFIRMED (bug) |
| **[rawlayout-sil-ownership-crash](rawlayout-sil-ownership-crash/)** | **Consolidated**: SIL ownership crash + enum _modify — 3 variants (V01-V03) covering CopyPropagation, enum _modify limitation, recovery strategies | 2026-03-21 | Swift 6.2.4 | CONFIRMED (bug + limitation) |
| **[rawlayout-deinit-alternatives](rawlayout-deinit-alternatives/)** | **Consolidated**: deinit workaround alternatives — 4 variants (V01-V04) covering discard self, guard idempotence, escapable lifetime, slab bitmap cleanup | 2026-03-21 | Swift 6.2.4 | CONFIRMED |
| **[rawlayout-minimal-reproducer](rawlayout-minimal-reproducer/)** | Standalone minimal reproducer: Bug 1 REPRODUCES (3-module chain, 2+ cross-module @_rawLayout fields), Bug 2 does NOT reproduce (7 patterns tried) | 2026-03-21 | Swift 6.2.4 | Bug 1: CONFIRMED, Bug 2: REFUTED |

### Removed (2026-03-21)

The following experiments were consolidated into the 4 experiments above and deleted:
- `rawlayout-release-verifier-crash/` (30 variants) → `rawlayout-llvm-verifier-crash/` V01-V06
- `slab-deinit-workaround/` → `rawlayout-deinit-alternatives/` V04
- `noncopyable-enum-modify/` → `rawlayout-sil-ownership-crash/` V02
- `copy-propagation-noncopyable-enum/` → `rawlayout-sil-ownership-crash/` V01
- `small-enum-modify-recovery/` → `rawlayout-sil-ownership-crash/` V03
- `cross-module-type-declaration/` → `rawlayout-llvm-verifier-crash/` V04
