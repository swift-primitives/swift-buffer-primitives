# Buffer Primitives Experiments

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| [ring-buffer-architecture-validation](ring-buffer-architecture-validation/) | Validate three-layer architecture (Header / Static Ops / Composed Type) with Storage.Heap | 2026-02-03 | Apple Swift 6.2.3 | CONFIRMED |
| [initialization-consistency](initialization-consistency/) | Verify Storage.Initialization consistency across Linear, Ring, and Slab disciplines | 2026-02-03 | Apple Swift 6.2.3 | CONFIRMED |
| [composed-vs-static-benchmark](composed-vs-static-benchmark/) | Benchmark composed type (Ring.Growable) vs direct static method calls | 2026-02-03 | Apple Swift 6.2.3 | CONFIRMED |
| [slab-deinit-workaround](slab-deinit-workaround/) | MoveOnlyChecker crash in Buffer.Slab.deinit — workaround: extract Ones.View into local | 2026-02-06 | Apple Swift 6.2.3 | SUPERSEDED |
| [noncopyable-enum-modify](noncopyable-enum-modify/) | Validate that _modify cannot yield into enum payloads for ~Copyable types (Optional can via &optional!) | 2026-02-12 | Apple Swift 6.2.3 | SUPERSEDED |
| [static-property-view-pattern](static-property-view-pattern/) | Validate static + Property.View pattern: consuming ~Copyable, CoW overloads, _modify, callAsFunction, overload coexistence | 2026-02-12 | Apple Swift 6.2.3 | CONFIRMED |
| [spill-building-block](spill-building-block/) | Test generic Spill\<Inline, Heap\> building block for factoring Small buffer pattern — mechanically feasible but net savings marginal | 2026-02-12 | Apple Swift 6.2.3 | CONFIRMED |
| [cross-module-type-declaration](cross-module-type-declaration/) | Cross-module type declaration patterns for ~Copyable types with deinit | 2026-02-15 | Xcode 26.0 beta 2 | SUPERSEDED |
| [rawlayout-release-verifier-crash](rawlayout-release-verifier-crash/) | LLVM verifier "Instruction does not dominate all uses!" — 30 variants of @_rawLayout + class reference combinations; none reproduce the crash in isolation | 2026-02-15 | Xcode 26.0 beta 2 | SUPERSEDED |
| [copy-propagation-noncopyable-enum](copy-propagation-noncopyable-enum/) | CopyPropagation SIL crash — consuming ~Copyable in enum switch + conditional loop with bitmap; 5 variants (concrete, generic, nested, value-generic, slab); none reproduce in isolation | 2026-02-15 | Xcode 26.0 beta 2 | SUPERSEDED |
| [small-enum-modify-recovery](small-enum-modify-recovery/) | DiagnoseStaticExclusivity crash FIXED; recover _modify for heap case via let-binding pointer bypass; inline case not recoverable via pointer (borrow temporary) | 2026-02-16 | Apple Swift 6.2.3 | SUPERSEDED |
| **[rawlayout-llvm-verifier-crash](rawlayout-llvm-verifier-crash/)** | **Consolidated**: LLVM verifier crash — 8 variants (V01-V08) covering baseline, struct-body threshold, extension-file, cross-module, class-ref, wrapper patterns, ~Copyable elements, pre-compiled deinit | 2026-03-21 | Swift 6.2.4 | CONFIRMED (bug) |
| **[rawlayout-sil-ownership-crash](rawlayout-sil-ownership-crash/)** | **Consolidated**: SIL ownership crash + enum _modify — 3 variants (V01-V03) covering CopyPropagation, enum _modify limitation, recovery strategies | 2026-03-21 | Swift 6.2.4 | CONFIRMED (bug + limitation) |
| **[rawlayout-deinit-alternatives](rawlayout-deinit-alternatives/)** | **Consolidated**: deinit workaround alternatives — 4 variants (V01-V04) covering discard self, guard idempotence, escapable lifetime, slab bitmap cleanup | 2026-03-21 | Swift 6.2.4 | CONFIRMED |
| **[rawlayout-minimal-reproducer](rawlayout-minimal-reproducer/)** | Standalone minimal reproducer: Bug 1 REPRODUCES (3-module chain, 2+ cross-module @_rawLayout fields), Bug 2 does NOT reproduce (7 patterns tried) | 2026-03-21 | Swift 6.2.4 | Bug 1: CONFIRMED, Bug 2: REFUTED |
