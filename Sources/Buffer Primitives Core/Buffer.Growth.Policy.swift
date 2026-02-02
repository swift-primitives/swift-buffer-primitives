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

public import Memory_Primitives

// MARK: - Built-in Policies

extension Buffer.Growth.Policy where Element: ~Copyable {
    /// Doubling growth policy (2x).
    ///
    /// Classic growth strategy that provides O(1) amortized append.
    /// Doubles capacity each time growth is needed.
    ///
    /// - Note: This is the recommended default for most use cases.
    public static var doubling: Self {
        Self { current, required in
            if current == 0 {
                return max(required, 64)  // Minimum initial allocation
            }
            var newCapacity = current
            while newCapacity < required {
                newCapacity = newCapacity * 2
            }
            return newCapacity
        }
    }
    /// Factor-based growth policy.
    ///
    /// Multiplies current capacity by the given factor until it exceeds required.
    /// Use factors < 2.0 for more memory-efficient growth at the cost of more allocations.
    ///
    /// - Parameter factor: Growth multiplier (must be > 1.0). Common values: 1.5, 2.0.
    /// - Returns: A growth policy using the specified factor.
    @inlinable
    public static func factor(
        _ factor: Double
    ) -> Self {
        precondition(factor > 1.0, "Growth factor must be > 1.0")
        return Self { current, required in
            if current == 0 {
                return max(required, 64)
            }
            var newCapacity = current
            while newCapacity < required {
                newCapacity = Int((Double(newCapacity) * factor).rounded(.up))
            }
            return newCapacity
        }
    }

    /// Exact growth policy (no over-allocation).
    ///
    /// Always allocates exactly the required capacity.
    /// Minimizes memory usage but maximizes reallocations.
    ///
    /// - Warning: This policy leads to O(n) amortized append cost.
    ///   Use only when memory is more critical than performance.
    public static var exact: Self {
        Self { _, required in required }
    }

    /// Page-aligned growth policy.
    ///
    /// Rounds up to the next alignment boundary.
    /// Good for large buffers where page alignment matters.
    ///
    /// - Parameter alignment: The alignment to round up to (default: `.page4096`).
    /// - Returns: A growth policy that rounds to alignment boundaries.
    @inlinable
    public static func pageAligned(_ alignment: Memory.Alignment = .page4096) -> Self {
        return Self { _, required in
            let mask: Int = alignment.mask()
            return (required + mask) & ~mask
        }
    }
}
