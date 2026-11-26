import Foundation
import OSLog

/// Immutable snapshot shared by the host app and WidgetKit extension.
/// A single atomic file avoids cross-process CFPrefs suite cache/domain failures.
struct SalaryClockWidgetSharedData: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let updatedAt: Date
    let settings: SalarySettings
    let breakRecords: [WorkBreakRecord]
    let activeBreak: WorkBreakRecord?
    let overtimeStartedAt: Date?

    init(
        settings: SalarySettings,
        breakRecords: [WorkBreakRecord],
        activeBreak: WorkBreakRecord?,
        overtimeStartedAt: Date?,
        updatedAt: Date = Date()
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.updatedAt = updatedAt
        self.settings = settings
        self.breakRecords = breakRecords
        self.activeBreak = activeBreak
        self.overtimeStartedAt = overtimeStartedAt
    }
}

enum SalaryClockWidgetSharedStore {
    static let appGroupIdentifier = "WXFKXAFBJ8.salaryclock"
    private static let directoryName = "SalaryClock"
    private static let fileName = "widget-shared-state-v1.json"
    private static let logger = Logger(subsystem: "com.jyd.salaryclock.desktop", category: "WidgetSharedStore")

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    @discardableResult
    static func write(
        settings: SalarySettings,
        breakRecords: [WorkBreakRecord],
        activeBreak: WorkBreakRecord?,
        overtimeStartedAt: Date?
    ) -> Bool {
        guard let fileURL else {
            logger.error("App Group container unavailable; shared widget snapshot was not written")
            return false
        }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let snapshot = SalaryClockWidgetSharedData(
                settings: settings,
                breakRecords: breakRecords,
                activeBreak: activeBreak,
                overtimeStartedAt: overtimeStartedAt
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            logger.debug("Shared widget snapshot written atomically; bytes=\(data.count), breaks=\(breakRecords.count)")
            return true
        } catch {
            logger.error("Failed to write shared widget snapshot: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    static func read() -> SalaryClockWidgetSharedData? {
        guard let fileURL else {
            logger.error("App Group container unavailable while reading widget snapshot")
            return nil
        }
        do {
            let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
            let snapshot = try JSONDecoder().decode(SalaryClockWidgetSharedData.self, from: data)
            guard snapshot.schemaVersion == SalaryClockWidgetSharedData.currentSchemaVersion else {
                logger.error("Unsupported widget snapshot schema version: \(snapshot.schemaVersion)")
                return nil
            }
            logger.debug("Shared widget snapshot read; updatedAt=\(snapshot.updatedAt.formatted(.iso8601)), bytes=\(data.count)")
            return snapshot
        } catch CocoaError.fileReadNoSuchFile {
            logger.notice("Shared widget snapshot does not exist yet")
            return nil
        } catch {
            logger.error("Failed to read shared widget snapshot: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
