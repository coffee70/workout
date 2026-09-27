extension Array {
    func rotated(startingAt index: Int) -> [Element] {
        guard !isEmpty else { return [] }
        let normalizedIndex = ((index % count) + count) % count
        return Array(self[normalizedIndex...]) + self[..<normalizedIndex]
    }
}
