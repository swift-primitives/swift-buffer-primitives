// Buffer Primitives Test Support — substrate-only.
//
// After the [MOD-031] discipline extraction (2026-05-23), the per-discipline
// array-initializer fixtures (`Buffer.Ring`, `Buffer.Linear`, `Buffer.Linked`) moved to
// their sibling packages' `Buffer {Discipline} Primitives Test Support` targets
// (e.g. swift-buffer-ring-primitives). The substrate owner exposes no discipline fixtures.
//
// This target re-exports the substrate umbrella (`Buffer Primitives`) and
// `Memory Primitives Test Support` via exports.swift for downstream test infrastructure.
