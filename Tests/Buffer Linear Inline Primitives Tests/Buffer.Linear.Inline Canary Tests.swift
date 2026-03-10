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

/// Canary tests for swiftlang/swift #86652: ~Copyable value-generic member destruction.
///
/// When any test FAILS ("Known issue was not recorded"), the compiler has
/// fixed #86652 and the workarounds can be removed from:
///   - Stack.Static, Array.Static, Heap.Static, Heap.MinMax.Static,
///     Set.Ordered.Static, Dictionary.Ordered.Static
@Suite("Buffer.Linear.Inline - Deinit Canary")
struct LinearInlineDeinitCanaryTests {

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
        var _buffer: Buffer<Element>.Linear.Inline<capacity>
        init() { self._buffer = Buffer<Element>.Linear.Inline<capacity>() }
        deinit {}
    }

    @Test
    func `compiler destroys cross-module value-generic member`() {
        withKnownIssue("swiftlang/swift #86652: ~Copyable value-generic member destruction") {
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
}
