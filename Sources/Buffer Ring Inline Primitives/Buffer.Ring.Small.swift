// MARK: - Extensions for Ring.Small (declared in Core)

extension Buffer.Ring.Small where Element: ~Copyable {

    /// Creates an empty small ring buffer with inline storage.
    @inlinable
    public init() {
        self.init(
            _storage: .inline(Buffer<Element>.Ring.Inline<inlineCapacity>())
        )
    }

    /// Whether the buffer has spilled to heap storage.
    @inlinable
    public var isSpilled: Bool {
        switch _storage {
        case .heap: return true
        case .inline: return false
        }
    }

    /// The number of elements in the buffer.
    @inlinable
    public var count: Index<Element>.Count {
        switch _storage {
        case .heap(let heap): return heap.count
        case .inline(let buf): return buf.count
        }
    }

    /// Whether the buffer has no elements.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// The current capacity of the buffer.
    @inlinable
    public var capacity: Index<Element>.Count {
        switch _storage {
        case .heap(let heap): return heap.capacity
        case .inline(_): return Index<Element>.Count(UInt(inlineCapacity))
        }
    }

    /// Whether the buffer is full (only meaningful in inline mode).
    @inlinable
    public var isFull: Bool {
        switch _storage {
        case .heap: return false
        case .inline(let buf): return buf.isFull
        }
    }

}

// MARK: - Tag View Typealiases

extension Buffer.Ring.Small where Element: ~Copyable {
    public enum Push {
        public typealias View = Property<Buffer<Element>.Ring.Push, Buffer<Element>.Ring.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }

    public enum Pop {
        public typealias View = Property<Buffer<Element>.Ring.Pop, Buffer<Element>.Ring.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }

    public enum Peek {
        public typealias View = Property<Buffer<Element>.Ring.Peek, Buffer<Element>.Ring.Small<inlineCapacity>>.View.Read.Typed<Element>.Valued<inlineCapacity>
    }

    public enum Remove {
        public typealias View = Property<Buffer<Element>.Ring.Remove, Buffer<Element>.Ring.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
}

// MARK: - Internal Mutations

extension Buffer.Ring.Small where Element: ~Copyable {

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
                _spillToHeapMoving()
                switch _storage {
                case .heap(var buf):
                    buf._pushBack(consume element)
                    self = Self(_storage: .heap(consume buf))
                case .inline(var buf):
                    self = Self(_storage: .inline(consume buf))
                    fatalError("_spillToHeapMoving must transition to heap")
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
                _spillToHeapMoving()
                switch _storage {
                case .heap(var buf):
                    buf._pushFront(consume element)
                    self = Self(_storage: .heap(consume buf))
                case .inline(var buf):
                    self = Self(_storage: .inline(consume buf))
                    fatalError("_spillToHeapMoving must transition to heap")
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

// MARK: - Property.View.Typed.Valued (.push, .pop, .peek, .remove)

extension Buffer.Ring.Small where Element: ~Copyable {
    @inlinable
    public var push: Push.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Push.View = unsafe .init(&self)
            yield &view
        }
    }

    @inlinable
    public var pop: Pop.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Pop.View = unsafe .init(&self)
            yield &view
        }
    }

    @inlinable
    public var peek: Peek.View {
        _read {
            yield Peek.View(borrowing: self)
        }
    }

    @inlinable
    public var remove: Remove.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Remove.View = unsafe .init(&self)
            yield &view
        }
    }
}

// MARK: - Push Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Buffer<Element>.Ring.Push,
      Base == Buffer<Element>.Ring.Small<n>,
      Element: ~Copyable
{
    /// Pushes an element to the back of the ring.
    ///
    /// If inline storage is full, spills to heap automatically using moves.
    @inlinable
    public mutating func back(_ element: consuming Element) {
        unsafe base.pointee._pushBack(consume element)
    }

    /// Pushes an element to the front of the ring.
    ///
    /// If inline storage is full, spills to heap automatically using moves.
    @inlinable
    public mutating func front(_ element: consuming Element) {
        unsafe base.pointee._pushFront(consume element)
    }
}

// MARK: - Pop Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Buffer<Element>.Ring.Pop,
      Base == Buffer<Element>.Ring.Small<n>,
      Element: ~Copyable
{
    /// Removes and returns the element at the front.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func front() -> Element {
        unsafe base.pointee._popFront()
    }

    /// Removes and returns the element at the back.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func back() -> Element {
        unsafe base.pointee._popBack()
    }
}

// MARK: - Remove Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Buffer<Element>.Ring.Remove,
      Base == Buffer<Element>.Ring.Small<n>,
      Element: ~Copyable
{
    /// Removes all elements from the buffer.
    ///
    /// Resets to inline mode.
    @inlinable
    public mutating func all() {
        unsafe base.pointee._removeAll()
    }

    /// Removes all elements from the buffer.
    ///
    /// - Parameter keepingCapacity: If `true` and the buffer has spilled,
    ///   stays in heap mode. If `false`, resets to inline mode.
    @inlinable
    public mutating func all(keepingCapacity: Bool) {
        unsafe base.pointee._removeAll(keepingCapacity: keepingCapacity)
    }
}

// MARK: - Spill to Heap (~Copyable)

extension Buffer.Ring.Small where Element: ~Copyable {

    /// Moves inline ring elements to heap storage and activates heap mode.
    ///
    /// Linearizes the ring: inline elements may wrap around, so we iterate
    /// in logical order using the header's initialization regions and move
    /// each element to contiguous heap slots.
    @usableFromInline
    mutating func _spillToHeapMoving() {
        switch _storage {
        case .heap(var buf):
            self = Self(_storage: .heap(consume buf))
            return
        case .inline(var buf):
            let currentCount = buf.count
            let newCapacity = Index<Element>.Count(UInt(inlineCapacity * 2))
            let newStorage = Storage<Element>.Heap.create(minimumCapacity: newCapacity)

            // Move elements in logical (FIFO) order from wrapped inline to linear heap
            buf.header.initialization.linearize { range, offset in
                buf.storage.move(range: range, to: newStorage, at: offset)
            }

            // Reset inline state so its deinit is a no-op
            buf.header = Buffer.Ring.Header(
                capacity: Index<Element>.Count(UInt(inlineCapacity))
            )
            buf.storage.initialization = .empty

            var newHeader = Buffer.Ring.Header(capacity: newStorage.slotCapacity)
            newHeader.count = currentCount
            newStorage.initialization = newHeader.initialization

            self = Self(_storage: .heap(Buffer<Element>.Ring(header: newHeader, storage: newStorage)))
            // buf goes out of scope — deinit runs on empty state (no-op)
        }
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Ring.Small: Sequence.Drain.`Protocol` where Element: Copyable {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while !isEmpty {
            body(_popFront())
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Ring.Small: Sequence.Clearable where Element: Copyable {
    @inlinable
    public mutating func removeAll() {
        _removeAll()
    }
}

// MARK: - Property.View (.drain)

extension Buffer.Ring.Small where Element: ~Copyable {
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}
