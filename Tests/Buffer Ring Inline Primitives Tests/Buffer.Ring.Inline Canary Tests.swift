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
import Buffer_Ring_Inline_Primitives

/// Canary tests for swiftlang/swift #86652: ~Copyable value-generic member destruction.
///
/// When any test FAILS ("Known issue was not recorded"), the compiler has
/// fixed #86652 and the workarounds can be removed from:
///   - Queue.Static, Queue.DoubleEnded.Static (swift-queue-primitives)
@Suite("Buffer.Ring.Inline - Deinit Canary")
struct RingInlineDeinitCanaryTests {

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
        var _buffer: Buffer<Element>.Ring.Inline<capacity>
        init() { self._buffer = Buffer<Element>.Ring.Inline<capacity>() }
        deinit {}
    }

    @Test
    func `compiler destroys cross-module value-generic member`() {
        withKnownIssue("swiftlang/swift #86652: ~Copyable value-generic member destruction") {
            let tracker = Tracker()
            do {
                var bare = _BareWrapper<TrackedElement, 4>()
                bare._buffer.push.back(TrackedElement(1, tracker: tracker))
                bare._buffer.push.back(TrackedElement(2, tracker: tracker))
                bare._buffer.push.back(TrackedElement(3, tracker: tracker))
            }
            #expect(tracker.deinitOrder == [1, 2, 3])
        }
    }
}
