import Foundation

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
        id: id, examNumber: number, stem: "Вопрос \(number) о радиосвязи",
        options: [
            QuestionOption(id: "\(id)-1", text: "Верно"),
            QuestionOption(id: "\(id)-2", text: "Неверно"),
            QuestionOption(id: "\(id)-3", text: "Тоже неверно"),
            QuestionOption(id: "\(id)-4", text: "Ещё один вариант")
        ],
        correctOptionId: "\(id)-1", officialCorrectAnswerText: "Верно", topic: topic, subtopic: topic,
        type: "понять принцип", explanationShort: "Короткое предметное объяснение.",
        explanationBeginner: "Понятное объяснение термина и принципа с нуля.",
        explanationReasoning: "Правильный вариант следует из физического принципа.",
        wrongOptionExplanations: ["\(id)-2": "Противоречит условию.", "\(id)-3": "Описывает другое явление.", "\(id)-4": "Не относится к вопросу."],
        memoryHint: "Свяжите правило с примером.", glossaryTerms: [], figureAsset: nil,
        sourceReference: SourceReference(document: "source.pdf", page: 1, sourceQuestionNumber: number, explanationDocument: "guide.pdf", explanationPage: 1),
        legalHistoricalNote: nil
    )
}

func temporaryURL(_ name: String = "progress.json") -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-\(name)")
}

@main
struct CoreTestRunner {
    @MainActor
    static func main() throws {
        let content = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Content")
        var tests: [(String, () throws -> Void)] = []
        let scheduler = AdaptiveReviewScheduler()

        tests.append(("wrong becomes due after five other answers", {
            let failed = scheduler.applying(.incorrect, to: QuestionProgress(questionId: "q"), completedStudyStep: 100)
            try expect(failed.nextDueStudyStep == 106, "wrong due step should be 106")
            try expect(!scheduler.isDue(failed, completedStudyStep: 104), "shown after only four other answers")
            try expect(scheduler.isDue(failed, completedStudyStep: 105), "not due after five other answers")
        }))

        tests.append(("dont know uses five-question gap", {
            let value = scheduler.applying(.dontKnow, to: QuestionProgress(questionId: "q"), completedStudyStep: 7)
            try expect(value.state == .weak && value.dontKnowCount == 1, "don't know not weak")
            try expect(value.nextDueStudyStep == 13, "don't know gap is not five")
        }))

        tests.append(("reveal is a graded failure", {
            let value = scheduler.applying(.revealedBeforeAnswer, to: QuestionProgress(questionId: "q"), completedStudyStep: 12)
            try expect(value.state == .weak && value.revealedCount == 1 && value.correctCount == 0, "reveal counted as knowledge")
            try expect(value.nextDueStudyStep == 18, "reveal gap is not five")
        }))

        tests.append(("review ladder is 5 10 20 40 80", {
            var value = scheduler.applying(.incorrect, to: QuestionProgress(questionId: "q"), completedStudyStep: 1)
            try expect(value.reviewStage == 0 && value.nextDueStudyStep == 7, "failure did not enter stage 5")
            value = scheduler.applying(.correct, to: value, completedStudyStep: 7)
            try expect(value.reviewStage == 1 && value.nextDueStudyStep == 18, "recovery did not schedule 10")
            value = scheduler.applying(.correct, to: value, completedStudyStep: 18)
            try expect(value.reviewStage == 2 && value.nextDueStudyStep == 39, "second recall did not schedule 20")
            value = scheduler.applying(.correct, to: value, completedStudyStep: 39)
            try expect(value.reviewStage == 3 && value.nextDueStudyStep == 80, "third recall did not schedule 40")
            value = scheduler.applying(.correct, to: value, completedStudyStep: 80)
            try expect(value.reviewStage == 4 && value.nextDueStudyStep == 161 && value.state == .mastered, "fourth recall did not schedule 80/master")
        }))

        tests.append(("first correct answer starts at distance five", {
            let value = scheduler.applying(.correct, to: QuestionProgress(questionId: "q"), completedStudyStep: 20)
            try expect(value.reviewStage == 0 && value.nextDueStudyStep == 26, "new correct card skipped the five-question stage")
        }))

        tests.append(("lapse removes mastery and rebuilds confidence", {
            var old = QuestionProgress(questionId: "q")
            old.state = .mastered; old.reviewStage = 4; old.successfulSpacedReviews = 6
            let value = scheduler.applying(.incorrect, to: old, completedStudyStep: 90)
            try expect(value.state == .weak && value.reviewStage == 0 && value.lapseCount == 1, "mastered lapse was not reset")
            try expect(value.nextDueStudyStep == 96, "lapse did not use short interval")
        }))

        tests.append(("study step persists across restart", {
            let url = temporaryURL()
            let question = sampleQuestion(1)
            let first = AppStore(persistenceURL: url, loadContent: false)
            _ = first.record(.incorrect, for: question)
            _ = first.record(.correct, for: sampleQuestion(2))
            let restarted = AppStore(persistenceURL: url, loadContent: false)
            try expect(restarted.studyStep == 2, "studyStep reset on restart")
            try expect(restarted.progressFor(question).nextDueStudyStep == 7, "due distance changed on restart")
        }))

        tests.append(("session boundary preserves remaining distance", {
            let url = temporaryURL()
            let failed = sampleQuestion(1)
            let first = AppStore(persistenceURL: url, loadContent: false)
            _ = first.record(.incorrect, for: failed)
            _ = first.record(.correct, for: sampleQuestion(2))
            _ = first.record(.correct, for: sampleQuestion(3))
            let restarted = AppStore(persistenceURL: url, loadContent: false)
            let remaining = scheduler.remainingQuestionDistance(restarted.progressFor(failed), completedStudyStep: restarted.studyStep)
            try expect(remaining == 3, "remaining question distance did not survive restart")
        }))

        tests.append(("question is never selected before due", {
            let q = sampleQuestion(1)
            var state = QuestionProgress(questionId: q.id)
            state.state = .weak; state.nextDueStudyStep = 20
            let early = scheduler.smartQueue(questions: [q], progress: [q.id: state], length: 20, completedStudyStep: 10)
            try expect(early.isEmpty, "non-due question entered Smart Study")
        }))

        tests.append(("non-due mastered bank yields empty Smart Study", {
            let bank = (1...405).map { sampleQuestion($0) }
            let state = Dictionary(uniqueKeysWithValues: bank.map { q -> (String, QuestionProgress) in
                var progress = QuestionProgress(questionId: q.id)
                progress.state = .mastered; progress.reviewStage = 4; progress.nextDueStudyStep = 500
                return (q.id, progress)
            })
            let queue = scheduler.smartQueue(questions: bank, progress: state, length: 20, completedStudyStep: 100)
            try expect(queue.isEmpty, "Smart Study fabricated mandatory mastered reviews")
        }))

        tests.append(("session repeat respects minimum gap and appearance cap", {
            let bank = (1...20).map { sampleQuestion($0) }
            var session = StudySession(questions: bank)
            session.record(.incorrect)
            let repeatIndex = session.queue.lastIndex(where: { $0.id == bank[0].id })
            try expect(repeatIndex == 6, "failure was not placed after five other cards")
            repeat { session.advance() } while session.currentQuestion?.id != bank[0].id
            session.record(.incorrect)
            try expect(session.queue.count(where: { $0.id == bank[0].id }) == 2, "normal session exceeded repeat cap")
        }))

        tests.append(("short session does not violate scheduled gap", {
            var session = StudySession(questions: (1...4).map { sampleQuestion($0) })
            session.record(.incorrect)
            try expect(session.queue.count == 4, "repeat inserted without five intervening cards")
        }))

        tests.append(("due weak questions outrank new questions", {
            let weak = sampleQuestion(1)
            let fresh = sampleQuestion(2)
            var weakProgress = QuestionProgress(questionId: weak.id)
            weakProgress.state = .weak; weakProgress.nextDueStudyStep = 10
            let queue = scheduler.smartQueue(questions: [fresh, weak], progress: [weak.id: weakProgress], length: 2, completedStudyStep: 9)
            try expect(queue.map(\.id) == [weak.id, fresh.id], "new question outranked due weak question")
            try expect(queue.map(\.reason) == [.weak, .new], "selection reasons are not explicit")
        }))

        tests.append(("requested length does not override eligibility", {
            let due = sampleQuestion(1)
            var dueProgress = QuestionProgress(questionId: due.id)
            dueProgress.state = .review; dueProgress.nextDueStudyStep = 2
            let mastered = (2...30).map { sampleQuestion($0) }
            var state = [due.id: dueProgress]
            for q in mastered {
                var value = QuestionProgress(questionId: q.id)
                value.state = .mastered; value.nextDueStudyStep = 999
                state[q.id] = value
            }
            let queue = scheduler.smartQueue(questions: [due] + mastered, progress: state, length: 20, completedStudyStep: 1)
            try expect(queue.count == 1 && queue[0].id == due.id, "session length fabricated non-due cards")
        }))

        tests.append(("due maintenance remains a small slice", {
            let bank = (1...100).map { sampleQuestion($0) }
            let state = Dictionary(uniqueKeysWithValues: bank.map { q -> (String, QuestionProgress) in
                var value = QuestionProgress(questionId: q.id)
                value.state = .mastered; value.nextDueStudyStep = 1
                return (q.id, value)
            })
            let queue = scheduler.smartQueue(questions: bank, progress: state, length: 20, completedStudyStep: 1)
            try expect(queue.count == 2 && queue.allSatisfy { $0.reason == .maintenance }, "maintenance cap is not 10 percent")
        }))

        tests.append(("option shuffling preserves correctness ID", {
            let q = sampleQuestion(1)
            for _ in 0..<30 {
                let shuffled = q.options.shuffled()
                try expect(shuffled.contains(where: { $0.id == q.correctOptionId }), "correct ID lost while shuffling")
                try expect(shuffled.first(where: { $0.id == q.correctOptionId })?.text == "Верно", "correct option mapping changed")
            }
        }))

        tests.append(("mock exam is 30 unique questions with 25 threshold", {
            let bank = (1...405).map { sampleQuestion($0) }
            let builder = MockExamBuilder()
            let exam = builder.makeExam(from: bank)
            try expect(exam.count == 30 && Set(exam.map(\.id)).count == 30, "mock selection invalid")
            try expect(!builder.passed(correct: 24) && builder.passed(correct: 25), "pass threshold invalid")
        }))

        tests.append(("early mock finish distinguishes unanswered", {
            let exam = (1...30).map { sampleQuestion($0) }
            let answers = Dictionary(uniqueKeysWithValues: exam.prefix(5).map { ($0.id, $0.correctOptionId) })
            let result = MockExamBuilder().grade(questions: exam, answers: answers)
            try expect(result.correct == 5 && result.answered == 5 && result.unansweredQuestionIDs.count == 25, "unanswered exam state is wrong")
            try expect(result.incorrectQuestionIDs.isEmpty, "unanswered questions became incorrect")
        }))

        tests.append(("mock adaptive history records only submitted answers", {
            let url = temporaryURL()
            let exam = (1...30).map { sampleQuestion($0) }
            let answers = [exam[0].id: exam[0].correctOptionId, exam[1].id: exam[1].options[1].id]
            let store = AppStore(persistenceURL: url, loadContent: false)
            let result = store.finishMockExam(questions: exam, answers: answers)
            try expect(store.studyStep == 2 && result.unansweredQuestionIDs.count == 28, "mock studyStep counted unanswered")
            try expect(store.progressFor(exam[0]).correctCount == 1, "submitted correct answer missing")
            try expect(store.progressFor(exam[1]).incorrectCount == 1, "submitted wrong answer missing")
            try expect(store.progressFor(exam[2]).attempts == 0, "unanswered question contaminated progress")
        }))

        tests.append(("notes bookmarks and scheduler state persist", {
            let url = temporaryURL()
            let q = sampleQuestion(9)
            let first = AppStore(persistenceURL: url, loadContent: false)
            _ = first.record(.dontKnow, for: q)
            first.toggleBookmark(q)
            first.updateNote("Проверить формулу", for: q)
            let restarted = AppStore(persistenceURL: url, loadContent: false)
            let value = restarted.progressFor(q)
            try expect(value.dontKnowCount == 1 && value.bookmarked && value.note == "Проверить формулу", "question-owned data did not persist")
            try expect(value.nextDueStudyStep == 7, "scheduler state did not persist")
        }))

        tests.append(("concept weakness is visible and learnable", {
            let url = temporaryURL()
            let store = AppStore(persistenceURL: url, loadContent: false)
            store.markConceptWeak("swr"); store.markConceptWeak("swr")
            try expect(store.weakConceptIds.contains("swr") && store.conceptProgressFor("swr").unclearCount == 2, "weak concept was hidden")
            store.markConceptUnderstood("swr")
            try expect(!store.weakConceptIds.contains("swr") && store.conceptProgressFor("swr").isLearned, "understood concept remained weak")
        }))

        tests.append(("personal glossary CRUD persists", {
            let url = temporaryURL()
            let first = AppStore(persistenceURL: url, loadContent: false)
            var entry = first.addPersonalGlossaryEntry(term: "Балун", relatedQuestionIDs: ["q-1"])
            entry.shortDefinition = "Симметрирующее устройство"
            entry.personalNotes = "Проверить тип 1:1"
            first.updatePersonalGlossaryEntry(entry)
            let restarted = AppStore(persistenceURL: url, loadContent: false)
            try expect(restarted.personalGlossary.first?.shortDefinition == "Симметрирующее устройство", "personal term did not persist")
            restarted.deletePersonalGlossaryEntry(id: entry.id)
            try expect(restarted.personalGlossary.isEmpty, "personal term was not deleted")
        }))

        tests.append(("backup round trip restores all user state", {
            let sourceURL = temporaryURL()
            let exportURL = temporaryURL("backup.json")
            let targetURL = temporaryURL()
            let q = sampleQuestion(3)
            let source = AppStore(persistenceURL: sourceURL, loadContent: false)
            _ = source.record(.incorrect, for: q)
            source.updateNote("заметка", for: q)
            source.markConceptWeak("dipole")
            _ = source.addPersonalGlossaryEntry(term: "Фидер", relatedQuestionIDs: [q.id])
            source.settings.defaultSessionLength = 30
            source.saveProgress()
            try source.exportBackup(to: exportURL)
            let target = AppStore(persistenceURL: targetURL, loadContent: false)
            try target.importBackup(from: exportURL)
            try expect(target.studyStep == 1 && target.progressFor(q).incorrectCount == 1, "progress/step backup failed")
            try expect(target.progressFor(q).note == "заметка" && target.weakConceptIds.contains("dipole"), "notes/concepts backup failed")
            try expect(target.personalGlossary.count == 1 && target.settings.defaultSessionLength == 30, "glossary/settings backup failed")
        }))

        tests.append(("malformed import does not erase current data", {
            let url = temporaryURL()
            let malformed = temporaryURL("broken.json")
            let q = sampleQuestion(4)
            let store = AppStore(persistenceURL: url, loadContent: false)
            _ = store.record(.correct, for: q)
            try Data("{not-json".utf8).write(to: malformed)
            do {
                try store.importBackup(from: malformed)
                throw TestFailure.failed("malformed import unexpectedly succeeded")
            } catch is TestFailure {
                throw TestFailure.failed("malformed import unexpectedly succeeded")
            } catch {}
            try expect(store.progressFor(q).correctCount == 1 && store.studyStep == 1, "malformed import mutated current state")
        }))

        tests.append(("session summary tracks outcomes and transitions", {
            let q = sampleQuestion(1)
            var session = StudySession(questions: [q])
            session.record(.dontKnow, previousState: .unseen, newState: .weak)
            try expect(session.summary.total == 1 && session.summary.dontKnow == 1, "summary outcome counts wrong")
            try expect(session.summary.becameWeak == 1 && session.summary.mistakeQuestionIDs == [q.id], "summary transition/mistake list wrong")
        }))

        tests.append(("content bank integrity and provenance", {
            let data = try Data(contentsOf: content.appendingPathComponent("questions.json"))
            let questions = try AppStore.decoder.decode([Question].self, from: data)
            let expected = Set(1...38).union(47...98).union(100...374).union(387...426)
            try expect(questions.count == 405 && Set(questions.map(\.examNumber)) == expected, "wrong question selection")
            try expect(Set(questions.map(\.id)).count == 405, "duplicate IDs")
            for question in questions {
                try expect(!question.stem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "empty stem \(question.examNumber)")
                try expect(question.options.count >= 3 && question.options.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "incomplete options \(question.examNumber)")
                try expect(question.options.contains(where: { $0.id == question.correctOptionId }), "invalid answer \(question.examNumber)")
                try expect(question.sourceReference.sourceQuestionNumber == question.examNumber, "missing provenance \(question.examNumber)")
                if let asset = question.figureAsset {
                    try expect(FileManager.default.fileExists(atPath: content.appendingPathComponent(asset).path), "missing \(asset)")
                }
            }
        }))

        tests.append(("all glossary references resolve", {
            let questions = try AppStore.decoder.decode([Question].self, from: Data(contentsOf: content.appendingPathComponent("questions.json")))
            let glossary = try AppStore.decoder.decode([GlossaryEntry].self, from: Data(contentsOf: content.appendingPathComponent("glossary.json")))
            let ids = Set(glossary.map(\.id))
            let missing = Set(questions.flatMap(\.glossaryTerms)).subtracting(ids)
            try expect(missing.isEmpty, "unresolved glossary IDs: \(missing.sorted())")
            try expect(glossary.count >= 100, "glossary is not comprehensive: \(glossary.count)")
        }))

        tests.append(("all 405 explanations pass anti-template audit", {
            let questions = try AppStore.decoder.decode([Question].self, from: Data(contentsOf: content.appendingPathComponent("questions.json")))
            let banned = [
                "Если слова в формулировке незнакомы, откройте выделенные термины",
                "Сначала определите, что именно проверяет вопрос. Затем сопоставьте это с правилом:",
                "не соответствует правилу из экзаменационного банка"
            ]
            for question in questions {
                try expect(question.explanationShort.count >= 25, "short explanation too small: \(question.examNumber)")
                try expect(question.explanationBeginner.count >= 160, "beginner explanation too small: \(question.examNumber)")
                try expect(question.explanationReasoning.count >= 80, "reasoning too small: \(question.examNumber)")
                try expect(!banned.contains(where: { question.explanationBeginner.contains($0) || question.explanationReasoning.contains($0) }), "generic explanation: \(question.examNumber)")
                try expect(question.wrongOptionExplanations.count == question.options.count - 1, "wrong-option coverage: \(question.examNumber)")
                try expect(question.wrongOptionExplanations.values.allSatisfy { value in !banned.contains(where: value.contains) && value.count >= 30 }, "generic wrong-option explanation: \(question.examNumber)")
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
