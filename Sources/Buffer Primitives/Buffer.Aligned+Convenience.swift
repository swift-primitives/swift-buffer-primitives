public import Binary_Primitives

// MARK: - Single Byte Access

extension Buffer.Aligned {
    /// Accesses the byte at the given index.
    ///
    /// - Parameter index: The byte index to access.
    /// - Returns: The byte value at that index.
    ///
    /// - Precondition: `index >= 0 && index < count`
    ///
    /// - Note: For bulk access, prefer `bytes`, `mutableBytes`, or `withUnsafeBytes`.
    ///   Single-byte subscripting is intended for debugging and infrequent access.
    @inlinable
    public subscript(index: Int) -> UInt8 {
        get {
            precondition(index >= 0 && index < count, "index out of bounds")
            return unsafe bytePointer[index]
        }
        set {
            precondition(index >= 0 && index < count, "index out of bounds")
            unsafe bytePointer[index] = newValue
        }
    }
}

// MARK: - Copy Convenience

extension Buffer.Aligned {
    /// Copies bytes from a source buffer into this buffer at the given offset.
    ///
    /// This is a convenience wrapper around `Binary.copy(from:into:at:)`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var buffer = try Buffer.Aligned.zeroed(byteCount: 4096, alignment: 4096)
    /// let source: [UInt8] = [1, 2, 3, 4]
    /// buffer.copy(from: source, at: 0)
    /// ```
    ///
    /// - Parameters:
    ///   - source: The source buffer to copy from.
    ///   - offset: The byte offset in this buffer where copying begins. Defaults to 0.
    ///
    /// - Precondition: `offset >= 0`
    /// - Precondition: `offset + source.count <= self.count`
    @inlinable
    public mutating func copy<Source: Binary.Contiguous>(
        from source: borrowing Source,
        at offset: Int = 0
    ) {
        Binary.copy(from: source, into: &self, at: offset)
    }

    /// Copies bytes from a raw buffer pointer into this buffer at the given offset.
    ///
    /// - Parameters:
    ///   - source: The raw buffer pointer to copy from.
    ///   - offset: The byte offset in this buffer where copying begins. Defaults to 0.
    ///
    /// - Precondition: `offset >= 0`
    /// - Precondition: `offset + source.count <= self.count`
    @inlinable
    public mutating func copy(
        from source: UnsafeRawBufferPointer,
        at offset: Int = 0
    ) {
        unsafe Binary.copy(from: source, into: &self, at: offset)
    }
}

// MARK: - Zero Convenience

extension Buffer.Aligned {
    /// Zeroes all bytes in this buffer.
    ///
    /// This is a convenience wrapper around `Binary.zero(_:)`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var buffer = try Buffer.Aligned(byteCount: 4096, alignment: 4096)
    /// buffer.zero()  // All bytes are now 0
    /// ```
    @inlinable
    public mutating func zero() {
        Binary.zero(&self)
    }

    /// Zeroes bytes in the specified range.
    ///
    /// This is a convenience wrapper around `Binary.zero(_:range:)`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var buffer = try Buffer.Aligned(byteCount: 4096, alignment: 4096)
    /// buffer.zero(range: 0..<512)  // First 512 bytes are now 0
    /// ```
    ///
    /// - Parameter range: The range of bytes to zero.
    ///
    /// - Precondition: `range.lowerBound >= 0`
    /// - Precondition: `range.upperBound <= count`
    @inlinable
    public mutating func zero(range: Range<Int>) {
        Binary.zero(&self, range: range)
    }

    /// Zeroes bytes from the given offset to the end of the buffer.
    ///
    /// - Parameter offset: The starting offset from which to zero.
    ///
    /// - Precondition: `offset >= 0`
    /// - Precondition: `offset <= count`
    @inlinable
    public mutating func zero(from offset: Int) {
        Binary.zero(&self, from: offset)
    }
}
