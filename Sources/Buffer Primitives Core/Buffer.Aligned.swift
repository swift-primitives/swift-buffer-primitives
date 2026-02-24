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

extension Buffer where Element == UInt8 {
    /// A fixed-size, aligned memory buffer with unique ownership.
    ///
    /// `Buffer.Aligned` provides guaranteed memory alignment for performance-critical
    /// operations like direct I/O, SIMD processing, and memory-mapped files.
    ///
    /// ## Design Constraints
    ///
    /// This type is intentionally **fixed-size**. It does not support:
    /// - Resizing or growth (use `Buffer.Unbounded` for growable storage)
    /// - Reader/writer indices (use `Binary.Cursor` for positioned access)
    /// - Copy-on-write semantics (move-only ownership guarantees exclusivity)
    ///
    /// ## Ownership
    ///
    /// `Buffer.Aligned` is move-only (`~Copyable`). This guarantees:
    /// - Unique ownership at compile time
    /// - No accidental copies of large allocations
    /// - Safe to send across concurrency domains (`Sendable`)
    ///
    /// Memory is deallocated when the buffer goes out of scope.
    ///
    /// ## Allocation
    ///
    /// Uses `UnsafeMutableRawPointer.allocate(byteCount:alignment:)` for pure Swift
    /// allocation with no platform-specific C imports.
    ///
    /// ## Concurrency
    ///
    /// `Aligned` is marked `@unchecked Sendable` because it is move-only (`~Copyable`).
    /// This guarantees unique ownership: after transferring an `Aligned` value to another
    /// task or actor, the original binding is invalidated by the compiler.
    ///
    /// - **Safe**: Moving an `Aligned` value across concurrency domains.
    /// - **Unsafe**: Concurrent access from multiple tasks without external synchronization.
    ///   If you need shared access, wrap the buffer in an actor or use a lock.
    ///
    /// ## Usage
    ///
    /// For most APIs, accept `some Memory.Contiguous.Protocol`
    /// rather than `Buffer.Aligned` directly. This keeps `Buffer.Aligned` as
    /// an implementation detail, not a type that "infects" public interfaces.
    @safe
    public struct Aligned: ~Copyable, @unchecked Sendable {
        /// Typed byte pointer to the allocated memory.
        /// Memory is bound to UInt8 at initialization.
        @usableFromInline
        var bytePointer: UnsafeMutablePointer<UInt8>

        /// The number of bytes allocated.
        public let count: Cardinal

        /// The alignment of the allocation.
        public let alignment: Memory.Alignment

        deinit {
            unsafe bytePointer.deallocate()
        }
    }
}

// MARK: - Initialization

extension Buffer.Aligned where Element == UInt8 {
    /// Creates an aligned buffer with uninitialized contents.
    ///
    /// - Parameters:
    ///   - byteCount: The number of bytes to allocate.
    ///   - alignment: The alignment boundary. `Memory.Alignment` guarantees
    ///     this is a valid power of 2.
    /// - Throws: `Error.allocationFailed` if allocation fails.
    ///
    /// - Note: Empty buffers (`byteCount == 0`) allocate 1 byte with the
    ///   requested alignment. This avoids sentinel pointers and platform-specific
    ///   page size queries.
    public init(byteCount: Cardinal, alignment: Memory.Alignment) throws(Error) {
        let alignmentMagnitude: Int = alignment.magnitude()

        if byteCount == .zero {
            let raw = UnsafeMutableRawPointer.allocate(
                byteCount: 1,
                alignment: alignmentMagnitude
            )
            unsafe self.bytePointer = raw.bindMemory(to: UInt8.self, capacity: 1)
            self.count = .zero
            self.alignment = alignment
            return
        }

        // Convert to Int at the C/stdlib boundary [IMPL-010]
        let size = Int(bitPattern: byteCount)

        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: size,
            alignment: alignmentMagnitude
        )
        unsafe self.bytePointer = raw.bindMemory(to: UInt8.self, capacity: size)

        self.count = byteCount
        self.alignment = alignment
    }

    /// Creates an aligned buffer initialized with zeros.
    ///
    /// - Parameters:
    ///   - byteCount: The number of bytes to allocate.
    ///   - alignment: The alignment boundary.
    /// - Throws: `Error.allocationFailed` if allocation fails.
    public static func zeroed(
        byteCount: Cardinal,
        alignment: Memory.Alignment
    ) throws(Error) -> Self {
        let buffer = try Self(byteCount: byteCount, alignment: alignment)
        unsafe buffer.bytePointer.initialize(repeating: 0, count: Int(bitPattern: byteCount))
        return buffer
    }
}

// MARK: - Memory Access (Typed Throws)

extension Buffer.Aligned where Element == UInt8 {
    /// Provides read-only access to the buffer contents.
    ///
    /// - Warning: The pointer must not escape the closure scope.
    ///
    /// - Parameter body: A closure that receives a pointer to the buffer.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by the closure (use `Never` for non-throwing).
    @unsafe
    @inlinable
    public func withUnsafeBytes<R, E: Swift.Error>(
        _ body: (UnsafeRawBufferPointer) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(UnsafeRawBufferPointer(start: UnsafeRawPointer(bytePointer), count: Int(bitPattern: count)))
    }

    /// Provides read-write access to the buffer contents.
    ///
    /// - Warning: The pointer must not escape the closure scope.
    ///
    /// - Parameter body: A closure that receives a mutable pointer to the buffer.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by the closure (use `Never` for non-throwing).
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBytes<R, E: Swift.Error>(
        _ body: (UnsafeMutableRawBufferPointer) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(bytePointer), count: Int(bitPattern: count)))
    }
}

// MARK: - Alignment Verification

extension Buffer.Aligned where Element == UInt8 {
    /// Checks if the buffer is aligned to the given boundary.
    ///
    /// The buffer is always aligned to at least `self.alignment`.
    /// It may also be aligned to larger powers of 2 depending on
    /// the underlying allocator.
    ///
    /// - Parameter boundary: The alignment to check.
    /// - Returns: `true` if the buffer's base address is aligned to the boundary.
    @inlinable
    public func isAligned(to boundary: Memory.Alignment) -> Bool {
        unsafe boundary.isAligned(UnsafeRawPointer(bytePointer))
    }
}

// MARK: - Span Access

extension Buffer.Aligned where Element == UInt8 {
    /// Read-only span of the buffer as bytes.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the borrow of `self`.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - Violating this contract is undefined behavior.
    @inlinable
    public var bytes: Span<UInt8> {
        @_lifetime(borrow self)
        borrowing get {
            unsafe Span(_unsafeStart: bytePointer, count: count)
        }
    }

    /// Mutable span of the buffer as bytes.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the exclusive mutable borrow.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - Violating this contract is undefined behavior.
    @inlinable
    public var mutableBytes: MutableSpan<UInt8> {
        @_lifetime(&self)
        mutating get {
            unsafe MutableSpan(_unsafeStart: bytePointer, count: count)
        }
    }
}

// MARK: - Raw Span Access (Closure-Based)

extension Buffer.Aligned where Element == UInt8 {
    /// Provides read-only raw span access to the buffer.
    ///
    /// Use this when you need `byteCount` semantics or type reinterpretation.
    /// The span is valid only within the closure scope.
    @inlinable
    public func withRawSpan<R, E: Swift.Error>(
        _ body: (RawSpan) throws(E) -> R
    ) throws(E) -> R {
        let span = unsafe RawSpan(_unsafeStart: UnsafeRawPointer(bytePointer), byteCount: Int(bitPattern: count))
        return try body(span)
    }

    /// Provides read-write raw span access to the buffer.
    ///
    /// Use this when you need `byteCount` semantics or type reinterpretation.
    /// The span is valid only within the closure scope.
    @inlinable
    public mutating func withMutableRawSpan<R, E: Swift.Error>(
        _ body: (inout MutableRawSpan) throws(E) -> R
    ) throws(E) -> R {
        var span = unsafe MutableRawSpan(_unsafeStart: UnsafeMutableRawPointer(bytePointer), byteCount: Int(bitPattern: count))
        return try body(&span)
    }
}

// MARK: - Protocol Conformances

extension Buffer.Aligned where Element == UInt8 {
    /// Address space marker for buffer memory positions.
    public enum Space {}

    /// Scalar type for index arithmetic (default Int).
    public typealias Scalar = Int
}

// MARK: - Memory.Contiguous.Protocol Conformance

extension Buffer.Aligned: Memory.Contiguous.`Protocol` where Element == UInt8 {
    /// The element type for this contiguous storage.
    public typealias Element = UInt8

    /// Read-only span of the buffer's bytes.
    @inlinable
    public var span: Span<UInt8> {
        @_lifetime(borrow self)
        borrowing get {
            bytes
        }
    }

    /// Mutable span of the buffer's bytes.
    @inlinable
    public var mutableSpan: MutableSpan<UInt8> {
        @_lifetime(&self)
        mutating get {
            mutableBytes
        }
    }

    /// Provides read-only access via typed buffer pointer.
    ///
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<UInt8>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(UnsafeBufferPointer(start: bytePointer, count: Int(bitPattern: count)))
    }

    /// Provides read-write access via typed mutable buffer pointer.
    ///
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<UInt8>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(UnsafeMutableBufferPointer(start: bytePointer, count: Int(bitPattern: count)))
    }
}
