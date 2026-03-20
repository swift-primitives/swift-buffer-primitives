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

extension Buffer.Aligned where Element == UInt8 {
    /// Errors that can occur during aligned buffer operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Memory allocation failed.
        case allocationFailed
    }
}
