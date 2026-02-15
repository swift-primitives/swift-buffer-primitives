// MARK: - Copyable Conformances for Ring.Small

extension Buffer.Ring.Small where Element: Copyable {

    /// Returns the front element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekFront: Element {
        switch _storage {
        case .heap(let heap): return heap.peekFront
        case .inline(let buf): return buf.peekFront
        }
    }

    /// Returns the back element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekBack: Element {
        switch _storage {
        case .heap(let heap): return heap.peekBack
        case .inline(let buf): return buf.peekBack
        }
    }

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

// MARK: - CoW-Safe Mutations

extension Buffer.Ring.Small where Element: Copyable {

    /// Pushes an element to the back (CoW-safe).
    @inlinable
    public mutating func pushBack(_ element: consuming Element) {
        switch _storage {
        case .heap(var buf):
            buf.ensureUnique()
            buf.pushBack(consume element)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            if !buf.isFull {
                _ = buf.pushBack(consume element)
                self = Self(_storage: .inline(consume buf))
            } else {
                self = Self(_storage: .inline(consume buf))
                _spillToHeap()
                switch _storage {
                case .heap(var buf):
                    buf.pushBack(consume element)
                    self = Self(_storage: .heap(consume buf))
                case .inline(var buf):
                    self = Self(_storage: .inline(consume buf))
                    fatalError("_spillToHeap must transition to heap")
                }
            }
        }
    }

    /// Removes and returns the element at the front (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popFront() -> Element {
        switch _storage {
        case .heap(var buf):
            buf.ensureUnique()
            let element = buf.popFront()
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf.popFront()
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    /// Pushes an element to the front (CoW-safe).
    @inlinable
    public mutating func pushFront(_ element: consuming Element) {
        switch _storage {
        case .heap(var buf):
            buf.ensureUnique()
            buf.pushFront(consume element)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            if !buf.isFull {
                _ = buf.pushFront(consume element)
                self = Self(_storage: .inline(consume buf))
            } else {
                self = Self(_storage: .inline(consume buf))
                _spillToHeap()
                switch _storage {
                case .heap(var buf):
                    buf.pushFront(consume element)
                    self = Self(_storage: .heap(consume buf))
                case .inline(var buf):
                    self = Self(_storage: .inline(consume buf))
                    fatalError("_spillToHeap must transition to heap")
                }
            }
        }
    }

    /// Removes and returns the element at the back (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popBack() -> Element {
        switch _storage {
        case .heap(var buf):
            buf.ensureUnique()
            let element = buf.popBack()
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf.popBack()
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    /// Removes all elements from the buffer (CoW-safe).
    ///
    /// Resets to inline mode.
    @inlinable
    public mutating func removeAll() {
        switch _storage {
        case .heap(var buf):
            buf.removeAll()
            self = Self(_storage: .inline(Buffer<Element>.Ring.Inline<inlineCapacity>()))
            _ = consume buf
        case .inline(var buf):
            buf.removeAll()
            self = Self(_storage: .inline(consume buf))
        }
    }

    /// Removes all elements from the buffer (CoW-safe).
    ///
    /// - Parameter keepingCapacity: If `true` and the buffer has spilled,
    ///   stays in heap mode. If `false`, resets to inline mode.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool) {
        if keepingCapacity {
            switch _storage {
            case .heap(var buf):
                buf.ensureUnique()
                buf.removeAll()
                self = Self(_storage: .heap(consume buf))
            case .inline(var buf):
                buf.removeAll()
                self = Self(_storage: .inline(consume buf))
            }
        } else {
            removeAll()
        }
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
