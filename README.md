# Buffer Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)
[![CI](https://github.com/swift-primitives/swift-buffer-primitives/actions/workflows/ci.yml/badge.svg)](https://github.com/swift-primitives/swift-buffer-primitives/actions/workflows/ci.yml)

`Buffer<S>` — the buffer-discipline namespace, parameterized by the storage substrate `S` (any `Storage.Protocol` conformer). It is the shared root the buffer disciplines build on: **`Buffer.Linear`** (contiguous, front-to-back), **`Buffer.Ring`** (circular, wrap-around), **`Buffer.Slots`** (metadata-parametric random-access slots), and **`Buffer.Linked`** (generational linked list) — each shipped in its own package over this namespace.

This package carries the *namespace* and the *capability protocol*, not the disciplines themselves. `Buffer.Protocol` is the shared logical surface — `count`, plus a derived `isEmpty` — that every discipline exposes. It is a **capability marker, not op-dispatch**: the hot `append` / `remove` / `subscript` operations stay on the concrete discipline types, so the protocol adds no dispatch cost. It is also **orthogonal to `Storage.Protocol`** — a buffer *has-a* storage, it is not a *kind-of* storage — so physical surface (`pointer(at:)`, `capacity`) stays in the storage layer. Code written against `Buffer.Protocol` reads occupancy uniformly across every discipline.

---

## Key Features

- **One namespace, four disciplines** — `Buffer.Linear` / `Ring` / `Slots` / `Linked` all live under `Buffer<S>`, each parameterized by the same storage substrate, so a substrate choice (heap, inline, shared) flows through unchanged.
- **`count` capability, dispatch-free** — `Buffer.Protocol` exposes the logical `count` (in the discipline's natural counting domain) and a single default `isEmpty`; conforming costs nothing at the call site.
- **`~Copyable` elements end to end** — the namespace is `~Copyable`-generic over its substrate; move-only elements are carried without an implicit copy.
- **Substrate-explicit composition** — a discipline's full spelling names its substrate (`Buffer<Storage<…>.Contiguous<Element>>.Ring`), keeping the storage strategy visible rather than hidden behind a default.

---

## Quick Start

`Buffer.Protocol` lets one algorithm range over every discipline:

```swift
import Buffer_Protocol_Primitives

// Works across Linear, Ring, Slots, and Linked alike.
func summary(of buffer: borrowing some Buffer.`Protocol` & ~Copyable) -> String {
    buffer.isEmpty ? "empty" : "\(buffer.count) element(s)"
}
```

The concrete disciplines live in their own packages — see Related Packages.

---

## Installation

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main")
]
```

Add a product to your target:

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Buffer Primitives", package: "swift-buffer-primitives")
    ]
)
```

The package is pre-1.0 — depend on `branch: "main"` until `0.1.0` is tagged. Requires Swift 6.3 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the corresponding Linux / Windows toolchain).

---

## Architecture

| Product | Contents | When to import |
|---------|----------|----------------|
| `Buffer Primitives` | Umbrella — re-exports the namespace and the protocol | Most consumers |
| `Buffer Primitive` | `Buffer<S>` — the discipline namespace over a storage substrate | Naming the namespace directly |
| `Buffer Protocol Primitives` | `Buffer.Protocol` — the shared `count` / `isEmpty` capability | Writing code generic over disciplines |

---

## Platform Support

| Platform         | CI  | Status       |
|------------------|-----|--------------|
| macOS 26         | Yes | Full support |
| Linux            | Yes | Full support |
| Windows          | Yes | Full support |
| iOS/tvOS/watchOS | —   | Supported    |
| Swift Embedded   | —   | Pending (nightly-toolchain follow-up) |

---

## Related Packages

- [`swift-buffer-linear-primitives`](https://github.com/swift-primitives/swift-buffer-linear-primitives) — `Buffer.Linear`, the contiguous discipline.
- [`swift-buffer-ring-primitives`](https://github.com/swift-primitives/swift-buffer-ring-primitives) — `Buffer.Ring`, the circular discipline.
- [`swift-buffer-linked-primitives`](https://github.com/swift-primitives/swift-buffer-linked-primitives) — `Buffer.Linked`, the linked discipline.
- [`swift-buffer-slots-primitives`](https://github.com/swift-primitives/swift-buffer-slots-primitives) — `Buffer.Slots`, the random-access slots discipline.
- [`swift-storage-primitives`](https://github.com/swift-primitives/swift-storage-primitives) — `Storage`, the substrate every discipline is parameterized over.
- [`swift-index-primitives`](https://github.com/swift-primitives/swift-index-primitives) — `Index<Element>.Count`, the natural counting domain.

---

## Community

<!-- BEGIN: discussion -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
