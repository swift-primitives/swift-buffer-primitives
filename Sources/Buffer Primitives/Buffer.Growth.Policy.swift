// Buffer.Growth.swift
// Namespace for growth-related types.

public import Binary_Primitives

extension Buffer {
    /// Namespace for buffer growth configuration.
    public enum Growth {}
}

// MARK: - Growth.Policy

extension Buffer.Growth {
    /// Policy for computing new capacity when a buffer needs to grow.
    ///
    /// Growth policies are value types that can be customized per-buffer
    /// or shared across multiple buffers.
    ///
    /// ## Built-in Policies
    ///
    /// - ``doubling``: Classic 2x growth (good general-purpose choice)
    /// - ``factor(_:)``: Custom multiplier (e.g., 1.5x for memory-constrained)
    /// - ``exact``: No over-allocation (minimizes memory, maximizes reallocations)
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Use 1.5x growth for memory-sensitive workloads
    /// var buffer = try Buffer.Unbounded(
    ///     minimumCapacity: 1024,
    ///     alignment: 16,
    ///     growthPolicy: .factor(1.5)
    /// )
    /// ```
    public struct Policy: Sendable {
        @usableFromInline
        internal let _compute: @Sendable (Int, Int) -> Int

        /// Creates a growth policy with a custom computation function.
        ///
        /// - Parameter compute: A function that takes (currentCapacity, requiredCapacity)
        ///   and returns the new capacity. Must return a value >= requiredCapacity.
        @inlinable
        public init(_ compute: @escaping @Sendable (_ current: Int, _ required: Int) -> Int) {
            self._compute = compute
        }

        /// Computes the next capacity given current and required capacities.
        ///
        /// - Parameters:
        ///   - current: The current buffer capacity.
        ///   - required: The minimum capacity needed.
        /// - Returns: The new capacity (always >= required).
        @inlinable
        public func nextCapacity(current: Int, required: Int) -> Int {
            let result = _compute(current, required)
            // Postcondition: result must be at least required
            return max(result, required)
        }
    }
}

// MARK: - Built-in Policies

extension Buffer.Growth.Policy {
    /// Doubling growth policy (2x).
    ///
    /// Classic growth strategy that provides O(1) amortized append.
    /// Doubles capacity each time growth is needed.
    ///
    /// - Note: This is the recommended default for most use cases.
    public static let doubling = Self { current, required in
        if current == 0 {
            return max(required, 64)  // Minimum initial allocation
        }
        var newCapacity = current
        while newCapacity < required {
            newCapacity = newCapacity * 2
        }
        return newCapacity
    }

    /// Factor-based growth policy.
    ///
    /// Multiplies current capacity by the given factor until it exceeds required.
    /// Use factors < 2.0 for more memory-efficient growth at the cost of more allocations.
    ///
    /// - Parameter factor: Growth multiplier (must be > 1.0). Common values: 1.5, 2.0.
    /// - Returns: A growth policy using the specified factor.
    @inlinable
    public static func factor(_ factor: Double) -> Self {
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
    public static let exact = Self { _, required in
        required
    }

    /// Page-aligned growth policy.
    ///
    /// Rounds up to the next alignment boundary.
    /// Good for large buffers where page alignment matters.
    ///
    /// - Parameter alignment: The alignment to round up to (default: `.page4096`).
    /// - Returns: A growth policy that rounds to alignment boundaries.
    @inlinable
    public static func pageAligned(_ alignment: Binary.Alignment = .page4096) -> Self {
        return Self { _, required in
            // Round up to next alignment boundary
            let mask: Int = alignment.mask()
            return (required + mask) & ~mask
        }
    }
}
