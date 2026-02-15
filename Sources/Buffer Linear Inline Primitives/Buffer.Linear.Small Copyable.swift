// MARK: - Copyable Conformances for Linear.Small

extension Buffer.Linear.Small where Element: Copyable {

    /// Returns the first element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekFront: Element {
        switch _storage {
        case .heap(let heap): return heap.peekFront
        case .inline(let buf): return buf.peekFront
        }
    }

    /// Returns the last element without removing it.
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
                    fatalError()
                }
            }
        }
    }

    /// Removes and returns the first element (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func removeFirst() -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf.removeFirst()
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf.removeFirst()
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    /// Removes and returns the last element (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func removeLast() -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf.removeLast()
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf.removeLast()
            self = Self(_storage: .inline(consume buf))
            return element
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

    /// Removes all elements from the buffer (CoW-safe).
    ///
    /// Resets to inline mode.
    @inlinable
    public mutating func removeAll() {
        switch _storage {
        case .heap(var buf):
            buf.removeAll()
            self = Self(_storage: .inline(Buffer<Element>.Linear.Inline<inlineCapacity>()))
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