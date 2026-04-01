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
import Buffer_Linear_Inline_Primitives

/// Regression test: Storage.Inline deinit cleans up elements through
/// cross-module member destruction chain.
@Suite("Buffer.Linear.Inline - Deinit")
struct LinearInlineDeinitTests {

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

    private struct _BareWrapper<Element: ~Copyable, let capacity: Int>: ~Copyable {
        var _buffer: Buffer<Element>.Linear.Inline<capacity>
        init() { self._buffer = Buffer<Element>.Linear.Inline<capacity>() }
        deinit {}
    }

    @Test
    func `Storage.Inline deinit cleans up through cross-module chain`() {
        let tracker = Tracker()
        do {
            var bare = _BareWrapper<TrackedElement, 4>()
            _ = bare._buffer.append(TrackedElement(1, tracker: tracker))
            _ = bare._buffer.append(TrackedElement(2, tracker: tracker))
            _ = bare._buffer.append(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitOrder == [1, 2, 3])
    }
}
