// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Buffer_Primitives_Core

// MARK: - Ring-Aware Storage Operations

extension Buffer.Ring where Element: ~Copyable {
    /// Deinitializes elements in ring order within Storage.
    ///
    /// Storage's deinit assumes linear layout (elements at 0..<count), but ring buffers
    /// store elements at wrapped positions. This method deinitializes elements in their
    /// actual ring positions.
    ///
    /// - Parameters:
    ///   - storage: The storage containing elements.
    ///   - head: Physical index of the first element.
    ///   - count: Number of elements to deinitialize.
    ///   - capacity: Buffer capacity for wrapping.
    @inlinable
    public static func deinitializeRing(
        in storage: Storage_Primitives.Storage.Heap<Element>,
        head: Index<Element>,
        count: Index<Element>.Count,
        capacity: Index<Element>.Count
    ) {
        guard count > .zero else { return }
        var index = head
        (Index<Element>.zero..<count).forEach { _ in
            _ = storage.move(at: index.retag(Storage.self))
            index = successor(of: index, wrapping: capacity)
        }
    }

    /// Moves elements from ring layout in source Storage to linear layout in destination Storage.
    ///
    /// Elements at wrapped positions in source are moved to linear positions 0..<count
    /// in destination. Source slots are deinitialized after moving.
    ///
    /// - Parameters:
    ///   - source: Source storage with ring-ordered elements.
    ///   - head: Physical index of the first element in source.
    ///   - count: Number of elements to move.
    ///   - capacity: Source buffer capacity for wrapping.
    ///   - destination: Destination storage (linear, starting at 0).
    @inlinable
    public static func linearizeToStorage(
        from source: Storage_Primitives.Storage.Heap<Element>,
        head: Index<Element>,
        count: Index<Element>.Count,
        capacity: Index<Element>.Count,
        to destination: Storage_Primitives.Storage.Heap<Element>
    ) {
        guard count > .zero else { return }
        var srcIndex = head
        (Index<Element>.zero..<count).forEach { dstIdx in
            let element = source.move(at: srcIndex.retag(Storage.self))
            destination.initialize(to: element, at: dstIdx.retag(Storage.self))
            srcIndex = successor(of: srcIndex, wrapping: capacity)
        }
    }
}

// MARK: - Copyable Elements

extension Buffer.Ring where Element: Copyable {
    /// Copies elements from ring layout in source Storage to linear layout in destination Storage.
    ///
    /// Elements at wrapped positions in source are copied (not moved) to linear positions
    /// 0..<count in destination. Source elements remain intact.
    ///
    /// - Parameters:
    ///   - source: Source storage with ring-ordered elements.
    ///   - head: Physical index of the first element in source.
    ///   - count: Number of elements to copy.
    ///   - capacity: Source buffer capacity for wrapping.
    ///   - destination: Destination storage (linear, starting at 0).
    @inlinable
    public static func copy(
        from source: Storage_Primitives.Storage.Heap<Element>,
        head: Index<Element>,
        count: Index<Element>.Count,
        capacity: Index<Element>.Count,
        to destination: Storage_Primitives.Storage.Heap<Element>
    ) {
        guard count > .zero else { return }
        var srcIndex = head
        (Index<Element>.zero..<count).forEach { dstIdx in
            let element = unsafe source.pointer(at: srcIndex.retag(Storage.self)).pointee
            destination.initialize(to: element, at: dstIdx.retag(Storage.self))
            srcIndex = successor(of: srcIndex, wrapping: capacity)
        }
    }
}

extension Storage.Inline {
    /// Deinitializes elements using a cyclic header.
    ///
    /// Iterates from head through count positions with wrapping, deinitializing
    /// each slot individually.
    ///
    /// - Parameter header: The cyclic ring buffer header.
    /// - Precondition: Elements from head through count positions must be initialized.
    /// - Note: Non-mutating to allow use from deinit contexts.
    @inlinable
    public func deinitialize<let N: Int>(
        header: Buffer<Element>.Ring.Header.Cyclic<N>
    ) {
        guard header.count > .zero else { return }
        var cyclicHead = header.head
        (Buffer<Element>.Index.zero..<header.count).forEach { _ in
            deinitialize(at: slotIndex(from: cyclicHead))
            cyclicHead += .one
        }
    }
}
