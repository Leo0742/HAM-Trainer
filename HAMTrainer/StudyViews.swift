import SwiftUI

struct SmartStudyView: View {
    @EnvironmentObject private var store: AppStore
    @State private var length = 20
    @State private var session: StudySession?

    var body: some View {
        Group {
            if let session {
                StudyRunnerView(session: session, onFinish: { self.session = nil })
            } else {
                VStack(alignment: .leading, spacing: 26) {
                    Spacer()
                    Image(systemName: "sparkles").font(.system(size: 46)).foregroundStyle(.tint)
                    Text("Умная учёба").font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Сессия смешивает просроченные повторения, новые вопросы и немного материала для поддержания памяти. Одна слабая тема не займёт больше 40% очереди.")
                        .font(.title3).foregroundStyle(.secondary).frame(maxWidth: 700, alignment: .leading)
                    Picker("Длина", selection: $length) {
                        ForEach([10, 20, 30, 40], id: \.self) { Text("\($0) вопросов").tag($0) }
                    }.pickerStyle(.segmented).frame(maxWidth: 520)
                    Button("Начать сессию") {
                        session = StudySession(questions: store.smartQuestions(length: length))
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                    HStack(spacing: 22) {
                        Label("Ошибки возвращаются через 6–12 вопросов", systemImage: "arrow.uturn.forward")
                        Label("Не больше двух появлений", systemImage: "shield.lefthalf.filled")
                    }.font(.callout).foregroundStyle(.secondary)
                    Spacer()
                }.padding(38).frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear { length = store.settings.defaultSessionLength }
            }
        }.navigationTitle("Умная учёба")
    }
}

struct StudyRunnerView: View {
    @EnvironmentObject private var store: AppStore
    @State private var session: StudySession
    @State private var awaitingNext = false
    @State private var lastOutcome: AttemptOutcome?
    @State private var previousState: LearningState?
    let onFinish: () -> Void

    init(session: StudySession, onFinish: @escaping () -> Void) {
        _session = State(initialValue: session)
        self.onFinish = onFinish
    }

    var body: some View {
        if session.isComplete {
            SessionSummaryView(summary: session.summary, onClose: onFinish)
        } else if let question = session.current {
            VStack(spacing: 0) {
                HStack {
                    Text("\(session.position) из \(session.queue.count)").monospacedDigit().foregroundStyle(.secondary)
                    ProgressView(value: Double(session.position - 1), total: Double(max(1, session.queue.count))).frame(maxWidth: 360)
                    Spacer()
                    Text(store.progressFor(question).state.title).font(.caption).padding(.horizontal, 9).padding(.vertical, 5).background(.quaternary, in: Capsule())
                    Button("Завершить") { onFinish() }.buttonStyle(.borderless)
                }.padding(.horizontal, 24).padding(.vertical, 12).background(.bar)

                QuestionInteractionView(question: question, awaitingNext: $awaitingNext, onOutcome: { outcome in
                    previousState = store.progressFor(question).state
                    _ = store.record(outcome, for: question)
                    session.record(outcome)
                    lastOutcome = outcome
                }, onNext: {
                    awaitingNext = false
                    lastOutcome = nil
                    session.advance()
                })
                .id("\(question.id)-\(session.position)")
            }
        }
    }
}

struct QuestionInteractionView: View {
    @EnvironmentObject private var store: AppStore
    let question: Question
    @Binding var awaitingNext: Bool
    let onOutcome: (AttemptOutcome) -> Void
    let onNext: () -> Void
    @State private var displayedOptions: [QuestionOption] = []
    @State private var selectedOptionId: String?
    @State private var outcome: AttemptOutcome?
    @State private var showExplanation = false
    @State private var selectedGlossary: GlossaryEntry?
    @State private var note = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("№ \(question.examNumber)", systemImage: "number").font(.callout.bold())
                    Text(question.topic).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button { store.toggleBookmark(question) } label: { Label("Закладка", systemImage: store.progressFor(question).bookmarked ? "bookmark.fill" : "bookmark") }
                        .keyboardShortcut("b", modifiers: [])
                    Button { store.toggleHard(question) } label: { Label("Сложный", systemImage: store.progressFor(question).manuallyMarkedHard ? "flame.fill" : "flame") }
                }
                Text(question.stem).font(.system(size: 22, weight: .semibold)).textSelection(.enabled)
                FigureView(asset: question.figureAsset)

                VStack(spacing: 10) {
                    ForEach(Array(displayedOptions.enumerated()), id: \.element.id) { index, option in
                        answerButton(option: option, index: index)
                    }
                }

                if outcome == nil {
                    HStack {
                        Button("Не знаю") { answer(.dontKnow, optionId: nil) }
                            .buttonStyle(.borderedProminent).tint(.orange).keyboardShortcut("d", modifiers: [])
                        Button("Объяснить") { answer(.revealedBeforeAnswer, optionId: nil) }
                            .buttonStyle(.bordered).keyboardShortcut("e", modifiers: [])
                        Spacer()
                        Text("Клавиши 1–4 · D · E · B").font(.caption).foregroundStyle(.tertiary)
                    }
                } else {
                    FeedbackBanner(outcome: outcome!, question: question)
                    if showExplanation { ExplanationView(question: question, selectedOptionId: selectedOptionId, onGlossary: { selectedGlossary = $0 }) }
                    MistakeReasonBar(question: question, visible: outcome != .correct)
                    notes
                    Button("Следующий вопрос") { onNext() }
                        .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.return, modifiers: [])
                }
                SourceView(question: question)
            }.padding(28).frame(maxWidth: 900, alignment: .leading)
        }
        .onAppear {
            displayedOptions = store.settings.randomizeOptions ? question.options.shuffled() : question.options
            note = store.progressFor(question).note
        }
        .sheet(item: $selectedGlossary) { term in GlossaryCard(entry: term) }
    }

    @ViewBuilder
    private func answerButton(option: QuestionOption, index: Int) -> some View {
        let isCorrect = option.id == question.correctOptionId
        let selected = selectedOptionId == option.id
        Button {
            guard outcome == nil else { return }
            answer(isCorrect ? .correct : .incorrect, optionId: option.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("\(index + 1)").font(.callout.bold()).frame(width: 25, height: 25).background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                Text(option.text).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                if outcome != nil && isCorrect { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                else if outcome != nil && selected { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
            }.padding(14)
                .background(background(isCorrect: isCorrect, selected: selected), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(border(isCorrect: isCorrect, selected: selected), lineWidth: selected || (outcome != nil && isCorrect) ? 2 : 1))
        }.buttonStyle(.plain).disabled(outcome != nil)
            .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])
    }

    private func background(isCorrect: Bool, selected: Bool) -> Color {
        guard outcome != nil else { return Color.primary.opacity(0.045) }
        if isCorrect { return .green.opacity(0.12) }
        if selected { return .red.opacity(0.12) }
        return Color.primary.opacity(0.045)
    }
    private func border(isCorrect: Bool, selected: Bool) -> Color {
        guard outcome != nil else { return .secondary.opacity(0.2) }
        if isCorrect { return .green }
        if selected { return .red }
        return .secondary.opacity(0.2)
    }

    private func answer(_ value: AttemptOutcome, optionId: String?) {
        guard outcome == nil else { return }
        selectedOptionId = optionId
        outcome = value
        awaitingNext = true
        showExplanation = value != .correct || store.settings.explanationStyle != "Кратко"
        onOutcome(value)
    }

    private var notes: some View {
        DisclosureGroup("Личная заметка") {
            TextEditor(text: $note).font(.body).frame(minHeight: 75).padding(6).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: note) { _, value in store.updateNote(value, for: question) }
        }
    }
}

struct FeedbackBanner: View {
    let outcome: AttemptOutcome
    let question: Question
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: outcome == .correct ? "checkmark.circle.fill" : "lightbulb.fill").font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text("Ответ экзаменационного банка: \(question.officialCorrectAnswerText)")
            }
        }.foregroundStyle(outcome == .correct ? .green : .orange).padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background((outcome == .correct ? Color.green : Color.orange).opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
    private var title: String {
        switch outcome { case .correct: "Верно"; case .incorrect: "Пока неверно"; case .dontKnow: "Хорошо, что сказали честно"; case .revealedBeforeAnswer: "Сначала разберём объяснение" }
    }
}

struct ExplanationView: View {
    @EnvironmentObject private var store: AppStore
    let question: Question
    var selectedOptionId: String? = nil
    var onGlossary: ((GlossaryEntry) -> Void)? = nil
    @State private var layer = 0
    private var terms: [GlossaryEntry] { question.glossaryTerms.compactMap { id in store.glossary.first(where: { $0.id == id }) } }
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Слой", selection: $layer) { Text("Кратко").tag(0); Text("С нуля").tag(1); Text("Почему").tag(2); Text("Другие ответы").tag(3) }
                    .pickerStyle(.segmented).labelsHidden()
                Text(layerText).textSelection(.enabled).lineSpacing(4)
                if !terms.isEmpty {
                    Divider()
                    Text("Термины").font(.caption.bold()).foregroundStyle(.secondary)
                    FlowLayout(spacing: 7) {
                        ForEach(terms) { term in Button(term.term) { onGlossary?(term) }.buttonStyle(.bordered).controlSize(.small) }
                    }
                }
                Label(question.memoryHint, systemImage: "brain.head.profile").font(.callout).foregroundStyle(.secondary)
                if let note = question.legalHistoricalNote {
                    VStack(alignment: .leading, spacing: 3) { Text("Примечание для реальной практики").font(.caption.bold()); Text(note).font(.callout) }
                        .padding(10).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }.padding(7)
        } label: { Label("Объяснение", systemImage: "lightbulb") }
    }
    private var layerText: String {
        switch layer {
        case 0: question.explanationShort
        case 1: question.explanationBeginner
        case 2: question.explanationReasoning
        default:
            if let selectedOptionId, let text = question.wrongOptionExplanations[selectedOptionId] { text }
            else { question.wrongOptionExplanations.values.sorted().joined(separator: "\n\n") }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
    }
}

struct GlossaryCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let entry: GlossaryEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Image(systemName: "character.book.closed.fill").foregroundStyle(.tint); Text(entry.term).font(.title.bold()); Spacer(); Button("Готово") { dismiss() } }
            Text(entry.shortDefinition).font(.title3)
            Text(entry.fromZero)
            Label(entry.radioExample, systemImage: "radio").foregroundStyle(.secondary)
            Button("Я не понимаю этот термин") { store.markConceptWeak(entry.id); dismiss() }.buttonStyle(.borderedProminent)
        }.padding(26).frame(width: 500)
    }
}

struct MistakeReasonBar: View {
    @EnvironmentObject private var store: AppStore
    let question: Question
    let visible: Bool
    @State private var selected: MistakeReason?
    var body: some View {
        if visible {
            VStack(alignment: .leading, spacing: 8) {
                Text("Что помешало? (необязательно)").font(.caption).foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(MistakeReason.allCases) { reason in
                        Button(reason.rawValue) { selected = reason; store.tagMistake(reason, question: question) }
                            .buttonStyle(.bordered).controlSize(.small).tint(selected == reason ? .accentColor : .secondary)
                    }
                }
            }
        }
    }
}

struct SessionSummaryView: View {
    let summary: SessionSummary
    let onClose: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 54)).foregroundStyle(.green)
            Text("Сессия завершена").font(.largeTitle.bold())
            HStack(spacing: 12) {
                StatCard(title: "Верно", value: summary.correct, icon: "checkmark", tint: .green)
                StatCard(title: "Ошибки", value: summary.incorrect, icon: "xmark", tint: .red)
                StatCard(title: "Не знаю", value: summary.dontKnow, icon: "questionmark", tint: .orange)
            }.frame(maxWidth: 700)
            if let hard = summary.topics.max(by: { $0.value < $1.value }) { Text("Больше всего внимания потребовала тема «\(hard.key)».").foregroundStyle(.secondary) }
            Text("Ошибки уже добавлены в расписание. Автоматическое повторение не будет показывать один вопрос подряд.").foregroundStyle(.secondary)
            Button("Вернуться") { onClose() }.buttonStyle(.borderedProminent).controlSize(.large)
        }.padding(36).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MockExamView: View {
    @EnvironmentObject private var store: AppStore
    @State private var questions: [Question] = []
    @State private var index = 0
    @State private var answers: [String: String] = [:]
    @State private var displayed: [QuestionOption] = []
    @State private var finished = false

    var body: some View {
        if questions.isEmpty { intro }
        else if finished { results }
        else { exam }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Image(systemName: "checklist").font(.system(size: 46)).foregroundStyle(.tint)
            Text("Пробный экзамен").font(.largeTitle.bold())
            Text("30 случайных вопросов из полного банка. Проходной результат — 25 из 30. Объяснения откроются только после завершения.").font(.title3).foregroundStyle(.secondary).frame(maxWidth: 650)
            Button("Начать экзамен") { questions = MockExamBuilder().makeExam(from: store.questions); loadOptions() }.buttonStyle(.borderedProminent).controlSize(.large)
            Spacer()
        }.padding(38).frame(maxWidth: .infinity, alignment: .leading).navigationTitle("Пробный экзамен")
    }

    private var exam: some View {
        let question = questions[index]
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack { Text("Вопрос \(index + 1) из 30").monospacedDigit(); ProgressView(value: Double(index + 1), total: 30).frame(maxWidth: 340); Spacer(); Button("Завершить досрочно") { finish() } }
                Text("№ \(question.examNumber)").font(.callout).foregroundStyle(.secondary)
                Text(question.stem).font(.title2.bold())
                FigureView(asset: question.figureAsset)
                ForEach(Array(displayed.enumerated()), id: \.element.id) { optionIndex, option in
                    Button {
                        answers[question.id] = option.id
                        if index == questions.count - 1 { finish() } else { index += 1; loadOptions() }
                    } label: {
                        HStack { Text("\(optionIndex + 1)").font(.callout.bold()).frame(width: 24); Text(option.text).frame(maxWidth: .infinity, alignment: .leading) }.padding(14)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
                    }.buttonStyle(.plain).keyboardShortcut(KeyEquivalent(Character(String(optionIndex + 1))), modifiers: [])
                }
            }.padding(30).frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var results: some View {
        let correct = questions.count(where: { answers[$0.id] == $0.correctOptionId })
        let failed = questions.filter { answers[$0.id] != $0.correctOptionId }
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(correct >= 25 ? "Экзамен сдан" : "Нужно ещё немного практики").font(.largeTitle.bold()).foregroundStyle(correct >= 25 ? .green : .orange)
                Text("\(correct) / 30").font(.system(size: 52, weight: .bold, design: .rounded)).monospacedDigit()
                Text("Проходной результат: 25 / 30").foregroundStyle(.secondary)
                Divider()
                Text("Разбор ошибок").font(.title2.bold())
                ForEach(failed) { question in
                    DisclosureGroup("№ \(question.examNumber)  \(question.stem)") {
                        VStack(alignment: .leading, spacing: 8) { Text("Ответ банка: \(question.officialCorrectAnswerText)").bold(); Text(question.explanationShort) }.padding(.vertical, 8)
                    }
                }
                Button("Новый экзамен") { questions = []; answers = [:]; index = 0; finished = false }.buttonStyle(.borderedProminent)
            }.padding(30).frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func loadOptions() { guard index < questions.count else { return }; displayed = store.settings.randomizeOptions ? questions[index].options.shuffled() : questions[index].options }
    private func finish() {
        guard !finished else { return }
        finished = true
        let correct = questions.count(where: { answers[$0.id] == $0.correctOptionId })
        let failed = questions.filter { answers[$0.id] != $0.correctOptionId }
        store.addMockScore(correct: correct, failed: failed)
    }
}
