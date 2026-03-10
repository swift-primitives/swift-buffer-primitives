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

/// Canary tests for swiftlang/swift #86652: ~Copyable value-generic member destruction.
///
/// When any test FAILS ("Known issue was not recorded"), the compiler has
/// fixed #86652 and the workarounds can be removed from:
///   - Tree.N.Inline (swift-tree-primitives)
@Suite("Buffer.Arena.Inline - Deinit Canary")
struct ArenaInlineDeinitCanaryTests {

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

    /// Bare wrapper — NO _deinitWorkaround, NO manual cleanup.
    private struct _BareWrapper<Element: ~Copyable, let capacity: Int>: ~Copyable {
        var _arena: Buffer<Element>.Arena.Inline<capacity>
        init() { self._arena = Buffer<Element>.Arena.Inline<capacity>() }
        deinit {}
    }

    @Test
    func `compiler destroys cross-module value-generic member`() throws {
        withKnownIssue("swiftlang/swift #86652: ~Copyable value-generic member destruction") {
            let tracker = Tracker()
            do {
                var bare = _BareWrapper<TrackedElement, 8>()
                try _ = bare._arena.insert(TrackedElement(1, tracker: tracker))
                try _ = bare._arena.insert(TrackedElement(2, tracker: tracker))
                try _ = bare._arena.insert(TrackedElement(3, tracker: tracker))
            }
            #expect(tracker.deinitOrder == [1, 2, 3])
        }
    }
}
