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
import Buffer_Slab_Inline_Primitives
import Buffer_Primitives_Test_Support

/// Canary tests for swiftlang/swift #86652: ~Copyable value-generic member destruction.
///
/// When any test FAILS ("Known issue was not recorded"), the compiler has
/// fixed #86652 and the workarounds can be removed from:
///   - Slab.Static (swift-slab-primitives)
@Suite("Buffer.Slab.Inline - Deinit Canary")
struct SlabInlineDeinitCanaryTests {

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
    private struct _BareWrapper<Element: ~Copyable, let wordCount: Int>: ~Copyable {
        var _buffer: Buffer<Element>.Slab.Inline<wordCount>
        init() { self._buffer = Buffer<Element>.Slab.Inline() }
        deinit {}
    }

    @Test
    func `compiler destroys cross-module value-generic member`() {
        withKnownIssue("swiftlang/swift #86652: ~Copyable value-generic member destruction") {
            let tracker = Tracker()
            do {
                var bare = _BareWrapper<TrackedElement, 4>()
                let s0: Bit.Index.Bounded<4> = 0
                let s1: Bit.Index.Bounded<4> = 1
                let s2: Bit.Index.Bounded<4> = 2
                bare._buffer.insert(TrackedElement(1, tracker: tracker), at: s0)
                bare._buffer.insert(TrackedElement(2, tracker: tracker), at: s1)
                bare._buffer.insert(TrackedElement(3, tracker: tracker), at: s2)
            }
            #expect(tracker.deinitOrder == [1, 2, 3])
        }
    }
}
