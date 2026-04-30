import Foundation

struct LocalLibraryService {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadPapers() throws -> [Paper] {
        let url = try libraryURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode([Paper].self, from: data)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func savePaper(_ paper: Paper) throws {
        var papers = try loadPapers()
        var updatedPaper = paper
        updatedPaper.updatedAt = Date()

        if let index = papers.firstIndex(where: { $0.id == paper.id }) {
            papers[index] = updatedPaper
        } else {
            papers.append(updatedPaper)
        }
        try savePapers(papers)
    }

    private func savePapers(_ papers: [Paper]) throws {
        let url = try libraryURL()
        let data = try encoder.encode(papers.sorted { $0.updatedAt > $1.updatedAt })
        try data.write(to: url, options: [.atomic])
    }

    private func libraryURL() throws -> URL {
        let directory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appDirectory = directory.appendingPathComponent("ResearchSupportIPhone", isDirectory: true)
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
        return appDirectory.appendingPathComponent("papers.json")
    }
}
