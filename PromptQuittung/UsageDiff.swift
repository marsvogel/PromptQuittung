import Foundation

nonisolated enum UsageDiff {
    // Returns the events to notify about (chronological, oldest first) and the updated seen set.
    // On the first run we only seed; nothing gets notified.
    static func detect(events: [UsageEvent], seen: Set<String>, isFirstRun: Bool)
        -> (toNotify: [UsageEvent], updatedSeen: Set<String>) {
        var updated = seen
        for event in events { updated.insert(event.dedupKey) }
        if isFirstRun { return ([], updated) }
        let fresh = events.filter { !seen.contains($0.dedupKey) }
        let ordered = fresh.sorted { $0.timestamp.value < $1.timestamp.value }
        return (ordered, updated)
    }
}
