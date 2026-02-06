// MARK: - Slab Deinit MoveOnlyChecker Crash Workaround
// Purpose: Document the MoveOnlyChecker crash (signal 11) in Buffer.Slab.deinit
//          and validate the workaround.
//
// Root Cause: In a ~Copyable struct's deinit, a forEach closure that borrows
//   one ~Copyable field (header.bitmap.ones) while capturing a sibling field
//   (storage) crashes the MoveOnlyChecker SIL pass. This only reproduces when
//   the struct is nested inside a generic enum (Buffer<Element: ~Copyable>.Slab),
//   not in standalone structs.
//
// Workaround: Extract the Copyable Ones.View into a local variable BEFORE
//   the closure. This breaks the borrow chain through the ~Copyable field,
//   so the closure only captures a local (Copyable) value and the sibling field.
//
//   BEFORE (crashes):
//     header.bitmap.ones.forEach { bitIndex in
//         storage.deinitialize(at: bitIndex.retag())
//     }
//
//   AFTER (works):
//     let ones = header.bitmap.ones
//     ones.forEach { bitIndex in
//         storage.deinitialize(at: bitIndex.retag())
//     }
//
// Note: Could not reproduce in a standalone experiment package — the crash
//   requires the exact compilation context of Buffer Primitives Core (same-module
//   compilation with Storage.Heap ~Copyable generics). The workaround was validated
//   directly on Buffer.swift.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — extracting Ones.View into local eliminates the crash
// Date: 2026-02-06
