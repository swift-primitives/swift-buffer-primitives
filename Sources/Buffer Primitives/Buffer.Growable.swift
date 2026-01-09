// Buffer.Growable.swift
// Resizable buffer storage backed by Buffer.Aligned.

public import Binary_Primitives

extension Buffer {
    /// Resizable buffer storage that conforms to `Binary.Mutable`.
    ///
    /// `Growable` provides dynamic capacity management while delegating
    /// index tracking to `Binary.Cursor`. The `count` property always
    /// equals the current capacity (addressable bytes).
    ///
    /// ## Design Principle
    ///
    /// > **Binary owns semantics** (indices, bounds).
    /// > **Buffer owns storage** (allocation, capacity).
    ///
    /// This type does NOT track "written bytes" — use `Binary.Cursor.writerIndex`
    /// for that. The buffer simply provides addressable storage.
    ///
    /// ## Capacity Management
    ///
    /// - ``ensureCapacity(minimum:)`` — grows if needed, **preserves existing bytes**
    /// - ``reserveDiscardingContents(minimum:)`` — grows if needed, **discards contents** (fast)
    ///
    /// ## Example
    ///
    /// ```swift
    /// var buffer = try Buffer.Growable(minimumCapacity: 64, alignment: .doubleWord)
    /// var cursor = try Binary.Cursor(storage: buffer)
    ///
    /// // Write some data
    /// cursor.storage.withUnsafeMutableBytes { ptr in
    ///     ptr[0] = 0xFF
    /// }
    /// try cursor.moveWriterIndex(by: 1)
    ///
    /// // Grow if needed (preserves byte at index 0)
    /// try cursor.storage.ensureCapacity(minimum: 1024)
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// Not thread-safe. External synchronization required for concurrent access.
    public struct Growable: ~Copyable {
        /// The underlying aligned storage.
        @usableFromInline
        internal var _storage: Aligned

        /// The growth policy for capacity expansion.
        public let growthPolicy: Growth.Policy

        /// The alignment requirement (preserved across reallocations).
        public let alignment: Binary.Alignment

        /// Creates a growable buffer with the specified minimum capacity.
        ///
        /// - Parameters:
        ///   - minimumCapacity: The minimum initial capacity in bytes.
        ///   - alignment: Memory alignment requirement.
        ///   - growthPolicy: Strategy for computing new capacity (default: doubling).
        /// - Throws: `Buffer.Aligned.Error` if allocation fails.
        @inlinable
        public init(
            minimumCapacity: Int,
            alignment: Binary.Alignment,
            growthPolicy: Growth.Policy = .doubling
        ) throws(Aligned.Error) {
            self._storage = try Aligned(byteCount: minimumCapacity, alignment: alignment)
            self.growthPolicy = growthPolicy
            self.alignment = alignment
        }

        /// Creates a growable buffer with zeroed initial contents.
        ///
        /// - Parameters:
        ///   - minimumCapacity: The minimum initial capacity in bytes.
        ///   - alignment: Memory alignment requirement.
        ///   - growthPolicy: Strategy for computing new capacity (default: doubling).
        /// - Throws: `Buffer.Aligned.Error` if allocation fails.
        @inlinable
        public static func zeroed(
            minimumCapacity: Int,
            alignment: Binary.Alignment,
            growthPolicy: Growth.Policy = .doubling
        ) throws(Aligned.Error) -> Self {
            var result = try Self(
                minimumCapacity: minimumCapacity,
                alignment: alignment,
                growthPolicy: growthPolicy
            )
            _ = result._storage.withUnsafeMutableBytes { ptr in
                ptr.initializeMemory(as: UInt8.self, repeating: 0)
            }
            return result
        }
    }
}

// MARK: - Capacity Properties

extension Buffer.Growable {
    /// The current capacity (addressable bytes).
    ///
    /// This equals the underlying storage's byte count.
    /// "Meaningful bytes" is tracked by `Binary.Cursor.writerIndex`, not here.
    @inlinable
    public var count: Int {
        _storage.count
    }

    /// Alias for `count` (capacity == addressable bytes).
    @inlinable
    public var capacity: Int {
        _storage.count
    }
}

// MARK: - Capacity Management

extension Buffer.Growable {
    /// Ensures the buffer has at least the specified capacity, preserving existing bytes.
    ///
    /// If the current capacity is sufficient, this is a no-op.
    /// If growth is needed, bytes in `[0..<min(oldCapacity, newCapacity)]` are preserved.
    ///
    /// - Parameter minimum: The minimum required capacity.
    /// - Throws: `Buffer.Aligned.Error` if reallocation fails.
    /// - Complexity: O(n) when reallocation occurs, O(1) otherwise.
    @inlinable
    public mutating func ensureCapacity(minimum: Int) throws(Buffer.Aligned.Error) {
        guard minimum > _storage.count else { return }

        let newCapacity = growthPolicy.nextCapacity(current: _storage.count, required: minimum)
        try reallocate(to: newCapacity, preserving: true)
    }

    /// Ensures the buffer has at least the specified capacity without bounds checking.
    ///
    /// - Parameters:
    ///   - __unchecked: Marker parameter.
    ///   - minimum: The minimum required capacity.
    /// - Precondition: Reallocation must succeed.
    @inlinable
    public mutating func ensureCapacity(__unchecked: Void = (), minimum: Int) {
        guard minimum > _storage.count else { return }

        let newCapacity = growthPolicy.nextCapacity(current: _storage.count, required: minimum)
        do {
            try reallocate(to: newCapacity, preserving: true)
        } catch {
            preconditionFailure("Buffer reallocation failed: \(error)")
        }
    }

    /// Reserves capacity without preserving existing contents.
    ///
    /// This is faster than `ensureCapacity` when you don't need the existing data.
    /// Use this when you're about to overwrite the entire buffer.
    ///
    /// - Parameter minimum: The minimum required capacity.
    /// - Throws: `Buffer.Aligned.Error` if reallocation fails.
    /// - Complexity: O(1) for the copy (no data preserved).
    @inlinable
    public mutating func reserveDiscardingContents(minimum: Int) throws(Buffer.Aligned.Error) {
        guard minimum > _storage.count else { return }

        let newCapacity = growthPolicy.nextCapacity(current: _storage.count, required: minimum)
        try reallocate(to: newCapacity, preserving: false)
    }

    /// Internal reallocation helper.
    @usableFromInline
    internal mutating func reallocate(to newCapacity: Int, preserving: Bool) throws(Buffer.Aligned.Error) {
        var newStorage = try Buffer.Aligned(byteCount: newCapacity, alignment: alignment)

        if preserving {
            let bytesToCopy = min(_storage.count, newCapacity)
            newStorage.withUnsafeMutableBytes { dest in
                _storage.withUnsafeBytes { src in
                    dest.copyMemory(from: UnsafeRawBufferPointer(rebasing: src.prefix(bytesToCopy)))
                }
            }
        }

        _storage = newStorage
    }
}

// MARK: - Byte Access (typed throws)

extension Buffer.Growable {
    /// Provides read-only access to the buffer's bytes.
    ///
    /// - Parameter body: A closure that receives a pointer to the buffer.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by the closure (use `Never` for non-throwing).
    @inlinable
    public func withUnsafeBytes<R, E: Swift.Error>(
        _ body: (UnsafeRawBufferPointer) throws(E) -> R
    ) throws(E) -> R {
        try _storage.withUnsafeBytes(body)
    }

    /// Provides mutable access to the buffer's bytes.
    ///
    /// - Parameter body: A closure that receives a mutable pointer to the buffer.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by the closure (use `Never` for non-throwing).
    @inlinable
    public mutating func withUnsafeMutableBytes<R, E: Swift.Error>(
        _ body: (UnsafeMutableRawBufferPointer) throws(E) -> R
    ) throws(E) -> R {
        try _storage.withUnsafeMutableBytes(body)
    }
}

// MARK: - Span Access

extension Buffer.Growable {
    /// Read-only span of the buffer as bytes.
    @inlinable
    public var bytes: Span<UInt8> {
        @_lifetime(borrow self)
        borrowing get {
            _storage.bytes
        }
    }

    /// Mutable span of the buffer as bytes.
    @inlinable
    public var mutableBytes: MutableSpan<UInt8> {
        @_lifetime(&self)
        mutating get {
            _storage.mutableBytes
        }
    }
}

// MARK: - Binary.Mutable Conformance

extension Buffer.Growable {
    /// Address space marker for buffer memory positions.
    public typealias Space = Buffer.Aligned.Space

    /// Scalar type for index arithmetic.
    public typealias Scalar = Buffer.Aligned.Scalar
}

extension Buffer.Growable: Binary.Mutable {}
