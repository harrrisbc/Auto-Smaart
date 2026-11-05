import Foundation

public enum CurveBankError: Error, Equatable {
    case blankName
}

public final class CurveBank {
    private let fileURL: URL
    public private(set) var presets: [CurvePreset] = []

    public init(fileURL: URL) {
        self.fileURL = fileURL
        try? reload()
    }

    public func reload() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            presets = []
            return
        }
        let data = try Data(contentsOf: fileURL)
        presets = try JSONDecoder().decode([CurvePreset].self, from: data)
    }

    public func store(name: String, kind: CurveKind, points: [MagnitudePoint]) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw CurveBankError.blankName }
        if let index = presets.firstIndex(where: { $0.name == trimmed }) {
            presets[index].kind = kind
            presets[index].points = points
        } else {
            presets.append(CurvePreset(name: trimmed, kind: kind, points: points))
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(presets).write(to: fileURL, options: .atomic)
    }
}
