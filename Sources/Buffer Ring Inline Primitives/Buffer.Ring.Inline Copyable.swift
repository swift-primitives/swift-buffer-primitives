// MARK: - Peek Operations (Copyable)

extension Property.View.Read.Typed.Valued
where Tag == Buffer<Element>.Ring.Peek,
      Base == Buffer<Element>.Ring.Inline<n>,
      Element: Copyable
{
    /// Returns the front element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var front: Element {
        let bounded = Index<Element>.Bounded<n>(unsafe base.pointee.header.head)!
        let ptr: UnsafePointer<Element> = unsafe base.pointee.storage.pointer(at: bounded)
        return unsafe ptr.pointee
    }

    /// Returns the back element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var back: Element {
        let bounded = Index<Element>.Bounded<n>(
            Index.Modular.advanced(
                unsafe base.pointee.header.head,
                by: Index<Element>.Offset(fromZero: unsafe base.pointee.header.count.subtract.saturating(.one).map(Ordinal.init)),
                capacity: unsafe base.pointee.header.capacity
            )
        )!
        let ptr: UnsafePointer<Element> = unsafe base.pointee.storage.pointer(at: bounded)
        return unsafe ptr.pointee
    }
}

// MARK: - Array Initialization

extension Buffer.Ring.Inline where Element: Copyable {

    /// Creates an inline ring buffer populated with the given elements.
    ///
    /// - Parameter elements: The elements to populate the buffer with.
    /// - Throws: ``Error/capacityExceeded`` if `elements.count` exceeds `capacity`.
    @inlinable
    public init(_ elements: [Element]) throws(Error) {
        guard elements.count <= capacity else { throw .capacityExceeded }
        var buffer = Self()
        for element in elements {
            _ = buffer._pushBack(element)
        }
        self = buffer
    }
}

// MARK: - Sequence.Protocol

extension Buffer.Ring.Inline: Sequence.`Protocol` where Element: Copyable {
    /// Iterator over ring inline buffer elements.
    ///
    /// Uses pointer-based iteration with ring wrap-around logic.
    /// The iterator is only valid while the source buffer exists.
    ///
    /// Uses pointer-based iteration with ring wrap-around logic.
    /// The iterator is only valid while the source buffer exists.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        let base: UnsafePointer<Element>
        @usableFromInline
        let header: Buffer.Ring.Header
        @usableFromInline
        var current: Index<Element>
        @usableFromInline
        let end: Index<Element>
        @usableFromInline
        var _element: Element? = nil

        @inlinable
        init(base: UnsafePointer<Element>, header: Buffer.Ring.Header) {
            self.base = base
            self.header = header
            self.current = .zero
            self.end = header.count.map(Ordinal.init)
        }

        @inlinable
        @_lifetime(&self)
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            let ptr = unsafe withUnsafeMutablePointer(to: &_element) { p in
                unsafe UnsafePointer<Element>(
                    unsafe UnsafeRawPointer(p).assumingMemoryBound(to: Element.self)
                )
            }
            guard maximumCount > .zero else {
                let span = unsafe Span(_unsafeStart: ptr, count: 0)
                return unsafe _overrideLifetime(span, mutating: &self)
            }
            guard let value = next() else {
                let span = unsafe Span(_unsafeStart: ptr, count: 0)
                return unsafe _overrideLifetime(span, mutating: &self)
            }
            _element = value
            let span = unsafe Span(_unsafeStart: ptr, count: 1)
            return unsafe _overrideLifetime(span, mutating: &self)
        }

        @_lifetime(self: immortal)
        @inlinable
        public mutating func next() -> Element? {
            guard current < end else { return nil }
            let physicalIdx = Index.Modular.physical(
                forLogical: current,
                head: header.head,
                capacity: header.capacity
            )
            current += .one
            return unsafe base[physicalIdx]
        }
    }

    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let bounded = Index<Element>.Bounded<capacity>(.zero)!
        let base: UnsafePointer<Element> = unsafe storage.pointer(at: bounded)
        return Iterator(base: base, header: header)
    }
}

// MARK: - Swift.Sequence
// WORKAROUND: Swift.Sequence conformance commented out
// WHY: Storage.Inline uses @_rawLayout which is unconditionally ~Copyable,
//      preventing the Copyable requirement for Swift.Sequence conformance
// WHEN TO REMOVE: When @_rawLayout is replaced with conditionally-Copyable InlineArray
// TRACKING: INV-INLINE-004a
//
// extension Buffer.Ring.Inline: Swift.Sequence where Element: Copyable {
//     @inlinable
//     public var underestimatedCount: Int { Int(bitPattern: header.count.rawValue.rawValue) }
// }