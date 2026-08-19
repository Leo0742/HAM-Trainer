import AppKit
import Combine
import Foundation

@MainActor
final class AppStore: ObservableObject {
    static let schemaVersion = 1
    @Published private(set) var questions: [Question] = []
    @Published private(set) var glossary: [GlossaryEntry] = []
    @Published var progress: [String: QuestionProgress] = [:]
    @Published var weakConceptIds: Set<String> = []
    @Published var mockScores: [MockExamScore] = []
    @Published var settings = UserSettings()
    @Published var errorMessage: String?

    private let scheduler = AdaptiveReviewScheduler()
    private let persistenceURL: URL

    init(persistenceURL: URL? = nil, loadContent: Bool = true) {
        self.persistenceURL = persistenceURL ?? Self.defaultPersistenceURL
        if loadContent { loadBundledContent() }
        loadProgress()
    }

    static var defaultPersistenceURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("HAMTrainer", isDirectory: true).appendingPathComponent("progress-v1.json")
    }

    func progressFor(_ question: Question) -> QuestionProgress { progress[question.id] ?? QuestionProgress(questionId: question.id) }

    @discardableResult
    func record(_ outcome: AttemptOutcome, for question: Question, at date: Date = Date()) -> QuestionProgress {
        let updated = scheduler.applying(outcome, to: progressFor(question), at: date)
        progress[question.id] = updated
        saveProgress()
        return updated
    }

    func toggleBookmark(_ question: Question) {
        var item = progressFor(question)
        item.bookmarked.toggle()
        progress[question.id] = item
        saveProgress()
    }

    func toggleHard(_ question: Question) {
        var item = progressFor(question)
        item.manuallyMarkedHard.toggle()
        if item.manuallyMarkedHard && item.state != .mastered { item.state = .weak }
        progress[question.id] = item
        saveProgress()
    }

    func updateNote(_ note: String, for question: Question) {
        var item = progressFor(question)
        item.note = note
        progress[question.id] = item
        saveProgress()
    }

    func markConceptWeak(_ id: String) {
        weakConceptIds.insert(id)
        saveProgress()
    }

    func tagMistake(_ reason: MistakeReason, question: Question) {
        var item = progressFor(question)
        item.lastMistakeReason = reason
        progress[question.id] = item
        saveProgress()
    }

    func smartQuestions(length: Int, now: Date = Date()) -> [Question] {
        scheduler.smartQueue(questions: questions, progress: progress, length: length, at: now)
    }

    func addMockScore(correct: Int, failed: [Question]) {
        mockScores.append(MockExamScore(id: UUID(), date: Date(), correct: correct, total: 30))
        for question in failed { _ = record(.incorrect, for: question) }
        saveProgress()
    }

    func exportBackup(to url: URL) throws {
        let backup = ProgressBackup(schemaVersion: Self.schemaVersion, exportedAt: Date(), progress: progress, weakConceptIds: weakConceptIds, mockScores: mockScores, settings: settings)
        try Self.encoder.encode(backup).write(to: url, options: .atomic)
    }

    func importBackup(from url: URL) throws {
        let backup = try Self.decoder.decode(ProgressBackup.self, from: Data(contentsOf: url))
        guard backup.schemaVersion <= Self.schemaVersion else { throw CocoaError(.coderReadCorrupt) }
        progress = questions.isEmpty ? backup.progress : backup.progress.filter { id, _ in questions.contains(where: { $0.id == id }) }
        weakConceptIds = backup.weakConceptIds
        mockScores = backup.mockScores
        settings = backup.settings
        saveProgress()
    }

    func resetProgress() {
        progress = [:]
        weakConceptIds = []
        mockScores = []
        saveProgress()
    }

    func saveProgress() {
        do {
            try FileManager.default.createDirectory(at: persistenceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let backup = ProgressBackup(schemaVersion: Self.schemaVersion, exportedAt: Date(), progress: progress, weakConceptIds: weakConceptIds, mockScores: mockScores, settings: settings)
            try Self.encoder.encode(backup).write(to: persistenceURL, options: .atomic)
        } catch { errorMessage = "Не удалось сохранить прогресс: \(error.localizedDescription)" }
    }

    private func loadBundledContent() {
        do {
            let questionsURL = try resourceURL("questions.json")
            let glossaryURL = try resourceURL("glossary.json")
            questions = try Self.decoder.decode([Question].self, from: Data(contentsOf: questionsURL))
            glossary = try Self.decoder.decode([GlossaryEntry].self, from: Data(contentsOf: glossaryURL))
        } catch { errorMessage = "Не удалось загрузить банк вопросов: \(error.localizedDescription)" }
    }

    private func resourceURL(_ name: String) throws -> URL {
        if let url = Bundle.studyResources.url(forResource: name, withExtension: nil, subdirectory: "Content") { return url }
        throw CocoaError(.fileNoSuchFile)
    }

    private func loadProgress() {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        do {
            let backup = try Self.decoder.decode(ProgressBackup.self, from: Data(contentsOf: persistenceURL))
            progress = backup.progress
            weakConceptIds = backup.weakConceptIds
            mockScores = backup.mockScores
            settings = backup.settings
        } catch { errorMessage = "Файл прогресса повреждён. Исходный файл сохранён: \(error.localizedDescription)" }
    }

    static let encoder: JSONEncoder = {
        let value = JSONEncoder(); value.outputFormatting = [.prettyPrinted, .sortedKeys]; value.dateEncodingStrategy = .iso8601; return value
    }()
    static let decoder: JSONDecoder = {
        let value = JSONDecoder(); value.dateDecodingStrategy = .iso8601; return value
    }()
}

extension Bundle {
    static var studyResources: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }
}
