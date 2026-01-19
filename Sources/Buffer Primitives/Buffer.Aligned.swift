public import Binary_Primitives

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif os(Windows)
    import ucrt
    import WinSDK
#endif

// MARK: - Global Sentinel for Empty Buffers

/// Process-global sentinel pointer for empty buffers with alignment <= pageSize.
///
/// Page-aligned pointer dominates all power-of-two alignments <= pageSize (8, 16, 32, ...).
/// For alignments > pageSize, empty buffers allocate a 1-byte buffer with the requested alignment.
/// Allocated once at process start; never freed. Memory is bound to UInt8.
@safe
@usableFromInline
nonisolated(unsafe) let emptyBufferSentinel: UnsafeMutablePointer<UInt8> = {
    #if os(Windows)
        var info = SYSTEM_INFO()
        GetSystemInfo(&info)
        let pageSize = Int(info.dwPageSize)
        guard let raw = unsafe _aligned_malloc(1, pageSize) else {
            fatalError("Failed to allocate empty buffer sentinel")
        }
        return unsafe raw.bindMemory(to: UInt8.self, capacity: 1)
    #else
        let pageSize = sysconf(Int32(_SC_PAGESIZE))
        let alignment = pageSize > 0 ? Int(pageSize) : 4096
        var raw: UnsafeMutableRawPointer?
        let result = unsafe posix_memalign(&raw, alignment, 1)
        guard result == 0, let p = unsafe raw else {
            fatalError("Failed to allocate empty buffer sentinel")
        }
        return unsafe p.bindMemory(to: UInt8.self, capacity: 1)
    #endif
}()

extension Buffer {
    /// A fixed-size, aligned memory buffer with unique ownership.
    ///
    /// `Buffer.Aligned` provides guaranteed memory alignment for performance-critical
    /// operations like direct I/O, SIMD processing, and memory-mapped files.
    ///
    /// ## Design Constraints
    ///
    /// This type is intentionally **fixed-size**. It does not support:
    /// - Resizing or growth (use growable buffers from swift-io)
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
    /// ## Platform Implementation
    ///
    /// | Platform | Allocation | Deallocation |
    /// |----------|------------|--------------|
    /// | POSIX | `posix_memalign` | `free` |
    /// | Windows | `_aligned_malloc` | `_aligned_free` |
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
    /// For most APIs, accept `some Binary.Contiguous` or `some Binary.Mutable`
    /// rather than `Buffer.Aligned` directly. This keeps `Buffer.Aligned` as
    /// an implementation detail, not a type that "infects" public interfaces.
    ///
    /// ```swift
    /// // Prefer accepting protocols in public APIs
    /// func process<B: Binary.Contiguous>(_ data: borrowing B) { ... }
    ///
    /// // Use Buffer.Aligned when alignment is the semantic requirement
    /// var buffer = try Buffer.Aligned(byteCount: 4096, alignment: .page4096)
    /// buffer.copy(from: sourceData, at: 0)
    /// ```
    @safe
    public struct Aligned: ~Copyable, @unchecked Sendable {
        /// Typed byte pointer to the allocated memory.
        /// Memory is bound to UInt8 at initialization.
        @usableFromInline
        var bytePointer: UnsafeMutablePointer<UInt8>

        /// The number of bytes allocated.
        public let count: Int

        /// The alignment of the allocation.
        public let alignment: Binary.Alignment

        deinit {
            // Don't free the shared page-aligned sentinel (used for empty buffers with alignment <= pageSize)
            // Empty buffers with alignment > pageSize have their own allocation that must be freed
            // Note: Structured as if-else to work around Swift 6.2.1 Windows MoveOnlyChecker crash
            if unsafe bytePointer != emptyBufferSentinel {
                #if os(Windows)
                    unsafe _aligned_free(UnsafeMutableRawPointer(bytePointer))
                #else
                    unsafe free(UnsafeMutableRawPointer(bytePointer))
                #endif
            }
        }
    }
}

// MARK: - Initialization

extension Buffer.Aligned {
    /// Creates an aligned buffer with uninitialized contents.
    ///
    /// - Parameters:
    ///   - byteCount: The number of bytes to allocate. Must be non-negative.
    ///   - alignment: The alignment boundary. `Binary.Alignment` guarantees
    ///     this is a valid power of 2.
    /// - Throws: `Error.invalidSize` if size is negative.
    /// - Throws: `Error.allocationFailed` if allocation fails.
    ///
    /// - Note: Empty buffers (`byteCount == 0`) are supported. They use a global
    ///   sentinel pointer and do not perform per-instance allocation.
    public init(byteCount: Int, alignment: Binary.Alignment) throws(Error) {
        guard byteCount >= 0 else {
            throw .invalidSize
        }

        let alignmentMagnitude: Int = alignment.magnitude()

        // Empty buffer handling
        if byteCount == 0 {
            // For alignment <= pageSize, use the shared page-aligned sentinel
            // For alignment > pageSize, allocate a 1-byte buffer with requested alignment
            if alignmentMagnitude <= Buffer.Memory.pageSize {
                unsafe self.bytePointer = emptyBufferSentinel
            } else {
                #if os(Windows)
                    guard let raw = unsafe _aligned_malloc(1, alignmentMagnitude) else {
                        throw .allocationFailed
                    }
                    unsafe self.bytePointer = raw.bindMemory(to: UInt8.self, capacity: 1)
                #else
                    var raw: UnsafeMutableRawPointer?
                    let result = unsafe posix_memalign(&raw, alignmentMagnitude, 1)
                    guard result == 0, let allocated = unsafe raw else {
                        throw .allocationFailed
                    }
                    unsafe self.bytePointer = allocated.bindMemory(to: UInt8.self, capacity: 1)
                #endif
            }
            self.count = 0
            self.alignment = alignment
            return
        }

        #if os(Windows)
            guard let raw = unsafe _aligned_malloc(byteCount, alignmentMagnitude) else {
                throw .allocationFailed
            }
            unsafe self.bytePointer = raw.bindMemory(to: UInt8.self, capacity: byteCount)
        #else
            var raw: UnsafeMutableRawPointer?
            let result = unsafe posix_memalign(&raw, alignmentMagnitude, byteCount)
            guard result == 0, let allocated = unsafe raw else {
                throw .allocationFailed
            }
            unsafe self.bytePointer = allocated.bindMemory(to: UInt8.self, capacity: byteCount)
        #endif

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
        byteCount: Int,
        alignment: Binary.Alignment
    ) throws(Error) -> Self {
        let buffer = try Self(byteCount: byteCount, alignment: alignment)
        unsafe buffer.bytePointer.initialize(repeating: 0, count: byteCount)
        return buffer
    }

    /// Creates a page-aligned buffer.
    ///
    /// This allocates a buffer aligned to the system page size,
    /// suitable for most memory-mapped I/O operations.
    ///
    /// - Parameter byteCount: The number of bytes to allocate.
    /// - Throws: `Error` if allocation fails.
    public static func pageAligned(byteCount: Int) throws(Error) -> Self {
        try Self(byteCount: byteCount, alignment: Buffer.Memory.pageAlignment)
    }
}

// MARK: - Memory Access (Typed Throws)

extension Buffer.Aligned {
    /// Provides read-only access to the buffer contents.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `bytes` span for safe access.
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
        try unsafe body(UnsafeRawBufferPointer(start: UnsafeRawPointer(bytePointer), count: count))
    }

    /// Provides read-write access to the buffer contents.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `mutableBytes` span for safe access.
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
        try unsafe body(UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(bytePointer), count: count))
    }
}

// MARK: - Alignment Verification

extension Buffer.Aligned {
    /// Checks if the buffer is aligned to the given boundary.
    ///
    /// The buffer is always aligned to at least `self.alignment`.
    /// It may also be aligned to larger powers of 2 depending on
    /// the underlying allocator.
    ///
    /// - Parameter boundary: The alignment to check.
    /// - Returns: `true` if the buffer's base address is aligned to the boundary.
    @inlinable
    public func isAligned(to boundary: Binary.Alignment) -> Bool {
        unsafe boundary.isAligned(UnsafeRawPointer(bytePointer))
    }
}

// MARK: - Span Access

extension Buffer.Aligned {
    /// Read-only span of the buffer as bytes.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the borrow of `self`.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - The returned span is lifetime-dependent; the compiler is expected to diagnose escapes.
    /// - Violating this contract is undefined behavior.
    ///
    /// ## Memory Semantics
    ///
    /// Memory is bound to `UInt8` at initialization. This is a byte buffer;
    /// no reinterpretation as other element types is supported through this API.
    /// For raw memory access, use `withRawSpan(_:)`.
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
    /// - The returned span is lifetime-dependent; the compiler is expected to diagnose escapes.
    /// - No concurrent mutable borrows are permitted.
    /// - No mutable + immutable borrow overlap is permitted.
    /// - Violating this contract is undefined behavior.
    ///
    /// ## Memory Semantics
    ///
    /// Memory is bound to `UInt8` at initialization. This is a byte buffer;
    /// no reinterpretation as other element types is supported through this API.
    /// For raw memory access, use `withMutableRawSpan(_:)`.
    @inlinable
    public var mutableBytes: MutableSpan<UInt8> {
        @_lifetime(&self)
        mutating get {
            unsafe MutableSpan(_unsafeStart: bytePointer, count: count)
        }
    }
}

// MARK: - Raw Span Access (Closure-Based)

extension Buffer.Aligned {
    /// Provides read-only raw span access to the buffer.
    ///
    /// Use this when you need `byteCount` semantics or type reinterpretation.
    /// The span is valid only within the closure scope.
    ///
    /// - Parameter body: A closure that receives a raw span view of the buffer.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by the closure.
    @inlinable
    public func withRawSpan<R, E: Swift.Error>(
        _ body: (RawSpan) throws(E) -> R
    ) throws(E) -> R {
        let span = unsafe RawSpan(_unsafeStart: UnsafeRawPointer(bytePointer), byteCount: count)
        return try body(span)
    }

    /// Provides read-write raw span access to the buffer.
    ///
    /// Use this when you need `byteCount` semantics or type reinterpretation.
    /// The span is valid only within the closure scope.
    ///
    /// - Parameter body: A closure that receives a mutable raw span view of the buffer.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by the closure.
    @inlinable
    public mutating func withMutableRawSpan<R, E: Swift.Error>(
        _ body: (inout MutableRawSpan) throws(E) -> R
    ) throws(E) -> R {
        var span = unsafe MutableRawSpan(_unsafeStart: UnsafeMutableRawPointer(bytePointer), byteCount: count)
        return try body(&span)
    }
}

// MARK: - Protocol Conformances

extension Buffer.Aligned {
    /// Address space marker for buffer memory positions.
    public enum Space {}

    /// Scalar type for index arithmetic (default Int).
    public typealias Scalar = Int
}

// Binary.Mutable refines Binary.Contiguous, so conforming to Mutable
// automatically satisfies the Contiguous requirement.
extension Buffer.Aligned: Binary.Mutable {}
