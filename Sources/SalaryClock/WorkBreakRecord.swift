import Foundation

enum WorkBreakType: String, Codable, CaseIterable, Identifiable {
    case restroom
    case phone
    case shortBreak
    case meal
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .restroom: return "上厕所"
        case .phone: return "玩手机"
        case .shortBreak: return "喝水 / 休息"
        case .meal: return "吃饭"
        case .other: return "其他"
        }
    }

    var symbol: String {
        switch self {
        case .restroom: return "figure.wave"
        case .phone: return "iphone"
        case .shortBreak: return "cup.and.saucer"
        case .meal: return "fork.knife"
        case .other: return "ellipsis.circle"
        }
    }
}

struct WorkBreakRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var type: WorkBreakType
    var startTime: Date
    var endTime: Date?
    var deductFromWork: Bool

    var duration: TimeInterval {
        max(0, (endTime ?? Date()).timeIntervalSince(startTime))
    }
}

enum WorkBreakCalculator {
    static func configuredMinutes(for type: WorkBreakType, settings: SalarySettings) -> Int {
        switch type {
        case .restroom: return max(0, settings.estimatedRestroomBreakMinutes)
        case .phone: return max(0, settings.estimatedPhoneBreakMinutes)
        case .shortBreak: return max(0, settings.estimatedShortBreakMinutes)
        case .meal: return max(0, settings.estimatedMealBreakMinutes)
        case .other: return max(0, settings.estimatedOtherBreakMinutes)
        }
    }

    static func estimatedMinutes(for type: WorkBreakType, settings: SalarySettings) -> Int {
        let deducts: Bool
        switch type {
        case .restroom: deducts = settings.deductRestroomBreaks
        case .phone: deducts = settings.deductPhoneBreaks
        case .shortBreak: deducts = settings.deductShortBreaks
        case .meal: deducts = settings.deductMealBreaks
        case .other: deducts = settings.deductOtherBreaks
        }
        return deducts ? configuredMinutes(for: type, settings: settings) : 0
    }

    static func deductedWorkSeconds(
        records: [WorkBreakRecord],
        activeRecord: WorkBreakRecord?,
        now: Date,
        on date: Date,
        settings: SalarySettings,
        calendar: Calendar = .current
    ) -> TimeInterval {
        let dayStart = calendar.startOfDay(for: date)
        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: min(23, max(0, hour)), minute: min(59, max(0, minute)), second: 0, of: dayStart) ?? dayStart
        }
        let shiftStart = at(settings.startHour, settings.startMinute)
        let shiftEnd = at(settings.endHour, settings.endMinute)
        guard shiftEnd > shiftStart else { return 0 }

        let lunchStart = at(settings.lunchStartHour, settings.lunchStartMinute)
        let lunchEnd = at(settings.lunchEndHour, settings.lunchEndMinute)
        var workIntervals: [(Date, Date)] = []
        if settings.lunchBreakEnabled, lunchEnd > lunchStart, lunchEnd > shiftStart, lunchStart < shiftEnd {
            let morningEnd = min(shiftEnd, lunchStart)
            let afternoonStart = max(shiftStart, lunchEnd)
            if morningEnd > shiftStart { workIntervals.append((shiftStart, morningEnd)) }
            if shiftEnd > afternoonStart { workIntervals.append((afternoonStart, shiftEnd)) }
        } else {
            workIntervals.append((shiftStart, shiftEnd))
        }

        let workdayCheck = SalaryCalculator.snapshot(
            settings: settings,
            now: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart) ?? dayStart,
            calendar: calendar
        )
        guard workdayCheck.isWorkday else { return 0 }
        let trackingStartDay = settings.effectiveWorkTrackingStartedAt.map { calendar.startOfDay(for: $0) }
        guard settings.effectiveWorkTrackingEnabled,
              trackingStartDay == nil || dayStart >= trackingStartDay! else {
            return actualDeductedSeconds(records: records, activeRecord: activeRecord, now: now, workIntervals: workIntervals)
        }

        let allRecords = records + (activeRecord.map { [$0] } ?? [])
        let elapsedWorkSeconds = workIntervals.reduce(0) { total, interval in
            let elapsedEnd = min(interval.1, max(interval.0, now))
            return total + max(0, elapsedEnd.timeIntervalSince(interval.0))
        }
        let totalWorkSeconds = workIntervals.reduce(0) { $0 + $1.1.timeIntervalSince($1.0) }
        let estimateProgress = totalWorkSeconds > 0 ? min(1, max(0, elapsedWorkSeconds / totalWorkSeconds)) : 0

        return WorkBreakType.allCases.reduce(0) { total, type in
            let actualSeconds = allRecords.reduce(0) { recordTotal, record in
                guard record.type == type, record.deductFromWork else { return recordTotal }
                let recordEnd = min(record.endTime ?? now, now)
                return recordTotal + workIntervals.reduce(0) { intervalTotal, interval in
                    let overlapStart = max(interval.0, record.startTime)
                    let overlapEnd = min(interval.1, recordEnd)
                    return intervalTotal + max(0, overlapEnd.timeIntervalSince(overlapStart))
                }
            }
            let estimateSeconds = settings.effectiveWorkTrackingEnabled
                ? Double(estimatedMinutes(for: type, settings: settings)) * 60 * estimateProgress
                : 0
            return total + max(actualSeconds, estimateSeconds)
        }
    }
    private static func actualDeductedSeconds(
        records: [WorkBreakRecord], activeRecord: WorkBreakRecord?, now: Date,
        workIntervals: [(Date, Date)]
    ) -> TimeInterval {
        (records + (activeRecord.map { [$0] } ?? [])).reduce(0) { total, record in
            guard record.deductFromWork else { return total }
            let recordEnd = min(record.endTime ?? now, now)
            return total + workIntervals.reduce(0) { intervalTotal, interval in
                let overlapStart = max(interval.0, record.startTime)
                let overlapEnd = min(interval.1, recordEnd)
                return intervalTotal + max(0, overlapEnd.timeIntervalSince(overlapStart))
            }
        }
    }

}
