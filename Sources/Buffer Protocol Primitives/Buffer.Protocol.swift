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

public import Buffer_Primitive
public import Index_Primitives

// MARK: - Buffer.Protocol (Hoisted as __BufferProtocol)

/// Consumer-facing capability protocol for buffer disciplines.
///
/// See ``Buffer/`Protocol``` for documentation.
public protocol __BufferProtocol: ~Copyable, ~Escapable {
    /// The element type stored in the buffer.
    ///
    /// The sole associated type (M7, [DS-025]/[DS-026] §4.2): `count` is the
    /// concrete `Index<Element>.Count`, so the former `associatedtype Count`
    /// is gone and no op extension reaches through a nested associated type.
    associatedtype Element: ~Copyable

    /// The number of elements logically held by the buffer, in the concrete
    /// element domain.
    ///
    /// Concrete (M7): every discipline reports its live-element cardinality as
    /// `Index<Element>.Count`. Sparse disciplines whose native ledger counts in
    /// a different domain (a slab counts occupied bitmap slots in `Bit.Index.Count`)
    /// re-tag into the element domain at this witness (`.retag(Element.self)` —
    /// one occupied slot IS one live element, a numerically-sound phantom-label
    /// change).
    var count: Index<Element>.Count { get }

    /// Whether the buffer has no elements.
    ///
    /// Provided as an UNCONSTRAINED default implementation (`count == .zero`) on
    /// the protocol extension (M7): the concrete `Index<Element>.Count`
    /// (= `Tagged<Element, Cardinal>`) surfaces both `==` and `.zero`, so the
    /// default fires for every conformer — dense and re-tagged sparse alike
    /// (resolving W18). A conformer may still supply its own `isEmpty`.
    var isEmpty: Bool { get }
}

// MARK: - Derived-Observable Default Implementations

extension __BufferProtocol where Self: ~Copyable & ~Escapable {
    /// Whether the buffer has no elements.
    ///
    /// UNCONSTRAINED default implementation (M7) across every discipline,
    /// replacing the per-leaf `isEmpty` copies. No `Count == Index<Element>.Count`
    /// pin is needed: `count` is already the concrete `Index<Element>.Count`
    /// (= `Tagged<Element, Cardinal>`), which surfaces `.zero` (Cardinal's
    /// constrained Carrier extension) and `==` (Tagged's `Equatable`) — both
    /// resolving via `Index_Primitives`' re-exports. Re-tagged sparse conformers
    /// (a slab counting in `Bit.Index.Count`) get this default for free.
    @inlinable
    public var isEmpty: Bool { count == .zero }
}

// MARK: - Namespace Typealias

extension Buffer where S: ~Copyable {
    /// Consumer-facing capability protocol for `Buffer` disciplines.
    ///
    /// `Buffer.Protocol` (accessed as `Buffer.`Protocol``) is the shared logical
    /// surface universal across disciplines (Linear, Ring, Slab, Linked, Slots,
    /// Arena). It exposes the logical `count`; derivable observables such as
    /// `isEmpty` are single default implementations.
    ///
    /// ## Capability, not op-dispatch
    ///
    /// `Buffer.Protocol` is a *capability* surface — it does NOT carry the hot
    /// mutating operations (append / remove / subscript). Those stay on
    /// concrete-Base `Property.Inout` accessors per the specialization evidence
    /// in `storage-generic-buffer-core.md`.
    ///
    /// ## Orthogonal to Storage.Protocol
    ///
    /// A buffer *has-a* storage; it is not a *kind-of* storage. `Buffer.Protocol`
    /// therefore does NOT refine `Storage.Protocol` — physical surface
    /// (`pointer(at:)`, `capacity`) stays in the storage layer.
    ///
    /// ## Iteration is orthogonal — NOT refined here
    ///
    /// `count` is header-knowable and needs no iteration, so `Buffer.Protocol`
    /// stays the *logical* surface and does NOT refine iterator-primitives'
    /// `Iterable`. Refining `Iterable` would couple the header-knowable `count`
    /// (occupancy — the buffer's identity) to iterability, an orthogonal concern
    /// (relate-don't-refine). Iteration terminals (`forEach` / `contains` /
    /// `first` / `reduce`) are therefore NOT on this protocol; buffers gain them
    /// by *separately* conforming to `Iterable`, whose span-primitive iterator
    /// (`next(maximumCount:) -> Swift.Span<Element>`, SE-0516) lends each element via
    /// the borrowing addressor `span[i]` — carrying Copyable AND `~Copyable` with
    /// no Copyable gate and no move-out. For the span-projecting
    /// `Storage.Contiguous` family (buffers, Set.Ordered) the span→Iterable
    /// bridge vends that conformance for free over `span`; see
    /// `unified-iteration-design.md` / `storage-generic-buffer-core.md`.
    ///
    /// ## Hoisted Protocol Pattern
    ///
    /// Swift does not allow nesting a protocol inside a generic type, so the
    /// protocol is declared at module scope as `__BufferProtocol` and aliased
    /// into the namespace:
    ///
    /// ```swift
    /// extension Buffer {
    ///     public typealias `Protocol` = __BufferProtocol
    /// }
    /// ```
    ///
    /// `associatedtype Element: ~Copyable` relies on the `SuppressedAssociatedTypes`
    /// experimental feature.
    public typealias `Protocol` = __BufferProtocol
}
