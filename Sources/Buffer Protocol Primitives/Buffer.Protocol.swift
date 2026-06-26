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
public import Cardinal_Primitive
public import Carrier_Protocol
public import Index_Primitives

// MARK: - Buffer.Protocol (Hoisted as __BufferProtocol)

/// Consumer-facing capability protocol for buffer disciplines.
///
/// See ``Buffer/`Protocol``` for documentation.
public protocol __BufferProtocol: ~Copyable, ~Escapable {
    /// The element type stored in the buffer.
    associatedtype Element: ~Copyable

    /// The domain in which this buffer reports its logical count.
    ///
    /// Defaults to `Index<Element>.Count` — the element domain — which keeps
    /// dense disciplines (Linear, Ring, Linked, Aligned, Unbounded, Arena)
    /// unchanged. Sparse disciplines that count in a different domain override
    /// `Count`: a slab counts occupied bitmap slots in `Bit.Index.Count`.
    ///
    /// The `Carrier.`Protocol`<Cardinal>` bound is the shared logical-quantity
    /// surface — every count domain in the ecosystem is a `Tagged<_, Cardinal>`
    /// (or bare `Cardinal`), so this bound admits both `Index<Element>.Count`
    /// and `Bit.Index.Count` while excluding non-cardinal carriers.
    associatedtype Count: Carrier.`Protocol`<Cardinal> = Index<Element>.Count

    /// The number of elements logically held by the buffer, in the buffer's
    /// natural counting domain (`Count`).
    var count: Count { get }

    /// Whether the buffer has no elements.
    ///
    /// Provided as a default implementation (`count == .zero`) on the protocol
    /// extension *for the element-domain default* (`Count == Index<Element>.Count`)
    /// — the deduplication payoff for dense disciplines, which need only supply
    /// `count`. Sparse disciplines whose `Count` is not the element-domain
    /// default fall outside this constrained extension and supply their own
    /// `isEmpty` (every such buffer already does).
    var isEmpty: Bool { get }
}

// MARK: - Derived-Observable Default Implementations

extension __BufferProtocol where Self: ~Copyable & ~Escapable, Count == Index<Element>.Count {
    /// Whether the buffer has no elements.
    ///
    /// Default implementation across every *element-domain* discipline,
    /// replacing the per-leaf `isEmpty` copies. The `Count == Index<Element>.Count`
    /// constraint is load-bearing: the `Carrier.`Protocol`<Cardinal>` bound does
    /// not surface `.zero`/`==` on the abstract `Count`, but the concrete
    /// element-domain `Tagged<Element, Cardinal>` does (via Cardinal's constrained
    /// Carrier extension). Sparse-domain conformers (e.g. slab counting in
    /// `Bit.Index.Count`) supply their own `isEmpty`.
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
