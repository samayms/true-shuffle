import Testing
@testable import TrueShuffle

/// A generator that returns a scripted sequence, so a shuffle can be checked
/// against a hand-computed expected result rather than "it looks random."
private struct ScriptedGenerator: RandomNumberGenerator {
    var values: [UInt64]
    private var index = 0

    init(_ values: [UInt64]) { self.values = values }

    mutating func next() -> UInt64 {
        defer { index += 1 }
        return values[index % values.count]
    }
}

@Suite("Fisher–Yates shuffle")
struct ShuffleTests {

    @Test("Empty and single-element inputs are returned unchanged")
    func degenerateInputs() {
        #expect(Shuffle.fisherYates([Int]()).isEmpty)
        #expect(Shuffle.fisherYates([42]) == [42])
    }

    @Test("Shuffling is a permutation: same elements, same count")
    func isAPermutation() {
        let input = Array(1...500)
        let output = Shuffle.fisherYates(input)

        #expect(output.count == input.count)
        #expect(output.sorted() == input)
    }

    @Test("Duplicate elements are preserved, not deduplicated")
    func preservesDuplicates() {
        let input = [1, 1, 1, 2, 2, 3]
        let output = Shuffle.fisherYates(input)

        #expect(output.sorted() == input.sorted())
        #expect(output.count(where: { $0 == 1 }) == 3)
    }

    @Test("Result is deterministic for a given generator")
    func deterministicWithSeededGenerator() {
        let input = Array(1...20)

        var a = ScriptedGenerator([7, 13, 2, 91, 44, 5])
        var b = ScriptedGenerator([7, 13, 2, 91, 44, 5])

        #expect(Shuffle.fisherYates(input, using: &a) == Shuffle.fisherYates(input, using: &b))
    }

    /// The bug this guards against is Sattolo's algorithm: using an *exclusive*
    /// upper bound (`0..<i` instead of `0...i`) produces only cyclic
    /// permutations, in which no element ever remains at its original index.
    /// Over many trials a correct shuffle must sometimes leave an element in
    /// place — the expected number of fixed points is exactly 1, for any n.
    @Test("Elements can remain in their original position (not Sattolo's algorithm)")
    func allowsFixedPoints() {
        let input = Array(0..<8)
        var sawFixedPoint = false

        for _ in 0..<2_000 where !sawFixedPoint {
            let output = Shuffle.fisherYates(input)
            if zip(input, output).contains(where: ==) {
                sawFixedPoint = true
            }
        }

        #expect(sawFixedPoint, "A uniform shuffle must sometimes leave an element in place")
    }

    /// A uniformity check with a deliberately loose tolerance: it is strong
    /// enough to catch a structurally biased shuffle, and loose enough not to
    /// fail spuriously on ordinary random variation.
    @Test("Every element reaches every position roughly equally often")
    func isApproximatelyUniform() {
        let n = 6
        let trials = 30_000
        let input = Array(0..<n)

        // counts[element][position]
        var counts = Array(repeating: Array(repeating: 0, count: n), count: n)

        for _ in 0..<trials {
            let output = Shuffle.fisherYates(input)
            for (position, element) in output.enumerated() {
                counts[element][position] += 1
            }
        }

        let expected = Double(trials) / Double(n)
        let tolerance = expected * 0.15

        for element in 0..<n {
            for position in 0..<n {
                let observed = Double(counts[element][position])
                #expect(
                    abs(observed - expected) < tolerance,
                    "element \(element) landed at position \(position) \(Int(observed)) times, expected ≈\(Int(expected))"
                )
            }
        }
    }

    /// With n = 4 there are only 24 orderings; a correct shuffle should produce
    /// all of them. A biased or cyclic shuffle will systematically miss some.
    @Test("All n! orderings are reachable")
    func coversEveryPermutation() {
        let input = [1, 2, 3, 4]
        var seen = Set<[Int]>()

        for _ in 0..<5_000 {
            seen.insert(Shuffle.fisherYates(input))
        }

        #expect(seen.count == 24, "expected all 24 permutations, saw \(seen.count)")
    }
}
