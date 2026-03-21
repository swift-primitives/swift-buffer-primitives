# Instructions: Per-Variant-Family Core Module Split

## Objective

Split the monolithic `Buffer Primitives Core` target (~39 files) into per-variant-family Core modules to fix the LLVM verifier crash in release mode. Each new Core module holds only type definitions (no `Copyable`-requiring conformances). Work in a git worktree to avoid disrupting other packages that depend on swift-buffer-primitives.

## Background

Read these documents first:
1. `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Research/release-mode-llvm-verifier-crash-diagnosis.md` — full crash diagnosis, Steps 1-7
2. The `/modularization` skill — all MOD-* rules, especially [MOD-004] (constraint isolation)

### Why this is needed

- `swift build -c release` crashes with LLVM verifier errors ("Instruction does not dominate all uses!")
- Root cause: 4 `~Copyable` structs with `@_rawLayout` fields + `deinit` in one large module under `-O`
- The fix: split Core so each sub-module has ≤ 2 such types

### Critical constraint: [MOD-004]

Type definitions that use `Storage<Element>.Heap where Element: ~Copyable` **CANNOT** be in the same module as `Copyable`-requiring protocol conformances (`Sequence.Drain.Protocol`, `Sequence.Clearable`, `Collection.Protocol`, `Sequence.Consume.Protocol`). The compiler propagates `Copyable` from the conformance to the stored property, breaking `Storage<Element>.Heap`.

This was empirically verified — see Step 7 in the diagnosis document. The existing Core/variant split IS the constraint isolation boundary. The new per-variant Core modules must preserve this property: **zero `Copyable`-requiring conformances in any Core module**.

## Setup

1. Create a git worktree from the current branch:
   ```bash
   cd /Users/coen/Developer/swift-primitives/swift-buffer-primitives
   git worktree add ../swift-buffer-primitives-modularization three-layer-rewrite
   ```
2. Work exclusively in `/Users/coen/Developer/swift-primitives/swift-buffer-primitives-modularization/`
3. Do NOT modify the main worktree at `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/`

## Target Architecture

### Before (1 Core module, ~39 files)

```
Buffer Primitives Core (39 files) ← crashes in release
├── Buffer.swift, Buffer.Growth.swift, Buffer.Growth.Policy.swift, exports.swift
├── Buffer.Ring.swift, Buffer.Ring.Header.swift, Buffer.Ring.Bounded.swift, ...
├── Buffer.Linear.swift, Buffer.Linear.Header.swift, Buffer.Linear.Bounded.swift, ...
├── Buffer.Slab.swift, Buffer.Slab.Header.swift, Buffer.Slab.Bounded.swift, ...
├── Buffer.Linked.swift, Buffer.Linked.Header.swift, Buffer.Linked.Node.swift, ...
├── Buffer.Arena.swift, Buffer.Arena.Header.swift, Buffer.Arena.Position.swift, ...
├── Buffer.Slots.swift
├── Buffer.Aligned.swift, Buffer.Aligned+Convenience.swift, ...
└── Buffer.Unbounded.swift
```

### After (1 root Core + per-variant Core modules)

```
Buffer Primitives Core              (4 files: namespace + growth + exports)
Buffer Ring Primitives Core         (~8 files: Ring/Bounded/Inline/Small/Header/Checkpoint type defs)
Buffer Linear Primitives Core       (~7 files: Linear/Bounded/Inline/Small/Header type defs)
Buffer Slab Primitives Core         (~7 files: Slab/Bounded/Inline/Small/Header type defs)
Buffer Linked Primitives Core       (~7 files: Linked/Inline/Small/Header/Node type defs)
Buffer Arena Primitives Core        (~9 files: Arena/Bounded/Inline/Small/Header/Position/Meta/Error type defs)
Buffer Slots Primitives Core        (~2 files: Slots type def — split Header out of Slots.swift per [API-IMPL-005])
Buffer Aligned Primitives Core      (~5 files: Aligned full impl — no Copyable conformances, safe)
Buffer Unbounded Primitives Core    (~1 file: Unbounded full impl — no Copyable conformances, safe)
```

## Step-by-Step Procedure

### Phase 1: Create new source directories

Create directories for each new Core module under `Sources/`:

```
Sources/Buffer Ring Primitives Core/
Sources/Buffer Linear Primitives Core/
Sources/Buffer Slab Primitives Core/
Sources/Buffer Linked Primitives Core/
Sources/Buffer Arena Primitives Core/
Sources/Buffer Slots Primitives Core/
Sources/Buffer Aligned Primitives Core/
Sources/Buffer Unbounded Primitives Core/
```

### Phase 2: Move files from Core to per-variant Core modules

**Files staying in `Buffer Primitives Core`** (4 files):
- `Buffer.swift`
- `Buffer.Growth.swift`
- `Buffer.Growth.Policy.swift`
- `exports.swift`

**Files moving to `Buffer Ring Primitives Core`** (8 files):
- `Buffer.Ring.swift`
- `Buffer.Ring.Header.swift`
- `Buffer.Ring.Bounded.swift`
- `Buffer.Ring.Checkpoint.swift`
- `Buffer.Ring.Inline.swift`
- `Buffer.Ring.Small.swift`

**Files moving to `Buffer Linear Primitives Core`** (7 files):
- `Buffer.Linear.swift`
- `Buffer.Linear.Header.swift`
- `Buffer.Linear.Bounded.swift`
- `Buffer.Linear.Inline.swift`
- `Buffer.Linear.Small.swift`

**Files moving to `Buffer Slab Primitives Core`** (7 files):
- `Buffer.Slab.swift`
- `Buffer.Slab.Header.swift`
- `Buffer.Slab.Bounded.swift`
- `Buffer.Slab.Inline.swift`
- `Buffer.Slab.Small.swift`

**Files moving to `Buffer Linked Primitives Core`** (5 files):
- `Buffer.Linked.swift`
- `Buffer.Linked.Header.swift`
- `Buffer.Linked.Node.swift`
- `Buffer.Linked.Inline.swift`
- `Buffer.Linked.Small.swift`

**Files moving to `Buffer Arena Primitives Core`** (9 files):
- `Buffer.Arena.swift`
- `Buffer.Arena.Header.swift`
- `Buffer.Arena.Bounded.swift`
- `Buffer.Arena.Error.swift`
- `Buffer.Arena.Inline.swift`
- `Buffer.Arena.Small.swift`
- `Buffer.Arena.Position.swift`
- `Buffer.Arena.Meta.swift`

**Files moving to `Buffer Slots Primitives Core`** (1 file, needs split):
- `Buffer.Slots.swift` — contains BOTH `Buffer.Slots` AND nested `Buffer.Slots.Header`. Split per [API-IMPL-005]: extract `Buffer.Slots.Header.swift`.

**Files moving to `Buffer Aligned Primitives Core`** (4 files):
- `Buffer.Aligned.swift` (full type def + implementation — safe because `Element == UInt8`, no generic `Copyable` conformances)
- `Buffer.Aligned+Convenience.swift`
- `Buffer.Aligned+Subscript.swift`
- `Buffer.Aligned.Error.swift`

**Files moving to `Buffer Unbounded Primitives Core`** (1 file):
- `Buffer.Unbounded.swift` (full type def + implementation — safe, same reason)

### Phase 3: Create exports.swift for each new Core module

Each per-variant Core module re-exports the root Core:

```swift
// All per-variant Core modules:
@_exported public import Buffer_Primitives_Core
```

**Exception** — `Buffer Unbounded Primitives Core` also needs Aligned:
```swift
@_exported public import Buffer_Primitives_Core
@_exported public import Buffer_Aligned_Primitives_Core
```

### Phase 4: Update root Core's exports.swift

The root `Buffer Primitives Core/exports.swift` currently has:
```swift
@_exported public import Storage_Primitives
@_exported public import Cyclic_Index_Primitives
@_exported public import Bit_Vector_Primitives
```

Keep this unchanged — the root Core still serves as the external dependency funnel.

### Phase 5: Update existing variant module exports.swift

Each variant module currently imports `Buffer Primitives Core`. It must now ALSO import its family Core:

**Ring Primitives** `exports.swift`:
```swift
@_exported public import Buffer_Primitives_Core
@_exported public import Buffer_Ring_Primitives_Core
@_exported public import Sequence_Primitives
```

**Linear Primitives** `exports.swift`:
```swift
@_exported public import Buffer_Primitives_Core
@_exported public import Buffer_Linear_Primitives_Core
// ... existing Sequence/Collection/Finite exports
```

Apply the same pattern for Slab, Linked, Arena, Slots. Add the family Core re-export.

For **Inline** variant modules (Ring Inline, Linear Inline, etc.) — these already depend on their heap variant (e.g., Ring Inline depends on Ring Primitives). Since Ring Primitives re-exports Ring Core, the Inline modules get Ring Core transitively. Still, add an explicit re-export for clarity.

### Phase 6: Update Package.swift

#### New products (per-variant Core modules are INTERNAL — not published as library products per [MOD-001])

Do NOT add new library products for the per-variant Core modules. They are internal targets only.

#### New targets

Add 8 new targets, each depending on the root Core:

```swift
// MARK: - Per-Variant Core Targets

.target(
    name: "Buffer Ring Primitives Core",
    dependencies: ["Buffer Primitives Core"]
),
.target(
    name: "Buffer Linear Primitives Core",
    dependencies: ["Buffer Primitives Core"]
),
.target(
    name: "Buffer Slab Primitives Core",
    dependencies: ["Buffer Primitives Core"]
),
.target(
    name: "Buffer Linked Primitives Core",
    dependencies: ["Buffer Primitives Core"]
),
.target(
    name: "Buffer Arena Primitives Core",
    dependencies: ["Buffer Primitives Core"]
),
.target(
    name: "Buffer Slots Primitives Core",
    dependencies: ["Buffer Primitives Core"]
),
.target(
    name: "Buffer Aligned Primitives Core",
    dependencies: ["Buffer Primitives Core"]
),
.target(
    name: "Buffer Unbounded Primitives Core",
    dependencies: [
        "Buffer Primitives Core",
        "Buffer Aligned Primitives Core",
    ]
),
```

#### Update existing variant target dependencies

Each variant target must add its family Core as a dependency:

```swift
// Example: Ring Primitives
.target(
    name: "Buffer Ring Primitives",
    dependencies: [
        "Buffer Primitives Core",
        "Buffer Ring Primitives Core",          // ← ADD
        .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
    ]
),
```

Apply to ALL variant targets:
- Ring Primitives → add Ring Core
- Ring Inline Primitives → add Ring Core
- Linear Primitives → add Linear Core
- Linear Inline Primitives → add Linear Core
- Linear Small Primitives → add Linear Core
- Slab Primitives → add Slab Core
- Slab Inline Primitives → add Slab Core
- Linked Primitives → add Linked Core
- Linked Inline Primitives → add Linked Core
- Slots Primitives → add Slots Core
- Arena Primitives → add Arena Core
- Arena Inline Primitives → add Arena Core

Aligned and Unbounded variants don't have separate variant modules (their full implementation is in their Core), so nothing extra needed.

#### Update Umbrella target dependencies

Add all per-variant Core modules to the umbrella:

```swift
.target(
    name: "Buffer Primitives",
    dependencies: [
        "Buffer Primitives Core",
        "Buffer Ring Primitives Core",
        "Buffer Linear Primitives Core",
        "Buffer Slab Primitives Core",
        "Buffer Linked Primitives Core",
        "Buffer Arena Primitives Core",
        "Buffer Slots Primitives Core",
        "Buffer Aligned Primitives Core",
        "Buffer Unbounded Primitives Core",
        // ... all existing variant targets
    ]
),
```

#### Update Umbrella exports.swift

Add re-exports for all new Core modules:

```swift
@_exported public import Buffer_Ring_Primitives_Core
@_exported public import Buffer_Linear_Primitives_Core
@_exported public import Buffer_Slab_Primitives_Core
@_exported public import Buffer_Linked_Primitives_Core
@_exported public import Buffer_Arena_Primitives_Core
@_exported public import Buffer_Slots_Primitives_Core
@_exported public import Buffer_Aligned_Primitives_Core
@_exported public import Buffer_Unbounded_Primitives_Core
// ... existing re-exports
```

### Phase 7: Fix imports in moved files

The type definition files moving from root Core to per-variant Core modules may have `import Index_Primitives` or `import Vector_Primitives` at the top. These were transitive imports available in root Core. In the per-variant Core modules, they should be available through the re-export chain (per-variant Core → root Core → Storage Primitives → Index Primitives). If they don't resolve, either:
- Remove the import (if the types are available through re-exports)
- Add the specific import (with `public import` if needed)

### Phase 8: Build and verify

Build incrementally, one module at a time:

```bash
# 1. Root Core (should be trivial — only 4 files)
swift build --target "Buffer Primitives Core"

# 2. Each per-variant Core
swift build --target "Buffer Ring Primitives Core"
swift build --target "Buffer Linear Primitives Core"
swift build --target "Buffer Slab Primitives Core"
swift build --target "Buffer Linked Primitives Core"
swift build --target "Buffer Arena Primitives Core"
swift build --target "Buffer Slots Primitives Core"
swift build --target "Buffer Aligned Primitives Core"
swift build --target "Buffer Unbounded Primitives Core"

# 3. Variant modules (these should still compile — they just import Core differently)
swift build --target "Buffer Ring Primitives"
swift build --target "Buffer Linear Primitives"
# ... etc

# 4. Full debug build
swift build

# 5. THE CRITICAL TEST — release build
swift build -c release

# 6. Full test suite
swift test
```

### Phase 9: File splitting for cross-variant code (if needed)

Some files in existing variant modules contain extensions on MULTIPLE variants. For example:
- `Buffer.Linear+forEach.swift` in Linear Primitives has extensions on `Buffer.Linear.Bounded`, `Buffer.Linear.Inline`, `Buffer.Linear.Small`
- `Buffer.Linear+Span.swift` has `Buffer.Linear.Bounded` Iterator + Sequence conformances
- `Buffer.Arena+forEach Property.View.swift` has `Buffer.Arena.Bounded` extensions
- `Buffer.Arena+Drain.swift` has `Buffer.Arena.Bounded` extensions
- `Buffer.Ring+Checkpoint.swift` has `Buffer.Ring.Bounded` and `Buffer.Ring.Inline` extensions

These files reference types from other modules (e.g., `Buffer.Linear.Bounded` is defined in Linear Core, but the forEach extension lives in Linear Primitives). Since variant modules import their family Core, these references should compile. But if they don't, the cross-variant extensions need to be split:
- Bounded extensions → stay in the heap variant module (which imports Core → has Bounded type)
- Inline extensions → move to Inline variant module
- Small extensions → move to Small variant module

This split was already partially done in the previous attempt. See the `+forEach.swift` split pattern.

## File-per-type violations to fix ([API-IMPL-005])

While moving files, fix these known violations:
1. `Buffer.Slots.swift` → extract `Buffer.Slots.Header.swift` (Slots.Header is nested inline)
2. `Buffer.Ring.Bounded.swift` → extract `Buffer.Ring.Bounded.Error.swift` (Error enum is nested inline; follows existing pattern of `Buffer.Aligned.Error.swift`, `Buffer.Arena.Error.swift`)

## Success Criteria

1. `swift build` passes (debug)
2. `swift build -c release` passes ← **the primary goal**
3. `swift test` passes (debug — release tests may still have the underlying LLVM bug, but the verifier crash should be eliminated)
4. Each per-variant Core module has ≤ 2 types with `@_rawLayout` + `deinit` (safe per Step 6 findings)
5. No `Copyable`-requiring conformances in any Core module

## Constraints

- Work ONLY in the worktree, not the main checkout
- Build iteratively — verify each module compiles before moving to the next
- Do NOT move Bounded/Small implementation files to new modules in this pass — that's a separate task. This pass only splits Core.
- The per-variant Core modules are internal targets per [MOD-001] — do NOT publish them as library products
