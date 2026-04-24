// MARK: - Copyable Conformances for Ring.Small


extension Buffer.Ring.Small where Element: Copyable {

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
            self = Self(_storage: .inline(consume buf))
            if minimumCapacity > Index<Element>.Count(UInt(inlineCapacity)) {
                _spillToHeap(minimumCapacity: minimumCapacity)
            }
        }
    }
}

// MARK: - Spill to Heap (Copyable)

extension Buffer.Ring.Small where Element: Copyable {

    /// Copies inline ring elements to heap storage and activates heap mode.
    @usableFromInline
    mutating func _spillToHeap() {
        switch _storage {
        case .heap(var buf):
            self = Self(_storage: .heap(consume buf))
            return
        case .inline(var buf):
            let currentCount = buf.count
            let newCapacity = Index<Element>.Count(UInt(inlineCapacity * 2))
            let newStorage = Storage<Element>.Heap.create(minimumCapacity: newCapacity)

            Buffer.Ring.linearize(
                header: buf.header,
                source: buf.storage,
                to: newStorage
            )

            var newHeader = Buffer.Ring.Header(capacity: newStorage.slotCapacity)
            newHeader.count = currentCount
            newStorage.initialization = newHeader.initialization

            self = Self(_storage: .heap(Buffer<Element>.Ring(header: newHeader, storage: newStorage)))
            _ = consume buf
        }
    }

    /// Copies inline ring elements to heap storage with at least the given capacity.
    @usableFromInline
    mutating func _spillToHeap(minimumCapacity: Index<Element>.Count) {
        switch _storage {
        case .heap(var buf):
            self = Self(_storage: .heap(consume buf))
            return
        case .inline(var buf):
            let currentCount = buf.count
            let newStorage = Storage<Element>.Heap.create(minimumCapacity: minimumCapacity)

            Buffer.Ring.linearize(
                header: buf.header,
                source: buf.storage,
                to: newStorage
            )

            var newHeader = Buffer.Ring.Header(capacity: newStorage.slotCapacity)
            newHeader.count = currentCount
            newStorage.initialization = newHeader.initialization

            self = Self(_storage: .heap(Buffer<Element>.Ring(header: newHeader, storage: newStorage)))
            _ = consume buf
        }
    }
}

// MARK: - CoW-Safe Internal Mutations

extension Buffer.Ring.Small where Element: Copyable {

    @usableFromInline
    mutating func _pushBack(_ element: consuming Element) {
        switch _storage {
        case .heap(var buf):
            buf._pushBack(consume element)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            if !buf.isFull {
                _ = buf._pushBack(consume element)
                self = Self(_storage: .inline(consume buf))
            } else {
                self = Self(_storage: .inline(consume buf))
                _spillToHeap()
                switch _storage {
                case .heap(var buf):
                    buf._pushBack(consume element)
                    self = Self(_storage: .heap(consume buf))
                case .inline(var buf):
                    self = Self(_storage: .inline(consume buf))
                    fatalError("_spillToHeap must transition to heap")
                }
            }
        }
    }

    @usableFromInline
    mutating func _popFront() -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf._popFront()
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf._popFront()
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    @usableFromInline
    mutating func _pushFront(_ element: consuming Element) {
        switch _storage {
        case .heap(var buf):
            buf._pushFront(consume element)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            if !buf.isFull {
                _ = buf._pushFront(consume element)
                self = Self(_storage: .inline(consume buf))
            } else {
                self = Self(_storage: .inline(consume buf))
                _spillToHeap()
                switch _storage {
                case .heap(var buf):
                    buf._pushFront(consume element)
                    self = Self(_storage: .heap(consume buf))
                case .inline(var buf):
                    self = Self(_storage: .inline(consume buf))
                    fatalError("_spillToHeap must transition to heap")
                }
            }
        }
    }

    @usableFromInline
    mutating func _popBack() -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf._popBack()
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf._popBack()
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    @usableFromInline
    mutating func _removeAll() {
        switch _storage {
        case .heap(var buf):
            buf._removeAll()
            self = Self(_storage: .inline(Buffer<Element>.Ring.Inline<inlineCapacity>()))
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
where Tag == Buffer<Element>.Ring.Peek,
      Base == Buffer<Element>.Ring.Small<n>,
      Element: Copyable
{
    /// Returns the front element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var front: Element {
        switch unsafe base.value._storage {
        case .heap(let heap):
            return unsafe heap.storage.pointer(at: heap.header.head).pointee
        case .inline(let buf):
            let bounded = Index<Element>.Bounded<n>(buf.header.head)!
            let ptr: UnsafePointer<Element> = unsafe buf.storage.pointer(at: bounded)
            return unsafe ptr.pointee
        }
    }

    /// Returns the back element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var back: Element {
        switch unsafe base.value._storage {
        case .heap(let heap):
            return unsafe heap.storage.pointer(at: Index.Modular.advanced(
                heap.header.head,
                by: Index<Element>.Offset(fromZero: heap.header.count.subtract.saturating(.one).map(Ordinal.init)),
                capacity: heap.header.capacity
            )).pointee
        case .inline(let buf):
            let bounded = Index<Element>.Bounded<n>(
                Index.Modular.advanced(
                    buf.header.head,
                    by: Index<Element>.Offset(fromZero: buf.header.count.subtract.saturating(.one).map(Ordinal.init)),
                    capacity: buf.header.capacity
                )
            )!
            let ptr: UnsafePointer<Element> = unsafe buf.storage.pointer(at: bounded)
            return unsafe ptr.pointee
        }
    }
}

// MARK: - Push Operations (Copyable)

extension Property.View.Typed.Valued
where Tag == Buffer<Element>.Ring.Push,
      Base == Buffer<Element>.Ring.Small<n>,
      Element: Copyable
{
    /// Pushes an element to the back (CoW-safe).
    @inlinable
    public mutating func back(_ element: consuming Element) {
        unsafe base.value._pushBack(consume element)
    }

    /// Pushes an element to the front (CoW-safe).
    @inlinable
    public mutating func front(_ element: consuming Element) {
        unsafe base.value._pushFront(consume element)
    }
}

// MARK: - Pop Operations (Copyable)

extension Property.View.Typed.Valued
where Tag == Buffer<Element>.Ring.Pop,
      Base == Buffer<Element>.Ring.Small<n>,
      Element: Copyable
{
    /// Removes and returns the element at the front (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func front() -> Element {
        unsafe base.value._popFront()
    }

    /// Removes and returns the element at the back (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func back() -> Element {
        unsafe base.value._popBack()
    }
}

// MARK: - Remove Operations (Copyable)

extension Property.View.Typed.Valued
where Tag == Buffer<Element>.Ring.Remove,
      Base == Buffer<Element>.Ring.Small<n>,
      Element: Copyable
{
    /// Removes all elements from the buffer (CoW-safe).
    ///
    /// Resets to inline mode.
    @inlinable
    public mutating func all() {
        unsafe base.value._removeAll()
    }

    /// Removes all elements from the buffer (CoW-safe).
    ///
    /// - Parameter keepingCapacity: If `true` and the buffer has spilled,
    ///   stays in heap mode. If `false`, resets to inline mode.
    @inlinable
    public mutating func all(keepingCapacity: Bool) {
        unsafe base.value._removeAll(keepingCapacity: keepingCapacity)
    }
}

// MARK: - Subscript (Copyable with CoW)

extension Buffer.Ring.Small where Element: Copyable {
    /// Accesses the element at the given logical index with copy-on-write semantics.
    ///
    /// - Parameter index: The logical index of the element to access.
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
                let physical = Index.Modular.physical(
                    forLogical: index, head: heap.header.head, capacity: heap.header.capacity)
                yield unsafe &heap.storage.pointer(at: physical).pointee
            case .inline(let buf):
                let bounded = Index<Element>.Bounded<inlineCapacity>(
                    Index.Modular.physical(
                        forLogical: index, head: buf.header.head, capacity: buf.header.capacity)
                )!
                yield unsafe &buf.storage.pointer(at: bounded).pointee
            }
        }
    }
}
