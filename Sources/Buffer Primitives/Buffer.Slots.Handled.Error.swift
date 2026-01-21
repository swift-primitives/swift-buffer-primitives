// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-buffer open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-buffer project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Buffer.Slots {
    /// Errors that can occur during handled slot operations.
    public struct HandledError: Swift.Error, Sendable, Hashable {
        public let kind: Kind

        public enum Kind: Sendable, Hashable {
            /// The handle is invalid (stale generation or out of bounds).
            case invalidHandle
            /// No free slots available for allocation.
            case capacityExhausted
        }

        @inlinable
        public init(kind: Kind) {
            self.kind = kind
        }

        public static let invalidHandle = HandledError(kind: .invalidHandle)
        public static let capacityExhausted = HandledError(kind: .capacityExhausted)
    }
}
