import Foundation

struct AdaptiveReviewScheduler: Sendable {
    static let intervals = [1, 3, 7, 14, 30, 60]
    private let calendar = Calendar(identifier: .gregorian)

    func applying(_ outcome: AttemptOutcome, to old: QuestionProgress, at now: Date) -> QuestionProgress {
        var progress = old
        progress.attempts += 1
        progress.firstSeenAt = progress.firstSeenAt ?? now
        progress.lastSeenAt = now
        progress.lastOutcome = outcome

        switch outcome {
        case .correct:
            progress.correctCount += 1
            progress.consecutiveCorrect += 1
            if old.state == .unseen {
                progress.state = .review
                progress.intervalDays = 1
            } else {
                progress.successfulSpacedReviews += 1
                let currentIndex = Self.intervals.lastIndex(where: { $0 <= max(1, old.intervalDays) }) ?? 0
                progress.intervalDays = Self.intervals[min(currentIndex + 1, Self.intervals.count - 1)]
                if old.state == .weak && progress.consecutiveCorrect >= 3 {
                    progress.state = .review
                } else if progress.successfulSpacedReviews >= 4,
                          progress.intervalDays >= 14,
                          !hasRecentFailure(progress, at: now) {
                    progress.state = .mastered
                } else if progress.state != .mastered {
                    progress.state = .review
                }
            }
            progress.nextDueAt = calendar.date(byAdding: .day, value: progress.intervalDays, to: now)

        case .incorrect, .dontKnow, .revealedBeforeAnswer:
            if outcome == .incorrect { progress.incorrectCount += 1 }
            if outcome == .dontKnow { progress.dontKnowCount += 1 }
            if outcome == .revealedBeforeAnswer { progress.revealedCount += 1 }
            progress.consecutiveCorrect = 0
            progress.lapseCount += old.state == .unseen ? 0 : 1
            progress.lastFailureAt = now
            progress.intervalDays = 1
            progress.state = (outcome == .dontKnow || outcome == .revealedBeforeAnswer || progress.lapseCount >= 2) ? .weak : .learning
            progress.nextDueAt = calendar.date(byAdding: .day, value: 1, to: now)
        }
        return progress
    }

    func priority(for progress: QuestionProgress, topicWeakness: Double, at now: Date) -> Double {
        let due: Double
        if let date = progress.nextDueAt {
            due = max(0, now.timeIntervalSince(date) / 86_400) + (date <= now ? 4 : 0)
        } else {
            due = progress.state == .unseen ? 2 : 0
        }
        let stateWeight: Double = switch progress.state {
        case .weak: 7
        case .learning: 5
        case .review: 3
        case .unseen: 2
        case .mastered: 0.2
        }
        let recencyRecovery = Double(progress.consecutiveCorrect) * 0.8
        return stateWeight + due + Double(progress.lapseCount) * 0.7 + topicWeakness * 2 - recencyRecovery
    }

    func smartQueue(questions: [Question], progress: [String: QuestionProgress], length: Int, at now: Date) -> [Question] {
        let length = max(1, min(length, questions.count))
        let topicWeakness = weaknessByTopic(questions: questions, progress: progress)
        let getProgress = { (q: Question) in progress[q.id] ?? QuestionProgress(questionId: q.id) }
        let due = questions.filter {
            let p = getProgress($0)
            return p.state != .unseen && p.state != .mastered && (p.nextDueAt ?? .distantPast) <= now
        }.sorted { a, b in
            let ap = priority(for: getProgress(a), topicWeakness: topicWeakness[a.topic, default: 0], at: now)
            let bp = priority(for: getProgress(b), topicWeakness: topicWeakness[b.topic, default: 0], at: now)
            return ap == bp ? a.examNumber < b.examNumber : ap > bp
        }
        let unseen = questions.filter { getProgress($0).state == .unseen }.sorted { $0.examNumber < $1.examNumber }
        let maintenance = questions.filter {
            let p = getProgress($0)
            return p.state == .mastered && (p.nextDueAt ?? .distantFuture) <= now
        }.sorted { $0.examNumber < $1.examNumber }

        var result: [Question] = []
        let dueTarget = min(due.count, Int(ceil(Double(length) * 0.5)))
        let unseenTarget = min(unseen.count, Int(ceil(Double(length) * 0.4)))
        appendBalanced(from: Array(due.prefix(dueTarget)), to: &result, limit: length)
        appendBalanced(from: Array(unseen.prefix(unseenTarget)), to: &result, limit: length)
        appendBalanced(from: Array(maintenance.prefix(max(1, length / 10))), to: &result, limit: length)
        appendBalanced(from: due + unseen + maintenance + questions.sorted { $0.examNumber < $1.examNumber }, to: &result, limit: length)
        return result
    }

    private func appendBalanced(from candidates: [Question], to result: inout [Question], limit: Int) {
        let maxPerTopic = max(1, Int(ceil(Double(limit) * 0.4)))
        for question in candidates where result.count < limit && !result.contains(where: { $0.id == question.id }) {
            let count = result.count(where: { $0.topic == question.topic })
            if count < maxPerTopic { result.append(question) }
        }
    }

    private func weaknessByTopic(questions: [Question], progress: [String: QuestionProgress]) -> [String: Double] {
        Dictionary(grouping: questions, by: \.topic).mapValues { values in
            let states = values.compactMap { progress[$0.id] }
            guard !states.isEmpty else { return 0 }
            return Double(states.count(where: { $0.state == .weak || $0.state == .learning })) / Double(states.count)
        }
    }

    private func hasRecentFailure(_ progress: QuestionProgress, at now: Date) -> Bool {
        guard let failure = progress.lastFailureAt else { return false }
        return now.timeIntervalSince(failure) < 7 * 86_400
    }
}

struct StudySession: Sendable {
    private(set) var queue: [Question]
    private(set) var index = 0
    private(set) var appearanceCounts: [String: Int] = [:]
    private(set) var summary = SessionSummary()
    let drillWeak: Bool

    init(questions: [Question], drillWeak: Bool = false) {
        self.queue = questions
        self.drillWeak = drillWeak
    }

    var current: Question? { index < queue.count ? queue[index] : nil }
    var isComplete: Bool { index >= queue.count }
    var position: Int { min(index + 1, queue.count) }

    mutating func record(_ outcome: AttemptOutcome) {
        guard let question = current else { return }
        let count = appearanceCounts[question.id, default: 0] + 1
        appearanceCounts[question.id] = count
        summary.total += 1
        switch outcome {
        case .correct: summary.correct += 1
        case .incorrect: summary.incorrect += 1
        case .dontKnow: summary.dontKnow += 1
        case .revealedBeforeAnswer: summary.revealed += 1
        }
        if outcome != .correct {
            summary.topics[question.topic, default: 0] += 1
            let limit = drillWeak ? 4 : 2
            if count < limit {
                let gap = 6 + (question.examNumber % 7)
                let insertion = min(queue.count, index + gap + 1)
                queue.insert(question, at: insertion)
            }
        }
    }

    mutating func advance() { index += 1 }
}

struct MockExamBuilder: Sendable {
    static let questionCount = 30
    static let passingScore = 25
    func makeExam(from questions: [Question]) -> [Question] { Array(questions.shuffled().prefix(Self.questionCount)) }
    func passed(correct: Int) -> Bool { correct >= Self.passingScore }
}
