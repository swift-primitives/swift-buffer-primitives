// StorageModule — Minimal reproduction of Storage.Inline pattern
//
// Provides a ~Copyable struct with @_rawLayout field + additional stored property,
// mimicking Storage<Element>.Inline<capacity> from storage-primitives.

/// Minimal bit vector (replaces Bit.Vector.Static).
@_rawLayout(likeArrayOf: UInt, count: 4)
public struct InlineBitVector: ~Copyable {
    @inlinable
    public init() {}

    /// Subscript that reads a bit (simplified — real version uses word indexing).
    @inlinable
    public func isSet(_ index: Int) -> Bool {
        unsafe withUnsafePointer(to: self) { ptr in
            let raw = UnsafeRawPointer(ptr)
            let word = unsafe raw.load(fromByteOffset: (index / 64) * 8, as: UInt.self)
            return (word >> (index % 64)) & 1 == 1
        }
    }
}

/// Minimal inline storage (replaces Storage<Element>.Inline<capacity>).
public struct InlineStorage<Element: ~Copyable>: ~Copyable {
    @_rawLayout(likeArrayOf: Element, count: 8)
    public struct _RawElements: ~Copyable {
        @inlinable
        public init() {}
    }

    public var slots: InlineBitVector
    public var elements: _RawElements

    @inlinable
    public init() {
        self.slots = InlineBitVector()
        self.elements = _RawElements()
    }

    /// Stride-based pointer access (mimics Storage.Inline.pointer(at:)).
    @inlinable
    public func pointer(at index: Int) -> UnsafePointer<Element> {
        unsafe withUnsafePointer(to: elements) { rawPtr in
            unsafe UnsafeRawPointer(rawPtr)
                .advanced(by: index * MemoryLayout<Element>.stride)
                .assumingMemoryBound(to: Element.self)
        }
    }

    /// Cleanup helper with actual stride arithmetic (mimics _deinitializeTrackedSlots).
    @inlinable
    public func cleanup() {
        for i in 0..<8 {
            if slots.isSet(i) {
                unsafe UnsafeMutablePointer(mutating: pointer(at: i))
                    .deinitialize(count: 1)
            }
        }
    }
}

/// Heap-backed storage (class reference, no @_rawLayout).
public final class HeapStorage<Element: ~Copyable>: @unchecked Sendable {
    @usableFromInline
    let _buffer: UnsafeMutablePointer<Element>
    public let capacity: Int

    public init(capacity: Int) {
        self.capacity = capacity
        self._buffer = .allocate(capacity: capacity)
    }

    /// Stride-based pointer access.
    @inlinable
    public func pointer(at index: Int) -> UnsafePointer<Element> {
        unsafe UnsafePointer(_buffer.advanced(by: index))
    }

    /// Cleanup with stride arithmetic.
    @inlinable
    public func cleanup() {
        for i in 0..<capacity {
            unsafe _buffer.advanced(by: i).deinitialize(count: 1)
        }
    }

    deinit {
        _buffer.deallocate()
    }
}
