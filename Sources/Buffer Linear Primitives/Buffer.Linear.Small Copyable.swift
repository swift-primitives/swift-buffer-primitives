// MARK: - Copyable Conformances for Linear.Small

extension Buffer.Linear.Small where Element: Copyable {

    /// Returns the first element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekFront: Element {
        switch _heapBuffer {
        case .some(let heap): return heap.peekFront
        case .none: return _inlineBuffer.peekFront
        }
    }

    /// Returns the last element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekBack: Element {
        switch _heapBuffer {
        case .some(let heap): return heap.peekBack
        case .none: return _inlineBuffer.peekBack
        }
    }

    /// Ensures this buffer has unique heap storage, returning whether a copy was made.
    ///
    /// In inline mode, storage is always unique (value type). In heap mode,
    /// delegates to the heap buffer's CoW check.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        if _heapBuffer != nil {
            return _heapBuffer!.ensureUnique()
        }
        return false
    }

    /// Ensures the buffer can hold at least `minimumCapacity` elements.
    ///
    /// May trigger spill to heap if the requested capacity exceeds inline capacity.
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Index<Element>.Count) {
        if _heapBuffer != nil {
            _heapBuffer!.reserveCapacity(minimumCapacity)
        } else if minimumCapacity > Index<Element>.Count(Cardinal(UInt(inlineCapacity))) {
            _spillToHeap(minimumCapacity: minimumCapacity)
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
        if _heapBuffer != nil {
            _heapBuffer!.append(consume element)
        } else if !_inlineBuffer.isFull {
            _ = _inlineBuffer.append(consume element)
        } else {
            _spillToHeap()
            _heapBuffer!.append(consume element)
        }
    }

    /// Removes and returns the first element (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func consumeFront() -> Element {
        if _heapBuffer != nil {
            return _heapBuffer!.consumeFront()
        } else {
            return _inlineBuffer.consumeFront()
        }
    }

    /// Removes and returns the last element (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func removeLast() -> Element {
        if _heapBuffer != nil {
            return _heapBuffer!.removeLast()
        } else {
            return _inlineBuffer.removeLast()
        }
    }

    /// Removes and returns the element at the given index (CoW-safe).
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func remove(at index: Index<Element>) -> Element {
        if _heapBuffer != nil {
            return _heapBuffer!.remove(at: index)
        } else {
            return _inlineBuffer.remove(at: index)
        }
    }

    /// Removes all elements from the buffer (CoW-safe).
    ///
    /// Resets to inline mode.
    @inlinable
    public mutating func removeAll() {
        if _heapBuffer != nil {
            _heapBuffer!.removeAll()
            _heapBuffer = nil
            _inlineBuffer.removeAll()
        } else {
            _inlineBuffer.removeAll()
        }
    }

    /// Removes all elements from the buffer (CoW-safe).
    ///
    /// - Parameter keepingCapacity: If `true` and the buffer has spilled,
    ///   stays in heap mode. If `false`, resets to inline mode.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool) {
        if keepingCapacity {
            if _heapBuffer != nil {
                _heapBuffer!.removeAll()
            } else {
                _inlineBuffer.removeAll()
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
            switch _heapBuffer {
            case .some(let heap):
                yield heap[index]
            case .none:
                yield _inlineBuffer[index]
            }
        }
        _modify {
            if _heapBuffer != nil {
                _heapBuffer!.ensureUnique()
                yield &_heapBuffer![index]
            } else {
                yield &_inlineBuffer[index]
            }
        }
    }
}

// MARK: - Property.View (.forEach)

extension Buffer.Linear.Small where Element: Copyable {
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, Self>.View(&self)
            yield &view
        }
    }
}
