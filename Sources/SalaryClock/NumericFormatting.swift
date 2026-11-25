import Foundation

enum NumericFormatting {
    static func number(_ value: Double, fractionDigits: Int = 2) -> String {
        let raw = String(format: "%.*f", max(0, fractionDigits), value)
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        let integerPart = String(parts.first ?? "0")
        let sign = integerPart.hasPrefix("-") ? "-" : ""
        let digits = sign.isEmpty ? integerPart : String(integerPart.dropFirst())
        let grouped = groupDigits(digits)
        guard parts.count > 1 else { return sign + grouped }
        return sign + grouped + "." + parts[1]
    }

    static func integer(_ value: Int) -> String {
        let raw = String(value)
        let sign = raw.hasPrefix("-") ? "-" : ""
        let digits = sign.isEmpty ? raw : String(raw.dropFirst())
        return sign + groupDigits(digits)
    }

    static func currency(_ value: Double, fractionDigits: Int = 2) -> String {
        "¥ " + number(value, fractionDigits: fractionDigits)
    }

    private static func groupDigits(_ digits: String) -> String {
        let reversed = Array(digits.reversed())
        var grouped = ""
        for (index, character) in reversed.enumerated() {
            if index > 0 && index.isMultiple(of: 3) { grouped.append(",") }
            grouped.append(character)
        }
        return String(grouped.reversed())
    }
}
