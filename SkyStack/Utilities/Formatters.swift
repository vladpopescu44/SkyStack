import Foundation

/// Formatting helpers for numbers and durations shown in the interface.
enum Formatters {
    /// Formats a duration in seconds as `m:ss`.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let remainder = total % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    /// Formats a score or currency amount with grouping separators.
    static func integer(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    /// Formats a height in floors, e.g. "42 floors".
    static func floors(_ value: Int) -> String {
        value == 1 ? "1 floor" : "\(integer(value)) floors"
    }

    /// Formats a percentage from a `0...1` fraction, e.g. "58%".
    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    /// Formats a multiplier with one decimal, e.g. "x1.3".
    static func multiplier(_ value: Double) -> String {
        "x" + oneDecimal(value)
    }

    /// One decimal place with a dot separator, trimming a trailing ".0" (e.g. "1.3", "2").
    /// Locale-independent so game stats read the same everywhere.
    static func oneDecimal(_ value: Double) -> String {
        let text = String(format: "%.1f", value)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    /// Formats a date for the run history list.
    static func runDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}
