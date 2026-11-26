import SwiftUI
import UniformTypeIdentifiers

struct SalarySettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var settings: SalarySettings

    init(settings: SalarySettings) {
        self.settings = settings
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        settings = try JSONDecoder().decode(SalarySettings.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        return FileWrapper(regularFileWithContents: data)
    }
}
