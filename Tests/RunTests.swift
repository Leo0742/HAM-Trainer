import Foundation

// SwiftPM synthesizes this accessor for the application. The lightweight test
// runner compiles the production files directly because this Mac's Command Line
// Tools package omits XCTest and Swift Testing.
extension Bundle { static let module = Bundle.main }

enum TestFailure: Error, CustomStringConvertible {
    case failed(String)
    var description: String { if case let .failed(message) = self { return message }; return "failure" }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure.failed(message) }
}

func sampleQuestion(_ number: Int, topic: String = "Тема") -> Question {
    let id = "q-\(number)"
    return Question(
        id: id, examNumber: number, stem: "Вопрос \(number)",
        options: [QuestionOption(id: "\(id)-1", text: "Верно"), QuestionOption(id: "\(id)-2", text: "Неверно")],
        correctOptionId: "\(id)-1", officialCorrectAnswerText: "Верно", topic: topic, subtopic: topic,
        type: "понять принцип", explanationShort: "Коротко", explanationBeginner: "С нуля",
        explanationReasoning: "Почему", wrongOptionExplanations: ["\(id)-2": "Неверно"], memoryHint: "Подсказка",
        glossaryTerms: [], figureAsset: nil,
        sourceReference: SourceReference(document: "source.pdf", page: 1, sourceQuestionNumber: number, explanationDocument: "guide.pdf", explanationPage: 1),
        legalHistoricalNote: nil
    )
}

@main
struct CoreTestRunner {
    @MainActor
    static func main() throws {
        let content = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Content")
        var tests: [(String, () throws -> Void)] = []
        let scheduler = AdaptiveReviewScheduler()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        tests.append(("wrong question returns later, not immediately", {
            let questions = (1...20).map { sampleQuestion($0) }
            var session = StudySession(questions: questions)
            session.record(.incorrect)
            try expect(session.queue.count == 21, "repeat was not inserted")
            try expect(session.queue[1].id != questions[0].id, "question repeated immediately")
            try expect(session.queue.lastIndex(where: { $0.id == questions[0].id })! >= 7, "repeat gap is too short")
        }))
        tests.append(("normal session limits repeats", {
            let questions = (1...20).map { sampleQuestion($0) }
            var session = StudySession(questions: questions)
            session.record(.incorrect)
            repeat { session.advance() } while session.current?.id != questions[0].id
            session.record(.incorrect)
            try expect(session.queue.count(where: { $0.id == questions[0].id }) == 2, "question repeated more than twice")
        }))
        tests.append(("correct reviews expand intervals and master", {
            var progress = scheduler.applying(.correct, to: QuestionProgress(questionId: "q"), at: now)
            try expect(progress.intervalDays == 1, "first interval is not one day")
            for _ in 0..<4 { progress = scheduler.applying(.correct, to: progress, at: progress.nextDueAt!) }
            try expect(progress.state == .mastered, "four spaced reviews did not master")
            try expect(progress.intervalDays >= 14, "mastery interval is too short")
        }))
        tests.append(("lapse removes mastery", {
            var progress = QuestionProgress(questionId: "q")
            progress.state = .mastered; progress.intervalDays = 30; progress.successfulSpacedReviews = 5
            progress = scheduler.applying(.incorrect, to: progress, at: now)
            try expect(progress.state != .mastered && progress.intervalDays == 1 && progress.lapseCount == 1, "lapse handling failed")
        }))
        tests.append(("weak item recovers after successes", {
            var progress = QuestionProgress(questionId: "q")
            progress.state = .weak; progress.intervalDays = 1
            for day in [1, 3, 7] { progress = scheduler.applying(.correct, to: progress, at: now.addingTimeInterval(Double(day) * 86_400)) }
            try expect(progress.state == .review, "weak state became permanent")
        }))
        tests.append(("dont know and reveal are distinct failures", {
            let unknown = scheduler.applying(.dontKnow, to: QuestionProgress(questionId: "q"), at: now)
            let revealed = scheduler.applying(.revealedBeforeAnswer, to: QuestionProgress(questionId: "r"), at: now)
            try expect(unknown.dontKnowCount == 1 && unknown.state == .weak, "dont know not recorded")
            try expect(revealed.revealedCount == 1 && revealed.correctCount == 0 && revealed.state == .weak, "reveal counted as knowledge")
        }))
        tests.append(("mastered maintenance is rare", {
            let questions = (1...100).map { sampleQuestion($0) }
            var state: [String: QuestionProgress] = [:]
            for q in questions.prefix(50) { var p = QuestionProgress(questionId: q.id); p.state = .mastered; p.nextDueAt = now.addingTimeInterval(-1); state[q.id] = p }
            let queue = scheduler.smartQueue(questions: questions, progress: state, length: 20, at: now)
            try expect(queue.count(where: { state[$0.id]?.state == .mastered }) <= 2, "too many mastered items")
        }))
        tests.append(("mock exam is 30 unique questions with 25 threshold", {
            let bank = (1...405).map { sampleQuestion($0) }
            let builder = MockExamBuilder(); let exam = builder.makeExam(from: bank)
            try expect(exam.count == 30 && Set(exam.map(\.id)).count == 30, "mock selection invalid")
            try expect(!builder.passed(correct: 24) && builder.passed(correct: 25), "pass threshold invalid")
        }))
        tests.append(("persistence survives restart and export/import", {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let progressURL = root.appendingPathComponent("progress.json")
            let exportURL = root.appendingPathComponent("backup.json")
            let question = sampleQuestion(9)
            let first = AppStore(persistenceURL: progressURL, loadContent: false)
            _ = first.record(.dontKnow, for: question); first.toggleBookmark(question)
            let restarted = AppStore(persistenceURL: progressURL, loadContent: false)
            try expect(restarted.progressFor(question).dontKnowCount == 1 && restarted.progressFor(question).bookmarked, "restart lost progress")
            try restarted.exportBackup(to: exportURL); restarted.resetProgress(); try restarted.importBackup(from: exportURL)
            try expect(restarted.progressFor(question).state == .weak && restarted.progressFor(question).bookmarked, "import lost progress")
        }))
        tests.append(("content bank integrity", {
            let data = try Data(contentsOf: content.appendingPathComponent("questions.json"))
            let questions = try JSONDecoder().decode([Question].self, from: data)
            let expected = Set(1...38).union(47...98).union(100...374).union(387...426)
            try expect(questions.count == 405 && Set(questions.map(\.examNumber)) == expected, "wrong question selection")
            try expect(Set(questions.map(\.id)).count == 405, "duplicate IDs")
            for question in questions {
                try expect(!question.options.isEmpty, "question \(question.examNumber) has no options")
                try expect(question.options.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "question \(question.examNumber) has an empty option")
                try expect(question.options.contains(where: { $0.id == question.correctOptionId }), "question \(question.examNumber) has invalid answer")
                try expect(!question.topic.isEmpty && !question.explanationBeginner.isEmpty, "question \(question.examNumber) has incomplete metadata")
                if let asset = question.figureAsset { try expect(FileManager.default.fileExists(atPath: content.appendingPathComponent(asset).path), "missing \(asset)") }
            }
        }))

        var failures = 0
        for (name, test) in tests {
            do { try test(); print("PASS  \(name)") }
            catch { failures += 1; print("FAIL  \(name): \(error)") }
        }
        print("\n\(tests.count - failures)/\(tests.count) tests passed")
        if failures > 0 { throw TestFailure.failed("\(failures) test(s) failed") }
    }
}
