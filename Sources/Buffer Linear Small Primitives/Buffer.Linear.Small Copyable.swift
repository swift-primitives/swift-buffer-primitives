// MARK: - Copyable Conformances for Linear.Small

extension Buffer.Linear.Small where Element: Copyable {

    /// Ensures this buffer has unique heap storage, returning whether a copy was made.
    ///
    /// In inline mode, storage is always unique (value type). In heap mode,
    /// delegates to the heap buffer's CoW check.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        switch _storage {
        case .heap(var buf):
            let copied = buf.ensureUnique()
            self = Self(_storage: .heap(consume buf))
            return copied
        case .inline(var buf):
            self = Self(_storage: .inline(consume buf))
            return false
        }
    }

    /// Ensures the buffer can hold at least `minimumCapacity` elements.
    ///
    /// May trigger spill to heap if the requested capacity exceeds inline capacity.
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Index<Element>.Count) {
        switch _storage {
        case .heap(var buf):
            buf.reserveCapacity(minimumCapacity)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            if minimumCapacity > Index<Element>.Count(UInt(inlineCapacity)) {
                self = Self(_storage: .inline(consume buf))
                _spillToHeap(minimumCapacity: minimumCapacity)
            } else {
                self = Self(_storage: .inline(consume buf))
            }
        }
    }
}

// MARK: - CoW-Safe Mutations

extension Buffer.Linear.Small where Element: Copyable {

    /// Appends an element to the back of the buffer (CoW-safe).
    ///
    /// If inline storage is full, spills to heap automatically.
    @inlinable
    public mutating func append(_ element: consuming Element) {
        switch _storage {
        case .heap(var buf):
            buf.append(consume element)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            if !buf.isFull {
                _ = buf.append(consume element)
                self = Self(_storage: .inline(consume buf))
            } else {
                self = Self(_storage: .inline(consume buf))
                _spillToHeap()
                // After spill, _storage is .heap — append into it
                switch _storage {
                case .heap(var heapBuf):
                    heapBuf.append(consume element)
                    self = Self(_storage: .heap(consume heapBuf))
                case .inline(var inlineBuf):
                    self = Self(_storage: .inline(consume inlineBuf))
                    fatalError("expected heap mode after spill")
                }
            }
        }
    }

    /// Removes and returns the element at the given index (CoW-safe).
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func remove(at index: Index<Element>) -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf.remove(at: index)
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf.remove(at: index)
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    /// Replaces the element at the given index, returning the old element (CoW-safe).
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func replace(at index: Index<Element>, with newElement: consuming Element) -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf.replace(at: index, with: consume newElement)
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf.replace(at: index, with: consume newElement)
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }
}

// MARK: - CoW-Safe Internal Mutations

extension Buffer.Linear.Small where Element: Copyable {

    @usableFromInline
    mutating func _removeFirst() -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf._removeFirst()
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf._removeFirst()
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    @usableFromInline
    mutating func _removeLast() -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf._removeLast()
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf._removeLast()
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    @usableFromInline
    mutating func _removeAll() {
        switch _storage {
        case .heap(var buf):
            buf._removeAll()
            self = Self(_storage: .inline(Buffer<Element>.Linear.Inline<inlineCapacity>()))
            _ = consume buf
        case .inline(var buf):
            buf._removeAll()
            self = Self(_storage: .inline(consume buf))
        }
    }

    @usableFromInline
    mutating func _removeAll(keepingCapacity: Bool) {
        if keepingCapacity {
            switch _storage {
            case .heap(var buf):
                buf._removeAll()
                self = Self(_storage: .heap(consume buf))
            case .inline(var buf):
                buf._removeAll()
                self = Self(_storage: .inline(consume buf))
            }
        } else {
            _removeAll()
        }
    }
}

// MARK: - Peek Operations (Copyable)

extension Property.View.Read.Typed.Valued
where Tag == Buffer<Element>.Linear.Peek,
      Base == Buffer<Element>.Linear.Small<n>,
      Element: Copyable
{
    /// Returns the first element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var front: Element {
        switch unsafe base.pointee._storage {
        case .heap(let heap):
            return unsafe heap.storage.pointer(at: .zero).pointee
        case .inline(let buf):
            return unsafe buf.storage.pointer(at: Index<Element>.Bounded<n>(.zero)!).pointee
        }
    }

    /// Returns the last element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var back: Element {
        switch unsafe base.pointee._storage {
        case .heap(let heap):
            return unsafe heap.storage.pointer(at: heap.header.count.subtract.saturating(.one).map(Ordinal.init)).pointee
        case .inline(let buf):
            return unsafe buf.storage.pointer(at: Index<Element>.Bounded<n>(buf.header.count.subtract.saturating(.one).map(Ordinal.init))!).pointee
        }
    }
}

// MARK: - Remove Operations (Copyable)

extension Property.View.Typed.Valued
where Tag == Buffer<Element>.Linear.Remove,
      Base == Buffer<Element>.Linear.Small<n>,
      Element: Copyable
{
    /// Removes and returns the first element (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func first() -> Element {
        unsafe base.pointee._removeFirst()
    }

    /// Removes and returns the last element (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func last() -> Element {
        unsafe base.pointee._removeLast()
    }

    /// Removes all elements from the buffer (CoW-safe).
    ///
    /// Resets to inline mode.
    @inlinable
    public mutating func all() {
        unsafe base.pointee._removeAll()
    }

    /// Removes all elements from the buffer (CoW-safe).
    ///
    /// - Parameter keepingCapacity: If `true` and the buffer has spilled,
    ///   stays in heap mode. If `false`, resets to inline mode.
    @inlinable
    public mutating func all(keepingCapacity: Bool) {
        unsafe base.pointee._removeAll(keepingCapacity: keepingCapacity)
    }
}

// MARK: - Subscript (Copyable with CoW)

extension Buffer.Linear.Small where Element: Copyable {
    /// Accesses the element at the given index with copy-on-write semantics.
    ///
    /// - Parameter index: The index of the element to access.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        _read {
            switch _storage {
            case .heap(let heap):
                yield heap[index]
            case .inline(let buf):
                yield buf[index]
            }
        }
        _modify {
            ensureUnique()
            switch _storage {
            case .heap(let heap):
                yield unsafe &heap.storage.pointer(at: index).pointee
            case .inline(let buf):
                let bounded = Index<Element>.Bounded<inlineCapacity>(index)!
                yield unsafe &buf.storage.pointer(at: bounded).pointee
            }
        }
    }
}

// MARK: - Mutable Span (Copyable with CoW)

extension Buffer.Linear.Small where Element: Copyable {
    /// Mutable span with copy-on-write semantics.
    ///
    /// Ensures unique ownership before providing mutable access.
    public var mutableSpan: MutableSpan<Element> {
        @inlinable
        mutating get {
            ensureUnique()
            let start: UnsafeMutablePointer<Element>
            let elementCount: Index<Element>.Count
            switch _storage {
            case .heap(let heap):
                unsafe start = heap.storage.pointer(at: .zero)
                elementCount = heap.header.count
            case .inline(let buf):
                let inlineBounded = Index<Element>.Bounded<inlineCapacity>(.zero)!
                unsafe start = buf.storage.pointer(at: inlineBounded)
                elementCount = buf.header.count
            }
            let span = unsafe MutableSpan(_unsafeStart: start, count: elementCount)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
    }
}