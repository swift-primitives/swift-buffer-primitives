import Binary_Primitives

// MARK: - Test Helpers (Package Visibility)

extension Buffer.Aligned {
    /// Creates a deliberately misaligned view for testing alignment validation.
    ///
    /// This is package-internal for use in tests only. It creates a view
    /// that is offset from the aligned base, simulating a misaligned buffer.
    ///
    /// - Parameters:
    ///   - offset: The number of bytes to offset (1 to alignment-1).
    ///   - body: A closure receiving the misaligned buffer pointer.
    /// - Returns: The value returned by `body`.
    ///
    /// - Precondition: `offset` must be positive and less than `alignment`.
    /// - Precondition: `offset` must be less than `count`.
    package func withMisalignedView<T>(
        offset: Int,
        _ body: (UnsafeRawBufferPointer) throws(Never) -> T
    ) -> T {
        let alignmentMagnitude: Int = alignment.magnitude()
        precondition(offset > 0 && offset < alignmentMagnitude, "Offset must break alignment")
        precondition(offset < count, "Offset exceeds buffer size")

        return withUnsafeBytes { buffer in
            let misaligned = buffer.baseAddress!.advanced(by: offset)
            let remaining = count - offset
            return body(UnsafeRawBufferPointer(start: misaligned, count: remaining))
        }
    }

    /// Creates a deliberately misaligned view for testing (throwing variant).
    ///
    /// - Parameters:
    ///   - offset: The number of bytes to offset.
    ///   - body: A closure receiving the misaligned buffer pointer.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by `body`.
    package func withMisalignedView<T, E: Swift.Error>(
        offset: Int,
        _ body: (UnsafeRawBufferPointer) throws(E) -> T
    ) throws(E) -> T {
        let alignmentMagnitude: Int = alignment.magnitude()
        precondition(offset > 0 && offset < alignmentMagnitude, "Offset must break alignment")
        precondition(offset < count, "Offset exceeds buffer size")

        return try withUnsafeBytes { (buffer: UnsafeRawBufferPointer) throws(E) -> T in
            let misaligned = buffer.baseAddress!.advanced(by: offset)
            let remaining = count - offset
            return try body(UnsafeRawBufferPointer(start: misaligned, count: remaining))
        }
    }

    /// Creates a deliberately misaligned mutable view for testing.
    ///
    /// - Parameters:
    ///   - offset: The number of bytes to offset.
    ///   - body: A closure receiving the misaligned buffer pointer.
    /// - Returns: The value returned by `body`.
    package mutating func withMisalignedMutableView<T>(
        offset: Int,
        _ body: (UnsafeMutableRawBufferPointer) throws(Never) -> T
    ) -> T {
        let alignmentMagnitude: Int = alignment.magnitude()
        precondition(offset > 0 && offset < alignmentMagnitude, "Offset must break alignment")
        precondition(offset < count, "Offset exceeds buffer size")

        return withUnsafeMutableBytes { [remaining = count - offset] buffer in
            let misaligned = buffer.baseAddress!.advanced(by: offset)
            return body(UnsafeMutableRawBufferPointer(start: misaligned, count: remaining))
        }
    }

    /// Creates a deliberately misaligned mutable view for testing (throwing variant).
    ///
    /// - Parameters:
    ///   - offset: The number of bytes to offset.
    ///   - body: A closure receiving the misaligned buffer pointer.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by `body`.
    package mutating func withMisalignedMutableView<T, E: Swift.Error>(
        offset: Int,
        _ body: (UnsafeMutableRawBufferPointer) throws(E) -> T
    ) throws(E) -> T {
        let alignmentMagnitude: Int = alignment.magnitude()
        precondition(offset > 0 && offset < alignmentMagnitude, "Offset must break alignment")
        precondition(offset < count, "Offset exceeds buffer size")

        return try withUnsafeMutableBytes { [remaining = count - offset] (buffer: UnsafeMutableRawBufferPointer) throws(E) -> T in
            let misaligned = buffer.baseAddress!.advanced(by: offset)
            return try body(UnsafeMutableRawBufferPointer(start: misaligned, count: remaining))
        }
    }
}

// MARK: - Internal Alignment Utilities

extension Buffer.Memory {
    /// Aligns an offset down to allocation granularity.
    ///
    /// - Parameter offset: The offset to align. Must be non-negative.
    /// - Returns: The offset aligned down to the nearest granularity boundary.
    /// - Precondition: `offset >= 0`
    package static func alignOffsetDown(_ offset: Int) -> Int {
        precondition(offset >= 0, "Offset must be non-negative")
        let g = granularity
        return (offset / g) * g
    }

    /// Aligns a length up to page size.
    ///
    /// - Parameter length: The length to align. Must be non-negative.
    /// - Returns: The length aligned up to the nearest page boundary,
    ///   or `nil` if the result would overflow `Int`.
    /// - Precondition: `length >= 0`
    package static func alignLengthUp(_ length: Int) -> Int? {
        precondition(length >= 0, "Length must be non-negative")
        let ps = pageSize
        // Use overflow-safe arithmetic: (length + ps - 1) can overflow
        let (sum, overflow) = length.addingReportingOverflow(ps - 1)
        guard !overflow else { return nil }
        return (sum / ps) * ps
    }

    /// Calculates the delta between requested offset and aligned offset.
    ///
    /// - Parameter requestedOffset: The offset to calculate delta for. Must be non-negative.
    /// - Returns: The difference between the requested offset and its aligned-down value.
    /// - Precondition: `requestedOffset >= 0`
    package static func offsetDelta(for requestedOffset: Int) -> Int {
        precondition(requestedOffset >= 0, "Offset must be non-negative")
        return requestedOffset - alignOffsetDown(requestedOffset)
    }
}
