import Foundation

/// Utility for formatting byte values and rates into human-readable strings.
public enum ByteFormatter {

    // MARK: - Byte Size Formatting

    /// Formats a byte count into a human-readable string (e.g., "1.5 GB").
    public static func format(bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else {
            return String(format: "%.1f %@", value, units[unitIndex])
        }
    }

    // MARK: - Rate Formatting

    /// Formats a byte rate into a human-readable string (e.g., "1.5 MB/s").
    public static func formatRate(bytesPerSecond: UInt64) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = Double(bytesPerSecond)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else {
            return String(format: "%.1f %@", value, units[unitIndex])
        }
    }

    /// Short rate format for menu bar display.
    public static func shortRate(bytesPerSecond: UInt64) -> String {
        let units = ["B", "K", "M", "G"]
        var value = Double(bytesPerSecond)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return String(format: "%.0f%@", value, units[unitIndex])
        } else if value >= 100 {
            return String(format: "%.0f%@", value, units[unitIndex])
        } else if value >= 10 {
            return String(format: "%.1f%@", value, units[unitIndex])
        } else {
            return String(format: "%.1f%@", value, units[unitIndex])
        }
    }
}
