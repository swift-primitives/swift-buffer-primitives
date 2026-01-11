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

extension Buffer.Bounded {
    /// Errors that can occur during buffer operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The buffer is full and cannot accept more elements.
        case full

        /// The buffer is empty and has no elements to return.
        case empty
    }
}
