import Foundation

/// A uniform random shuffle.
///
/// Swift's own `shuffled()` is already an unbiased Fisher–Yates, so this type
/// is not here to fix a correctness gap in the standard library. It exists to
/// make the shuffle *auditable*: this app's entire reason for existing is the
/// claim "every ordering is equally likely, unlike Apple Music's shuffle," and
/// that claim deserves an implementation you can read and a test that measures
/// it, rather than a call into a black box.
enum Shuffle {
    /// Fisher–Yates (modern / Durstenfeld variant), walking from the end down.
    ///
    /// At each step `i`, one element is chosen uniformly from the still-unshuffled
    /// prefix `0...i` and swapped into position `i`. Because the choice at step `i`
    /// is uniform over exactly `i + 1` candidates, every one of the `n!` orderings
    /// is produced with probability `1/n!`.
    ///
    /// The generator is injected so tests can drive it deterministically; callers
    /// in the app pass the system CSPRNG.
    static func fisherYates<Element>(
        _ items: [Element],
        using generator: inout some RandomNumberGenerator
    ) -> [Element] {
        guard items.count > 1 else { return items }

        var result = items
        for i in stride(from: result.count - 1, to: 0, by: -1) {
            // Inclusive upper bound: element `i` must be able to stay put,
            // otherwise the shuffle is biased (this is the classic off-by-one
            // that turns Fisher–Yates into Sattolo's algorithm, which only ever
            // produces cyclic permutations and never leaves anything in place).
            let j = Int.random(in: 0...i, using: &generator)
            result.swapAt(i, j)
        }
        return result
    }

    /// Convenience overload using the system's cryptographically secure generator.
    static func fisherYates<Element>(_ items: [Element]) -> [Element] {
        var generator = SystemRandomNumberGenerator()
        return fisherYates(items, using: &generator)
    }
}
