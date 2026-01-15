// Buffer.Aligned+Binary.swift
// Binary protocol conformance and typed accessors.

public import Binary_Primitives

// MARK: - Binary Conformance Contract
//
// `Buffer.Aligned` conforms to `Binary.Mutable` (which implies `Binary.Contiguous`).
//
// Semantics:
// - `count == capacity`: The addressable byte region.
// - "Meaningful bytes" is tracked by `Binary.Cursor.writerIndex`, not by this storage.
// - Bounds errors throw `Binary.Error`, not `Buffer.Aligned.Error`.
//
// Index Space:
// Uses `Buffer.Aligned.Space` as the phantom type for `Binary.Position`.
// This prevents accidental mixing of positions from different address spaces.
//
// Invariants:
// - `count >= 0` always holds
// - Alignment guarantee is maintained for the buffer's lifetime
// - Memory is bound to `UInt8` at initialization

// MARK: - Byte Accessor Namespace

extension Buffer.Aligned {
    /// Namespace for byte-level access operations.
    ///
    /// Provides grouped operations for reading and writing bytes at typed positions.
    /// Access via `buffer.byte.at(position)` and `buffer.byte.set(value, at: position)`.
    @safe
    public struct Byte: ~Copyable {
        @usableFromInline
        var pointer: UnsafeMutablePointer<UInt8>

        @usableFromInline
        let count: Int

        @usableFromInline
        internal init(pointer: UnsafeMutablePointer<UInt8>, count: Int) {
            unsafe self.pointer = pointer
            self.count = count
        }
    }
}

// MARK: - Byte Accessor Property

extension Buffer.Aligned {
    /// Byte-level accessor namespace.
    ///
    /// Provides typed position access:
    /// ```swift
    /// let value = try buffer.byte.at(position)
    /// try buffer.byte.set(value, at: position)
    /// ```
    @inlinable
    public var byte: Byte {
        unsafe Byte(pointer: bytePointer, count: count)
    }
}

// MARK: - Byte Read Operations

extension Buffer.Aligned.Byte {
    /// Reads a byte at the given position.
    ///
    /// - Parameter position: The position to read from.
    /// - Returns: The byte at the specified position.
    /// - Throws: `Binary.Error.bounds` if position is out of range.
    @inlinable
    public func at(
        _ position: Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>
    ) throws(Binary.Error) -> UInt8 {
        let index = position.rawValue
        guard index >= 0, index < count else {
            throw .bounds(
                .init(
                    field: .reader,
                    value: index,
                    lower: 0,
                    upper: Buffer.Aligned.Scalar(count)
                )
            )
        }
        return unsafe pointer[index]
    }

    /// Reads a byte at the given position without bounds checking.
    ///
    /// - Parameters:
    ///   - __unchecked: Marker parameter.
    ///   - position: The position to read from.
    /// - Returns: The byte at the specified position.
    /// - Precondition: `0 <= position < count`
    @inlinable
    public func at(
        __unchecked: Void = (),
        _ position: Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>
    ) -> UInt8 {
        let index = position.rawValue
        precondition(index >= 0 && index < count, "Position out of bounds")
        return unsafe pointer[index]
    }
}

// MARK: - Byte Write Operations

extension Buffer.Aligned.Byte {
    /// Writes a byte at the given position.
    ///
    /// - Parameters:
    ///   - value: The byte to write.
    ///   - position: The position to write to.
    /// - Throws: `Binary.Error.bounds` if position is out of range.
    @inlinable
    public func set(
        _ value: UInt8,
        at position: Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>
    ) throws(Binary.Error) {
        let index = position.rawValue
        guard index >= 0, index < count else {
            throw .bounds(
                .init(
                    field: .writer,
                    value: index,
                    lower: 0,
                    upper: Buffer.Aligned.Scalar(count)
                )
            )
        }
        unsafe pointer[index] = value
    }

    /// Writes a byte at the given position without bounds checking.
    ///
    /// - Parameters:
    ///   - __unchecked: Marker parameter.
    ///   - value: The byte to write.
    ///   - position: The position to write to.
    /// - Precondition: `0 <= position < count`
    @inlinable
    public func set(
        __unchecked: Void = (),
        _ value: UInt8,
        at position: Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>
    ) {
        let index = position.rawValue
        precondition(index >= 0 && index < count, "Position out of bounds")
        unsafe pointer[index] = value
    }
}

// MARK: - Subscript (Unchecked, Traps)

extension Buffer.Aligned {
    /// Accesses a byte at the given position.
    ///
    /// This subscript traps on invalid positions. For throwing validation,
    /// use `byte.at(position)` and `byte.set(value, at: position)`.
    ///
    /// - Parameter position: The position to access.
    /// - Returns: The byte at the specified position.
    /// - Precondition: `0 <= position < count`
    @inlinable
    public subscript(position: Binary.Position<Scalar, Space>) -> UInt8 {
        get {
            let index = position.rawValue
            precondition(index >= 0 && index < count, "Position out of bounds")
            return unsafe bytePointer[index]
        }
        set {
            let index = position.rawValue
            precondition(index >= 0 && index < count, "Position out of bounds")
            unsafe bytePointer[index] = newValue
        }
    }
}

// MARK: - Range Access (Closure-Based)

extension Buffer.Aligned {
    /// Provides read-only access to a range of bytes.
    ///
    /// - Parameters:
    ///   - range: The range of positions to access.
    ///   - body: A closure that receives a span covering the range.
    /// - Returns: The value returned by `body`.
    /// - Throws: `Binary.Error.bounds` if range is out of bounds, or the error thrown by `body`.
    @inlinable
    public func withBytes<R, E: Swift.Error>(
        in range: Range<Binary.Position<Scalar, Space>>,
        _ body: (Span<UInt8>) throws(E) -> R
    ) throws(BytesRangeError<E>) -> R {
        let lower = range.lowerBound.rawValue
        let upper = range.upperBound.rawValue

        guard lower >= 0 else {
            throw .bounds(.negative(.init(field: .reader, value: lower)))
        }

        guard upper <= count else {
            throw .bounds(
                .bounds(
                    .init(
                        field: .reader,
                        value: upper,
                        lower: 0,
                        upper: Scalar(count)
                    )
                )
            )
        }

        guard lower <= upper else {
            throw .bounds(
                .invariant(
                    .init(
                        kind: .reader,
                        left: lower,
                        right: upper
                    )
                )
            )
        }

        let span = unsafe Span(
            _unsafeStart: unsafe bytePointer.advanced(by: lower),
            count: upper - lower
        )
        do {
            return try body(span)
        } catch {
            throw .body(error)
        }
    }

    /// Provides read-only access to a range of bytes without bounds checking.
    ///
    /// - Parameters:
    ///   - __unchecked: Marker parameter.
    ///   - range: The range of positions to access.
    ///   - body: A closure that receives a span covering the range.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by `body`.
    /// - Precondition: `0 <= range.lowerBound <= range.upperBound <= count`
    @inlinable
    public func withBytes<R, E: Swift.Error>(
        __unchecked: Void = (),
        in range: Range<Binary.Position<Scalar, Space>>,
        _ body: (Span<UInt8>) throws(E) -> R
    ) throws(E) -> R {
        let lower = range.lowerBound.rawValue
        let upper = range.upperBound.rawValue
        precondition(lower >= 0 && lower <= upper && upper <= count)
        let span = unsafe Span(
            _unsafeStart: unsafe bytePointer.advanced(by: lower),
            count: upper - lower
        )
        return try body(span)
    }

    /// Error type for range access operations.
    public enum BytesRangeError<E: Swift.Error>: Swift.Error {
        case bounds(Binary.Error)
        case body(E)
    }
}
