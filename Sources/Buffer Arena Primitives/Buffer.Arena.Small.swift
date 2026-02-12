public import Buffer_Primitives_Core

// MARK: - Extensions for Arena.Small (declared in Core)

extension Buffer.Arena.Small where Element: ~Copyable {

    // MARK: - Init

    /// Creates an empty small arena with inline capacity `inlineCapacity`.
    @inlinable
    public init() {
        self.init(
            _inlineBuffer: Buffer<Element>.Arena.Inline<inlineCapacity>(),
            _heapBuffer: nil
        )
    }

    /// Projected access to the heap buffer.
    ///
    /// - Precondition: `isSpilled` — callers MUST guard `_heapBuffer != nil` before access.
    @inlinable
    package var heap: Buffer<Element>.Arena {
        // Force-unwrap is necessary: Optional._modify has compiler support for
        // yielding &_heapBuffer! that arbitrary enums lack (no _modify into enum
        // payloads for ~Copyable types). Enum storage was evaluated and rejected —
        // see Research/small-buffer-storage-representation.md.
        // Safe: all callers guard `_heapBuffer != nil` before accessing `heap`.
        _read { yield _heapBuffer! }
        _modify { yield &_heapBuffer! }
    }

    // MARK: - Insert

    /// Allocates a slot, initializes the element, and returns a Position handle.
    ///
    /// If the inline buffer is full, spills to heap before inserting.
    @inlinable
    public mutating func insert(
        _ element: consuming Element
    ) -> Buffer<Element>.Arena.Position {
        if _heapBuffer != nil {
            return heap.insert(consume element)
        }
        if _inlineBuffer.isFull {
            _spillToHeap()
            return heap.insert(consume element)
        }
        return try! _inlineBuffer.insert(consume element)
    }

    /// Allocates a slot without initializing the element.
    ///
    /// If the inline buffer is full, spills to heap before allocating.
    /// Caller MUST initialize the element at `position.slot` before use.
    @inlinable
    public mutating func allocate() -> Buffer<Element>.Arena.Position {
        if _heapBuffer != nil {
            return heap.allocate()
        }
        if _inlineBuffer.isFull {
            _spillToHeap()
            return heap.allocate()
        }
        return try! _inlineBuffer.allocate()
    }

    // MARK: - Remove

    /// Validates the position, moves the element out, and releases the slot.
    ///
    /// - Throws: `.invalidPosition` if the position is stale or invalid.
    @inlinable
    public mutating func remove(
        at position: Buffer<Element>.Arena.Position
    ) throws(Buffer<Element>.Arena.Error) -> Element {
        if _heapBuffer != nil {
            return try heap.remove(at: position)
        }
        let inlineMeta = unsafe _inlineBuffer._metaPointer()
        guard unsafe Buffer<Element>.Arena.isValid(
            position, header: _inlineBuffer.header, meta: inlineMeta
        ) else {
            throw .invalidPosition
        }
        let element = unsafe _inlineBuffer._elementPointer(at: position.slot).move()
        unsafe Buffer<Element>.Arena._releaseSlot(
            position.slot, header: &_inlineBuffer.header, meta: inlineMeta
        )
        return element
    }

    /// Moves the element out of the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func remove(at slot: Index<Element>) -> Element {
        if _heapBuffer != nil {
            return heap.remove(at: slot)
        }
        return _inlineBuffer.remove(at: slot)
    }

    /// Deinitializes the element at the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func free(at slot: Index<Element>) {
        if _heapBuffer != nil {
            heap.free(at: slot)
            return
        }
        _inlineBuffer.free(at: slot)
    }

    /// Deinitializes all occupied elements and resets the arena to empty state.
    @inlinable
    public mutating func removeAll() {
        if _heapBuffer != nil {
            heap.removeAll()
            return
        }
        _inlineBuffer.removeAll()
    }

    // MARK: - Validation

    /// Returns whether the given position handle is still valid.
    @inlinable
    public mutating func isValid(
        _ position: Buffer<Element>.Arena.Position
    ) -> Bool {
        if _heapBuffer != nil {
            return heap.isValid(position)
        }
        return _inlineBuffer.isValid(position)
    }

    /// Returns whether the slot at the given index is occupied.
    @inlinable
    public func isOccupied(_ slot: Index<Element>) -> Bool {
        if _heapBuffer != nil {
            return heap.isOccupied(slot)
        }
        return _inlineBuffer.isOccupied(slot)
    }

    // MARK: - Token Access

    /// Returns the current generation token for the given slot.
    @inlinable
    public func token(at slot: Index<Element>) -> UInt32 {
        if _heapBuffer != nil {
            return heap.token(at: slot)
        }
        return _inlineBuffer.token(at: slot)
    }

    /// Constructs a Position handle from an occupied slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func position(
        forOccupied slot: Index<Element>
    ) -> Buffer<Element>.Arena.Position {
        if _heapBuffer != nil {
            return heap.position(forOccupied: slot)
        }
        return _inlineBuffer.position(forOccupied: slot)
    }

    // MARK: - Element Access

    /// Pointer to the element at the given slot index.
    ///
    /// - Precondition: `slot` is within `[.zero, highWater)`.
    @unsafe
    @inlinable
    public mutating func pointer(
        at slot: Index<Element>
    ) -> UnsafeMutablePointer<Element> {
        if _heapBuffer != nil {
            return unsafe heap.pointer(at: slot)
        }
        return unsafe _inlineBuffer.pointer(at: slot)
    }

    // MARK: - Spill

    /// Moves all occupied inline elements to a new heap arena.
    ///
    /// Preserves slot indices: an `Index<Element>` or `Position` obtained
    /// before spill remains valid after spill.
    @inlinable
    mutating func _spillToHeap() {
        let growCapCount = Index<Element>.Count(Cardinal(UInt(inlineCapacity * 2)))
        var newArena = Buffer<Element>.Arena(minimumCapacity: growCapCount)
        let newMeta = unsafe newArena.storage.meta
        let inlineMeta = unsafe _inlineBuffer._metaPointer()
        let hw = Int(bitPattern: _inlineBuffer.header.highWater)

        // Copy meta prefix — preserves tokens, free-list links
        unsafe newMeta.update(from: inlineMeta, count: hw)

        // Move occupied elements from inline → heap, preserving slot indices
        for i in 0..<hw {
            if unsafe inlineMeta[i].isOccupied {
                let slot = Index<Element>(Ordinal(UInt(i)))
                let element = unsafe _inlineBuffer._elementPointer(at: slot).move()
                unsafe newArena.storage.pointer(at: slot)
                    .initialize(to: element)
            }
        }

        // Sync heap header from inline header
        newArena.header.occupied = _inlineBuffer.header.occupied
        newArena.header.highWater = _inlineBuffer.header.highWater
        newArena.header.freeHead = _inlineBuffer.header.freeHead
        newArena.storage.highWater = _inlineBuffer.header.highWater

        // Reset inline header so inline deinit is a no-op
        _inlineBuffer.header.highWater = .zero
        _inlineBuffer.header.occupied = .zero
        _inlineBuffer.header.freeHead = .max

        _heapBuffer = .some(consume newArena)
    }
}
