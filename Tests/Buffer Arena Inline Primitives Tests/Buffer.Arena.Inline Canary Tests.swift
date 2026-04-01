// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Testing
import Buffer_Arena_Inline_Primitives

/// Regression tests for Buffer.Arena.Inline deinit via cross-module member destruction.
///
/// Buffer.Arena.Inline's `_deinitWorkaround` resolves swiftlang/swift #86652
/// (triviality misclassification). These tests verify that element cleanup
/// works through the member destruction chain — matching the pattern validated
/// for Storage.Inline across 18 data structure types.
@Suite("Buffer.Arena.Inline - Deinit Regression")
struct ArenaInlineDeinitRegressionTests {

    final class Tracker: @unchecked Sendable {
        private var _storage: [Int] = []
        var deinitOrder: [Int] { _storage }
        func append(_ id: Int) { _storage.append(id) }
    }

    struct TrackedElement: ~Copyable {
        let id: Int
        let tracker: Tracker
        init(_ id: Int, tracker: Tracker) { self.id = id; self.tracker = tracker }
        deinit { tracker.append(id) }
    }

    /// Wrapper with empty deinit — tests that Buffer.Arena.Inline's deinit fires
    /// through the explicit-deinit → member-destruction chain.
    private struct _EmptyDeinitWrapper<Element: ~Copyable, let capacity: Int>: ~Copyable {
        var _arena: Buffer<Element>.Arena.Inline<capacity>
        init() { self._arena = Buffer<Element>.Arena.Inline<capacity>() }
        deinit {}
    }

    /// Wrapper with NO deinit — tests that Buffer.Arena.Inline's deinit fires
    /// through pure implicit member destruction. This is the exact shape
    /// Tree.N.Inline has after removing _deinitWorkaround and deinit.
    private struct _NoDeinitWrapper<Element: ~Copyable, let capacity: Int>: ~Copyable {
        var _arena: Buffer<Element>.Arena.Inline<capacity>
        init() { self._arena = Buffer<Element>.Arena.Inline<capacity>() }
    }

    @Test("cross-module member destruction — wrapper with empty deinit")
    func emptyDeinitWrapper() throws {
        let tracker = Tracker()
        do {
            var bare = _EmptyDeinitWrapper<TrackedElement, 8>()
            try _ = bare._arena.insert(TrackedElement(1, tracker: tracker))
            try _ = bare._arena.insert(TrackedElement(2, tracker: tracker))
            try _ = bare._arena.insert(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitOrder == [1, 2, 3])
    }

    @Test("cross-module member destruction — wrapper with no deinit")
    func noDeinitWrapper() throws {
        let tracker = Tracker()
        do {
            var bare = _NoDeinitWrapper<TrackedElement, 8>()
            try _ = bare._arena.insert(TrackedElement(1, tracker: tracker))
            try _ = bare._arena.insert(TrackedElement(2, tracker: tracker))
            try _ = bare._arena.insert(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitOrder == [1, 2, 3])
    }
}
