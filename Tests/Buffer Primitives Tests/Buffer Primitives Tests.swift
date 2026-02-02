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

// Buffer Primitives Tests
//
// Test organization:
// - Buffer.Ring Tests.swift         - Unbounded ring buffer tests
// - Buffer.Ring.Static Tests.swift  - Bounded ring buffer tests
// - Buffer.Slots.Static Tests.swift - Index-addressable slot storage tests
//
// All tests use parallel namespace pattern per [TEST-004] due to generic types.

import Buffer_Primitives_Test_Support
