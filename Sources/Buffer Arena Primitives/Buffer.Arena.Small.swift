public import Buffer_Primitives_Core

// MARK: - Extensions for Arena.Small (declared in Core)

extension Buffer.Arena.Small where Element: ~Copyable {

    // MARK: - Init

    /// Creates an empty small arena with inline capacity `inlineCapacity`.
    @inlinable
    public init() {
        self.init(
            _storage: .inline(Buffer<Element>.Arena.Inline<inlineCapacity>())
        )
    }

    // MARK: - Insert

    /// Allocates a slot, initializes the element, and returns a Position handle.
    ///
    /// If the inline buffer is full, spills to heap before inserting.
    @inlinable
    public mutating func insert(
        _ element: consuming Element
    ) -> Buffer<Element>.Arena.Position {
        switch _storage {
        case .heap(var buf):
            let pos = buf.insert(consume element)
            self = Self(_storage: .heap(consume buf))
            return pos
        case .inline(var buf):
            if buf.isFull {
                self = Self(_storage: .inline(consume buf))
                _spillToHeap()
                switch _storage {
                case .heap(var heap):
                    let pos = heap.insert(consume element)
                    self = Self(_storage: .heap(consume heap))
                    return pos
                case .inline(var inl):
                    self = Self(_storage: .inline(consume inl))
                    fatalError()
                }
            }
            let pos = try! buf.insert(consume element)
            self = Self(_storage: .inline(consume buf))
            return pos
        }
    }

    /// Allocates a slot without initializing the element.
    ///
    /// If the inline buffer is full, spills to heap before allocating.
    /// Caller MUST initialize the element at `position.slot` before use.
    @inlinable
    public mutating func allocate() -> Buffer<Element>.Arena.Position {
        switch _storage {
        case .heap(var buf):
            let pos = buf.allocate()
            self = Self(_storage: .heap(consume buf))
            return pos
        case .inline(var buf):
            if buf.isFull {
                self = Self(_storage: .inline(consume buf))
                _spillToHeap()
                switch _storage {
                case .heap(var heap):
                    let pos = heap.allocate()
                    self = Self(_storage: .heap(consume heap))
                    return pos
                case .inline(var inl):
                    self = Self(_storage: .inline(consume inl))
                    fatalError()
                }
            }
            let pos = try! buf.allocate()
            self = Self(_storage: .inline(consume buf))
            return pos
        }
    }

    // MARK: - Remove

    /// Validates the position, moves the element out, and releases the slot.
    ///
    /// - Throws: `.invalidPosition` if the position is stale or invalid.
    @inlinable
    public mutating func remove(
        at position: Buffer<Element>.Arena.Position
    ) throws(Buffer<Element>.Arena.Error) -> Element {
        switch _storage {
        case .heap(var buf):
            do {
                let element = try buf.remove(at: position)
                self = Self(_storage: .heap(consume buf))
                return element
            } catch {
                self = Self(_storage: .heap(consume buf))
                throw error
            }
        case .inline(var buf):
            let inlineMeta = unsafe buf._metaPointer()
            guard unsafe Buffer<Element>.Arena.isValid(
                position, header: buf.header, meta: inlineMeta
            ) else {
                self = Self(_storage: .inline(consume buf))
                throw .invalidPosition
            }
            let element = unsafe buf._elementPointer(at: position.slot).move()
            unsafe Buffer<Element>.Arena._releaseSlot(
                position.slot, header: &buf.header, meta: inlineMeta
            )
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    /// Moves the element out of the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func remove(at slot: Index<Element>) -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf.remove(at: slot)
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf.remove(at: slot)
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    /// Deinitializes the element at the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func free(at slot: Index<Element>) {
        switch _storage {
        case .heap(var buf):
            buf.free(at: slot)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            buf.free(at: slot)
            self = Self(_storage: .inline(consume buf))
        }
    }

    /// Deinitializes all occupied elements and resets the arena to empty state.
    @inlinable
    public mutating func removeAll() {
        switch _storage {
        case .heap(var buf):
            buf.removeAll()
            self = Self(_storage: .inline(Buffer<Element>.Arena.Inline<inlineCapacity>()))
            // buf goes out of scope — heap cleanup runs
        case .inline(var buf):
            buf.removeAll()
            self = Self(_storage: .inline(consume buf))
        }
    }

    // MARK: - Validation

    /// Returns whether the given position handle is still valid.
    @inlinable
    public mutating func isValid(
        _ position: Buffer<Element>.Arena.Position
    ) -> Bool {
        switch _storage {
        case .heap(var buf):
            let result = buf.isValid(position)
            self = Self(_storage: .heap(consume buf))
            return result
        case .inline(var buf):
            let result = buf.isValid(position)
            self = Self(_storage: .inline(consume buf))
            return result
        }
    }

    /// Returns whether the slot at the given index is occupied.
    @inlinable
    public func isOccupied(_ slot: Index<Element>) -> Bool {
        switch _storage {
        case .heap(let buf):
            return buf.isOccupied(slot)
        case .inline(let buf):
            return buf.isOccupied(slot)
        }
    }

    // MARK: - Token Access

    /// Returns the current generation token for the given slot.
    @inlinable
    public func token(at slot: Index<Element>) -> UInt32 {
        switch _storage {
        case .heap(let buf):
            return buf.token(at: slot)
        case .inline(let buf):
            return buf.token(at: slot)
        }
    }

    /// Constructs a Position handle from an occupied slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func position(
        forOccupied slot: Index<Element>
    ) -> Buffer<Element>.Arena.Position {
        switch _storage {
        case .heap(var buf):
            let pos = buf.position(forOccupied: slot)
            self = Self(_storage: .heap(consume buf))
            return pos
        case .inline(var buf):
            let pos = buf.position(forOccupied: slot)
            self = Self(_storage: .inline(consume buf))
            return pos
        }
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
        switch _storage {
        case .heap(var buf):
            let ptr = unsafe buf.pointer(at: slot)
            self = Self(_storage: .heap(consume buf))
            return unsafe ptr
        case .inline(var buf):
            let ptr = unsafe buf.pointer(at: slot)
            self = Self(_storage: .inline(consume buf))
            return unsafe ptr
        }
    }

    // MARK: - Spill

    /// Moves all occupied inline elements to a new heap arena.
    ///
    /// Preserves slot indices: an `Index<Element>` or `Position` obtained
    /// before spill remains valid after spill.
    @inlinable
    mutating func _spillToHeap() {
        switch _storage {
        case .heap(var buf):
            self = Self(_storage: .heap(consume buf))
            return
        case .inline(var inlineBuf):
            let growCapCount = Index<Element>.Count(Cardinal(UInt(inlineCapacity * 2)))
            var newArena = Buffer<Element>.Arena(minimumCapacity: growCapCount)
            let newMeta = unsafe newArena.storage.meta
            let inlineMeta = unsafe inlineBuf._metaPointer()
            let hw = Int(bitPattern: inlineBuf.header.highWater)

            // Copy meta prefix — preserves tokens, free-list links
            unsafe newMeta.update(from: inlineMeta, count: hw)

            // Move occupied elements from inline -> heap, preserving slot indices
            for i in 0..<hw {
                if unsafe inlineMeta[i].isOccupied {
                    let slot = Index<Element>(Ordinal(UInt(i)))
                    let element = unsafe inlineBuf._elementPointer(at: slot).move()
                    unsafe newArena.storage.pointer(at: slot)
                        .initialize(to: element)
                }
            }

            // Sync heap header from inline header
            newArena.header.occupied = inlineBuf.header.occupied
            newArena.header.highWater = inlineBuf.header.highWater
            newArena.header.freeHead = inlineBuf.header.freeHead
            newArena.storage.highWater = inlineBuf.header.highWater

            // Reset inline header so inline deinit is a no-op
            inlineBuf.header.highWater = .zero
            inlineBuf.header.occupied = .zero
            inlineBuf.header.freeHead = .max

            self = Self(_storage: .heap(consume newArena))
            // inlineBuf goes out of scope — deinit runs on empty state
        }
    }
}
