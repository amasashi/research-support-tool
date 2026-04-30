import Foundation

struct Paper: Identifiable, Codable, Hashable {
    var id: UUID
    var documentID: Int?
    var title: String
    var sourceText: String
    var translatedText: String
    var summary: String
    var sourceURL: String?
    var contentType: String?
    var notes: String
    var updatedAt: Date
    var paragraphNotes: [Int: String]
    var readingTemplate: String
    var character: PaperCharacter
    var sections: [PaperSection]
    var chatMessages: [PaperChatMessage]

    static let empty = Paper(
        id: UUID(),
        documentID: nil,
        title: "Untitled paper",
        sourceText: "",
        translatedText: "",
        summary: "",
        sourceURL: nil,
        contentType: nil,
        notes: "",
        updatedAt: Date(),
        paragraphNotes: [:],
        readingTemplate: "",
        character: .default,
        sections: [],
        chatMessages: []
    )

    init(
        id: UUID,
        documentID: Int?,
        title: String,
        sourceText: String,
        translatedText: String,
        summary: String,
        sourceURL: String?,
        contentType: String?,
        notes: String,
        updatedAt: Date,
        paragraphNotes: [Int: String] = [:],
        readingTemplate: String = "",
        character: PaperCharacter = .default,
        sections: [PaperSection] = [],
        chatMessages: [PaperChatMessage] = []
    ) {
        self.id = id
        self.documentID = documentID
        self.title = title
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.summary = summary
        self.sourceURL = sourceURL
        self.contentType = contentType
        self.notes = notes
        self.updatedAt = updatedAt
        self.paragraphNotes = paragraphNotes
        self.readingTemplate = readingTemplate
        self.character = character
        self.sections = sections
        self.chatMessages = chatMessages
    }

    enum CodingKeys: String, CodingKey {
        case id
        case documentID
        case title
        case sourceText
        case translatedText
        case summary
        case sourceURL
        case contentType
        case notes
        case updatedAt
        case paragraphNotes
        case readingTemplate
        case character
        case sections
        case chatMessages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        documentID = try container.decodeIfPresent(Int.self, forKey: .documentID)
        title = try container.decode(String.self, forKey: .title)
        sourceText = try container.decode(String.self, forKey: .sourceText)
        translatedText = try container.decode(String.self, forKey: .translatedText)
        summary = try container.decode(String.self, forKey: .summary)
        sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
        contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        notes = try container.decode(String.self, forKey: .notes)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        paragraphNotes = try container.decodeIfPresent([Int: String].self, forKey: .paragraphNotes) ?? [:]
        readingTemplate = try container.decodeIfPresent(String.self, forKey: .readingTemplate) ?? ""
        character = try container.decodeIfPresent(PaperCharacter.self, forKey: .character) ?? .default
        sections = try container.decodeIfPresent([PaperSection].self, forKey: .sections) ?? []
        chatMessages = try container.decodeIfPresent([PaperChatMessage].self, forKey: .chatMessages) ?? []
    }
}

struct PaperSection: Identifiable, Codable, Hashable {
    var id: UUID
    var index: Int
    var title: String
    var sourceText: String
    var translatedText: String
    var summary: String
    var note: String

    var characterCount: Int {
        sourceText.count
    }

    var textSection: PaperTextSection {
        PaperTextSection(index: index, title: title, text: sourceText)
    }
}

struct PaperChatMessage: Identifiable, Codable, Hashable {
    var id = UUID()
    var scope: ChatScope
    var sectionID: UUID?
    var question: String
    var answer: String
    var createdAt = Date()
}

enum ChatScope: String, Codable, Hashable, CaseIterable, Identifiable {
    case wholePaper
    case section

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wholePaper:
            return "論文全体"
        case .section:
            return "選択セクション"
        }
    }
}

struct PaperCharacter: Codable, Hashable {
    var domain: PaperDomain
    var difficulty: PaperDifficulty
    var nature: PaperNature
    var evolutionStage: PaperEvolutionStage
    var understandingScore: Int

    static let `default` = PaperCharacter(
        domain: .unknown,
        difficulty: .intermediate,
        nature: .mixed,
        evolutionStage: .egg,
        understandingScore: 0
    )
}

enum PaperDomain: String, Codable, Hashable {
    case vlm
    case nlp
    case cv
    case rag
    case ml
    case theory
    case systems
    case unknown

    var label: String {
        switch self {
        case .vlm: return "VLM"
        case .nlp: return "NLP"
        case .cv: return "CV"
        case .rag: return "RAG"
        case .ml: return "ML"
        case .theory: return "理論"
        case .systems: return "Systems"
        case .unknown: return "未分類"
        }
    }

    var systemImage: String {
        switch self {
        case .vlm: return "photo.on.rectangle"
        case .nlp: return "text.bubble"
        case .cv: return "eye"
        case .rag: return "books.vertical"
        case .ml: return "brain"
        case .theory: return "function"
        case .systems: return "server.rack"
        case .unknown: return "doc.text"
        }
    }
}

enum PaperDifficulty: String, Codable, Hashable {
    case beginner
    case intermediate
    case advanced

    var label: String {
        switch self {
        case .beginner: return "初級"
        case .intermediate: return "中級"
        case .advanced: return "上級"
        }
    }
}

enum PaperNature: String, Codable, Hashable {
    case theoretical
    case experimental
    case practical
    case survey
    case mixed

    var label: String {
        switch self {
        case .theoretical: return "理論寄り"
        case .experimental: return "実験寄り"
        case .practical: return "実用寄り"
        case .survey: return "サーベイ"
        case .mixed: return "複合"
        }
    }
}

enum PaperEvolutionStage: String, Codable, Hashable {
    case egg
    case reading
    case mastered

    var label: String {
        switch self {
        case .egg: return "未読"
        case .reading: return "読書中"
        case .mastered: return "整理済み"
        }
    }

    var progress: Double {
        switch self {
        case .egg: return 0.2
        case .reading: return 0.6
        case .mastered: return 1.0
        }
    }
}

struct PaperParagraph: Identifiable, Hashable {
    var id: Int { index }
    var index: Int
    var sourceText: String
    var translatedText: String
    var note: String
}

struct QuestionAnswer: Identifiable, Codable, Hashable {
    var id = UUID()
    var question: String
    var answer: String
    var scope: QuestionScope
    var createdAt = Date()
}

enum QuestionScope: String, Codable, Hashable {
    case wholePaper
    case selection

    var label: String {
        switch self {
        case .wholePaper:
            return "論文全体"
        case .selection:
            return "選択箇所"
        }
    }
}
