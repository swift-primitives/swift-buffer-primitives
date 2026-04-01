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

/// Regression test: Storage.Inline deinit cleans up elements through
/// cross-module member destruction chain.
///
/// Previously a canary for swiftlang/swift #86652. Now that Storage.Inline
/// has its own deinit (with _deinitWorkaround for triviality misclassification),
/// elements are properly deinitialized even through bare wrappers with no
/// manual cleanup. The compiler bug is worked around at the storage layer.
@Suite("Buffer.Ring.Inline - Deinit")
struct RingInlineDeinitTests {

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
    /// Storage.Inline's deinit handles element cleanup.
    private struct _BareWrapper<Element: ~Copyable, let capacity: Int>: ~Copyable {
        var _buffer: Buffer<Element>.Ring.Inline<capacity>
        init() { self._buffer = Buffer<Element>.Ring.Inline<capacity>() }
        deinit {}
    }

    @Test
    func `Storage.Inline deinit cleans up through cross-module chain`() {
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
