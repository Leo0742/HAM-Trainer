import Foundation

struct QuestionOption: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let text: String
}

struct SourceReference: Codable, Hashable, Sendable {
    let document: String
    let page: Int
    let sourceQuestionNumber: Int
    let explanationDocument: String
    let explanationPage: Int
}

struct Question: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let examNumber: Int
    let stem: String
    let options: [QuestionOption]
    let correctOptionId: String
    let officialCorrectAnswerText: String
    let topic: String
    let subtopic: String
    let type: String
    let explanationShort: String
    let explanationBeginner: String
    let explanationReasoning: String
    let wrongOptionExplanations: [String: String]
    let memoryHint: String
    let glossaryTerms: [String]
    let figureAsset: String?
    let sourceReference: SourceReference
    let legalHistoricalNote: String?
}

struct GlossaryEntry: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let term: String
    let aliases: [String]
    let shortDefinition: String
    let fromZero: String
    let radioExample: String
}

enum LearningState: String, Codable, CaseIterable, Sendable {
    case unseen, learning, review, mastered, weak

    var title: String {
        switch self {
        case .unseen: "Не изучен"
        case .learning: "Изучение"
        case .review: "Повторение"
        case .mastered: "Освоен"
        case .weak: "Слабый"
        }
    }
}

enum AttemptOutcome: String, Codable, Sendable {
    case correct, incorrect, dontKnow, revealedBeforeAnswer
}

enum MistakeReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case unknownTerm = "Не знал термин"
    case forgotFact = "Забыл факт"
    case missedPrinciple = "Не понял принцип"
    case calculation = "Ошибка в расчёте"
    case misread = "Невнимательно прочитал"
    case guessed = "Угадал"
    var id: String { rawValue }
}

struct QuestionProgress: Codable, Hashable, Sendable {
    var questionId: String
    var state: LearningState = .unseen
    var attempts = 0
    var correctCount = 0
    var incorrectCount = 0
    var dontKnowCount = 0
    var revealedCount = 0
    var consecutiveCorrect = 0
    var successfulSpacedReviews = 0
    var lapseCount = 0
    var firstSeenAt: Date?
    var lastSeenAt: Date?
    var lastFailureAt: Date?
    var nextDueAt: Date?
    var intervalDays = 0
    var lastOutcome: AttemptOutcome?
    var bookmarked = false
    var manuallyMarkedHard = false
    var note = ""
    var lastMistakeReason: MistakeReason?

    init(questionId: String) { self.questionId = questionId }
}

struct MockExamScore: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let correct: Int
    let total: Int
    var passed: Bool { correct >= 25 }
}

struct UserSettings: Codable, Hashable, Sendable {
    var defaultSessionLength = 20
    var randomizeOptions = true
    var soundEffects = false
    var explanationStyle = "С нуля"
}

struct ProgressBackup: Codable, Sendable {
    var schemaVersion: Int
    var exportedAt: Date
    var progress: [String: QuestionProgress]
    var weakConceptIds: Set<String>
    var mockScores: [MockExamScore]
    var settings: UserSettings
}

struct SessionSummary: Sendable {
    var total = 0
    var correct = 0
    var incorrect = 0
    var dontKnow = 0
    var revealed = 0
    var becameWeak = 0
    var topics: [String: Int] = [:]
}
