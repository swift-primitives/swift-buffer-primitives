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

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(ucrt)
import ucrt
#endif

// The model-test harness core (arc-2; home seat-ruled 2026-06-11, ASK-W1-A:
// beside Seam.Ledger — the ledger checks the law sequence once, this harness
// checks law preservation under seeded random op streams). Zero tower imports.
//
// Shape constraint (binding, arc-2 incident 2.5): consumers keep each op as its
// OWN small method on a ~Copyable stream struct — one large stream body (loop +
// wide switch + move-only traffic) spins 6.3.2's -Onone
// `MovedAsyncVarDebugInfoPropagator` SIL pass for >1h.

/// The reference-model harness nest: seeded determinism, the divergence verdict,
/// and the soak knobs.
public enum Model {}

extension Model {
    /// SplitMix64 (Steele, Lea & Flood 2014 — the JDK `SplittableRandom` finalizer):
    /// the op-stream generator. Fixed seeds only; never time-seeded. Streams MUST
    /// generate from MODEL state, never SUT state, so a seed fully determines the
    /// op transcript.
    public struct Random {
        var state: UInt64

        public init(seed: UInt64) { self.state = seed }

        public mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var mixed = state
            mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
            mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
            return mixed ^ (mixed >> 31)
        }

        /// Uniform draw in `0..<bound` (modulo draw; generator-grade bias is
        /// irrelevant for op-stream generation).
        public mutating func below(_ bound: Int) -> Int {
            Int(next() % UInt64(bound))
        }

        /// True with probability `percent`/100.
        public mutating func chance(_ percent: Int) -> Bool {
            below(100) < percent
        }
    }
}

extension Model {
    /// The run record: seed + full op transcript + findings. Any finding is a
    /// MODEL DIVERGENCE; `report` is the replayable repro the failure prints.
    public struct Verdict {
        public let seed: UInt64
        public var transcript: [String] = []
        public var findings: [String] = []

        public init(seed: UInt64) { self.seed = seed }

        public var isClean: Bool { findings.isEmpty }

        public mutating func record(_ operation: String) {
            transcript.append(operation)
        }

        public mutating func diverged(_ messages: [String]) {
            guard !messages.isEmpty else { return }
            let at = transcript.endIndex - 1
            let operation = at >= 0 ? transcript[at] : "(setup)"
            findings.append(contentsOf: messages.map { "after op #\(at) `\(operation)`: \($0)" })
        }

        public var report: String {
            if isClean {
                return "clean — seed 0x\(String(seed, radix: 16)), \(transcript.count) ops"
            }
            return """
            MODEL DIVERGENCE — seed 0x\(String(seed, radix: 16)), \(transcript.count) ops run
            findings:
            \(findings.map { "  - \($0)" }.joined(separator: "\n"))
            transcript (replay by passing this seed):
            \(transcript.enumerated().map { "  \($0.offset): \($0.element)" }.joined(separator: "\n"))
            """
        }
    }
}

extension Model {
    /// CI-scale defaults; the soak knobs raise them without code changes:
    /// `MODEL_SOAK_OPERATIONS` (decimal op count per stream) and `MODEL_SOAK_SEEDS`
    /// (comma-separated seeds, decimal or 0x-hex, appended to the fixed defaults).
    public static func operations(default count: Int) -> Int {
        guard
            let raw = environment("MODEL_SOAK_OPERATIONS"),
            let soak = Int(raw),
            soak > 0
        else {
            return count
        }
        return soak
    }

    /// The seed set for a stream: the committed fixed defaults plus any
    /// `MODEL_SOAK_SEEDS` extras. Green MUST NOT depend on the defaults — any
    /// seed is expected to pass (the seat re-verifies with fresh seeds).
    public static func seeds(default fixed: [UInt64]) -> [UInt64] {
        guard let raw = environment("MODEL_SOAK_SEEDS") else { return fixed }
        let extras = raw.split(separator: ",").compactMap { piece -> UInt64? in
            let cleaned = piece.filter { !$0.isWhitespace }
            if cleaned.hasPrefix("0x") || cleaned.hasPrefix("0X") {
                return UInt64(cleaned.dropFirst(2), radix: 16)
            }
            return UInt64(cleaned)
        }
        return fixed + extras
    }

    /// Full-state oracles run after EVERY op at CI scale; past 4096 ops (soak)
    /// they thin to every 64th op plus the final op, keeping soak wall-clock
    /// linear in the op count.
    public static func shouldAudit(op index: Int, of operations: Int) -> Bool {
        if operations <= 4_096 { return true }
        return index % 64 == 0 || index == operations - 1
    }

    private static func environment(_ name: String) -> String? {
        guard let pointer = unsafe getenv(name) else { return nil }
        return unsafe String(validatingCString: pointer)
    }
}
