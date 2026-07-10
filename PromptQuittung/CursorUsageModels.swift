import Foundation

// Decodiert einen Wert, der als JSON-Zahl oder -String kommen kann, zu Int64 (ms).
nonisolated struct FlexibleMillis: Codable {
    let value: Int64
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int64.self) { value = i }
        else if let d = try? c.decode(Double.self) { value = Int64(d) }
        else if let s = try? c.decode(String.self), let i = Int64(s) { value = i }
        else if let s = try? c.decode(String.self), let d = Double(s) { value = Int64(d) }
        else { value = 0 }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer(); try c.encode(value)
    }
}

// Decodiert Zahl oder numerischen String zu Int.
nonisolated struct FlexibleInt: Codable {
    let value: Int
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { value = i }
        else if let d = try? c.decode(Double.self) { value = Int(d) }
        else if let s = try? c.decode(String.self), let i = Int(s) { value = i }
        else { value = 0 }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer(); try c.encode(value)
    }
}

// Decodiert Zahl, numerischen String oder "-" (== 0) zu Double.
nonisolated struct LenientDouble: Codable {
    let value: Double
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { value = d }
        else if let s = try? c.decode(String.self) { value = s == "-" ? 0 : (Double(s) ?? 0) }
        else { value = 0 }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer(); try c.encode(value)
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

    // Der volle verrechnete Betrag in USD (chargedCents ist in Cent) — deckt sich mit dem Dashboard.
    var displayCost: Double { (chargedCents?.value ?? 0) / 100 }

    // Gesamte Tokens wie im Dashboard: Input + Output + Cache-Read + Cache-Write.
    var totalTokens: Int {
        (tokenUsage?.inputTokens?.value ?? 0)
            + (tokenUsage?.outputTokens?.value ?? 0)
            + (tokenUsage?.cacheReadTokens?.value ?? 0)
            + (tokenUsage?.cacheWriteTokens?.value ?? 0)
    }

    // Kompakte, aus dem Augenwinkel lesbare Token-Zahl: 198862 → "198.9k".
    static func compactTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }

    var costString: String { String(format: "$%.2f", displayCost) }
    var tokenString: String { Self.compactTokens(totalTokens) }

    // Notification: Betrag zuerst (Blickfang), dann Modell.
    var notificationTitle: String { "\(costString) · \(model ?? "Cursor")" }
    var notificationBody: String { "\(tokenString) Tokens" }
}

nonisolated struct UsageEventsResponse: Codable {
    let totalUsageEventsCount: FlexibleInt?
    let usageEventsDisplay: [UsageEvent]?
}
