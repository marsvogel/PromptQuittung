import Foundation

// Decodes a value that may arrive as a JSON number or string into Int64 (ms).
nonisolated struct FlexibleMillis: Codable {
    let value: Int64
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int64.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = Int64(double)
        } else if let string = try? container.decode(String.self), let int = Int64(string) {
            value = int
        } else if let string = try? container.decode(String.self), let double = Double(string) {
            value = Int64(double)
        } else {
            value = 0
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// Decodes a number or numeric string into Int.
nonisolated struct FlexibleInt: Codable {
    let value: Int
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = Int(double)
        } else if let string = try? container.decode(String.self), let int = Int(string) {
            value = int
        } else {
            value = 0
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// Decodes a number, numeric string, or "-" (== 0) into Double.
nonisolated struct LenientDouble: Codable {
    let value: Double
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string == "-" ? 0 : (Double(string) ?? 0)
        } else {
            value = 0
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

nonisolated struct TokenUsage: Codable {
    let totalCents: LenientDouble?
    let inputTokens: FlexibleInt?
    let outputTokens: FlexibleInt?
    let cacheWriteTokens: FlexibleInt?
    let cacheReadTokens: FlexibleInt?
}

nonisolated struct UsageEvent: Codable {
    let timestamp: FlexibleMillis
    let model: String?
    let kind: String?
    let chargedCents: LenientDouble?
    let requestsCosts: LenientDouble?
    let usageBasedCosts: LenientDouble?
    let isTokenBasedCall: Bool?
    let maxMode: Bool?
    let owningUser: String?
    let tokenUsage: TokenUsage?

    var kindShort: String {
        (kind ?? "").replacingOccurrences(of: "USAGE_EVENT_KIND_", with: "")
    }

    var dedupKey: String {
        let inTok = tokenUsage?.inputTokens?.value ?? 0
        let outTok = tokenUsage?.outputTokens?.value ?? 0
        return "\(timestamp.value)|\(model ?? "")|\(kind ?? "")|\(inTok)|\(outTok)"
    }

    // The full charged amount in USD (chargedCents is in cents) — matches the dashboard.
    var displayCost: Double { (chargedCents?.value ?? 0) / 100 }

    // Total tokens as shown in the dashboard: input + output + cache read + cache write.
    var totalTokens: Int {
        (tokenUsage?.inputTokens?.value ?? 0)
            + (tokenUsage?.outputTokens?.value ?? 0)
            + (tokenUsage?.cacheReadTokens?.value ?? 0)
            + (tokenUsage?.cacheWriteTokens?.value ?? 0)
    }

    // Compact token count readable at a glance: 198862 → "198.9k".
    static func compactTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fk", Double(count) / 1_000) }
        return "\(count)"
    }

    var costString: String { String(format: "$%.2f", displayCost) }
    var tokenString: String { Self.compactTokens(totalTokens) }

    // Notification: amount first (the eye-catcher), then the model.
    var notificationTitle: String { "\(costString) · \(model ?? "Cursor")" }
    var notificationBody: String { "\(tokenString) tokens" }
}

nonisolated struct UsageEventsResponse: Codable {
    let totalUsageEventsCount: FlexibleInt?
    let usageEventsDisplay: [UsageEvent]?
}
